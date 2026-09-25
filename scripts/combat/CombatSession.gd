class_name CombatSession
extends RefCounted

## Headless combat rules shared by the combat UI and the run simulator.
## Upgrade hooks read RunUpgradeDatabase so tuning lives in one place.

const STARTING_ENERGY := 3
const CARDS_DRAWN_PER_TURN := 5
const MAX_TURNS := 24
const PLACEHOLDER_STARTER_DECK := [
	"ember_strike",
	"ember_strike",
	"ember_strike",
	"ember_strike",
	"ember_strike",
	"guard_up",
	"guard_up",
	"guard_up",
	"guard_up",
	"burning_oath",
]

const Database := preload("res://scripts/rewards/RunUpgradeDatabase.gd")

var encounter_id: String = ""
var hp: int = 0
var block: int = 0
var energy: int = STARTING_ENERGY
var strength: int = 0
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []
var enemies: Array[EnemyInstance] = []
var minions: Array[MinionInstance] = []
var turn_number: int = 0
var selected_enemy_index: int = 0
var outcome: String = "running"
var combat_log: Array[String] = []

var _card_database := CardDatabase.new()
var _enemy_database := EnemyDatabase.new()
var _temporary_strength: int = 0
var _pending_soul: int = 0
var _pending_pyre_damage: int = 0
var _pending_pyre_burn: int = 0
var _committed := false
var _skill_discount_used := false
var _last_ember_used := false
var _rite_used := false
var _interpose_ready := true
var _strength_cut_used := false
var _brute_raised_this_combat := false
var _chorus_left: int = 0
var _card_attack_bonus: int = 0
var _tithe_spent_for_card := false
var _dead_resolved := {}


func start(next_encounter_id: String) -> void:
	encounter_id = next_encounter_id
	outcome = "running"
	_committed = false
	hp = RunState.current_hp if RunState.current_hp > 0 else 75
	block = 0
	energy = max_energy()
	strength = 0
	_temporary_strength = 0
	_pending_soul = 0
	_pending_pyre_damage = 0
	_pending_pyre_burn = 0
	_skill_discount_used = false
	_last_ember_used = false
	_rite_used = false
	_interpose_ready = true
	_strength_cut_used = false
	_brute_raised_this_combat = false
	_chorus_left = 0
	_card_attack_bonus = 0
	_tithe_spent_for_card = false
	_dead_resolved = {}
	turn_number = 0
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	minions.clear()
	combat_log.clear()
	draw_pile = _create_draw_pile()
	enemies = _create_enemies()
	if enemies.is_empty():
		var fallback := _enemy_database.create_enemy("charred_rat")
		if fallback != null:
			enemies.append(fallback)
	selected_enemy_index = _first_living_enemy_index()
	_log("Combat begins.")
	_start_player_turn()


func is_running() -> bool:
	return outcome == "running"


func is_victory() -> bool:
	return outcome == "victory"


func is_defeat() -> bool:
	return outcome == "defeat"


func max_energy() -> int:
	var bonus := 0
	if turn_number <= 1:
		bonus = _stacks("ember_capacity") * Database.effect_int("ember_capacity", "energy_per_stack", 1)
	return STARTING_ENERGY + bonus


func select_enemy(index: int) -> void:
	if not _is_living_enemy_index(index):
		return
	selected_enemy_index = index


func focus_lowest_hp_enemy() -> void:
	var best_index := -1
	var best_hp := 999999
	for index in range(enemies.size()):
		if not _is_living_enemy_index(index):
			continue
		if enemies[index].hp < best_hp:
			best_hp = enemies[index].hp
			best_index = index
	if best_index >= 0:
		selected_enemy_index = best_index


func get_play_cost(card_data: CardData) -> int:
	if card_data == null:
		return 99
	var cost := card_data.cost
	if cost < 0:
		return cost
	if (
		card_data.card_type == "Skill"
		and _stacks("ember_step") >= Database.effect_int("ember_step", "skill_discount_min_stacks", 2)
		and not _skill_discount_used
	):
		cost = maxi(0, cost - Database.effect_int("ember_step", "skill_discount", 1))
	return cost


