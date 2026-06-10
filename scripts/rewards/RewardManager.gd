class_name RewardManager
extends RefCounted

const GOLD_BY_ENCOUNTER := {
	"charred_rat": 12,
	"furnace_cultist": 18,
	"molten_guard": 24,
	"bellows_saint": 55,
	"ember_warden": 28,
	"cinder_colossus": 34,
	"furnace_hound": 16,
	"ash_zealot": 22,
	"ember_regent": 65,
}

const BOSS_ENCOUNTER_IDS: Array[String] = [
	"bellows_saint",
	"ember_regent",
]

const ELITE_ENCOUNTER_IDS: Array[String] = [
	"ember_warden",
	"cinder_colossus",
]

const BOSS_GOLD_BONUS := 15
const ELITE_GOLD_BONUS := 14
const ACT_GOLD_BONUS := 8
const CARD_REWARD_COUNT := 3
const ELITE_CARD_REWARD_COUNT := 4
const RELIC_REWARD_COUNT := 3
const FINAL_ACT := 2


static func build_combat_reward_payload(encounter_id: String, floor: int) -> Dictionary:
	var is_boss := is_boss_encounter(encounter_id)
	var is_elite := is_elite_encounter(encounter_id)
	var gold := get_gold_reward(encounter_id, floor, is_boss, is_elite)
	var card_database := CardDatabase.new()
	var relic_database := RelicDatabase.new()
	var card_choices: Array[String] = []

	if not is_boss:
		var reward_count := ELITE_CARD_REWARD_COUNT if is_elite else CARD_REWARD_COUNT
		for card_data in card_database.get_reward_cards(RunState.selected_class, reward_count):
			card_choices.append(card_data.id)

	var relic_choices: Array[String] = []
	if is_boss:
		for relic_data in relic_database.get_boss_reward_choices(RELIC_REWARD_COUNT, RunState.relics):
			relic_choices.append(relic_data.id)

	return {
		"encounter_id": encounter_id,
		"floor": floor,
		"is_boss": is_boss,
		"is_elite": is_elite,
		"gold": gold,
		"card_choices": card_choices,
		"relic_choices": relic_choices,
	}


static func is_boss_encounter(encounter_id: String) -> bool:
	return BOSS_ENCOUNTER_IDS.has(encounter_id)


static func is_elite_encounter(encounter_id: String) -> bool:
	return ELITE_ENCOUNTER_IDS.has(encounter_id)


static func get_gold_reward(encounter_id: String, floor: int, is_boss: bool, is_elite: bool) -> int:
	var base_gold := int(GOLD_BY_ENCOUNTER.get(encounter_id, 10))
	var floor_bonus: int = maxi(floor, 0) * 2
	var act_bonus: int = maxi(RunState.current_act - 1, 0) * ACT_GOLD_BONUS
	var total: int = base_gold + floor_bonus + act_bonus

	if is_boss:
		total += BOSS_GOLD_BONUS

	if is_elite:
		total += ELITE_GOLD_BONUS

	return total


static func get_boss_encounter_for_act(act: int) -> String:
	if act >= FINAL_ACT:
		return "ember_regent"

	return "bellows_saint"
