extends RefCounted

const CombatManagerScript := preload("res://scripts/combat/CombatManager.gd")
const HeuristicPolicyScript := preload("res://scripts/dev/HeuristicRunPolicy.gd")
const RandomPolicyScript := preload("res://scripts/dev/RandomRunPolicy.gd")
const RunActionsScript := preload("res://scripts/core/RunActions.gd")

const SEED_STRIDE := 104729
const MAX_ROOM_STEPS := 48
const MAX_COMBAT_TURNS := 30
const MAX_CARDS_PER_TURN := 16

const UNMAPPED_METRICS := [
	"Corpse carryover is not in this game. Cross-floor state is HP, max HP, deck, relics, and gold.",
	"Reserve spawning is not in this game.",
	"Raise is not in this game, so Raise counts are not simulated.",
	"Souls are not in this game. Gold is the currency.",
	"Horde size is not in this game. Encounter size is the length of the enemy list spawned by combat (currently one enemy).",
	"The game does not categorize failures as horde wiped or outnumbered. Combat ends when HP reaches 0; the lethal source is the enemy attack or Burn status that dropped HP, plus the encounter tier. Events can also reduce HP to 0.",
]


static func default_config() -> Dictionary:
	return {
		"runs": 100,
		"seed": 1,
		"policy": "heuristic",
		"class_id": ClassDatabase.ASH_KNIGHT,
	}


static func parse_cmdline(config: Dictionary) -> Dictionary:
	var parsed := config.duplicate(true)
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var arg := str(args[index])
		if index + 1 < args.size():
			match arg:
				"--runs":
					parsed["runs"] = maxi(int(args[index + 1]), 1)
					index += 1
				"--seed":
					parsed["seed"] = int(args[index + 1])
					index += 1
				"--policy":
					parsed["policy"] = str(args[index + 1])
					index += 1
				"--class":
					parsed["class_id"] = str(args[index + 1])
					index += 1
		index += 1
	return parsed


func run(config: Dictionary) -> Dictionary:
	_backup_save()
	GameState.simulation_quiet = true
	var result := _run_configured(_normalize_config(config))
	_restore_save()
	return result


func _normalize_config(config: Dictionary) -> Dictionary:
	var normalized := default_config()
	normalized["runs"] = maxi(int(config.get("runs", normalized["runs"])), 1)
	normalized["seed"] = int(config.get("seed", normalized["seed"]))
	normalized["policy"] = str(config.get("policy", normalized["policy"]))
	normalized["class_id"] = str(config.get("class_id", normalized["class_id"]))
	if normalized["policy"] not in ["heuristic", "random", "compare"]:
		normalized["policy"] = "heuristic"
		normalized["policy_note"] = "Unknown policy replaced with heuristic."
	else:
		normalized["policy_note"] = ""
	return normalized


func _run_configured(config: Dictionary) -> Dictionary:
	var started_ms := Time.get_ticks_msec()
	var policy_ids: Array[String] = []
	if str(config["policy"]) == "compare":
		policy_ids = ["heuristic", "random"]
	else:
		policy_ids = [str(config["policy"])]

	var batches: Array = []
	for policy_id in policy_ids:
		var batch_config := config.duplicate(true)
		batch_config["policy"] = policy_id
		print(
			"Balance sim start policy=%s class=%s runs=%d seed=%d"
			% [policy_id, batch_config["class_id"], batch_config["runs"], batch_config["seed"]]
		)
		var runs := _simulate_batch(batch_config)
		var summary := _summarize(runs, batch_config)
		batches.append({
			"policy": policy_id,
			"summary": summary,
			"runs": runs,
		})

	var elapsed_ms := Time.get_ticks_msec() - started_ms
	var markdown := _render_report(config, batches, elapsed_ms)
	var payload := _json_payload(config, batches, elapsed_ms)
	var paths := _write_outputs(config, markdown, payload, batches)
	print(markdown)
	print("Balance report markdown: %s" % paths.get("markdown", ""))
	print("Balance report json: %s" % paths.get("json", ""))
	print("Balance report csv: %s" % paths.get("csv", ""))

	var primary: Dictionary = batches[0]["summary"]
	var status_line := "%s %s: %d/%d clears (%s). Report: %s" % [
		str(primary.get("class_name", config["class_id"])),
		str(primary.get("policy", "")),
		int(primary.get("completed", 0)),
		int(primary.get("runs", 0)),
		_pct(int(primary.get("completed", 0)), int(primary.get("runs", 0))),
		paths.get("markdown_global", paths.get("markdown", "")),
	]
	if batches.size() > 1:
		var other: Dictionary = batches[1]["summary"]
		status_line += " | %s %d/%d (%s)." % [
			other.get("policy", ""),
			int(other.get("completed", 0)),
			int(other.get("runs", 0)),
			_pct(int(other.get("completed", 0)), int(other.get("runs", 0))),
		]

	return {
		"markdown": markdown,
		"status_line": status_line,
		"paths": paths,
		"errors": 0,
		"summary": primary,
	}


