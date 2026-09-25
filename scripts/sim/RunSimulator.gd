class_name RunSimulator
extends RefCounted

## Full-run simulator. Room rewards, tower progression, and combat all call
## the same scripts the game uses. Non-combat rooms apply the same numbers
## as their screens. The card player is CombatAI, not a human.

const POLICY_RANDOM := "random"
const POLICY_GREEDY := "greedy"
const POLICY_SMART := "smart"

const Database := preload("res://scripts/rewards/RunUpgradeDatabase.gd")
const Rules := preload("res://scripts/rewards/RunUpgradeRules.gd")
const RewardManagerScript := preload("res://scripts/rewards/RewardManager.gd")
const MapNavigatorScript := preload("res://scripts/map/MapNavigator.gd")
const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")
const ShopManagerScript := preload("res://scripts/shop/ShopManager.gd")
const EventManagerScript := preload("res://scripts/events/EventManager.gd")
const ObservatoryScript := preload("res://scripts/ui/ObservatoryScreen.gd")

const DECK_TAKE_LIMIT := 15
const REST_HEAL_RATIO := 0.25
const SHRINE_HEAL_RATIO := 0.4
const FORGE_MAX_HP := 4

var _cards := CardDatabase.new()
var _relics := RelicDatabase.new()
var _events := EventDatabase.new()
var _classes := ClassDatabase.new()
var _ai := CombatAI.new()


func simulate_policy(policy: String, run_count: int) -> Dictionary:
	var records: Array = []
	for index in range(run_count):
		var theme := ""
		if policy == POLICY_GREEDY:
			theme = Database.BUILD_THEMES[index % Database.BUILD_THEMES.size()]
		var class_id := "ash_knight" if index % 2 == 0 else "cinder_witch"
		var seed := 5000 + (index * 97) + (policy.hash() % 1000)
		records.append(_simulate_run(policy, theme, class_id, seed))
		if index > 0 and index % 250 == 0:
			print("%s progress %d/%d" % [policy, index, run_count])
	return {
		"policy": policy,
		"records": records,
	}


func summarize(batch: Dictionary) -> Dictionary:
	var policy := str(batch.get("policy", ""))
	var records: Array = batch.get("records", [])
	var runs := records.size()
	var wins := 0
	var combat_total := 0
	var offer_events := 0
	var upgrade_rows := {}
	var pair_rows := {}
	var triple_rows := {}
	var by_count := {}

	for upgrade_id in Database.all_ids():
		upgrade_rows[upgrade_id] = {
			"offers": 0,
			"picks": 0,
			"owned_runs": 0,
			"owned_wins": 0,
			"owned_combats": 0,
			"owned_hp": 0.0,
		}

	for record in records:
		var won: bool = bool(record.get("won", false))
		var combats := int(record.get("combats", 0))
		if won:
			wins += 1
		combat_total += combats

		var owned: Array = record.get("owned", [])
		var owned_count := owned.size()
		var hp_ratio := float(record.get("hp_ratio", 0.0))
		if not by_count.has(owned_count):
			by_count[owned_count] = {"runs": 0, "wins": 0}
		by_count[owned_count]["runs"] = int(by_count[owned_count]["runs"]) + 1
		if won:
			by_count[owned_count]["wins"] = int(by_count[owned_count]["wins"]) + 1

		for event in record.get("offer_events", []):
			offer_events += 1
			var offered: Array = event.get("offered", [])
			var picked := str(event.get("picked", ""))
			for upgrade_id in offered:
				var row: Dictionary = upgrade_rows[str(upgrade_id)]
				row["offers"] = int(row["offers"]) + 1
			if picked != "" and upgrade_rows.has(picked):
				var picked_row: Dictionary = upgrade_rows[picked]
				picked_row["picks"] = int(picked_row["picks"]) + 1

		for upgrade_id in owned:
			var owned_row: Dictionary = upgrade_rows[str(upgrade_id)]
			owned_row["owned_runs"] = int(owned_row["owned_runs"]) + 1
			owned_row["owned_combats"] = int(owned_row["owned_combats"]) + combats
			owned_row["owned_hp"] = float(owned_row["owned_hp"]) + hp_ratio
			if won:
				owned_row["owned_wins"] = int(owned_row["owned_wins"]) + 1

		_accumulate_combos(pair_rows, owned, 2, won, hp_ratio)
		_accumulate_combos(triple_rows, owned, 3, won, hp_ratio)

	return {
		"policy": policy,
		"runs": runs,
		"wins": wins,
		"win_rate": _ratio(wins, runs),
		"mean_combats": _ratio(combat_total, runs),
		"offer_events": offer_events,
		"upgrades": upgrade_rows,
		"pairs": pair_rows,
		"triples": triple_rows,
		"by_count": by_count,
	}


