extends PanelContainer

const STARTING_ENERGY := 3
const CARDS_DRAWN_PER_TURN := 5
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

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")
const ENEMY_VIEW_SCENE := preload("res://scenes/combat/EnemyView.tscn")
const RewardManagerScript := preload("res://scripts/rewards/RewardManager.gd")

@onready var encounter_title: Label = %EncounterTitle
@onready var enemies_container: VBoxContainer = %EnemiesContainer
@onready var player_stats_label: Label = %PlayerStatsLabel
@onready var pile_stats_label: Label = %PileStatsLabel
@onready var hand_container: HBoxContainer = %HandContainer
@onready var combat_log_label: Label = %CombatLogLabel
@onready var end_turn_button: Button = %EndTurnButton

var encounter_id: String = "charred_rat"

var hp: int = 0
var block: int = 0
var energy: int = STARTING_ENERGY
var strength: int = 0
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []

var _enemies: Array[EnemyInstance] = []
var _turn_number: int = 0
var _combat_started := false
var _combat_log: Array[String] = []
var _card_database := CardDatabase.new()
var _enemy_database := EnemyDatabase.new()
var _selected_enemy_index: int = 0
var _temporary_strength: int = 0


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	call_deferred("_start_combat")


func set_payload(payload: Dictionary) -> void:
	encounter_id = payload.get("encounter_id", encounter_id)


func _start_combat() -> void:
	if _combat_started:
		return

	_combat_started = true
	encounter_title.text = "Encounter: %s" % encounter_id
	hp = RunState.current_hp if RunState.current_hp > 0 else 75
	block = 0
	energy = STARTING_ENERGY
	strength = 0
	_temporary_strength = 0
	draw_pile = _create_draw_pile()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	_enemies = _create_enemy_encounter()
	_selected_enemy_index = _get_first_living_enemy_index()

	_log("Combat begins.")
	_log("Your deck is shuffled into the draw pile.")
	_start_player_turn()


func _create_draw_pile() -> Array[CardInstance]:
	var source_deck: Array = RunState.deck.duplicate()

	if source_deck.is_empty():
		source_deck = PLACEHOLDER_STARTER_DECK.duplicate()

	var instances: Array[CardInstance] = []
	for card_id in source_deck:
		instances.append(CardInstance.new().setup(str(card_id)))

	return _shuffle_card_instances(instances)


func _create_enemy_encounter() -> Array[EnemyInstance]:
	var enemy_ids := _get_enemy_ids_for_current_encounter()
	var enemies: Array[EnemyInstance] = []

	for enemy_id in enemy_ids:
		var enemy := _enemy_database.create_enemy(enemy_id)
		if enemy != null:
			enemies.append(enemy)

	return enemies


func _get_enemy_ids_for_current_encounter() -> Array[String]:
	var enemy_ids: Array[String] = []

	match encounter_id:
		"charred_rat", "furnace_cultist", "molten_guard", "bellows_saint",
		"ember_warden", "cinder_colossus", "furnace_hound", "ash_zealot", "ember_regent":
			enemy_ids.append(encounter_id)
		_:
			enemy_ids.append("charred_rat")

	return enemy_ids


func _start_player_turn() -> void:
	_turn_number += 1
	energy = STARTING_ENERGY
	block = 0

	if _turn_number == 1:
		_apply_combat_start_relics()

	_draw_cards(CARDS_DRAWN_PER_TURN)
	_log("Turn %d begins. Drew up to %d cards." % [_turn_number, CARDS_DRAWN_PER_TURN])
	_refresh_ui()


func _draw_cards(amount: int) -> void:
	for _index in range(amount):
		if draw_pile.is_empty():
			_refill_draw_pile_from_discard()

		if draw_pile.is_empty():
			return

		hand.append(draw_pile.pop_back())


func _refill_draw_pile_from_discard() -> void:
	if discard_pile.is_empty():
		return

	draw_pile = _shuffle_card_instances(discard_pile)
	discard_pile.clear()
	_log("Discard pile shuffled into draw pile.")


func _on_end_turn_pressed() -> void:
	_log("Player ends the turn.")
	_resolve_burn_cards_at_end_of_turn()
	_discard_hand()
	_clear_temporary_strength()

	if _is_defeated():
		_handle_defeat()
		return

	_resolve_enemy_turn()

	if _is_defeated():
		_handle_defeat()
		return

	_choose_next_enemy_intents()
	_start_player_turn()


func _discard_hand() -> void:
	for card_instance in hand:
		discard_pile.append(card_instance)

	hand.clear()