func _simulate_batch(config: Dictionary) -> Array:
	var runs: Array = []
	var run_count := int(config["runs"])
	var base_seed := int(config["seed"])
	var class_id := str(config["class_id"])
	var policy_id := str(config["policy"])
	_events = EventDatabase.new()
	_cards = CardDatabase.new()

	for run_index in range(run_count):
		if run_index % 25 == 0:
			print("Balance sim %s run %d/%d" % [policy_id, run_index + 1, run_count])
		runs.append(_simulate_run(run_index, base_seed, class_id, policy_id))

	if is_instance_valid(_events):
		_events.free()
		_events = null
	if is_instance_valid(_cards):
		_cards.free()
		_cards = null
	return runs


var _events: EventDatabase
var _cards: CardDatabase
var _save_backup := PackedByteArray()
var _had_save := false


func _simulate_run(run_index: int, base_seed: int, class_id: String, policy_id: String) -> Dictionary:
	var run_seed := base_seed + run_index * SEED_STRIDE
	var policy = _make_policy(policy_id, run_seed)
	var record := {
		"run_index": run_index,
		"seed": run_seed,
		"class_id": class_id,
		"policy": policy_id,
		"completed": false,
		"death_act": 0,
		"death_floor": 0,
		"failure_reason": "",
		"rooms": 0,
		"combats": 0,
		"turns": 0,
		"gold_start": 0,
		"gold_earned": 0,
		"gold_spent": 0,
		"gold_end": 0,
		"hp_end": 0,
		"max_hp_end": 0,
		"deck_size_end": 0,
		"deck_power_end": 0,
		"relic_count_end": 0,
		"act1_boss_fought": 0,
		"act1_boss_won": 0,
		"act2_boss_fought": 0,
		"act2_boss_won": 0,
		"floors": [],
		"rewards": [],
	}

	if policy == null or not RunState.start_class_run(class_id, run_seed):
		record["failure_reason"] = "start_failed"
		if policy != null:
			policy.cleanup()
		return record

	record["gold_start"] = RunState.gold
	var rewards: Array = []
	var floors: Array = []
	var failure := ""
	var completed := false
	var steps := 0

	while steps < MAX_ROOM_STEPS:
		steps += 1
		if RunState.is_run_complete():
			completed = true
			break
		if RunState.current_hp <= 0:
			failure = "hp_zero"
			break

		var available := RunState.get_tower_state().get_available_rooms()
		if available.is_empty():
			failure = "no_available_room"
			break

		var room: TowerRoomData = policy.choose_room(available)
		var entry := _snapshot_entry(room)
		RunState.enter_room(room.room_id)
		var gold_before := RunState.gold
		var room_result: Dictionary = _resolve_room(room, policy, rewards)
		var gold_delta := RunState.gold - gold_before
		if gold_delta > 0:
			record["gold_earned"] = int(record["gold_earned"]) + gold_delta
		else:
			record["gold_spent"] = int(record["gold_spent"]) + (-gold_delta)

		entry["result"] = str(room_result.get("result", ""))
		entry["encounter_id"] = str(room_result.get("encounter_id", ""))
		entry["encounter_size"] = int(room_result.get("encounter_size", -1))
		entry["turns"] = int(room_result.get("turns", 0))
		entry["hp_out"] = int(room_result.get("hp_out", RunState.current_hp))
		floors.append(entry)

		record["rooms"] = int(record["rooms"]) + 1
		record["combats"] = int(record["combats"]) + int(room_result.get("combats", 0))
		record["turns"] = int(record["turns"]) + int(room_result.get("turns", 0))
		_record_boss(record, room_result)

		if str(room_result.get("result", "")) == "defeat":
			failure = str(room_result.get("failure_reason", "combat_defeat"))
			break

		RunState.complete_active_room()
		if RunState.is_run_complete():
			completed = true
			break

	if not completed and failure == "":
		failure = "run_room_cap"

	record["completed"] = completed
	record["failure_reason"] = "" if completed else failure
	record["floors"] = floors
	record["rewards"] = rewards
	record["gold_end"] = RunState.gold
	record["max_hp_end"] = RunState.max_hp
	record["deck_size_end"] = RunState.deck.size()
	record["deck_power_end"] = _deck_power()
	record["relic_count_end"] = _relic_count()
	if completed:
		record["hp_end"] = RunState.current_hp
		record["death_act"] = 0
		record["death_floor"] = 0
	else:
		record["death_act"] = RunState.current_act
		record["death_floor"] = RunState.current_floor
		if floors.is_empty():
			record["hp_end"] = 0
		else:
			record["hp_end"] = int(floors[floors.size() - 1].get("hp_out", 0))

	policy.cleanup()
	return record


func _make_policy(policy_id: String, seed_value: int):
	var policy = null
	if policy_id == "random":
		policy = RandomPolicyScript.new()
	else:
		policy = HeuristicPolicyScript.new()
	policy.setup(seed_value)
	return policy


func _snapshot_entry(room: TowerRoomData) -> Dictionary:
	return {
		"act": RunState.current_act,
		"floor": room.floor,
		"room_type": room.room_type,
		"room_id": room.room_id,
		"hp_in": RunState.current_hp,
		"max_hp_in": RunState.max_hp,
		"gold_in": RunState.gold,
		"deck_size_in": RunState.deck.size(),
		"deck_power_in": _deck_power(),
		"relic_count_in": _relic_count(),
	}


