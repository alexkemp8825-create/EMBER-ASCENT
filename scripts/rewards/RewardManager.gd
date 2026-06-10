class_name RewardManager
extends RefCounted

const GOLD_BY_ENCOUNTER := {
	"charred_rat": 12,
	"furnace_cultist": 18,
	"molten_guard": 24,
	"bellows_saint": 55,
}

const BOSS_GOLD_BONUS := 15
const CARD_REWARD_COUNT := 3
const RELIC_REWARD_COUNT := 3


static func build_combat_reward_payload(encounter_id: String, floor: int) -> Dictionary:
	var is_boss := encounter_id == "bellows_saint"
	var gold := get_gold_reward(encounter_id, floor, is_boss)
	var card_database := CardDatabase.new()
	var relic_database := RelicDatabase.new()
	var card_choices: Array[String] = []

	if not is_boss:
		for card_data in card_database.get_reward_cards(RunState.selected_class, CARD_REWARD_COUNT):
			card_choices.append(card_data.id)

	var relic_choices: Array[String] = []
	if is_boss:
		for relic_data in relic_database.get_boss_reward_choices(RELIC_REWARD_COUNT, RunState.relics):
			relic_choices.append(relic_data.id)

	return {
		"encounter_id": encounter_id,
		"floor": floor,
		"is_boss": is_boss,
		"gold": gold,
		"card_choices": card_choices,
		"relic_choices": relic_choices,
	}


static func get_gold_reward(encounter_id: String, floor: int, is_boss: bool) -> int:
	var base_gold := int(GOLD_BY_ENCOUNTER.get(encounter_id, 10))
	var floor_bonus := max(floor, 0) * 2

	if is_boss:
		return base_gold + BOSS_GOLD_BONUS + floor_bonus

	return base_gold + floor_bonus
