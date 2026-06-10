extends PanelContainer

const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")

@onready var stats_label: Label = %StatsLabel
@onready var status_label: Label = %StatusLabel
@onready var tower_map_canvas: Control = %TowerMapCanvas


func _ready() -> void:
	if tower_map_canvas.has_signal("room_pressed"):
		tower_map_canvas.room_pressed.connect(_on_room_pressed)

	_refresh_map()


func _refresh_map() -> void:
	var tower_state := RunState.get_tower_state()
	stats_label.text = "HP: %d/%d  |  Gold: %d  |  Floor: %d" % [
		RunState.current_hp,
		RunState.max_hp,
		RunState.gold,
		tower_state.get_room(tower_state.current_room_id).floor if tower_state.get_room(tower_state.current_room_id) != null else 0,
	]

	if tower_map_canvas.has_method("refresh"):
		tower_map_canvas.refresh(tower_state)

	var available_rooms := tower_state.get_available_rooms()
	if available_rooms.is_empty():
		status_label.text = "Tower path complete. More floors coming soon."
	else:
		status_label.text = "Choose your next room."


func _on_room_pressed(room: TowerRoomData) -> void:
	RunState.enter_room(room.room_id)

	match room.room_type:
		TowerRoomDatabaseScript.ROOM_BATTLE:
			SceneLoader.change_to_combat(_get_battle_encounter_id(room.floor))
		TowerRoomDatabaseScript.ROOM_BOSS:
			SceneLoader.change_to_combat("bellows_saint")
		TowerRoomDatabaseScript.ROOM_REST:
			SceneLoader.change_to_rest()
		TowerRoomDatabaseScript.ROOM_MARKET:
			SceneLoader.change_to_shop()
		_:
			_complete_placeholder_room(room)


func _get_battle_encounter_id(floor: int) -> String:
	if floor >= 3:
		return "molten_guard"

	if floor >= 2:
		return "furnace_cultist"

	return "charred_rat"


func _complete_placeholder_room(room: TowerRoomData) -> void:
	RunState.complete_active_room()
	status_label.text = "%s cleared." % room.display_name
	_refresh_map()