func get_incoming_damage() -> int:
	var total := 0
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var action := enemy.get_current_action()
		match str(action.get("type", "")):
			"attack":
				total += _preview_attack_damage(enemy, int(action.get("amount", 0)))
			"attack_block":
				total += _preview_attack_damage(enemy, int(action.get("attack_amount", 0)))
			_:
				pass
	return total


func attack_bonus_for(card_data: CardData) -> int:
	if card_data == null or card_data.card_type != "Attack":
		return 0

	var bonus := 0
	var crushing_stacks := _stacks("crushing_swing")
	if crushing_stacks > 0 and card_data.cost >= Database.effect_int("crushing_swing", "min_cost", 2):
		bonus += crushing_stacks * Database.effect_int("crushing_swing", "damage_per_stack", 3)
		if _has_living_minion("brute"):
			bonus += Database.effect_int("crushing_swing", "brute_bonus", 2)

	if _stacks("tithe_blade") > 0 and _total_soul() >= Database.effect_int("tithe_blade", "spend_threshold", 12):
		bonus += Database.effect_int("tithe_blade", "bonus_damage", 5)

	return bonus


func play_card(card_instance: CardInstance) -> bool:
	if not is_running() or card_instance == null or not hand.has(card_instance):
		return false

	var card_data := _card_database.get_card(card_instance.card_id)
	if card_data == null or not card_data.is_playable():
		return false

	var cost := get_play_cost(card_data)
	if energy < cost:
		return false

	var target_index := _selected_living_enemy_index()
	if card_data.target_type == "Enemy" and target_index == -1:
		return false

	energy -= cost
	if card_data.card_type == "Skill" and cost < card_data.cost:
		_skill_discount_used = true

	_begin_attack_bonus(card_data)
	_log("Played %s." % card_data.display_name)
	_resolve_card_effects(card_data, target_index)
	_resolve_rattling_volley(card_data, target_index)
	_move_card_to_discard(card_instance)
	_finish_if_combat_over()
	return true


func end_turn() -> void:
	if not is_running():
		return

	_log("Player ends the turn.")
	_resolve_burn_cards_in_hand()
	_resolve_minion_attacks()
	_resolve_enemy_burn_ticks()
	if _finish_if_combat_over():
		return

	_discard_hand()
	_clear_temporary_strength()
	if hp <= 0:
		_commit_defeat()
		return

	_resolve_enemy_turn()
	if _finish_if_combat_over():
		return
	if hp <= 0:
		_commit_defeat()
		return

	_choose_next_enemy_intents()
	_start_player_turn()


func living_minion_count() -> int:
	var count := 0
	for minion in minions:
		if minion.is_alive():
			count += 1
	return count


func _start_player_turn() -> void:
	if not is_running():
		return

	turn_number += 1
	if turn_number > MAX_TURNS:
		_log("The fight drags on until your flame gutters.")
		_commit_defeat()
		return

	_skill_discount_used = false
	_interpose_ready = true
	if turn_number == 1:
		block = 0
	elif _stacks("hold_the_line") > 0:
		var denominator := maxi(1, Database.effect_int("hold_the_line", "retain_denominator", 2))
		var numerator := Database.effect_int("hold_the_line", "retain_numerator", 1)
		block = int((float(block) * float(numerator)) / float(denominator))
		_log("Hold the Line keeps %d Block." % block)
	else:
		block = 0

	for minion in minions:
		if minion.is_alive():
			minion.block = 0

	energy = max_energy()
	_chorus_left = _stacks("chorus_of_ash") * Database.effect_int("chorus_of_ash", "draws_per_stack", 1)
	if turn_number == 1:
		_apply_combat_start_relics()
		_apply_ash_reserves()
		_apply_opening_pyre()
		if _finish_if_combat_over():
			return
		_raise_free_skeleton()

	var draw_count := CARDS_DRAWN_PER_TURN
	if _stacks("ember_step") > 0:
		draw_count += Database.effect_int("ember_step", "bonus_draw", 1)
	_draw_cards(draw_count)
	_perform_raises()
	_log("Turn %d begins." % turn_number)