func _resolve_enemy_turn() -> void:
	for enemy in _enemies:
		if not enemy.is_alive():
			continue

		var action := _get_enemy_action(enemy)
		match action.get("type", ""):
			"attack":
				_resolve_enemy_attack(enemy, int(action.get("amount", 0)))
			"block":
				var block_amount := int(action.get("amount", 0))
				enemy.gain_block(block_amount)
				_log("%s gains %d block." % [enemy.display_name, block_amount])
			"buff_strength":
				var strength_amount := int(action.get("amount", 0))
				enemy.gain_strength(strength_amount)
				_log("%s gains %d Strength." % [enemy.display_name, strength_amount])
			"add_burn":
				var burn_amount := int(action.get("amount", 1))
				_add_status_to_discard("burn", burn_amount)
				_log("%s scatters Burn into your discard pile." % enemy.display_name)
			"attack_block":
				_resolve_enemy_attack(enemy, int(action.get("attack_amount", 0)))
				var followup_block_amount := int(action.get("block_amount", 0))
				enemy.gain_block(followup_block_amount)
				_log("%s gains %d block." % [enemy.display_name, followup_block_amount])
			"big_attack_warning":
				_log("%s draws in a thunderous breath." % enemy.display_name)
			_:
				_log("%s hesitates." % enemy.display_name)


func _resolve_enemy_attack(enemy: EnemyInstance, amount: int) -> void:
	var total_amount := amount + enemy.strength
	var blocked_damage: int = min(block, total_amount)
	var damage: int = total_amount - blocked_damage
	block -= blocked_damage
	hp -= damage
	_log("%s attacks for %d. Block absorbs %d. You take %d damage." % [
		enemy.display_name,
		total_amount,
		blocked_damage,
		damage,
	])


func _choose_next_enemy_intents() -> void:
	for enemy in _enemies:
		if enemy.is_alive():
			enemy.advance_action()


func _get_enemy_action(enemy: EnemyInstance) -> Dictionary:
	return enemy.get_current_action()


func _shuffle_card_instances(cards: Array[CardInstance]) -> Array[CardInstance]:
	var shuffled: Array = RNG.shuffle_array(cards)
	var typed_cards: Array[CardInstance] = []

	for card in shuffled:
		typed_cards.append(card)

	return typed_cards


func _on_card_play_requested(card_instance: CardInstance) -> void:
	_play_card(card_instance)


func _play_card(card_instance: CardInstance) -> void:
	if not hand.has(card_instance):
		_log("That card is no longer in your hand.")
		return

	var card_data := _card_database.get_card(card_instance.card_id)
	if card_data == null:
		_log("Unknown card: %s." % card_instance.card_id)
		return

	if not card_data.is_playable():
		_log("%s cannot be played." % card_data.display_name)
		return

	if energy < card_data.cost:
		_log("Not enough energy for %s." % card_data.display_name)
		return

	var target_index := _get_selected_living_enemy_index()
	if card_data.target_type == "Enemy" and target_index == -1:
		_log("%s needs a living enemy target." % card_data.display_name)
		return

	energy -= card_data.cost
	_log("Played %s." % card_data.display_name)
	_resolve_card_effects(card_data, target_index)
	_move_card_from_hand_to_discard(card_instance)

	if _are_all_enemies_defeated():
		_handle_victory()
		return

	_refresh_ui()


func _resolve_card_effects(card_data: CardData, target_index: int) -> void:
	for effect in card_data.effects:
		match effect.get("type", ""):
			"damage":
				_apply_damage_effect(target_index, int(effect.get("amount", 0)))
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
			_:
				_log("Unhandled effect: %s." % effect.get("type", "unknown"))


func _apply_damage_effect(target_index: int, amount: int) -> void:
	if target_index < 0 or target_index >= _enemies.size():
		_log("No enemy target.")
		return

	var enemy := _enemies[target_index]
	if not enemy.is_alive():
		_log("%s is already defeated." % enemy.display_name)
		return

	var total_damage := amount + strength
	var enemy_block := enemy.block
	var blocked_damage: int = min(enemy_block, total_damage)
	var damage := enemy.take_damage(total_damage)
	_log("%s takes %d damage. Block absorbs %d." % [
		enemy.display_name,
		damage,
		blocked_damage,
	])

	if not enemy.is_alive():
		_log("%s is defeated." % enemy.display_name)
		_selected_enemy_index = _get_first_living_enemy_index()


func _gain_block(amount: int) -> void:
	block += amount
	_log("Gained %d block." % amount)


func _heal(amount: int) -> void:
	var max_hp := RunState.max_hp if RunState.max_hp > 0 else 75
	var healed := min(amount, max_hp - hp)
	hp += healed
	_log("Healed %d HP." % healed)


func _gain_temporary_strength(amount: int) -> void:
	strength += amount
	_temporary_strength += amount
	_log("Gained %d Strength this turn." % amount)