func _simulate_run(policy: String, theme: String, class_id: String, seed_value: int) -> Dictionary:
	_begin_run(class_id, seed_value)
	var combats := 0
	var offer_events: Array = []
	var won := false
	var died := false
	var guard := 0

	while guard < 40:
		guard += 1
		if RunState.current_hp <= 0:
			break
		if RunState.is_run_complete():
			won = true
			break

		var rooms: Array = RunState.get_tower_state().get_available_rooms()
		if rooms.is_empty():
			won = RunState.is_run_complete()
			break

		var room: TowerRoomData = _pick_room(rooms)
		RunState.enter_room(room.room_id)
		var survived := _resolve_room(room, policy, theme, offer_events)
		if not survived or RunState.current_hp <= 0:
			died = true
			break
		if room.room_type == TowerRoomDatabaseScript.ROOM_BATTLE \
				or room.room_type == TowerRoomDatabaseScript.ROOM_ELITE \
				or room.room_type == TowerRoomDatabaseScript.ROOM_BOSS:
			combats += 1
		RunState.complete_active_room(false)
		if RunState.is_run_complete():
			won = true
			break

	var owned: Array[String] = []
	for upgrade_id in Database.all_ids():
		if int(RunState.upgrade_stacks.get(upgrade_id, 0)) > 0:
			owned.append(upgrade_id)

	var hp_ratio := 0.0
	if not died and RunState.max_hp > 0:
		hp_ratio = float(RunState.current_hp) / float(RunState.max_hp)

	return {
		"won": won,
		"died": died,
		"combats": combats,
		"hp_ratio": hp_ratio,
		"act": RunState.current_act,
		"owned": owned,
		"offer_events": offer_events,
		"class_id": class_id,
		"theme": theme,
	}


func _begin_run(class_id: String, seed_value: int) -> void:
	var definition := _classes.get_class_definition(class_id)
	RunState.reset_run()
	RunState.selected_class = class_id
	RunState.max_hp = int(definition.get("max_hp", 70))
	RunState.current_hp = RunState.max_hp
	RunState.gold = int(definition.get("starting_gold", 0))
	RunState.current_act = 1
	RunState.run_seed = seed_value
	RunState.deck.clear()
	for card_id in definition.get("starter_deck", []):
		RunState.deck.append(str(card_id))
	RunState.relics.clear()
	var starter_relic := str(definition.get("starter_relic", ""))
	if starter_relic != "":
		RunState.relics.append(starter_relic)
	RNG.set_seed(seed_value)
	RunState.suppress_room_log = true
	RunState.create_new_tower()


func _pick_room(rooms: Array) -> TowerRoomData:
	var ratio := float(RunState.current_hp) / float(maxi(1, RunState.max_hp))
	if ratio < 0.45:
		for room in rooms:
			if room is TowerRoomData and (room as TowerRoomData).room_type == TowerRoomDatabaseScript.ROOM_REST:
				return room as TowerRoomData
	if ratio < 0.62:
		for room in rooms:
			if room is TowerRoomData and (room as TowerRoomData).room_type != TowerRoomDatabaseScript.ROOM_ELITE:
				return room as TowerRoomData
	return rooms[0] as TowerRoomData


