extends Node

const TowerStateScript := preload("res://scripts/tower/TowerState.gd")

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
var tower_state: TowerState
var active_room_id: String = ""


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
	tower_state = null
	active_room_id = ""


func has_active_run() -> bool:
	return selected_class != "" and current_hp > 0


func create_new_tower() -> void:
	tower_state = TowerStateScript.new()
	var seed_value := run_seed if run_seed != 0 else int(Time.get_unix_time_from_system())
	tower_state.create_new_tower(seed_value)
	current_floor = 0
	current_node_id = tower_state.current_room_id


func get_tower_state() -> TowerState:
	if tower_state == null:
		create_new_tower()

	return tower_state


func enter_room(room_id: String) -> void:
	active_room_id = room_id
	var room := get_tower_state().get_room(room_id)
	if room != null:
		current_floor = room.floor
		current_node_id = room_id


func complete_active_room() -> bool:
	if active_room_id == "":
		return false

	var completed := get_tower_state().mark_room_completed(active_room_id)
	if completed:
		current_node_id = get_tower_state().current_room_id
		current_floor = get_tower_state().get_room(active_room_id).floor

	active_room_id = ""
	return completed


func add_card_to_deck(card_id: String) -> void:
	if card_id == "":
		return

	deck.append(card_id)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return

	gold += amount


func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false

	gold -= amount
	return true


func can_remove_card_from_deck(min_deck_size: int = 5) -> bool:
	return deck.size() > min_deck_size


func remove_card_from_deck(card_id: String, min_deck_size: int = 5) -> bool:
	if not can_remove_card_from_deck(min_deck_size):
		return false

	var card_index := deck.find(card_id)
	if card_index == -1:
		return false

	deck.remove_at(card_index)
	return true


func get_unique_deck_card_ids() -> Array[String]:
	var unique_ids: Array[String] = []
	var seen_ids := {}

	for card_id in deck:
		if seen_ids.has(card_id):
			continue

		seen_ids[card_id] = true
		unique_ids.append(card_id)

	return unique_ids


func add_relic(relic_id: String) -> void:
	if relic_id == "" or relics.has(relic_id):
		return

	relics.append(relic_id)


func has_relic(relic_id: String) -> bool:
	return relics.has(relic_id)