func _resolve_room(room: TowerRoomData, policy, rewards: Array) -> Dictionary:
	var result := {
		"result": "clear",
		"combats": 0,
		"turns": 0,
		"encounter_size": -1,
		"encounter_id": "",
		"failure_reason": "",
		"hp_out": RunState.current_hp,
		"boss_id": "",
		"boss_fought": false,
		"boss_won": false,
	}

	var room_type := room.room_type
	if (
		room_type == TowerRoomDatabase.ROOM_BATTLE
		or room_type == TowerRoomDatabase.ROOM_ELITE
		or room_type == TowerRoomDatabase.ROOM_BOSS
	):
		return _resolve_combat(room, policy, rewards, result)

	if room_type == TowerRoomDatabase.ROOM_REST:
		if policy.should_rest():
			RunActionsScript.rest()
	elif room_type == TowerRoomDatabase.ROOM_FORGE:
		if policy.should_temper():
			RunActionsScript.temper()
	elif room_type == TowerRoomDatabase.ROOM_OBSERVATORY:
		if policy.should_scout():
			RunActionsScript.scout()
	elif room_type == TowerRoomDatabase.ROOM_SHRINE:
		if policy.should_pray():
			RunActionsScript.pray()
	elif room_type == TowerRoomDatabase.ROOM_MARKET:
		_resolve_shop(policy)
	elif room_type == TowerRoomDatabase.ROOM_EVENT:
		return _resolve_event(room, policy, result)

	result["hp_out"] = RunState.current_hp
	return result


func _resolve_shop(policy) -> void:
	var inventory := ShopManager.build_shop_inventory(RunState.current_floor, RunState.current_act)
	policy.begin_shop()
	var guard := 0
	while guard < MAX_CARDS_PER_TURN:
		guard += 1
		var action: Dictionary = policy.choose_shop_action(inventory)
		var action_type := str(action.get("type", "leave"))
		if action_type == "leave" or action_type == "":
			return
		if action_type == "buy_card":
			ShopManager.try_buy_card(inventory, int(action.get("index", -1)))
		elif action_type == "buy_relic":
			ShopManager.try_buy_relic(inventory)
		elif action_type == "remove_card":
			ShopManager.try_remove_card(inventory, str(action.get("card_id", "")))
		else:
			return


func _resolve_event(room: TowerRoomData, policy, result: Dictionary) -> Dictionary:
	var event_data := _events.get_event(room.source_card_id)
	if event_data == null:
		result["hp_out"] = RunState.current_hp
		return result

	var choice_id := str(policy.choose_event_choice(event_data))
	if choice_id != "":
		EventManager.apply_choice(event_data, choice_id)

	result["hp_out"] = RunState.current_hp
	if RunState.current_hp <= 0:
		result["result"] = "defeat"
		result["failure_reason"] = "event_lethal:%s" % event_data.id
		result["hp_out"] = 0
	return result


func _resolve_combat(room: TowerRoomData, policy, rewards: Array, result: Dictionary) -> Dictionary:
	var encounter_id := _encounter_id_for_room(room)
	result["encounter_id"] = encounter_id
	result["combats"] = 1
	if room.room_type == TowerRoomDatabase.ROOM_BOSS:
		result["boss_fought"] = true
		result["boss_id"] = encounter_id

	var combat = CombatManagerScript.new()
	combat.begin_headless(encounter_id)
	result["encounter_size"] = combat.get_enemy_count()

	var safety := 0
	while combat.combat_outcome == "" and safety < MAX_COMBAT_TURNS:
		safety += 1
		combat.focus_lowest_hp_enemy()
		var plays := 0
		while combat.combat_outcome == "" and plays < MAX_CARDS_PER_TURN:
			plays += 1
			var card = policy.choose_card(combat)
			if card == null:
				break
			var hand_before: int = combat.hand.size()
			var energy_before: int = int(combat.energy)
			combat.play_card(card)
			if combat.combat_outcome != "":
				break
			if combat.hand.size() == hand_before and int(combat.energy) == energy_before:
				break
		if combat.combat_outcome == "":
			combat.end_player_turn()

	result["turns"] = combat.get_turn_number()
	var outcome := str(combat.combat_outcome)
	var cause := str(combat.defeat_cause)
	var combat_hp := int(combat.hp)
	var payload: Dictionary = combat.pending_reward_payload.duplicate(true)
	combat.cleanup_headless()
	combat.free()

	if outcome == "":
		result["result"] = "defeat"
		result["failure_reason"] = "combat_stall:%s" % encounter_id
		result["hp_out"] = combat_hp
		result["boss_won"] = false
		return result

	if outcome == "defeat":
		result["result"] = "defeat"
		if cause == "":
			cause = "unknown"
		if not cause.contains(":"):
			cause = "%s:%s" % [cause, encounter_id]
		result["failure_reason"] = "%s:%s" % [_combat_tier(room.room_type), cause]
		result["hp_out"] = 0
		result["boss_won"] = false
		return result

	result["boss_won"] = bool(result["boss_fought"])
	_apply_reward(payload, policy, rewards)
	result["hp_out"] = RunState.current_hp
	result["result"] = "victory"
	return result


func _encounter_id_for_room(room: TowerRoomData) -> String:
	if room.room_type == TowerRoomDatabase.ROOM_BOSS:
		return RewardManager.get_boss_encounter_for_act(RunState.current_act)
	if room.room_type == TowerRoomDatabase.ROOM_ELITE:
		return MapNavigator.get_elite_encounter_id(room)
	return MapNavigator.get_battle_encounter_id(room.floor)