func _resolve_room(room: TowerRoomData, policy: String, theme: String, offer_events: Array) -> bool:
	match room.room_type:
		TowerRoomDatabaseScript.ROOM_BATTLE:
			return _resolve_combat(MapNavigatorScript.get_battle_encounter_id(room.floor), false, false, policy, theme, offer_events)
		TowerRoomDatabaseScript.ROOM_ELITE:
			return _resolve_combat(MapNavigatorScript.get_elite_encounter_id(room), false, true, policy, theme, offer_events)
		TowerRoomDatabaseScript.ROOM_BOSS:
			return _resolve_combat(
				RewardManagerScript.get_boss_encounter_for_act(RunState.current_act),
				true,
				false,
				policy,
				theme,
				offer_events
			)
		TowerRoomDatabaseScript.ROOM_REST:
			var heal := int(ceil(float(RunState.max_hp) * REST_HEAL_RATIO))
			RunState.current_hp = mini(RunState.current_hp + heal, RunState.max_hp)
		TowerRoomDatabaseScript.ROOM_SHRINE:
			_apply_shrine()
		TowerRoomDatabaseScript.ROOM_FORGE:
			RunState.max_hp += FORGE_MAX_HP
			RunState.current_hp += FORGE_MAX_HP
		TowerRoomDatabaseScript.ROOM_OBSERVATORY:
			RunState.add_gold(ObservatoryScript.SCOUT_GOLD)
		TowerRoomDatabaseScript.ROOM_MARKET:
			_apply_shop(room.floor)
		TowerRoomDatabaseScript.ROOM_EVENT:
			_apply_event(room.source_card_id)
		_:
			pass
	return RunState.current_hp > 0


func _resolve_combat(
	encounter_id: String,
	is_boss: bool,
	is_elite: bool,
	policy: String,
	theme: String,
	offer_events: Array
) -> bool:
	var won := _ai.fight(encounter_id)
	if not won:
		return false

	RunState.add_gold(RewardManagerScript.get_gold_reward(
		encounter_id,
		RunState.current_floor,
		is_boss,
		is_elite
	))
	_take_card_or_relic(is_boss)

	var offered := Rules.build_offer(Rules.OFFER_SIZE)
	var picked := _pick_upgrade(policy, offered, theme)
	if picked != "":
		Rules.apply_upgrade(picked)
	offer_events.append({
		"offered": offered,
		"picked": picked,
	})
	return true


func _take_card_or_relic(is_boss: bool) -> void:
	if is_boss:
		var relic_choices := _relics.get_boss_reward_choices(1, RunState.relics)
		if not relic_choices.is_empty():
			RunState.add_relic(relic_choices[0].id)
		return

	if RunState.deck.size() >= DECK_TAKE_LIMIT:
		return
	var card_choices := _cards.get_reward_cards(RunState.selected_class, 1)
	if not card_choices.is_empty():
		RunState.add_card_to_deck(card_choices[0].id)


func _apply_shrine() -> void:
	var heal := int(ceil(float(RunState.max_hp) * SHRINE_HEAL_RATIO))
	RunState.current_hp = mini(RunState.current_hp + heal, RunState.max_hp)
	var relic_choices := _relics.get_boss_reward_choices(1, RunState.relics)
	if not relic_choices.is_empty():
		RunState.add_relic(relic_choices[0].id)


func _apply_shop(floor: int) -> void:
	if RunState.deck.size() >= DECK_TAKE_LIMIT:
		return
	var inventory := ShopManagerScript.build_shop_inventory(floor, RunState.current_act)
	var offers: Array = inventory.get("card_offers", [])
	var best_id := ""
	var best_price := 999999
	for offer in offers:
		if not offer is Dictionary:
			continue
		var price := int((offer as Dictionary).get("price", 0))
		if price < best_price and RunState.gold >= price:
			best_price = price
			best_id = str((offer as Dictionary).get("card_id", ""))
	if best_id != "" and RunState.spend_gold(best_price):
		RunState.add_card_to_deck(best_id)


