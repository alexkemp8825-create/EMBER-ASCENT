class_name EnemyDatabase
extends Node

const ENEMY_DEFINITIONS := {
	"charred_rat": {
		"id": "charred_rat",
		"display_name": "Charred Rat",
		"max_hp": 22,
		"actions": [
			{"type": "attack", "amount": 5},
			{"type": "attack", "amount": 5},
			{"type": "block", "amount": 4},
		],
	},
	"furnace_cultist": {
		"id": "furnace_cultist",
		"display_name": "Furnace Cultist",
		"max_hp": 35,
		"actions": [
			{"type": "buff_strength", "amount": 2},
			{"type": "attack", "amount": 7},
			{"type": "attack", "amount": 7},
		],
	},
	"molten_guard": {
		"id": "molten_guard",
		"display_name": "Molten Guard",
		"max_hp": 48,
		"actions": [
			{"type": "block", "amount": 8},
			{"type": "attack", "amount": 10},
			{"type": "attack_block", "attack_amount": 6, "block_amount": 5},
		],
	},
	"bellows_saint": {
		"id": "bellows_saint",
		"display_name": "The Bellows Saint",
		"max_hp": 130,
		"actions": [
			{"type": "attack", "amount": 12},
			{"type": "add_burn", "amount": 1},
			{"type": "block", "amount": 15},
			{"type": "big_attack_warning"},
			{"type": "attack", "amount": 24},
		],
	},
	"ember_warden": {
		"id": "ember_warden",
		"display_name": "Ember Warden",
		"max_hp": 65,
		"actions": [
			{"type": "block", "amount": 10},
			{"type": "attack", "amount": 11},
			{"type": "buff_strength", "amount": 2},
			{"type": "attack", "amount": 14},
		],
	},
	"cinder_colossus": {
		"id": "cinder_colossus",
		"display_name": "Cinder Colossus",
		"max_hp": 88,
		"actions": [
			{"type": "attack", "amount": 10},
			{"type": "block", "amount": 12},
			{"type": "attack_block", "attack_amount": 8, "block_amount": 8},
			{"type": "attack", "amount": 16},
		],
	},
	"furnace_hound": {
		"id": "furnace_hound",
		"display_name": "Furnace Hound",
		"max_hp": 42,
		"actions": [
			{"type": "attack", "amount": 7},
			{"type": "attack", "amount": 9},
			{"type": "add_burn", "amount": 1},
		],
	},
	"ash_zealot": {
		"id": "ash_zealot",
		"display_name": "Ash Zealot",
		"max_hp": 58,
		"actions": [
			{"type": "buff_strength", "amount": 3},
			{"type": "attack", "amount": 9},
			{"type": "attack", "amount": 11},
		],
	},
	"ember_regent": {
		"id": "ember_regent",
		"display_name": "The Ember Regent",
		"max_hp": 155,
		"actions": [
			{"type": "attack", "amount": 14},
			{"type": "block", "amount": 18},
			{"type": "add_burn", "amount": 2},
			{"type": "big_attack_warning"},
			{"type": "attack", "amount": 28},
		],
	},
}

var _enemies: Dictionary = {}


func _init() -> void:
	load_all_enemies()


func load_all_enemies() -> void:
	_enemies.clear()

	for enemy_id in ENEMY_DEFINITIONS:
		_enemies[enemy_id] = EnemyData.new().setup(ENEMY_DEFINITIONS[enemy_id])


func get_enemy(enemy_id: String) -> EnemyData:
	if _enemies.is_empty():
		load_all_enemies()

	return _enemies.get(enemy_id)


func create_enemy(enemy_id: String) -> EnemyInstance:
	var enemy_data := get_enemy(enemy_id)
	if enemy_data == null:
		push_error("Unknown enemy requested: %s" % enemy_id)
		enemy_data = EnemyData.new().setup({
			"id": enemy_id,
			"display_name": "Unknown Enemy",
			"max_hp": 1,
			"actions": [],
		})

	return EnemyInstance.new().setup(enemy_data)