func _combat_tier(room_type: String) -> String:
	if room_type == TowerRoomDatabase.ROOM_BOSS:
		return "boss_combat"
	if room_type == TowerRoomDatabase.ROOM_ELITE:
		return "elite_combat"
	return "normal_combat"


func _apply_reward(payload: Dictionary, policy, rewards: Array) -> void:
	var gold := int(payload.get("gold", 0))
	if gold > 0:
		RunState.add_gold(gold)

	var is_boss := bool(payload.get("is_boss", false))
	var offered: Array = []
	var picked := ""
	var skipped := false
	var kind := "card"

	if is_boss:
		kind = "relic"
		for relic_id in payload.get("relic_choices", []):
			offered.append(str(relic_id))
		picked = str(policy.choose_reward_relic(offered))
		if picked == "" or not offered.has(picked):
			picked = str(offered[0]) if not offered.is_empty() else ""
		if picked != "":
			RunState.add_relic(picked)
	else:
		for card_id in payload.get("card_choices", []):
			offered.append(str(card_id))
		picked = str(policy.choose_reward_card(offered))
		if picked != "" and not offered.has(picked):
			picked = ""
		if picked == "":
			skipped = not offered.is_empty()
		else:
			RunState.add_card_to_deck(picked)

	rewards.append({
		"act": RunState.current_act,
		"floor": int(payload.get("floor", RunState.current_floor)),
		"encounter_id": str(payload.get("encounter_id", "")),
		"kind": kind,
		"offered": offered,
		"picked": picked,
		"skipped": skipped,
		"gold": gold,
	})


func _record_boss(record: Dictionary, room_result: Dictionary) -> void:
	if not bool(room_result.get("boss_fought", false)):
		return

	var boss_id := str(room_result.get("boss_id", ""))
	var won := 1 if bool(room_result.get("boss_won", false)) else 0
	if boss_id == "bellows_saint":
		record["act1_boss_fought"] = 1
		record["act1_boss_won"] = won
	elif boss_id == "ember_regent":
		record["act2_boss_fought"] = 1
		record["act2_boss_won"] = won


func _deck_power() -> int:
	if _cards == null:
		return 0

	var total := 0
	for card_id in RunState.deck:
		var card_data := _cards.get_card(str(card_id))
		if card_data == null:
			continue
		for effect in card_data.effects:
			var effect_type := str(effect.get("type", ""))
			if effect_type in ["damage", "block", "draw", "temp_strength", "heal", "enemy_burn", "enemy_burn_all"]:
				total += int(effect.get("amount", 0))
	return total


func _relic_count() -> int:
	var count := 0
	for relic_id in RunState.relics:
		if str(relic_id) != "":
			count += 1
	return count


