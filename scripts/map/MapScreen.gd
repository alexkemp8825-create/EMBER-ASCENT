extends PanelContainer

const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")
const TowerGeneratorScript := preload("res://scripts/tower/TowerGenerator.gd")
const RewardManagerScript := preload("res://scripts/rewards/RewardManager.gd")
const LegacyRunDataScript := preload("res://scripts/legacy/LegacyRunData.gd")

@onready var stats_label: Label = %StatsLabel
@onready var status_label: Label = %StatusLabel
@onready var tower_map_canvas: Control = %TowerMapCanvas
@onready var abandon_button: Button = %AbandonButton


func _ready() -> void:
	if tower_map_canvas.has_signal("room_pressed"):
		tower_map_canvas.room_pressed.connect(_on_room_pressed)

	abandon_button.pressed.connect(_on_abandon_pressed)
	_refresh_map()


func _refresh_map() -> void:
	var tower_state := RunState.get_tower_state()
	var current_room := tower_state.get_room(tower_state.current_room_id)
	stats_label.text = "HP: %d/%d  |  Gold: %d  |  Act %d Floor %d" % [
		RunState.current_hp,
		RunState.max_hp,
		RunState.gold,
		RunState.current_act,
		current_room.floor if current_room != null else 0,
	]

	if tower_map_canvas.has_method("refresh"):
		tower_map_canvas.refresh(tower_state)

	if tower_state.is_boss_defeated() and RunState.current_act >= RewardManagerScript.FINAL_ACT:
		status_label.text = "Run complete! The tower falls silent."
		return

	var available_rooms := tower_state.get_available_rooms()
	if available_rooms.is_empty():
		status_label.text = "No paths remain from here."
	else:
		status_label.text = "Choose your next room."


func _on_room_pressed(room: TowerRoomData) -> void:
	RunState.enter_room(room.room_id)

	match room.room_type:
		TowerRoomDatabaseScript.ROOM_BATTLE:
			SceneLoader.change_to_combat(_get_battle_encounter_id(room.floor))
		TowerRoomDatabaseScript.ROOM_ELITE:
			SceneLoader.change_to_combat(_get_elite_encounter_id(room))
		TowerRoomDatabaseScript.ROOM_BOSS:
			SceneLoader.change_to_combat(
				RewardManagerScript.get_boss_encounter_for_act(RunState.current_act)
			)
		TowerRoomDatabaseScript.ROOM_REST:
			SceneLoader.change_to_rest()
		TowerRoomDatabaseScript.ROOM_MARKET:
			SceneLoader.change_to_shop()
		TowerRoomDatabaseScript.ROOM_FORGE:
			SceneLoader.change_to_forge()
		TowerRoomDatabaseScript.ROOM_OBSERVATORY:
			SceneLoader.change_to_observatory()
		TowerRoomDatabaseScript.ROOM_SHRINE:
			SceneLoader.change_to_shrine()
		TowerRoomDatabaseScript.ROOM_EVENT:
			SceneLoader.change_to_event(room.source_card_id)
		TowerRoomDatabaseScript.ROOM_GHOST:
			SceneLoader.change_to_ghost_room({
				"legacy_id": room.source_legacy_id,
			})
		_:
			push_warning("Unhandled room type: %s" % room.room_type)


func _on_abandon_pressed() -> void:
	var legacy_run := LegacyManager.finalize_run_end(LegacyRunDataScript.RESULT_ABANDONED)
	RunState.reset_run()
	SceneLoader.change_to_main_menu()


func _get_elite_encounter_id(room: TowerRoomData) -> String:
	if room.source_card_id != "":
		return room.source_card_id

	if RunState.current_act >= 2:
		return "cinder_colossus"

	return "ember_warden"


func _get_battle_encounter_id(floor: int) -> String:
	if RunState.current_act >= 2:
		if floor >= TowerGeneratorScript.FLOOR_CONVERGENCE_BATTLE:
			return "ash_zealot"

		if floor == TowerGeneratorScript.FLOOR_FIRST_BATTLE:
			return "furnace_hound"

		return "molten_guard"

	if floor >= TowerGeneratorScript.FLOOR_CONVERGENCE_BATTLE:
		return "molten_guard"

	if floor == TowerGeneratorScript.FLOOR_FIRST_BATTLE:
		return "charred_rat"

	return "furnace_cultist"
