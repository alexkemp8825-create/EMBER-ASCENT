class_name CardDatabase
extends Node

const ASH_KNIGHT := "ash_knight"
const ALL_CLASSES := "all"

const CARD_DEFINITIONS := {
	"ember_strike": {
		"id": "ember_strike",
		"display_name": "Ember Strike",
		"card_type": "Attack",
		"cost": 1,
		"rarity": "Starter",
		"description": "Deal 6 damage.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 6},
		],
		"upgraded_id": "",
	},
	"guard_up": {
		"id": "guard_up",
		"display_name": "Guard Up",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Starter",
		"description": "Gain 5 block.",
		"target_type": "Self",
		"effects": [
			{"type": "block", "amount": 5},
		],
		"upgraded_id": "",
	},
	"burning_oath": {
		"id": "burning_oath",
		"display_name": "Burning Oath",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Starter",
		"description": "Gain 2 Strength for this turn. Draw 1 card.",
		"target_type": "Self",
		"effects": [
			{"type": "temp_strength", "amount": 2},
			{"type": "draw", "amount": 1},
		],
		"upgraded_id": "",
	},
	"burn": {
		"id": "burn",
		"display_name": "Burn",
		"card_type": "Status",
		"cost": -1,
		"rarity": "Status",
		"description": "Unplayable. At end of turn, take 2 damage, then exhaust.",
		"target_type": "None",
		"effects": [
			{"type": "end_turn_damage", "amount": 2},
			{"type": "exhaust_self"},
		],
		"upgraded_id": "",
	},
}

const CARD_CLASSES := {
	"ember_strike": [ASH_KNIGHT],
	"guard_up": [ASH_KNIGHT],
	"burning_oath": [ASH_KNIGHT],
	"burn": [ALL_CLASSES],
}

var _cards: Dictionary = {}


func _init() -> void:
	load_all_cards()


func load_all_cards() -> void:
	_cards.clear()

	for card_id in CARD_DEFINITIONS:
		_cards[card_id] = CardData.new().setup(CARD_DEFINITIONS[card_id])


func get_card(card_id: String) -> CardData:
	if _cards.is_empty():
		load_all_cards()

	return _cards.get(card_id)


func get_cards_by_class(class_id: String) -> Array[CardData]:
	if _cards.is_empty():
		load_all_cards()

	var results: Array[CardData] = []

	for card_id in _cards:
		var allowed_classes: Array = CARD_CLASSES.get(card_id, [])
		if allowed_classes.has(class_id) or allowed_classes.has(ALL_CLASSES):
			results.append(_cards[card_id])

	return results


func get_reward_cards(class_id: String, count: int) -> Array[CardData]:
	var candidates: Array[CardData] = []

	for card_data in get_cards_by_class(class_id):
		if card_data.rarity != "Starter" and card_data.card_type != "Status":
			candidates.append(card_data)

	var rewards: Array[CardData] = []
	var shuffled := candidates.duplicate()
	var rng_node := get_node_or_null("/root/RNG") if is_inside_tree() else null

	if rng_node != null and rng_node.has_method("shuffle_array"):
		shuffled = rng_node.shuffle_array(candidates)

	for card_data in shuffled:
		if rewards.size() >= count:
			break
		rewards.append(card_data)

	return rewards
