class_name EnemyData
extends Resource

var id: String = ""
var display_name: String = ""
var max_hp: int = 0
var actions: Array[Dictionary] = []


func setup(data: Dictionary) -> EnemyData:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	max_hp = data.get("max_hp", 0)
	actions = data.get("actions", []).duplicate(true)
	return self
