extends Control

const TowerRoomViewScene := preload("res://scenes/ui/TowerRoomView.tscn")

signal room_pressed(room: TowerRoomData)

const ROOM_NODE_SIZE := Vector2(140, 72)
const CANVAS_PADDING := Vector2(80, 80)
const CANVAS_WIDTH := 800.0
const CANVAS_BASE_HEIGHT := 960.0

var _tower_state: TowerState
var _room_views: Dictionary = {}


func refresh(tower_state: TowerState) -> void:
	_tower_state = tower_state
	_clear_room_views()
	_update_canvas_size()
	_create_room_views()
	queue_redraw()


func _clear_room_views() -> void:
	for child in get_children():
		child.queue_free()

	_room_views.clear()


func _create_room_views() -> void:
	if _tower_state == null:
		return

	var available_room_ids := {}
	for room in _tower_state.get_available_rooms():
		available_room_ids[room.room_id] = true

	for room in _tower_state.rooms:
		var room_view := TowerRoomViewScene.instantiate()
		add_child(room_view)
		room_view.position = _room_screen_position(room) - (ROOM_NODE_SIZE * 0.5)
		room_view.custom_minimum_size = ROOM_NODE_SIZE
		room_view.size = ROOM_NODE_SIZE
		room_view.set_room(
			room,
			room.room_id == _tower_state.current_room_id,
			available_room_ids.has(room.room_id)
		)
		room_view.room_pressed.connect(_on_room_pressed)
		_room_views[room.room_id] = room_view

	_update_canvas_size()


func _update_canvas_size() -> void:
	var canvas_height := CANVAS_BASE_HEIGHT
	if _tower_state != null:
		canvas_height = max(
			CANVAS_BASE_HEIGHT,
			absf(_tower_state.highest_floor) * TowerState.ROOM_VERTICAL_SPACING + (CANVAS_PADDING.y * 2.0) + ROOM_NODE_SIZE.y
		)

	custom_minimum_size = Vector2(CANVAS_WIDTH, canvas_height)
	size = custom_minimum_size


func _room_screen_position(room: TowerRoomData) -> Vector2:
	return Vector2(CANVAS_WIDTH * 0.5, size.y - CANVAS_PADDING.y) + room.position


func _draw() -> void:
	if _tower_state == null:
		return

	for connection in _tower_state.connections:
		var from_room := _tower_state.get_room(str(connection.get("from", "")))
		var to_room := _tower_state.get_room(str(connection.get("to", "")))
		if from_room == null or to_room == null:
			continue

		var from_position := _room_screen_position(from_room)
		var to_position := _room_screen_position(to_room)
		draw_line(from_position, to_position, Color(0.75, 0.55, 0.35, 0.9), 3.0)


func _on_room_pressed(room: TowerRoomData) -> void:
	room_pressed.emit(room)