func _summarize(runs: Array, config: Dictionary) -> Dictionary:
	var display_name := _class_display_name(str(config["class_id"]))
	var run_count := runs.size()
	var completed := 0
	var rooms := 0
	var combats := 0
	var turns := 0
	var completed_rooms := 0
	var completed_combats := 0
	var completed_turns := 0
	var gold_start := 0
	var gold_earned := 0
	var gold_spent := 0
	var gold_end := 0
	var deaths := {}
	var floors := {}
	var offered_cards := {}
	var picked_cards := {}
	var offered_relics := {}
	var picked_relics := {}
	var card_skips := 0
	var card_offers := 0
	var failures := {}
	var act1_fought := 0
	var act1_won := 0
	var act2_fought := 0
	var act2_won := 0

	for run in runs:
		var run_data: Dictionary = run
		var did_complete := bool(run_data.get("completed", false))
		if did_complete:
			completed += 1
			completed_rooms += int(run_data.get("rooms", 0))
			completed_combats += int(run_data.get("combats", 0))
			completed_turns += int(run_data.get("turns", 0))
		else:
			var death_key := "%d|%d" % [int(run_data.get("death_act", 0)), int(run_data.get("death_floor", 0))]
			deaths[death_key] = int(deaths.get(death_key, 0)) + 1
			var reason := str(run_data.get("failure_reason", "unknown"))
			failures[reason] = int(failures.get(reason, 0)) + 1

		rooms += int(run_data.get("rooms", 0))
		combats += int(run_data.get("combats", 0))
		turns += int(run_data.get("turns", 0))
		gold_start += int(run_data.get("gold_start", 0))
		gold_earned += int(run_data.get("gold_earned", 0))
		gold_spent += int(run_data.get("gold_spent", 0))
		gold_end += int(run_data.get("gold_end", 0))
		act1_fought += int(run_data.get("act1_boss_fought", 0))
		act1_won += int(run_data.get("act1_boss_won", 0))
		act2_fought += int(run_data.get("act2_boss_fought", 0))
		act2_won += int(run_data.get("act2_boss_won", 0))

		for entry in run_data.get("floors", []):
			var floor_entry: Dictionary = entry
			var floor_key := "%d|%d" % [int(floor_entry.get("act", 0)), int(floor_entry.get("floor", 0))]
			if not floors.has(floor_key):
				floors[floor_key] = {
					"entries": 0,
					"hp": 0,
					"max_hp": 0,
					"deck_size": 0,
					"deck_power": 0,
					"relics": 0,
					"gold": 0,
					"battles": 0,
					"enemies": 0,
					"combat_turns": 0,
				}
			var bucket: Dictionary = floors[floor_key]
			bucket["entries"] = int(bucket["entries"]) + 1
			bucket["hp"] = int(bucket["hp"]) + int(floor_entry.get("hp_in", 0))
			bucket["max_hp"] = int(bucket["max_hp"]) + int(floor_entry.get("max_hp_in", 0))
			bucket["deck_size"] = int(bucket["deck_size"]) + int(floor_entry.get("deck_size_in", 0))
			bucket["deck_power"] = int(bucket["deck_power"]) + int(floor_entry.get("deck_power_in", 0))
			bucket["relics"] = int(bucket["relics"]) + int(floor_entry.get("relic_count_in", 0))
			bucket["gold"] = int(bucket["gold"]) + int(floor_entry.get("gold_in", 0))
			var encounter_size := int(floor_entry.get("encounter_size", -1))
			if encounter_size >= 0:
				bucket["battles"] = int(bucket["battles"]) + 1
				bucket["enemies"] = int(bucket["enemies"]) + encounter_size
				bucket["combat_turns"] = int(bucket["combat_turns"]) + int(floor_entry.get("turns", 0))
			floors[floor_key] = bucket

		for reward in run_data.get("rewards", []):
			var reward_data: Dictionary = reward
			var offered: Array = reward_data.get("offered", [])
			var picked := str(reward_data.get("picked", ""))
			if str(reward_data.get("kind", "")) == "relic":
				for relic_id in offered:
					var relic_key := str(relic_id)
					offered_relics[relic_key] = int(offered_relics.get(relic_key, 0)) + 1
				if picked != "":
					picked_relics[picked] = int(picked_relics.get(picked, 0)) + 1
			else:
				card_offers += offered.size()
				for card_id in offered:
					var card_key := str(card_id)
					offered_cards[card_key] = int(offered_cards.get(card_key, 0)) + 1
				if bool(reward_data.get("skipped", false)):
					card_skips += 1
				elif picked != "":
					picked_cards[picked] = int(picked_cards.get(picked, 0)) + 1

	return {
		"policy": str(config["policy"]),
		"class_id": str(config["class_id"]),
		"class_name": display_name,
		"runs": run_count,
		"seed": int(config["seed"]),
		"seed_stride": SEED_STRIDE,
		"completed": completed,
		"deaths": run_count - completed,
		"avg_rooms": _div(rooms, run_count),
		"avg_combats": _div(combats, run_count),
		"avg_turns": _div(turns, run_count),
		"avg_rooms_completed": _div(completed_rooms, completed),
		"avg_combats_completed": _div(completed_combats, completed),
		"avg_turns_completed": _div(completed_turns, completed),
		"death_floors": _death_rows(deaths),
		"encounter_size_by_floor": _encounter_rows(floors),
		"carryover_by_floor": _carryover_rows(floors),
		"card_offers": _count_rows(offered_cards),
		"card_picks": _count_rows(picked_cards),
		"card_offer_total": card_offers,
		"card_skips": card_skips,
		"relic_offers": _count_rows(offered_relics),
		"relic_picks": _count_rows(picked_relics),
		"gold": {
			"avg_start": _div(gold_start, run_count),
			"avg_earned": _div(gold_earned, run_count),
			"avg_spent": _div(gold_spent, run_count),
			"avg_end": _div(gold_end, run_count),
		},
		"bosses": [
			{"id": "bellows_saint", "label": "Act 1 Bellows Saint", "fought": act1_fought, "won": act1_won},
			{"id": "ember_regent", "label": "Act 2 Ember Regent", "fought": act2_fought, "won": act2_won},
		],
		"failure_reasons": _count_rows(failures),
		"raises": null,
		"souls": null,
		"horde_size": null,
		"corpse_carryover": null,
	}


func _class_display_name(class_id: String) -> String:
	var class_database := ClassDatabase.new()
	var definition := class_database.get_class_definition(class_id)
	class_database.free()
	var display_name := str(definition.get("display_name", class_id))
	return display_name if display_name != "" else class_id