func _apply_ash_reserves() -> void:
	var stacks := _stacks("ash_reserves")
	if stacks <= 0:
		return
	var amount := stacks * Database.effect_int("ash_reserves", "block_per_stack", 3)
	block += amount
	_log("Ash Reserves grant %d Block." % amount)


func _apply_opening_pyre() -> void:
	var damage := RunState.opening_pyre_damage
	var burn := RunState.opening_pyre_burn
	if damage <= 0 and burn <= 0:
		return

	RunState.opening_pyre_damage = 0
	RunState.opening_pyre_burn = 0
	_log("Opening pyre surges for %d damage." % damage)
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		if damage > 0:
			enemy.take_damage(damage)
		if burn > 0:
			enemy.apply_burn(burn)
	_resolve_enemy_deaths(false)


func _raise_free_skeleton() -> void:
	if _stacks("bone_ranks") < Database.effect_int("bone_ranks", "free_summon_min_stacks", 1):
		return
	if living_minion_count() >= Database.MINION_CAP:
		return
	_summon_minion("skeleton")
	_consume_chorus_draw()


func _perform_raises() -> void:
	var grave_raises := _stacks("grave_call") * Database.effect_int("grave_call", "raises_per_stack", 1)
	var brute_only := grave_raises <= 0 and _stacks("brute_summons") > 0 and not _brute_raised_this_combat
	var raises := grave_raises
	if brute_only:
		raises = 1

	for _index in range(raises):
		if living_minion_count() >= Database.MINION_CAP:
			break
		var raised := false
		if _can_raise_brute():
			RunState.corpses -= Database.effect_int("brute_summons", "corpse_cost", 2)
			_summon_minion("brute")
			if brute_only:
				_brute_raised_this_combat = true
			raised = true
		elif _stacks("grave_call") > 0 and RunState.corpses >= 1:
			RunState.corpses -= 1
			_summon_minion("skeleton")
			raised = true
		if not raised:
			break
		_consume_chorus_draw()


func _consume_chorus_draw() -> void:
	if _chorus_left <= 0:
		return
	_chorus_left -= 1
	_draw_cards(1)
	_log("Chorus of Ash draws a card.")


func _can_raise_brute() -> bool:
	if _stacks("brute_summons") <= 0:
		return false
	return RunState.corpses >= Database.effect_int("brute_summons", "corpse_cost", 2)


func _summon_minion(kind: String) -> void:
	var minion := MinionInstance.new()
	if kind == "brute":
		var stacks := _stacks("brute_summons")
		var minion_hp := Database.BRUTE_BASE_HP + stacks * Database.effect_int("brute_summons", "hp_per_stack", 4)
		var minion_attack := Database.BRUTE_BASE_ATTACK + stacks * Database.effect_int("brute_summons", "attack_per_stack", 3)
		minion.setup("brute", "Brute", minion_hp, minion_attack)
		if stacks >= Database.effect_int("brute_summons", "block_at_stacks", 2):
			minion.block = Database.effect_int("brute_summons", "block_amount", 4)
	else:
		var stacks := _stacks("bone_ranks")
		var minion_hp := Database.SKELETON_BASE_HP + stacks * Database.effect_int("bone_ranks", "hp_per_stack", 3)
		var minion_attack := Database.SKELETON_BASE_ATTACK + stacks * Database.effect_int("bone_ranks", "attack_per_stack", 2)
		minion.setup("skeleton", "Skeleton", minion_hp, minion_attack)

	minions.append(minion)
	_log("Raised a %s (%d HP, %d attack)." % [minion.display_name, minion.max_hp, minion.attack])


