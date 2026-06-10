class_name ClassDatabase
extends Node

const ASH_KNIGHT := "ash_knight"
const CINDER_WITCH := "cinder_witch"

const PLAYABLE_CLASSES: Array[String] = [
	ASH_KNIGHT,
	CINDER_WITCH,
]

const CLASS_DEFINITIONS := {
	ASH_KNIGHT: {
		"id": ASH_KNIGHT,
		"display_name": "Ash Knight",
		"max_hp": 75,
		"starting_gold": 99,
		"starter_relic": "cracked_helm",
		"starter_deck": [
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
		],
	},
	CINDER_WITCH: {
		"id": CINDER_WITCH,
		"display_name": "Cinder Witch",
		"max_hp": 68,
		"starting_gold": 95,
		"starter_relic": "smoldering_tinder",
		"starter_deck": [
			"cinder_bolt",
			"cinder_bolt",
			"cinder_bolt",
			"cinder_bolt",
			"witch_flame",
			"witch_flame",
			"ember_barrier",
			"ember_barrier",
			"ember_barrier",
			"cinder_wave",
		],
	},
}


func get_class_definition(class_id: String) -> Dictionary:
	return CLASS_DEFINITIONS.get(class_id, {}).duplicate(true)


func is_playable(class_id: String) -> bool:
	return PLAYABLE_CLASSES.has(class_id)