func _apply_event(event_id: String) -> void:
	var event_data := _events.get_event(event_id)
	if event_data == null:
		return
	var choice := _pick_event_choice(event_data)
	if choice.is_empty():
		return
	EventManagerScript.apply_choice(event_data, str(choice.get("id", "")))


func _pick_event_choice(event_data: EventData) -> Dictionary:
	var ratio := float(RunState.current_hp) / float(maxi(1, RunState.max_hp))
	if ratio < 0.6:
		for choice in event_data.choices:
			if _choice_has(choice, "heal") and _choice_affordable(choice):
				return choice
	for choice in event_data.choices:
		if _choice_has(choice, "gold") and not _choice_has(choice, "damage") and _choice_affordable(choice):
			return choice
	for choice in event_data.choices:
		var effects: Array = choice.get("effects", [])
		if effects.is_empty():
			return choice
	for choice in event_data.choices:
		if _choice_affordable(choice):
			return choice
	return {}


func _choice_has(choice: Dictionary, effect_type: String) -> bool:
	for effect in choice.get("effects", []):
		if effect is Dictionary and str((effect as Dictionary).get("type", "")) == effect_type:
			return true
	return false


func _choice_affordable(choice: Dictionary) -> bool:
	for effect in choice.get("effects", []):
		if effect is Dictionary and str((effect as Dictionary).get("type", "")) == "gold_cost":
			if RunState.gold < int((effect as Dictionary).get("amount", 0)):
				return false
	return true


func _pick_upgrade(policy: String, offered: Array[String], theme: String) -> String:
	if offered.is_empty():
		return ""
	match policy:
		POLICY_RANDOM:
			return offered[RNG.rand_int(0, offered.size() - 1)]
		POLICY_GREEDY:
			return _pick_greedy(offered, theme)
		_:
			return _pick_smart(offered)


func _pick_greedy(offered: Array[String], theme: String) -> String:
	var best := ""
	var best_stacks := -1
	for upgrade_id in offered:
		if Database.theme_of(upgrade_id) != theme:
			continue
		var stacks := Rules.get_stacks(upgrade_id)
		if stacks > best_stacks:
			best = upgrade_id
			best_stacks = stacks
	if best != "":
		return best

	for upgrade_id in ["ember_capacity", "ash_reserves", "soul_cache"]:
		if offered.has(upgrade_id):
			return upgrade_id
	return offered[0]


func _pick_smart(offered: Array[String]) -> String:
	var best := offered[0]
	var best_score := -999
	for upgrade_id in offered:
		var score := _smart_score(upgrade_id)
		if score > best_score:
			best_score = score
			best = upgrade_id
	return best