func _begin_attack_bonus(card_data: CardData) -> void:
	_card_attack_bonus = 0
	_tithe_spent_for_card = false
	if card_data.card_type != "Attack":
		return

	var crushing_stacks := _stacks("crushing_swing")
	if crushing_stacks > 0 and card_data.cost >= Database.effect_int("crushing_swing", "min_cost", 2):
		_card_attack_bonus += crushing_stacks * Database.effect_int("crushing_swing", "damage_per_stack", 3)
		if _has_living_minion("brute"):
			_card_attack_bonus += Database.effect_int("crushing_swing", "brute_bonus", 2)

	var threshold := Database.effect_int("tithe_blade", "spend_threshold", 12)
	if _stacks("tithe_blade") > 0 and _total_soul() >= threshold:
		_card_attack_bonus += Database.effect_int("tithe_blade", "bonus_damage", 5)
		_spend_soul(threshold)
		_tithe_spent_for_card = true
		_log("Tithe Blade spends %d Soul." % threshold)


func _resolve_card_effects(card_data: CardData, target_index: int) -> void:
	var dealt_damage := false
	for effect in card_data.effects:
		match str(effect.get("type", "")):
			"damage":
				if _apply_damage_effect(target_index, int(effect.get("amount", 0)) + _card_attack_bonus):
					dealt_damage = true
			"block":
				_gain_block(int(effect.get("amount", 0)))
			"draw":
				_draw_cards(int(effect.get("amount", 0)))
			"temp_strength":
				_gain_temporary_strength(int(effect.get("amount", 0)))
			"add_status_to_discard":
				_add_status_to_discard(str(effect.get("card_id", "burn")), int(effect.get("amount", 1)))
			"heal":
				_heal(int(effect.get("amount", 0)))
			"enemy_burn":
				_apply_enemy_burn(target_index, int(effect.get("amount", 0)))
			"enemy_burn_all":
				_apply_enemy_burn_all(int(effect.get("amount", 0)))
			_:
				pass

	if dealt_damage and card_data.card_type == "Attack":
		_pending_soul += _stacks("tithe_blade") * Database.effect_int("tithe_blade", "soul_per_stack", 1)


func _resolve_rattling_volley(card_data: CardData, target_index: int) -> void:
	var stacks := _stacks("rattling_volley")
	if stacks <= 0 or card_data.card_type != "Attack":
		return
	if card_data.cost > Database.effect_int("rattling_volley", "max_card_cost", 1):
		return

	var damage := stacks * Database.effect_int("rattling_volley", "damage_per_stack", 2)
	if damage <= 0:
		return

	var target := target_index
	if not _is_living_enemy_index(target):
		target = _first_living_enemy_index()
	if target == -1:
		return

	for minion in minions:
		if not minion.is_alive() or minion.kind != "skeleton":
			continue
		if not _is_living_enemy_index(target):
			target = _first_living_enemy_index()
		if target == -1:
			return
		var enemy := enemies[target]
		var dealt := enemy.take_damage(damage)
		_log("%s's volley hits %s for %d." % [minion.display_name, enemy.display_name, dealt])
	_resolve_enemy_deaths(true)


func _apply_damage_effect(target_index: int, amount: int) -> bool:
	if not _is_living_enemy_index(target_index):
		return false

	var enemy := enemies[target_index]
	var total := amount + strength
	var dealt := enemy.take_damage(total)
	_log("%s takes %d damage." % [enemy.display_name, dealt])
	_resolve_enemy_deaths(true)
	if not enemy.is_alive():
		selected_enemy_index = _first_living_enemy_index()
	return dealt > 0


func _gain_block(amount: int) -> void:
	if amount <= 0:
		return
	block += amount
	_log("Gained %d block." % amount)


func _heal(amount: int) -> void:
	var max_hp := RunState.max_hp if RunState.max_hp > 0 else 75
	var healed: int = mini(amount, max_hp - hp)
	hp += healed
	if healed > 0:
		_log("Healed %d HP." % healed)