func _clear_temporary_strength() -> void:
	if _temporary_strength <= 0:
		return

	strength -= _temporary_strength
	_log("Temporary Strength fades.")
	_temporary_strength = 0


func _add_status_to_discard(card_id: String, amount: int) -> void:
	for _index in range(amount):
		discard_pile.append(CardInstance.new().setup(card_id, false, true))

	_log("Added %d %s to discard pile." % [amount, card_id])


func _move_card_from_hand_to_discard(card_instance: CardInstance) -> void:
	var card_index := hand.find(card_instance)
	if card_index == -1:
		return

	hand.remove_at(card_index)
	discard_pile.append(card_instance)


func _resolve_burn_cards_at_end_of_turn() -> void:
	var remaining_hand: Array[CardInstance] = []

	for card_instance in hand:
		if card_instance.card_id == "burn":
			hp -= 2
			exhaust_pile.append(card_instance)
			_log("Burn sears you for 2 damage, then exhausts.")
		else:
			remaining_hand.append(card_instance)

	hand = remaining_hand


func _get_selected_living_enemy_index() -> int:
	if _is_living_enemy_index(_selected_enemy_index):
		return _selected_enemy_index

	_selected_enemy_index = _get_first_living_enemy_index()
	return _selected_enemy_index


func _get_first_living_enemy_index() -> int:
	for index in range(_enemies.size()):
		if _is_living_enemy_index(index):
			return index

	return -1


func _is_living_enemy_index(index: int) -> bool:
	return index >= 0 and index < _enemies.size() and _enemies[index].is_alive()


func _on_enemy_target_pressed(enemy_index: int) -> void:
	if not _is_living_enemy_index(enemy_index):
		_log("That enemy is already defeated.")
		return

	_selected_enemy_index = enemy_index
	_log("Targeting %s." % _enemies[enemy_index].display_name)
	_refresh_enemies()


func _is_defeated() -> bool:
	return hp <= 0


func _are_all_enemies_defeated() -> bool:
	for enemy in _enemies:
		if enemy.is_alive():
			return false

	return true


func _handle_victory() -> void:
	RunState.current_hp = max(hp, 1)
	_log("Victory.")
	var reward_payload := RewardManagerScript.build_combat_reward_payload(encounter_id, RunState.current_floor)
	SceneLoader.change_to_rewards(reward_payload)


func _handle_defeat() -> void:
	_log("Defeat.")
	SaveManager.delete_save()
	RunState.reset_run()
	SceneLoader.change_to_main_menu()


func _apply_combat_start_relics() -> void:
	for relic_id in RunState.relics:
		match relic_id:
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
			_:
				pass


func _refresh_ui() -> void:
	if _are_all_enemies_defeated():
		_handle_victory()
		return

	player_stats_label.text = "HP: %d/%d\nBlock: %d\nEnergy: %d/%d\nStrength: %d" % [
		hp,
		RunState.max_hp if RunState.max_hp > 0 else 75,
		block,
		energy,
		STARTING_ENERGY,
		strength,
	]
	pile_stats_label.text = "Draw: %d  Hand: %d  Discard: %d  Exhaust: %d" % [
		draw_pile.size(),
		hand.size(),
		discard_pile.size(),
		exhaust_pile.size(),
	]
	_refresh_enemies()
	_refresh_hand()
	_refresh_log()


func _refresh_enemies() -> void:
	for child in enemies_container.get_children():
		child.queue_free()

	for enemy_index in range(_enemies.size()):
		var enemy := _enemies[enemy_index]
		var enemy_view := ENEMY_VIEW_SCENE.instantiate()
		enemies_container.add_child(enemy_view)
		enemy_view.set_enemy(enemy, enemy_index == _selected_enemy_index)
		enemy_view.target_pressed.connect(_on_enemy_view_target_pressed)


func _on_enemy_view_target_pressed(enemy: EnemyInstance) -> void:
	var enemy_index := _enemies.find(enemy)
	if enemy_index == -1:
		return

	_on_enemy_target_pressed(enemy_index)


func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()

	for card_instance in hand:
		var card_view := CARD_VIEW_SCENE.instantiate()
		hand_container.add_child(card_view)
		card_view.set_card_instance(card_instance)
		card_view.play_pressed.connect(_on_card_play_requested)


func _refresh_log() -> void:
	combat_log_label.text = _format_combat_log()


func _format_combat_log() -> String:
	var text := ""

	for index in range(_combat_log.size()):
		if index > 0:
			text += "\n"
		text += _combat_log[index]

	return text


func _log(message: String) -> void:
	_combat_log.append(message)
	if _combat_log.size() > 12:
		_combat_log.pop_front()

	if is_node_ready():
		_refresh_log()