func _smart_score(upgrade_id: String) -> int:
	var theme := Database.theme_of(upgrade_id)
	var totals := Rules.theme_stack_totals()
	var best_theme := ""
	var best_theme_stacks := 0
	for theme_id in Database.BUILD_THEMES:
		var theme_stacks := int(totals.get(theme_id, 0))
		if theme_stacks > best_theme_stacks:
			best_theme_stacks = theme_stacks
			best_theme = theme_id

	var score := 8
	if theme == best_theme and best_theme_stacks > 0:
		score += 10 + best_theme_stacks * 4
	elif int(totals.get(theme, 0)) > 0:
		score += 6
	elif best_theme_stacks >= 2 and theme != Database.THEME_FOUNDATION:
		score -= 5

	var hp_ratio := float(RunState.current_hp) / float(maxi(1, RunState.max_hp))
	var total_stacks := 0
	for key in RunState.upgrade_stacks.keys():
		total_stacks += int(RunState.upgrade_stacks[key])

	match upgrade_id:
		"ember_capacity":
			score += 8 if total_stacks < 3 else 4
		"ash_reserves":
			score += 12 if hp_ratio < 0.7 else 4
		"soul_cache":
			score += 6
			if _owns_any(["tithe_blade", "soul_interest"]):
				score += 8
		"grave_call":
			score += 6
			if RunState.corpses >= 1:
				score += 6
			if _owns_any(["bone_ranks", "brute_summons", "chorus_of_ash", "unfinished_rite"]):
				score += 8
		"unfinished_rite":
			score += 4 if _owns_any(["grave_call", "bone_ranks", "brute_summons"]) else -4
		"chorus_of_ash":
			score += 12 if _owns_any(["grave_call", "bone_ranks"]) else -6
		"cinder_corpse":
			score += 7
			if _owns_any(["chain_ash"]):
				score += 6
		"pyre_funeral":
			score += 10 if _owns_any(["grave_call", "bone_ranks", "brute_summons"]) else -8
		"chain_ash":
			score += 6
			if _owns_any(["cinder_corpse", "pyre_funeral"]):
				score += 8
		"hold_the_line":
			score += 9
			if hp_ratio < 0.6:
				score += 6
		"interpose":
			score += 12 if _owns_any(["grave_call", "bone_ranks", "brute_summons"]) else -3
		"last_ember":
			score += 8
			if hp_ratio < 0.5:
				score += 8
		"ember_step":
			score += 11
		"break_intent":
			score += 7
			if RunState.current_act >= 2:
				score += 6
		"bone_ranks":
			score += 8
			if _owns_any(["grave_call", "rattling_volley"]):
				score += 8
		"rattling_volley":
			score += mini(10, _count_attacks(1, true))
			score += 8 if _owns_any(["bone_ranks", "grave_call"]) else -2
		"brute_summons":
			score += 4
			if RunState.corpses >= 2:
				score += 8
			if _owns_any(["grave_call", "crushing_swing"]):
				score += 6
		"crushing_swing":
			var heavy := _count_attacks(2, false)
			score += heavy * 6
			if heavy == 0:
				score -= 6
			if _owns_any(["brute_summons"]):
				score += 6
		"soul_interest":
			score += 4
			if RunState.soul >= 8 or _owns_any(["soul_cache", "tithe_blade"]):
				score += 8
		"tithe_blade":
			score += 7
			if RunState.soul >= 12:
				score += 8
			if _owns_any(["soul_cache", "soul_interest"]):
				score += 5
		_:
			pass

	return score


func _owns_any(upgrade_ids: Array) -> bool:
	for upgrade_id in upgrade_ids:
		if int(RunState.upgrade_stacks.get(str(upgrade_id), 0)) > 0:
			return true
	return false


func _count_attacks(cost_cutoff: int, cheap: bool) -> int:
	var count := 0
	for card_id in RunState.deck:
		var card_data := _cards.get_card(str(card_id))
		if card_data == null or card_data.card_type != "Attack":
			continue
		if cheap and card_data.cost <= cost_cutoff:
			count += 1
		elif not cheap and card_data.cost >= cost_cutoff:
			count += 1
	return count


func _accumulate_combos(rows: Dictionary, owned: Array, width: int, won: bool, hp_ratio: float) -> void:
	if owned.size() < width:
		return
	var index_sets := _combinations(owned.size(), width)
	for index_set in index_sets:
		var ids: Array[String] = []
		for index in index_set:
			ids.append(str(owned[index]))
		ids.sort()
		var key := "+".join(ids)
		if not rows.has(key):
			rows[key] = {"runs": 0, "wins": 0, "hp": 0.0}
		rows[key]["runs"] = int(rows[key]["runs"]) + 1
		rows[key]["hp"] = float(rows[key]["hp"]) + hp_ratio
		if won:
			rows[key]["wins"] = int(rows[key]["wins"]) + 1


func _combinations(count: int, width: int) -> Array:
	var results: Array = []
	var current: Array = []
	_combine_into(results, current, 0, count, width)
	return results


func _combine_into(results: Array, current: Array, start: int, count: int, width: int) -> void:
	if current.size() == width:
		results.append(current.duplicate())
		return
	for index in range(start, count):
		current.append(index)
		_combine_into(results, current, index + 1, count, width)
		current.pop_back()


func _ratio(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	return float(numerator) / float(denominator)
