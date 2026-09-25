class_name MinionInstance
extends RefCounted

var kind: String = ""
var display_name: String = ""
var max_hp: int = 0
var hp: int = 0
var block: int = 0
var attack: int = 0


func setup(minion_kind: String, minion_name: String, minion_hp: int, minion_attack: int) -> MinionInstance:
	kind = minion_kind
	display_name = minion_name
	max_hp = maxi(minion_hp, 1)
	hp = max_hp
	block = 0
	attack = maxi(minion_attack, 0)
	return self


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int) -> int:
	var blocked_damage: int = mini(block, amount)
	var damage: int = amount - blocked_damage
	block -= blocked_damage
	hp = maxi(0, hp - damage)
	return damage
