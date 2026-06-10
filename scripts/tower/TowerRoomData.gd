extends RefCounted
class_name TowerRoomData

var room_id: String = ""
var room_type: String = ""
var display_name: String = ""
var floor: int = 0
var position: Vector2 = Vector2.ZERO
var connected_room_ids: Array[String] = []
var source_card_id: String = ""
var completed: bool = false
var is_ghost: bool = false
var source_legacy_id: String = ""
var original_room_type: String = ""
var ghost_strength: String = ""
var ghost_anchor_room_id: String = ""


func _init(
	p_room_id: String = "",
	p_room_type: String = "",
	p_display_name: String = "",
	p_floor: int = 0,
	p_position: Vector2 = Vector2.ZERO,
	p_source_card_id: String = ""
) -> void:
	room_id = p_room_id
	room_type = p_room_type
	display_name = p_display_name
	floor = p_floor
	position = p_position
	source_card_id = p_source_card_id


func serialize() -> Dictionary:
	return {
		"room_id": room_id,
		"room_type": room_type,
		"display_name": display_name,
		"floor": floor,
		"position": {
			"x": position.x,
			"y": position.y,
		},
		"connected_room_ids": connected_room_ids.duplicate(),
		"source_card_id": source_card_id,
		"completed": completed,
		"is_ghost": is_ghost,
		"source_legacy_id": source_legacy_id,
		"original_room_type": original_room_type,
		"ghost_strength": ghost_strength,
		"ghost_anchor_room_id": ghost_anchor_room_id,
	}


static func deserialize(data: Dictionary) -> TowerRoomData:
	var room := TowerRoomData.new()
	room.room_id = str(data.get("room_id", ""))
	room.room_type = str(data.get("room_type", ""))
	room.display_name = str(data.get("display_name", ""))
	room.floor = int(data.get("floor", 0))
	room.position = _deserialize_position(data.get("position", {}))
	room.source_card_id = str(data.get("source_card_id", ""))
	room.completed = bool(data.get("completed", false))
	room.is_ghost = bool(data.get("is_ghost", false))
	room.source_legacy_id = str(data.get("source_legacy_id", ""))
	room.original_room_type = str(data.get("original_room_type", ""))
	room.ghost_strength = str(data.get("ghost_strength", ""))
	room.ghost_anchor_room_id = str(data.get("ghost_anchor_room_id", ""))

	room.connected_room_ids.clear()
	for connected_room_id in data.get("connected_room_ids", []):
		room.connected_room_ids.append(str(connected_room_id))

	return room


static func _deserialize_position(value: Variant) -> Vector2:
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))

	if value is Vector2:
		return value

	return Vector2.ZERO
