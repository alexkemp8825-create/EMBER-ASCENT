extends RefCounted
class_name TowerState

const TowerRoomDataScript := preload("res://scripts/tower/TowerRoomData.gd")
const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")
const TowerGeneratorScript := preload("res://scripts/tower/TowerGenerator.gd")
const GhostRoomPlacerScript := preload("res://scripts/tower/GhostRoomPlacer.gd")
const EventDatabaseScript := preload("res://scripts/events/EventDatabase.gd")

const ROOM_VERTICAL_SPACING := 160.0
const HORIZONTAL_LANE_SPACING := 180.0

var rooms: Array = []
var connections: Array = []
var current_room_id: String = ""
var highest_floor: int = 0
var tower_seed: int = 0


func create_new_tower(seed_value: int = -1) -> void:
	if seed_value < 0:
		tower_seed = int(Time.get_unix_time_from_system())
	else:
		tower_seed = seed_value

	TowerGeneratorScript.generate_act_one(self, tower_seed)
	GhostRoomPlacerScript.add_ghost_rooms(self, tower_seed)


func add_room(room_type: String, source_card_id: String, floor: int) -> TowerRoomData:
	return add_room_at(room_type, floor, 0, source_card_id)


func add_room_at(
	room_type: String,
	floor: int,
	lane: int,
	source_card_id: String = ""
) -> TowerRoomData:
	var room_id := _generate_room_id(room_type)
	var room := _create_room(room_id, room_type, source_card_id, floor, lane)
	_apply_event_room_metadata(room)
	rooms.append(room)
	highest_floor = max(highest_floor, floor)
	return room


func add_ghost_room_at(
	floor: int,
	lane: int,
	source_legacy_id: String,
	run_number: int,
	original_room_type: String,
	ghost_strength: String,
	anchor_room_id: String
) -> TowerRoomData:
	var room_id := _generate_room_id(TowerRoomDatabaseScript.ROOM_GHOST)
	var room := _create_room(
		room_id,
		TowerRoomDatabaseScript.ROOM_GHOST,
		"",
		floor,
		lane
	)
	room.is_ghost = true
	room.source_legacy_id = source_legacy_id
	room.original_room_type = original_room_type
	room.ghost_strength = ghost_strength
	room.ghost_anchor_room_id = anchor_room_id
	room.display_name = "G\nGHOST"
	rooms.append(room)
	highest_floor = max(highest_floor, floor)
	return room


func complete_ghost_room(room_id: String) -> bool:
	var room := get_room(room_id)
	if room == null or not room.is_ghost:
		return false

	room.completed = true
	if room.ghost_anchor_room_id != "":
		current_room_id = room.ghost_anchor_room_id
	else:
		current_room_id = room.room_id

	highest_floor = max(highest_floor, room.floor)
	return true


func connect_rooms(room_a_id: String, room_b_id: String) -> bool:
	var room_a := get_room(room_a_id)
	var room_b := get_room(room_b_id)
	if room_a == null or room_b == null:
		return false

	if not room_a.connected_room_ids.has(room_b_id):
		room_a.connected_room_ids.append(room_b_id)

	for connection in connections:
		if connection.get("from", "") == room_a_id and connection.get("to", "") == room_b_id:
			return true

	connections.append({
		"from": room_a_id,
		"to": room_b_id,
	})
	return true


func get_available_rooms() -> Array:
	var available_rooms: Array = []
	var current_room := get_room(current_room_id)
	if current_room == null:
		return available_rooms

	for connected_room_id in current_room.connected_room_ids:
		var connected_room := get_room(connected_room_id)
		if connected_room != null and not connected_room.completed:
			available_rooms.append(connected_room)

	return available_rooms


func is_boss_defeated() -> bool:
	for room in rooms:
		if room.room_type == TowerRoomDatabaseScript.ROOM_BOSS and room.completed:
			return true

	return false


func mark_room_completed(room_id: String) -> bool:
	var room := get_room(room_id)
	if room == null:
		return false

	room.completed = true
	current_room_id = room.room_id
	highest_floor = max(highest_floor, room.floor)
	return true


func get_room(room_id: String) -> TowerRoomData:
	for room in rooms:
		if room.room_id == room_id:
			return room

	return null


func serialize() -> Dictionary:
	var serialized_rooms: Array = []
	for room in rooms:
		serialized_rooms.append(room.serialize())

	var serialized_connections: Array = []
	for connection in connections:
		serialized_connections.append(connection.duplicate(true))

	return {
		"rooms": serialized_rooms,
		"connections": serialized_connections,
		"current_room_id": current_room_id,
		"highest_floor": highest_floor,
		"tower_seed": tower_seed,
	}


func deserialize(data: Dictionary) -> void:
	rooms.clear()
	connections.clear()

	for room_data in data.get("rooms", []):
		if room_data is Dictionary:
			rooms.append(TowerRoomDataScript.deserialize(room_data))

	for connection_data in data.get("connections", []):
		if connection_data is Dictionary:
			connections.append({
				"from": str(connection_data.get("from", "")),
				"to": str(connection_data.get("to", "")),
			})

	current_room_id = str(data.get("current_room_id", ""))
	highest_floor = int(data.get("highest_floor", 0))
	tower_seed = int(data.get("tower_seed", 0))


func _create_room(
	room_id: String,
	room_type: String,
	source_card_id: String,
	floor: int,
	lane: int = 0
) -> TowerRoomData:
	var display_name := TowerRoomDatabaseScript.get_default_display_name(room_type)
	var room_position := Vector2(
		float(lane) * HORIZONTAL_LANE_SPACING,
		-float(floor) * ROOM_VERTICAL_SPACING
	)
	return TowerRoomDataScript.new(
		room_id,
		room_type,
		display_name,
		floor,
		room_position,
		source_card_id
	)


func _apply_event_room_metadata(room: TowerRoomData) -> void:
	if room.room_type != TowerRoomDatabaseScript.ROOM_EVENT:
		return

	if room.source_card_id == "":
		return

	var event_database := EventDatabaseScript.new()
	var event_data := event_database.get_event(room.source_card_id)
	if event_data != null:
		room.display_name = event_data.title


func _generate_room_id(room_type: String) -> String:
	var room_index := rooms.size()
	var room_id := "%s_%d" % [room_type, room_index]

	while get_room(room_id) != null:
		room_index += 1
		room_id = "%s_%d" % [room_type, room_index]

	return room_id