func _death_rows(deaths: Dictionary) -> Array:
	var rows: Array = []
	for key in deaths.keys():
		var parts := str(key).split("|")
		rows.append({
			"act": int(parts[0]) if parts.size() > 0 else 0,
			"floor": int(parts[1]) if parts.size() > 1 else 0,
			"deaths": int(deaths[key]),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := int(a["act"]) * 10 + int(a["floor"])
		var b_key := int(b["act"]) * 10 + int(b["floor"])
		if a_key == b_key:
			return int(a["deaths"]) > int(b["deaths"])
		return a_key < b_key
	)
	return rows


func _encounter_rows(floors: Dictionary) -> Array:
	var rows: Array = []
	for key in floors.keys():
		var bucket: Dictionary = floors[key]
		if int(bucket.get("battles", 0)) <= 0:
			continue
		var parts := str(key).split("|")
		var battles := int(bucket["battles"])
		rows.append({
			"act": int(parts[0]),
			"floor": int(parts[1]),
			"battles": battles,
			"avg_enemies": _div(int(bucket["enemies"]), battles),
			"avg_turns": _div(int(bucket["combat_turns"]), battles),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["act"]) * 10 + int(a["floor"]) < int(b["act"]) * 10 + int(b["floor"])
	)
	return rows


func _carryover_rows(floors: Dictionary) -> Array:
	var rows: Array = []
	for key in floors.keys():
		var bucket: Dictionary = floors[key]
		var parts := str(key).split("|")
		var entries := int(bucket["entries"])
		rows.append({
			"act": int(parts[0]),
			"floor": int(parts[1]),
			"entries": entries,
			"avg_hp": _div(int(bucket["hp"]), entries),
			"avg_max_hp": _div(int(bucket["max_hp"]), entries),
			"avg_deck_size": _div(int(bucket["deck_size"]), entries),
			"avg_deck_power": _div(int(bucket["deck_power"]), entries),
			"avg_relics": _div(int(bucket["relics"]), entries),
			"avg_gold": _div(int(bucket["gold"]), entries),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["act"]) * 10 + int(a["floor"]) < int(b["act"]) * 10 + int(b["floor"])
	)
	return rows


func _count_rows(counts: Dictionary) -> Array:
	var rows: Array = []
	for key in counts.keys():
		rows.append({"id": str(key), "count": int(counts[key])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) == int(b["count"]):
			return str(a["id"]) < str(b["id"])
		return int(a["count"]) > int(b["count"])
	)
	return rows


func _render_report(config: Dictionary, batches: Array, elapsed_ms: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# EMBER ASCENT balance report")
	lines.append("")
	lines.append("Full runs use the live tower, combat, reward, shop, event, rest, forge, shrine, and observatory rules. Each act is a 5-floor tower (floors 1–5). A completed run defeats the Act 2 boss, The Ember Regent.")
	lines.append("")
	lines.append("- Game version: %s" % GameState.VERSION)
	lines.append("- Runs per policy: %d" % int(config["runs"]))
	lines.append("- Base seed: %d" % int(config["seed"]))
	lines.append("- Per-run seed: base + run_index * %d" % SEED_STRIDE)
	lines.append("- Class: %s" % str(config["class_id"]))
	lines.append("- Policy: %s" % str(config["policy"]))
	if str(config.get("policy_note", "")) != "":
		lines.append("- Note: %s" % str(config["policy_note"]))
	lines.append("- Elapsed: %d ms" % elapsed_ms)
	lines.append("- Length is rooms entered, combats fought, and combat turns. The game does not track in-world time.")
	lines.append("")

	if batches.size() > 1:
		lines.append("## Policy comparison")
		lines.append("")
		lines.append("| Metric | %s | %s |" % [batches[0]["policy"], batches[1]["policy"]])
		lines.append("| --- | ---: | ---: |")
		lines.append("| Completion | %s | %s |" % [
			_completion_cell(batches[0]["summary"]),
			_completion_cell(batches[1]["summary"]),
		])
		lines.append("| Avg rooms | %.2f | %.2f |" % [
			float(batches[0]["summary"]["avg_rooms"]),
			float(batches[1]["summary"]["avg_rooms"]),
		])
		lines.append("| Avg combat turns | %.2f | %.2f |" % [
			float(batches[0]["summary"]["avg_turns"]),
			float(batches[1]["summary"]["avg_turns"]),
		])
		lines.append("| Act 1 boss win rate | %s | %s |" % [
			_boss_cell(batches[0]["summary"], 0),
			_boss_cell(batches[1]["summary"], 0),
		])
		lines.append("| Act 2 boss win rate | %s | %s |" % [
			_boss_cell(batches[0]["summary"], 1),
			_boss_cell(batches[1]["summary"], 1),
		])
		lines.append("| Avg gold end | %.2f | %.2f |" % [
			float(batches[0]["summary"]["gold"]["avg_end"]),
			float(batches[1]["summary"]["gold"]["avg_end"]),
		])
		lines.append("")

	for batch in batches:
		_append_batch_section(lines, batch["summary"])

	lines.append("## Requested metrics this game does not track")
	lines.append("")
	for note in UNMAPPED_METRICS:
		lines.append("- %s" % note)
	lines.append("")
	lines.append("Deck power is the sum of damage, block, draw, temporary Strength, heal, and Burn amounts on cards in the deck when the room is entered.")
	lines.append("")
	return "\n".join(lines)


func _append_batch_section(lines: PackedStringArray, summary: Dictionary) -> void:
	lines.append("## %s / %s" % [summary["class_name"], summary["policy"]])
	lines.append("")
	lines.append("### Run completion")
	lines.append("")
	lines.append("- Completed: %d/%d (%s)" % [
		int(summary["completed"]),
		int(summary["runs"]),
		_pct(int(summary["completed"]), int(summary["runs"])),
	])
	lines.append("- Deaths: %d" % int(summary["deaths"]))
	for boss in summary["bosses"]:
		lines.append("- %s win rate: %d/%d (%s)" % [
			boss["label"],
			int(boss["won"]),
			int(boss["fought"]),
			_pct(int(boss["won"]), int(boss["fought"])),
		])
	lines.append("")
	lines.append("### Death floor distribution")
	lines.append("")
	lines.append("| Act | Floor | Deaths | Share of deaths | Share of runs |")
	lines.append("| ---: | ---: | ---: | ---: | ---: |")
	var death_rows: Array = summary["death_floors"]
	if death_rows.is_empty():
		lines.append("| — | — | 0 | n/a | n/a |")
	for row in death_rows:
		lines.append("| %d | %d | %d | %s | %s |" % [
			int(row["act"]),
			int(row["floor"]),
			int(row["deaths"]),
			_pct(int(row["deaths"]), int(summary["deaths"])),
			_pct(int(row["deaths"]), int(summary["runs"])),
		])
	lines.append("")
	lines.append("### Average run length")
	lines.append("")
	lines.append("- All runs: %.2f rooms, %.2f combats, %.2f combat turns" % [
		float(summary["avg_rooms"]),
		float(summary["avg_combats"]),
		float(summary["avg_turns"]),
	])
	lines.append("- Completed runs only: %.2f rooms, %.2f combats, %.2f combat turns" % [
		float(summary["avg_rooms_completed"]),
		float(summary["avg_combats_completed"]),
		float(summary["avg_turns_completed"]),
	])
	lines.append("")
	lines.append("### Encounter size per floor")
	lines.append("")
	lines.append("There is no horde. This is the average number of enemies combat actually spawned, plus combat turns and a Raise column that stays n/a.")
	lines.append("")
	lines.append("| Act | Floor | Battles | Avg enemies | Avg turns | Raises |")
	lines.append("| ---: | ---: | ---: | ---: | ---: | ---: |")
	for row in summary["encounter_size_by_floor"]:
		lines.append("| %d | %d | %d | %.2f | %.2f | n/a |" % [
			int(row["act"]),
			int(row["floor"]),
			int(row["battles"]),
			float(row["avg_enemies"]),
			float(row["avg_turns"]),
		])
	lines.append("")
	lines.append("### Raise counts")
	lines.append("")
	lines.append("Per floor: n/a. Per run: n/a. This game has no Raise mechanic.")
	lines.append("")
	lines.append("### Reward offer and pick frequencies")
	lines.append("")
	lines.append("Card offers: %d. Skips: %d (%s of card rewards)." % [
		int(summary["card_offer_total"]),
		int(summary["card_skips"]),
		_pct(int(summary["card_skips"]), _card_reward_events(summary)),
	])
	lines.append("")
	lines.append("| Card | Offered | Picked | Pick rate |")
	lines.append("| --- | ---: | ---: | ---: |")
	_append_offer_pick_rows(lines, summary["card_offers"], summary["card_picks"])
	lines.append("")
	lines.append("| Relic | Offered | Picked | Pick rate |")
	lines.append("| --- | ---: | ---: | ---: |")
	_append_offer_pick_rows(lines, summary["relic_offers"], summary["relic_picks"])
	lines.append("")
	lines.append("### Gold")
	lines.append("")
	lines.append("Souls are not a currency in EMBER ASCENT. These are gold totals.")
	lines.append("")
	var gold: Dictionary = summary["gold"]
	lines.append("- Average starting gold: %.2f" % float(gold["avg_start"]))
	lines.append("- Average gold earned: %.2f" % float(gold["avg_earned"]))
	lines.append("- Average gold spent: %.2f" % float(gold["avg_spent"]))
	lines.append("- Average ending gold: %.2f" % float(gold["avg_end"]))
	lines.append("")
	lines.append("### Carryover strength")
	lines.append("")
	lines.append("No corpses or reserves are carried between floors. Values below are the state entering each floor.")
	lines.append("")
	lines.append("| Act | Floor | Entries | Avg HP | Avg max HP | Avg deck | Avg deck power | Avg relics | Avg gold |")
	lines.append("| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for row in summary["carryover_by_floor"]:
		lines.append("| %d | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |" % [
			int(row["act"]),
			int(row["floor"]),
			int(row["entries"]),
			float(row["avg_hp"]),
			float(row["avg_max_hp"]),
			float(row["avg_deck_size"]),
			float(row["avg_deck_power"]),
			float(row["avg_relics"]),
			float(row["avg_gold"]),
		])
	lines.append("")
	lines.append("### Boss win rate")
	lines.append("")
	lines.append("| Boss | Fought | Won | Win rate |")
	lines.append("| --- | ---: | ---: | ---: |")
	for boss in summary["bosses"]:
		lines.append("| %s | %d | %d | %s |" % [
			boss["label"],
			int(boss["fought"]),
			int(boss["won"]),
			_pct(int(boss["won"]), int(boss["fought"])),
		])
	lines.append("")
	lines.append("### Common failure reasons")
	lines.append("")
	lines.append("| Reason | Count | Share of failures |")
	lines.append("| --- | ---: | ---: |")
	var reasons: Array = summary["failure_reasons"]
	if reasons.is_empty():
		lines.append("| — | 0 | n/a |")
	for row in reasons:
		lines.append("| %s | %d | %s |" % [
			row["id"],
			int(row["count"]),
			_pct(int(row["count"]), int(summary["deaths"])),
		])
	lines.append("")


func _append_offer_pick_rows(lines: PackedStringArray, offers: Array, picks: Array) -> void:
	var pick_map := {}
	for row in picks:
		pick_map[str(row["id"])] = int(row["count"])
	if offers.is_empty():
		lines.append("| — | 0 | 0 | n/a |")
		return
	for row in offers:
		var card_id := str(row["id"])
		var offered := int(row["count"])
		var picked := int(pick_map.get(card_id, 0))
		lines.append("| %s | %d | %d | %s |" % [card_id, offered, picked, _pct(picked, offered)])


func _card_reward_events(summary: Dictionary) -> int:
	var picks := 0
	for row in summary["card_picks"]:
		picks += int(row["count"])
	return picks + int(summary["card_skips"])


func _completion_cell(summary: Dictionary) -> String:
	return "%d/%d (%s)" % [
		int(summary["completed"]),
		int(summary["runs"]),
		_pct(int(summary["completed"]), int(summary["runs"])),
	]


func _boss_cell(summary: Dictionary, index: int) -> String:
	var bosses: Array = summary["bosses"]
	if index < 0 or index >= bosses.size():
		return "n/a"
	var boss: Dictionary = bosses[index]
	return "%d/%d (%s)" % [int(boss["won"]), int(boss["fought"]), _pct(int(boss["won"]), int(boss["fought"]))]


func _json_payload(config: Dictionary, batches: Array, elapsed_ms: int) -> Dictionary:
	var exported_batches: Array = []
	for batch in batches:
		exported_batches.append({
			"policy": batch["policy"],
			"summary": batch["summary"],
			"runs": batch["runs"],
		})
	return {
		"game": "EMBER ASCENT",
		"version": GameState.VERSION,
		"generated_at": Time.get_datetime_string_from_system(true),
		"elapsed_ms": elapsed_ms,
		"config": {
			"runs": int(config["runs"]),
			"seed": int(config["seed"]),
			"seed_stride": SEED_STRIDE,
			"policy": str(config["policy"]),
			"class_id": str(config["class_id"]),
		},
		"unmapped_metrics": UNMAPPED_METRICS,
		"batches": exported_batches,
	}


func _write_outputs(config: Dictionary, markdown: String, payload: Dictionary, batches: Array) -> Dictionary:
	var basename := "balance_%s_%s_seed%d_n%d" % [
		str(config["policy"]),
		str(config["class_id"]),
		int(config["seed"]),
		int(config["runs"]),
	]
	var json_text := JSON.stringify(payload, "\t")
	var csv_text := _render_csv(batches)
	var res_paths := _write_triplet("res://reports", basename, markdown, json_text, csv_text)
	var user_paths := _write_triplet("user://balance_reports", basename, markdown, json_text, csv_text)
	return {
		"markdown": res_paths.get("markdown", user_paths.get("markdown", "")),
		"json": res_paths.get("json", user_paths.get("json", "")),
		"csv": res_paths.get("csv", user_paths.get("csv", "")),
		"markdown_global": res_paths.get("markdown_global", user_paths.get("markdown_global", "")),
		"json_global": res_paths.get("json_global", user_paths.get("json_global", "")),
		"csv_global": res_paths.get("csv_global", user_paths.get("csv_global", "")),
		"user_markdown": user_paths.get("markdown_global", ""),
		"res_markdown": res_paths.get("markdown_global", ""),
	}


func _write_triplet(dir_path: String, basename: String, markdown: String, json_text: String, csv_text: String) -> Dictionary:
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	var made := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if made != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		push_error("Could not create report directory: %s" % absolute_dir)
		return {}

	var written := {}
	written["markdown"] = _write_named(dir_path, absolute_dir, basename + ".md", markdown)
	written["json"] = _write_named(dir_path, absolute_dir, basename + ".json", json_text)
	written["csv"] = _write_named(dir_path, absolute_dir, basename + ".csv", csv_text)
	_write_named(dir_path, absolute_dir, "latest.md", markdown)
	_write_named(dir_path, absolute_dir, "latest.json", json_text)
	_write_named(dir_path, absolute_dir, "latest.csv", csv_text)
	written["markdown_global"] = absolute_dir.path_join("latest.md")
	written["json_global"] = absolute_dir.path_join("latest.json")
	written["csv_global"] = absolute_dir.path_join("latest.csv")
	return written


func _write_named(dir_path: String, absolute_dir: String, file_name: String, contents: String) -> String:
	var resource_path := dir_path.path_join(file_name)
	var absolute_path := absolute_dir.path_join(file_name)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write %s" % absolute_path)
		return ""
	file.store_string(contents)
	file.close()
	return resource_path


func _render_csv(batches: Array) -> String:
	var header := [
		"run_index", "seed", "class_id", "policy", "completed", "death_act", "death_floor",
		"failure_reason", "rooms", "combats", "turns", "gold_start", "gold_earned", "gold_spent",
		"gold_end", "hp_end", "max_hp_end", "deck_size_end", "deck_power_end", "relic_count_end",
		"act1_boss_fought", "act1_boss_won", "act2_boss_fought", "act2_boss_won",
	]
	var lines: PackedStringArray = PackedStringArray()
	lines.append(",".join(header))
	for batch in batches:
		for run in batch["runs"]:
			var run_data: Dictionary = run
			var cells: PackedStringArray = PackedStringArray()
			for column in header:
				cells.append(_csv_escape(run_data.get(column, "")))
			lines.append(",".join(cells))
	return "\n".join(lines)


func _csv_escape(value: Variant) -> String:
	var text := str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	else:
		_save_backup = PackedByteArray()


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_save_backup)
			file.close()
	else:
		SaveManager.delete_save()
	RunState.reset_run()
	GameState.simulation_quiet = false
	RNG.set_seed(int(Time.get_unix_time_from_system()))


func _pct(part: int, whole: int) -> String:
	if whole <= 0:
		return "n/a"
	return "%.1f%%" % (100.0 * float(part) / float(whole))


func _div(total: int, count: int) -> float:
	if count <= 0:
		return 0.0
	return float(total) / float(count)
