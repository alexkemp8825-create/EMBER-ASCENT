extends Button

signal room_pressed(room: TowerRoomData)

var room_data: TowerRoomData


func _ready() -> void:
	pressed.connect(_on_pressed)


func set_room(room: TowerRoomData, is_current: bool, is_available: bool) -> void:
	room_data = room
	text = "%s\nFloor %d" % [room.display_name, room.floor]
	tooltip_text = room.room_type.capitalize()

	if room.completed:
		modulate = Color(0.55, 0.55, 0.55, 1.0)
		disabled = true
	elif is_current:
		modulate = Color(1.0, 0.85, 0.45, 1.0)
		disabled = true
	elif is_available:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		disabled = false
	else:
		modulate = Color(0.7, 0.7, 0.7, 1.0)
		disabled = true


func _on_pressed() -> void:
	if room_data != null:
		room_pressed.emit(room_data)
