extends Node

var selected_class: String = ""
var max_hp: int = 0
var current_hp: int = 0
var gold: int = 0
var deck: Array[String] = []
var relics: Array[String] = []
var current_act: int = 1
var current_floor: int = 0
var map_data: Array = []
var completed_nodes: Array[String] = []
var current_node_id: String = ""
var run_seed: int = 0


func reset_run() -> void:
	selected_class = ""
	max_hp = 0
	current_hp = 0
	gold = 0
	deck.clear()
	relics.clear()
	current_act = 1
	current_floor = 0
	map_data.clear()
	completed_nodes.clear()
	current_node_id = ""
	run_seed = 0


func has_active_run() -> bool:
	return selected_class != "" and current_hp > 0