func _gain_temporary_strength(amount: int) -> void:
	strength += amount
	_temporary_strength += amount
	_log("Gained %d Strength this turn." % amount)


func _clear_temporary_strength() -> void:
	if _temporary_strength <= 0:
		return
	strength -= _temporary_strength
	_temporary_strength = 0


func _apply_enemy_burn(target_index: int, amount: int) -> void:
	if not _is_living_enemy_index(target_index):
		return
	var enemy := enemies[target_index]
	enemy.apply_burn(amount)
	_log("Applied %d Burn to %s." % [amount, enemy.display_name])


func _apply_enemy_burn_all(amount: int) -> void:
	for enemy_index in range(enemies.size()):
		if _is_living_enemy_index(enemy_index):
			_apply_enemy_burn(enemy_index, amount)


func _apply_burn_to_random_enemy(amount: int) -> void:
	var living_indices: Array[int] = []
	for enemy_index in range(enemies.size()):
		if _is_living_enemy_index(enemy_index):
			living_indices.append(enemy_index)
	if living_indices.is_empty():
		return
	var chosen_index: int = living_indices[RNG.rand_int(0, living_indices.size() - 1)]
	_apply_enemy_burn(chosen_index, amount)


func _resolve_enemy_burn_ticks() -> void:
	for enemy in enemies:
		if not enemy.is_alive() or enemy.burn_stacks <= 0:
			continue
		var burn_damage := enemy.burn_stacks
		var dealt := enemy.take_damage(burn_damage)
		enemy.burn_stacks = maxi(0, enemy.burn_stacks - 1)
		_log("%s suffers %d Burn damage." % [enemy.display_name, dealt])
	_resolve_enemy_deaths(true)
	selected_enemy_index = _first_living_enemy_index()


func _resolve_minion_attacks() -> void:
	for minion in minions:
		if minion.is_alive():
			_minion_attack(minion)


func _minion_attack(minion: MinionInstance) -> void:
	if not minion.is_alive():
		return
	var target := _selected_living_enemy_index()
	if target == -1:
		return
	var enemy := enemies[target]
	var dealt := enemy.take_damage(minion.attack)
	_log("%s attacks %s for %d." % [minion.display_name, enemy.display_name, dealt])
	_resolve_enemy_deaths(true)


func _resolve_burn_cards_in_hand() -> void:
	var remaining: Array[CardInstance] = []
	for card_instance in hand:
		if card_instance.card_id == "burn":
			_log("Burn sears you for 2 damage, then exhausts.")
			_lose_hp(2)
			exhaust_pile.append(card_instance)
		else:
			remaining.append(card_instance)
	hand = remaining


func _discard_hand() -> void:
	for card_instance in hand:
		discard_pile.append(card_instance)
	hand.clear()


func _resolve_enemy_turn() -> void:
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		enemy.block = 0
		var action := enemy.get_current_action()
		match str(action.get("type", "")):
			"attack":
				_resolve_enemy_attack(enemy, int(action.get("amount", 0)))
			"block":
				var block_amount := int(action.get("amount", 0))
				enemy.gain_block(block_amount)
				_log("%s gains %d block." % [enemy.display_name, block_amount])
			"buff_strength":
				_resolve_enemy_strength(enemy, int(action.get("amount", 0)))
			"add_burn":
				var burn_amount := int(action.get("amount", 1))
				_add_status_to_discard("burn", burn_amount)
				_log("%s scatters Burn into your discard pile." % enemy.display_name)
			"attack_block":
				_resolve_enemy_attack(enemy, int(action.get("attack_amount", 0)))
				var followup_block := int(action.get("block_amount", 0))
				enemy.gain_block(followup_block)
				_log("%s gains %d block." % [enemy.display_name, followup_block])
			"big_attack_warning":
				enemy.heavy_attack_ready = true
				_log("%s draws in a thunderous breath." % enemy.display_name)
			_:
				_log("%s hesitates." % enemy.display_name)

		if _finish_if_combat_over():
			return


