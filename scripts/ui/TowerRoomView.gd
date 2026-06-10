extends Button

signal room_pressed(room: TowerRoomData)

var room_data: TowerRoomData


func _ready() -> void:
	pressed.connect(_on_pressed)


func set_room(room: TowerRoomData, is_current: bool, is_available: bool) -> void:
	room_data = room

	if room.is_ghost:
		text = _get_ghost_room_text(room)
		tooltip_text = "This room is an echo of a past run."
	else:
		text = "%s\nFloor %d" % [room.display_name, room.floor]
		tooltip_text = room.room_type.capitalize()

	if room.completed:
		modulate = _get_completed_modulate(room)
		disabled = true
	elif is_current:
		modulate = _get_current_modulate(room)
		disabled = true
	elif is_available:
		modulate = _get_available_modulate(room)
		disabled = false
	else:
		modulate = _get_locked_modulate(room)
		disabled = true


func _get_ghost_room_text(room: TowerRoomData) -> String:
	var legacy_run := LegacyManager.get_legacy_run_by_id(room.source_legacy_id)
	var run_number := legacy_run.run_number if legacy_run != null else 0
	return "GHOST\nRun %d" % run_number


func _get_completed_modulate(room: TowerRoomData) -> Color:
	if room.is_ghost:
		return Color(0.45, 0.4, 0.65, 0.7)

	return Color(0.55, 0.55, 0.55, 1.0)


func _get_current_modulate(room: TowerRoomData) -> Color:
	if room.is_ghost:
		return Color(0.75, 0.65, 1.0, 1.0)

	return Color(1.0, 0.85, 0.45, 1.0)


func _get_available_modulate(room: TowerRoomData) -> Color:
	if room.is_ghost:
		return Color(0.7, 0.6, 0.95, 1.0)

	return Color(1.0, 1.0, 1.0, 1.0)


func _get_locked_modulate(room: TowerRoomData) -> Color:
	if room.is_ghost:
		return Color(0.5, 0.45, 0.7, 0.75)

	return Color(0.7, 0.7, 0.7, 1.0)


func _on_pressed() -> void:
	if room_data != null:
		room_pressed.emit(room_data)
