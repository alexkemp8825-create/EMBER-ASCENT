extends RefCounted
class_name TowerState

const TowerRoomDataScript := preload("res://scripts/tower/TowerRoomData.gd")
const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")

const ROOM_VERTICAL_SPACING := 160.0

var rooms: Array = []
var connections: Array = []
var current_room_id: String = ""
var highest_floor: int = 0
var tower_seed: int = 0


func create_new_tower() -> void:
	rooms.clear()
	connections.clear()

	tower_seed = int(Time.get_unix_time_from_system())

	var entrance := _create_room(
		"room_0",
		TowerRoomDatabaseScript.ROOM_ENTRANCE,
		"",
		0
	)
	var battle := _create_room(
		"room_1",
		TowerRoomDatabaseScript.ROOM_BATTLE,
		"",
		1
	)
	var boss := _create_room(
		"room_2",
		TowerRoomDatabaseScript.ROOM_BOSS,
		"",
		5
	)

	entrance.completed = true

	rooms.append(entrance)
	rooms.append(battle)
	rooms.append(boss)

	current_room_id = entrance.room_id
	highest_floor = boss.floor

	connect_rooms(entrance.room_id, battle.room_id)
	connect_rooms(battle.room_id, boss.room_id)


func add_room(room_type: String, source_card_id: String, floor: int) -> TowerRoomData:
	var room_id := _generate_room_id(room_type)
	var room := _create_room(room_id, room_type, source_card_id, floor)
	rooms.append(room)
	highest_floor = max(highest_floor, floor)
	return room


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


func _create_room(room_id: String, room_type: String, source_card_id: String, floor: int) -> TowerRoomData:
	var display_name := TowerRoomDatabaseScript.get_default_display_name(room_type)
	var room_position := Vector2(0.0, -float(floor) * ROOM_VERTICAL_SPACING)
	return TowerRoomDataScript.new(
		room_id,
		room_type,
		display_name,
		floor,
		room_position,
		source_card_id
	)


func _generate_room_id(room_type: String) -> String:
	var room_index := rooms.size()
	var room_id := "%s_%d" % [room_type, room_index]

	while get_room(room_id) != null:
		room_index += 1
		room_id = "%s_%d" % [room_type, room_index]

	return room_id
