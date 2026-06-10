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