func _resolve_enemy_strength(enemy: EnemyInstance, amount: int) -> void:
	var granted := amount
	if _stacks("break_intent") > 0 and not _strength_cut_used:
		granted = maxi(0, granted - Database.effect_int("break_intent", "strength_cut", 2))
		_strength_cut_used = true
		_log("Break Intent disrupts %s." % enemy.display_name)
	if granted > 0:
		enemy.gain_strength(granted)
		_log("%s gains %d Strength." % [enemy.display_name, granted])


func _preview_attack_damage(enemy: EnemyInstance, amount: int) -> int:
	var total := amount + enemy.strength
	var stacks := _stacks("break_intent")
	if stacks > 0:
		total = maxi(0, total - stacks * Database.effect_int("break_intent", "damage_reduction_per_stack", 2))
		if stacks >= Database.effect_int("break_intent", "halve_min_stacks", 2) and enemy.heavy_attack_ready:
			total = int(float(total) / 2.0)
	return total


func _resolve_enemy_attack(enemy: EnemyInstance, amount: int) -> void:
	var total := _preview_attack_damage(enemy, amount)
	if enemy.heavy_attack_ready:
		enemy.heavy_attack_ready = false

	if _try_interpose(enemy, total):
		_finish_if_combat_over()
		return

	var blocked_damage: int = mini(block, total)
	var damage: int = total - blocked_damage
	block -= blocked_damage
	_log("%s attacks for %d. Block absorbs %d. You take %d damage." % [
		enemy.display_name,
		total,
		blocked_damage,
		damage,
	])
	_lose_hp(damage)


func _try_interpose(enemy: EnemyInstance, amount: int) -> bool:
	if _stacks("interpose") <= 0 or not _interpose_ready:
		return false
	var minion := _lowest_hp_minion()
	if minion == null:
		return false

	_interpose_ready = false
	_log("%s intercepts %s's attack." % [minion.display_name, enemy.display_name])
	_damage_minion(minion, amount)
	return true


func _damage_minion(minion: MinionInstance, amount: int) -> void:
	minion.take_damage(amount)
	if minion.is_alive():
		_log("%s holds at %d HP." % [minion.display_name, minion.hp])
		return

	if not _rite_used and _stacks("unfinished_rite") > 0:
		_rite_used = true
		minion.hp = 1
		_log("Unfinished Rite pulls %s back to 1 HP." % minion.display_name)
		_minion_attack(minion)
		return

	_log("%s falls." % minion.display_name)
	_on_minion_died(minion)


func _on_minion_died(minion: MinionInstance) -> void:
	var stacks := _stacks("pyre_funeral")
	if stacks <= 0:
		return

	var target := _first_living_enemy_index()
	if target == -1:
		_pending_soul += stacks * Database.effect_int("pyre_funeral", "soul_per_stack", 1)
		return

	var enemy := enemies[target]
	var damage := stacks * Database.effect_int("pyre_funeral", "damage_per_stack", 5)
	var dealt := enemy.take_damage(damage)
	_log("Pyre Funeral burns %s for %d." % [enemy.display_name, dealt])
	if _stacks("chain_ash") > 0 and enemy.is_alive():
		enemy.apply_burn(Database.effect_int("chain_ash", "burn", 2))
	_pending_soul += stacks * Database.effect_int("pyre_funeral", "soul_per_stack", 1)
	_resolve_enemy_deaths(true)


func _lose_hp(amount: int) -> void:
	if amount <= 0 or not is_running():
		return
	if hp - amount <= 0 and _stacks("last_ember") > 0 and not _last_ember_used:
		_last_ember_used = true
		hp = Database.effect_int("last_ember", "survive_hp", 1)
		block += Database.effect_int("last_ember", "block", 6)
		_log("Last Ember keeps you at %d HP." % hp)
		return
	hp -= amount


