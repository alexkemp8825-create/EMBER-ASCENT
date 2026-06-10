class_name RelicDatabase
extends Node

const RELIC_DEFINITIONS := {
	"cracked_helm": {
		"id": "cracked_helm",
		"display_name": "Cracked Helm",
		"description": "At the start of combat, gain 2 Block.",
		"rarity": "Starter",
	},
	"ember_heart": {
		"id": "ember_heart",
		"display_name": "Ember Heart",
		"description": "At the start of combat, heal 2 HP.",
		"rarity": "Uncommon",
	},
	"ash_shield": {
		"id": "ash_shield",
		"display_name": "Ash Shield",
		"description": "At the start of combat, gain 3 Block.",
		"rarity": "Uncommon",
	},
	"smoldering_brand": {
		"id": "smoldering_brand",
		"display_name": "Smoldering Brand",
		"description": "At the start of combat, gain 1 Strength.",
		"rarity": "Rare",
	},
	"smoldering_tinder": {
		"id": "smoldering_tinder",
		"display_name": "Smoldering Tinder",
		"description": "At the start of combat, apply 2 Burn to a random enemy.",
		"rarity": "Starter",
	},
}

const BOSS_REWARD_POOL: Array[String] = [
	"ember_heart",
	"ash_shield",
	"smoldering_brand",
]

const SHOP_RELIC_POOL: Array[String] = BOSS_REWARD_POOL

var _relics: Dictionary = {}


func _init() -> void:
	load_all_relics()


func load_all_relics() -> void:
	_relics.clear()

	for relic_id in RELIC_DEFINITIONS:
		_relics[relic_id] = RelicData.new().setup(RELIC_DEFINITIONS[relic_id])


func get_relic(relic_id: String) -> RelicData:
	if _relics.is_empty():
		load_all_relics()

	return _relics.get(relic_id)


func get_boss_reward_choices(count: int, excluded_ids: Array[String] = []) -> Array[RelicData]:
	var candidates: Array[RelicData] = []

	for relic_id in BOSS_REWARD_POOL:
		if excluded_ids.has(relic_id):
			continue

		var relic_data := get_relic(relic_id)
		if relic_data != null:
			candidates.append(relic_data)

	var shuffled: Array = RNG.shuffle_array(candidates)
	var choices: Array[RelicData] = []

	for relic in shuffled:
		if choices.size() >= count:
			break
		choices.append(relic)

	return choices


func get_shop_relic_offer(excluded_ids: Array[String] = []) -> RelicData:
	var choices := get_shop_relic_choices(1, excluded_ids)
	if choices.is_empty():
		return null

	return choices[0]


func get_shop_relic_choices(count: int, excluded_ids: Array[String] = []) -> Array[RelicData]:
	var candidates: Array[RelicData] = []

	for relic_id in SHOP_RELIC_POOL:
		if excluded_ids.has(relic_id):
			continue

		var relic_data := get_relic(relic_id)
		if relic_data != null:
			candidates.append(relic_data)

	var shuffled: Array = RNG.shuffle_array(candidates)
	var choices: Array[RelicData] = []

	for relic in shuffled:
		if choices.size() >= count:
			break
		choices.append(relic)

	return choices
