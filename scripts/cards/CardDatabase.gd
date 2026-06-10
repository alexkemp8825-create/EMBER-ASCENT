class_name CardDatabase
extends Node

const ASH_KNIGHT := "ash_knight"
const CINDER_WITCH := "cinder_witch"
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
	"heavy_strike": {
		"id": "heavy_strike",
		"display_name": "Heavy Strike",
		"card_type": "Attack",
		"cost": 2,
		"rarity": "Common",
		"description": "Deal 10 damage.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 10},
		],
		"upgraded_id": "",
	},
	"iron_wall": {
		"id": "iron_wall",
		"display_name": "Iron Wall",
		"card_type": "Skill",
		"cost": 2,
		"rarity": "Common",
		"description": "Gain 8 block.",
		"target_type": "Self",
		"effects": [
			{"type": "block", "amount": 8},
		],
		"upgraded_id": "",
	},
	"deflect": {
		"id": "deflect",
		"display_name": "Deflect",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Common",
		"description": "Gain 4 block. Draw 1 card.",
		"target_type": "Self",
		"effects": [
			{"type": "block", "amount": 4},
			{"type": "draw", "amount": 1},
		],
		"upgraded_id": "",
	},
	"second_wind": {
		"id": "second_wind",
		"display_name": "Second Wind",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Common",
		"description": "Heal 3 HP.",
		"target_type": "Self",
		"effects": [
			{"type": "heal", "amount": 3},
		],
		"upgraded_id": "",
	},
	"ember_wall": {
		"id": "ember_wall",
		"display_name": "Ember Wall",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Common",
		"description": "Gain 6 block.",
		"target_type": "Self",
		"effects": [
			{"type": "block", "amount": 6},
		],
		"upgraded_id": "",
	},
	"piercing_blow": {
		"id": "piercing_blow",
		"display_name": "Piercing Blow",
		"card_type": "Attack",
		"cost": 1,
		"rarity": "Uncommon",
		"description": "Deal 7 damage.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 7},
		],
		"upgraded_id": "",
	},
	"molten_slash": {
		"id": "molten_slash",
		"display_name": "Molten Slash",
		"card_type": "Attack",
		"cost": 2,
		"rarity": "Uncommon",
		"description": "Deal 9 damage.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 9},
		],
		"upgraded_id": "",
	},
	"rally": {
		"id": "rally",
		"display_name": "Rally",
		"card_type": "Skill",
		"cost": 0,
		"rarity": "Uncommon",
		"description": "Draw 2 cards.",
		"target_type": "Self",
		"effects": [
			{"type": "draw", "amount": 2},
		],
		"upgraded_id": "",
	},
	"intimidating_shout": {
		"id": "intimidating_shout",
		"display_name": "Intimidating Shout",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Uncommon",
		"description": "Gain 4 block. Draw 1 card.",
		"target_type": "Self",
		"effects": [
			{"type": "block", "amount": 4},
			{"type": "draw", "amount": 1},
		],
		"upgraded_id": "",
	},
	"cinder_bolt": {
		"id": "cinder_bolt",
		"display_name": "Cinder Bolt",
		"card_type": "Attack",
		"cost": 1,
		"rarity": "Starter",
		"description": "Deal 4 damage. Apply 2 Burn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 4},
			{"type": "enemy_burn", "amount": 2},
		],
		"upgraded_id": "",
	},
	"witch_flame": {
		"id": "witch_flame",
		"display_name": "Witch Flame",
		"card_type": "Attack",
		"cost": 1,
		"rarity": "Starter",
		"description": "Deal 3 damage. Apply 3 Burn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 3},
			{"type": "enemy_burn", "amount": 3},
		],
		"upgraded_id": "",
	},
	"ember_barrier": {
		"id": "ember_barrier",
		"display_name": "Ember Barrier",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Starter",
		"description": "Gain 4 block. Apply 1 Burn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "block", "amount": 4},
			{"type": "enemy_burn", "amount": 1},
		],
		"upgraded_id": "",
	},
	"cinder_wave": {
		"id": "cinder_wave",
		"display_name": "Cinder Wave",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Starter",
		"description": "Apply 4 Burn. Draw 1 card.",
		"target_type": "Enemy",
		"effects": [
			{"type": "enemy_burn", "amount": 4},
			{"type": "draw", "amount": 1},
		],
		"upgraded_id": "",
	},
	"scorch": {
		"id": "scorch",
		"display_name": "Scorch",
		"card_type": "Skill",
		"cost": 0,
		"rarity": "Starter",
		"description": "Apply 2 Burn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "enemy_burn", "amount": 2},
		],
		"upgraded_id": "",
	},
	"fire_sigil": {
		"id": "fire_sigil",
		"display_name": "Fire Sigil",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Common",
		"description": "Apply 5 Burn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "enemy_burn", "amount": 5},
		],
		"upgraded_id": "",
	},
	"cinder_lance": {
		"id": "cinder_lance",
		"display_name": "Cinder Lance",
		"card_type": "Attack",
		"cost": 1,
		"rarity": "Common",
		"description": "Deal 5 damage. Apply 3 Burn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 5},
			{"type": "enemy_burn", "amount": 3},
		],
		"upgraded_id": "",
	},
	"blazefall": {
		"id": "blazefall",
		"display_name": "Blazefall",
		"card_type": "Attack",
		"cost": 2,
		"rarity": "Common",
		"description": "Deal 7 damage. Apply 4 Burn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 7},
			{"type": "enemy_burn", "amount": 4},
		],
		"upgraded_id": "",
	},
	"pyre_shield": {
		"id": "pyre_shield",
		"display_name": "Pyre Shield",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Common",
		"description": "Gain 5 block. Draw 1 card.",
		"target_type": "Self",
		"effects": [
			{"type": "block", "amount": 5},
			{"type": "draw", "amount": 1},
		],
		"upgraded_id": "",
	},
	"feed_the_flame": {
		"id": "feed_the_flame",
		"display_name": "Feed the Flame",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Common",
		"description": "Apply 3 Burn. Gain 1 Strength this turn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "enemy_burn", "amount": 3},
			{"type": "temp_strength", "amount": 1},
		],
		"upgraded_id": "",
	},
	"inferno_chant": {
		"id": "inferno_chant",
		"display_name": "Inferno Chant",
		"card_type": "Attack",
		"cost": 2,
		"rarity": "Uncommon",
		"description": "Deal 8 damage. Apply 6 Burn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "damage", "amount": 8},
			{"type": "enemy_burn", "amount": 6},
		],
		"upgraded_id": "",
	},
	"ash_pact": {
		"id": "ash_pact",
		"display_name": "Ash Pact",
		"card_type": "Skill",
		"cost": 1,
		"rarity": "Uncommon",
		"description": "Apply 3 Burn to ALL enemies.",
		"target_type": "Self",
		"effects": [
			{"type": "enemy_burn_all", "amount": 3},
		],
		"upgraded_id": "",
	},
	"smolder_hex": {
		"id": "smolder_hex",
		"display_name": "Smolder Hex",
		"card_type": "Skill",
		"cost": 0,
		"rarity": "Uncommon",
		"description": "Apply 2 Burn. Draw 2 cards.",
		"target_type": "Enemy",
		"effects": [
			{"type": "enemy_burn", "amount": 2},
			{"type": "draw", "amount": 2},
		],
		"upgraded_id": "",
	},
}