func _resolve_enemy_deaths(bank_corpses: bool) -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		var found := false
		for enemy in enemies:
			if enemy.is_alive() or _dead_resolved.has(enemy.get_instance_id()):
				continue
			found = true
			_dead_resolved[enemy.get_instance_id()] = true
			_log("%s is defeated." % enemy.display_name)
			if bank_corpses:
				_on_enemy_corpse()
		if not found:
			return


func _on_enemy_corpse() -> void:
	var cinder_stacks := _stacks("cinder_corpse")
	var others := _living_enemy_count()
	if cinder_stacks > 0 and others > 0:
		var splash := cinder_stacks * Database.effect_int("cinder_corpse", "splash_per_stack", 4)
		var burn := Database.effect_int("chain_ash", "burn", 2) if _stacks("chain_ash") > 0 else 0
		for enemy in enemies:
			if not enemy.is_alive():
				continue
			var dealt := enemy.take_damage(splash)
			_log("Cinder Corpse bursts into %s for %d." % [enemy.display_name, dealt])
			if burn > 0 and enemy.is_alive():
				enemy.apply_burn(burn)
		return

	if cinder_stacks > 0:
		_pending_pyre_damage += cinder_stacks * Database.effect_int("cinder_corpse", "pyre_per_stack", 4)
		if _stacks("chain_ash") > 0:
			_pending_pyre_burn += Database.effect_int("chain_ash", "burn", 2)
		_log("The corpse is banked as opening pyre.")
		return

	RunState.corpses = mini(Database.CORPSE_CAP, RunState.corpses + 1)
	_log("A corpse remains. Corpses: %d." % RunState.corpses)


func _finish_if_combat_over() -> bool:
	if not is_running():
		return true
	if _all_enemies_defeated():
		_commit_victory()
		return true
	if hp <= 0:
		_commit_defeat()
		return true
	return false


func _commit_victory() -> void:
	if _committed:
		return
	_committed = true
	outcome = "victory"
	hp = maxi(hp, 1)
	RunState.current_hp = hp
	_commit_soul()
	_commit_pyre()
	_log("Victory.")


func _commit_defeat() -> void:
	if _committed:
		return
	_committed = true
	outcome = "defeat"
	_log("Defeat.")


func _commit_soul() -> void:
	var cache_stacks := _stacks("soul_cache")
	_pending_soul += cache_stacks * Database.effect_int("soul_cache", "soul_per_stack_on_victory", 2)

	var interest_stacks := _stacks("soul_interest")
	if interest_stacks > 0:
		var projected := RunState.soul + _pending_soul
		var flat := interest_stacks * Database.effect_int("soul_interest", "flat_per_stack", 2)
		var divisor := maxi(1, Database.effect_int("soul_interest", "interest_divisor", 5))
		var cap := Database.effect_int("soul_interest", "interest_cap", 6)
		var interest := mini(cap, int(float(projected) / float(divisor)))
		_pending_soul += flat + interest

	if _pending_soul > 0:
		RunState.soul += _pending_soul
		_log("Gained %d Soul." % _pending_soul)
	_pending_soul = 0


func _commit_pyre() -> void:
	if _stacks("chain_ash") > 0 and _pending_pyre_burn <= 0:
		_pending_pyre_burn += Database.effect_int("chain_ash", "burn", 3)
	if _pending_pyre_damage <= 0 and _pending_pyre_burn <= 0:
		return
	var cap := Database.effect_int("cinder_corpse", "pyre_cap", 18)
	RunState.opening_pyre_damage = mini(cap, RunState.opening_pyre_damage + _pending_pyre_damage)
	RunState.opening_pyre_burn = mini(8, RunState.opening_pyre_burn + _pending_pyre_burn)
	_pending_pyre_damage = 0
	_pending_pyre_burn = 0


func _choose_next_enemy_intents() -> void:
	for enemy in enemies:
		if enemy.is_alive():
			enemy.advance_action()


