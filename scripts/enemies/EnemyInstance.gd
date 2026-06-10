class_name EnemyInstance
extends Resource

var enemy_id: String = ""
var display_name: String = ""
var max_hp: int = 0
var hp: int = 0
var block: int = 0
var strength: int = 0
var burn_stacks: int = 0
var actions: Array[Dictionary] = []
var action_index: int = 0


func setup(data: EnemyData) -> EnemyInstance:
	enemy_id = data.id
	display_name = data.display_name
	max_hp = data.max_hp
	hp = data.max_hp
	block = 0
	strength = 0
	burn_stacks = 0
	actions.clear()
	for action in data.actions:
		actions.append(action)
	action_index = 0
	return self


func is_alive() -> bool:
	return hp > 0


func get_current_action() -> Dictionary:
	if actions.is_empty():
		return {}

	return actions[action_index]


func advance_action() -> void:
	if actions.is_empty():
		return

	action_index = (action_index + 1) % actions.size()


func take_damage(amount: int) -> int:
	var blocked_damage: int = min(block, amount)
	var damage: int = amount - blocked_damage
	block -= blocked_damage
	hp = max(0, hp - damage)
	return damage


func gain_block(amount: int) -> void:
	block += amount


func gain_strength(amount: int) -> void:
	strength += amount


func apply_burn(amount: int) -> void:
	if amount <= 0:
		return

	burn_stacks += amount
