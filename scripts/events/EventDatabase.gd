class_name EventDatabase
extends Node

const EVENT_DEFINITIONS := {
	"emberscript_scribe": {
		"id": "emberscript_scribe",
		"title": "Emberscript Scribe",
		"description": "A hooded scribe offers to trade your warmth for ember-coins.",
		"choices": [
			{
				"id": "trade_blood",
				"text": "Trade 6 HP for 28 gold.",
				"effects": [
					{"type": "damage", "amount": 6},
					{"type": "gold", "amount": 28},
				],
			},
			{
				"id": "decline",
				"text": "Decline and move on.",
				"effects": [],
			},
		],
	},
	"cracked_altar": {
		"id": "cracked_altar",
		"title": "Cracked Altar",
		"description": "A fractured altar hums with dying embers.",
		"choices": [
			{
				"id": "pray",
				"text": "Pray for healing (restore 12 HP).",
				"effects": [
					{"type": "heal", "amount": 12},
				],
			},
			{
				"id": "donate",
				"text": "Donate 35 gold for +3 Max HP.",
				"effects": [
					{"type": "gold_cost", "amount": 35},
					{"type": "max_hp", "amount": 3},
				],
			},
			{
				"id": "leave",
				"text": "Leave the altar untouched.",
				"effects": [],
			},
		],
	},
	"wandering_merchant": {
		"id": "wandering_merchant",
		"title": "Wandering Merchant",
		"description": "A masked merchant opens a satchel of singed cards.",
		"choices": [
			{
				"id": "buy_card",
				"text": "Pay 40 gold for a random card.",
				"effects": [
					{"type": "gold_cost", "amount": 40},
					{"type": "add_card", "card_id": "random_shop"},
				],
			},
			{
				"id": "haggle",
				"text": "Haggle and gain 15 gold.",
				"effects": [
					{"type": "gold", "amount": 15},
				],
			},
			{
				"id": "pass",
				"text": "Ignore the merchant.",
				"effects": [],
			},
		],
	},
	"smoldering_cache": {
		"id": "smoldering_cache",
		"title": "Smoldering Cache",
		"description": "A locked chest pulses with heat at the tower's edge.",
		"choices": [
			{
				"id": "force_open",
				"text": "Force it open (take 22 gold, lose 5 HP).",
				"effects": [
					{"type": "gold", "amount": 22},
					{"type": "damage", "amount": 5},
				],
			},
			{
				"id": "careful_open",
				"text": "Pick the lock carefully (gain 14 gold).",
				"effects": [
					{"type": "gold", "amount": 14},
				],
			},
			{
				"id": "walk_away",
				"text": "Walk away.",
				"effects": [],
			},
		],
	},
	"lost_knight": {
		"id": "lost_knight",
		"title": "Lost Knight",
		"description": "An armored knight slumps against the wall, breathing hard.",
		"choices": [
			{
				"id": "help",
				"text": "Share supplies (lose 20 gold, heal 10 HP).",
				"effects": [
					{"type": "gold_cost", "amount": 20},
					{"type": "heal", "amount": 10},
				],
			},
			{
				"id": "duel",
				"text": "Challenge the knight (lose 8 HP, gain 25 gold).",
				"effects": [
					{"type": "damage", "amount": 8},
					{"type": "gold", "amount": 25},
				],
			},
			{
				"id": "ignore",
				"text": "Pass in silence.",
				"effects": [],
			},
		],
	},
	"ember_storm": {
		"id": "ember_storm",
		"title": "Ember Storm",
		"description": "A burst of cinders sweeps across the stairwell.",
		"choices": [
			{
				"id": "endure",
				"text": "Brace through the storm (lose 7 HP).",
				"effects": [
					{"type": "damage", "amount": 7},
				],
			},
			{
				"id": "shelter",
				"text": "Pay 18 gold for sheltered passage.",
				"effects": [
					{"type": "gold_cost", "amount": 18},
				],
			},
			{
				"id": "dash",
				"text": "Sprint through (lose 3 HP, gain 10 gold).",
				"effects": [
					{"type": "damage", "amount": 3},
					{"type": "gold", "amount": 10},
				],
			},
		],
	},
}

var _events: Dictionary = {}


func _init() -> void:
	load_all_events()


func load_all_events() -> void:
	_events.clear()

	for event_id in EVENT_DEFINITIONS:
		_events[event_id] = EventData.new().setup(EVENT_DEFINITIONS[event_id])


func get_event(event_id: String) -> EventData:
	if _events.is_empty():
		load_all_events()

	return _events.get(event_id)


func pick_random_event_id(rng: RandomNumberGenerator) -> String:
	var event_ids: Array[String] = []
	for event_id in _events.keys():
		event_ids.append(str(event_id))

	if event_ids.is_empty():
		return ""

	return event_ids[rng.randi_range(0, event_ids.size() - 1)]