const CARD_CLASSES := {
	"ember_strike": [ASH_KNIGHT],
	"guard_up": [ASH_KNIGHT],
	"burning_oath": [ASH_KNIGHT],
	"burn": [ALL_CLASSES],
	"heavy_strike": [ASH_KNIGHT],
	"iron_wall": [ASH_KNIGHT],
	"deflect": [ASH_KNIGHT],
	"second_wind": [ASH_KNIGHT],
	"ember_wall": [ASH_KNIGHT],
	"piercing_blow": [ASH_KNIGHT],
	"molten_slash": [ASH_KNIGHT],
	"rally": [ASH_KNIGHT],
	"intimidating_shout": [ASH_KNIGHT],
	"cinder_bolt": [CINDER_WITCH],
	"witch_flame": [CINDER_WITCH],
	"ember_barrier": [CINDER_WITCH],
	"cinder_wave": [CINDER_WITCH],
	"scorch": [CINDER_WITCH],
	"fire_sigil": [CINDER_WITCH],
	"cinder_lance": [CINDER_WITCH],
	"blazefall": [CINDER_WITCH],
	"pyre_shield": [CINDER_WITCH],
	"feed_the_flame": [CINDER_WITCH],
	"inferno_chant": [CINDER_WITCH],
	"ash_pact": [CINDER_WITCH],
	"smolder_hex": [CINDER_WITCH],
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
	return _pick_shopable_cards(class_id, count)


func get_shop_cards(class_id: String, count: int) -> Array[CardData]:
	return _pick_shopable_cards(class_id, count)


func _pick_shopable_cards(class_id: String, count: int) -> Array[CardData]:
	var candidates: Array[CardData] = []

	for card_data in get_cards_by_class(class_id):
		if card_data.rarity != "Starter" and card_data.card_type != "Status":
			candidates.append(card_data)

	var results: Array[CardData] = []
	var shuffled: Array = RNG.shuffle_array(candidates)

	for card_data in shuffled:
		if results.size() >= count:
			break
		results.append(card_data)

	return results