func _apply_combat_start_relics() -> void:
	for relic_id in RunState.relics:
		match str(relic_id):
			"cracked_helm":
				block += 2
				_log("Cracked Helm grants 2 Block.")
			"ember_heart":
				_heal(2)
				_log("Ember Heart restores 2 HP.")
			"ash_shield":
				block += 3
				_log("Ash Shield grants 3 Block.")
			"smoldering_brand":
				strength += 1
				_log("Smoldering Brand grants 1 Strength.")
			"smoldering_tinder":
				_apply_burn_to_random_enemy(2)
				_log("Smoldering Tinder ignites a foe.")
			_:
				pass


func _create_draw_pile() -> Array[CardInstance]:
	var source_deck: Array = RunState.deck.duplicate()
	if source_deck.is_empty():
		source_deck = PLACEHOLDER_STARTER_DECK.duplicate()

	var instances: Array[CardInstance] = []
	for card_id in source_deck:
		instances.append(CardInstance.new().setup(str(card_id)))
	return _shuffle_cards(instances)


func _create_enemies() -> Array[EnemyInstance]:
	var created: Array[EnemyInstance] = []
	for enemy_id in EncounterTable.enemy_ids_for(encounter_id):
		var enemy := _enemy_database.create_enemy(enemy_id)
		if enemy != null:
			created.append(enemy)
	return created


func _draw_cards(amount: int) -> void:
	for _index in range(amount):
		if draw_pile.is_empty():
			_refill_draw_pile()
		if draw_pile.is_empty():
			return
		hand.append(draw_pile.pop_back())


func _refill_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile = _shuffle_cards(discard_pile)
	discard_pile.clear()


func _shuffle_cards(cards: Array[CardInstance]) -> Array[CardInstance]:
	var shuffled: Array = RNG.shuffle_array(cards)
	var typed_cards: Array[CardInstance] = []
	for card in shuffled:
		typed_cards.append(card)
	return typed_cards


func _add_status_to_discard(card_id: String, amount: int) -> void:
	for _index in range(amount):
		discard_pile.append(CardInstance.new().setup(card_id, false, true))


func _move_card_to_discard(card_instance: CardInstance) -> void:
	var card_index := hand.find(card_instance)
	if card_index == -1:
		return
	hand.remove_at(card_index)
	discard_pile.append(card_instance)


func _selected_living_enemy_index() -> int:
	if _is_living_enemy_index(selected_enemy_index):
		return selected_enemy_index
	selected_enemy_index = _first_living_enemy_index()
	return selected_enemy_index


func _first_living_enemy_index() -> int:
	for index in range(enemies.size()):
		if _is_living_enemy_index(index):
			return index
	return -1


func _is_living_enemy_index(index: int) -> bool:
	return index >= 0 and index < enemies.size() and enemies[index].is_alive()


func _living_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.is_alive():
			count += 1
	return count


func _all_enemies_defeated() -> bool:
	if enemies.is_empty():
		return false
	return _living_enemy_count() == 0


func _has_living_minion(kind: String) -> bool:
	for minion in minions:
		if minion.is_alive() and minion.kind == kind:
			return true
	return false


func _lowest_hp_minion() -> MinionInstance:
	var chosen: MinionInstance = null
	for minion in minions:
		if not minion.is_alive():
			continue
		if chosen == null or minion.hp < chosen.hp:
			chosen = minion
	return chosen


func _stacks(upgrade_id: String) -> int:
	return int(RunState.upgrade_stacks.get(upgrade_id, 0))


func _total_soul() -> int:
	return RunState.soul + _pending_soul


func _spend_soul(amount: int) -> void:
	var from_pending: int = mini(_pending_soul, amount)
	_pending_soul -= from_pending
	var remainder := amount - from_pending
	RunState.soul = maxi(0, RunState.soul - remainder)


func _log(message: String) -> void:
	combat_log.append(message)
	if combat_log.size() > 12:
		combat_log.pop_front()
