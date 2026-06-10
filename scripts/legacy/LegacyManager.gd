extends Node

const LegacyRunDataScript := preload("res://scripts/legacy/LegacyRunData.gd")
const TowerRoomDataScript := preload("res://scripts/tower/TowerRoomData.gd")
const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")

const SAVE_PATH := "user://ember_ascent_legacy.save"
const SAVE_VERSION := 1

const GHOST_NAMES := {
	"ash_knight": "Fallen Ash Knight",
}

var legacy_runs: Array = []
var max_legacy_runs: int = 25


func _ready() -> void:
	load_legacy_data()


func has_legacy_data() -> bool:
	return not legacy_runs.is_empty()


func record_run_end(result: String) -> LegacyRunData:
	if not LegacyRunDataScript.is_valid_result(result):
		push_error("LegacyManager.record_run_end received invalid result: %s" % result)
		return null

	var legacy_run := create_legacy_from_current_run(result)
	if legacy_run == null:
		return null

	legacy_runs.append(legacy_run)
	_trim_legacy_runs()
	save_legacy_data()
	return legacy_run


func finalize_run_end(result: String) -> LegacyRunData:
	var legacy_run := record_run_end(result)
	if legacy_run != null:
		print("Legacy saved: Run %d became part of the tower." % legacy_run.run_number)
	else:
		push_warning("LegacyManager.finalize_run_end could not record legacy for result: %s" % result)

	SaveManager.delete_save()
	return legacy_run


func build_run_end_payload(legacy_run: LegacyRunData) -> Dictionary:
	if legacy_run == null:
		return {}

	return {
		"legacy_run": legacy_run.serialize(),
	}


func create_legacy_from_current_run(result: String) -> LegacyRunData:
	if not RunState.has_active_run() and not _has_legacy_snapshot_data():
		return null

	var legacy_run := LegacyRunDataScript.new()
	legacy_run.legacy_id = _generate_legacy_id()
	legacy_run.run_number = legacy_runs.size() + 1
	legacy_run.class_id = RunState.selected_class
	legacy_run.final_hp = RunState.current_hp
	legacy_run.max_hp = RunState.max_hp
	legacy_run.result = result
	legacy_run.final_floor = RunState.current_floor
	legacy_run.deck_snapshot = RunState.deck.duplicate()
	legacy_run.relic_snapshot = RunState.relics.duplicate()
	legacy_run.created_at = int(Time.get_unix_time_from_system())
	legacy_run.ghost_name = _get_ghost_name(legacy_run.class_id)

	_populate_tower_snapshot(legacy_run, result)
	return legacy_run


func save_legacy_data() -> bool:
	var serialized_runs: Array = []
	for legacy_run in legacy_runs:
		if legacy_run is LegacyRunDataScript:
			serialized_runs.append(legacy_run.serialize())

	var save_data := {
		"save_version": SAVE_VERSION,
		"game_version": GameState.VERSION,
		"max_legacy_runs": max_legacy_runs,
		"legacy_runs": serialized_runs,
	}

	var json_text := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open legacy save file for writing: %s" % SAVE_PATH)
		return false

	file.store_string(json_text)
	return true


func load_legacy_data() -> bool:
	legacy_runs.clear()

	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open legacy save file for reading: %s" % SAVE_PATH)
		return false

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Failed to parse legacy save file.")
		return false

	var save_data: Variant = json.data
	if not save_data is Dictionary:
		return false

	if not _is_valid_save_data(save_data):
		push_error("Legacy save file failed validation.")
		return false

	max_legacy_runs = int(save_data.get("max_legacy_runs", 25))

	for legacy_data in save_data.get("legacy_runs", []):
		if legacy_data is Dictionary:
			legacy_runs.append(LegacyRunDataScript.deserialize(legacy_data))

	return true


func get_recent_legacy_runs(count: int) -> Array:
	if count <= 0 or legacy_runs.is_empty():
		return []

	var start_index := max(legacy_runs.size() - count, 0)
	var recent_runs: Array = []
	for index in range(legacy_runs.size() - 1, start_index - 1, -1):
		recent_runs.append(legacy_runs[index])

	return recent_runs


func get_random_legacy_run() -> LegacyRunData:
	if legacy_runs.is_empty():
		return null

	var random_index := randi() % legacy_runs.size()
	var legacy_run: Variant = legacy_runs[random_index]
	if legacy_run is LegacyRunDataScript:
		return legacy_run

	return null


func clear_legacy_data_debug_only() -> bool:
	if not GameState.debug_mode:
		push_warning("clear_legacy_data_debug_only ignored because debug_mode is false.")
		return false

	legacy_runs.clear()

	var save_dir := DirAccess.open("user://")
	if save_dir != null and save_dir.file_exists("ember_ascent_legacy.save"):
		save_dir.remove("ember_ascent_legacy.save")

	return true


func _populate_tower_snapshot(legacy_run: LegacyRunData, result: String) -> void:
	var tower_state := RunState.tower_state
	if tower_state == null:
		legacy_run.death_room_id = RunState.current_node_id
		legacy_run.boss_reached = false
		return

	legacy_run.rooms_built_snapshot.clear()
	for room in tower_state.rooms:
		if room is TowerRoomDataScript:
			legacy_run.rooms_built_snapshot.append(room.serialize())

	legacy_run.path_taken.clear()
	for room in tower_state.rooms:
		if room is TowerRoomDataScript and room.completed:
			legacy_run.path_taken.append(room.room_id)

	legacy_run.boss_reached = _did_reach_boss(tower_state)
	legacy_run.final_floor = _resolve_final_floor(tower_state, legacy_run.final_floor)
	legacy_run.death_room_id = _resolve_death_room_id(result)


func _resolve_death_room_id(result: String) -> String:
	if result == LegacyRunDataScript.RESULT_VICTORY:
		return RunState.current_node_id

	if RunState.active_room_id != "":
		return RunState.active_room_id

	return RunState.current_node_id


func _resolve_final_floor(tower_state: TowerState, fallback_floor: int) -> int:
	var current_room := tower_state.get_room(RunState.current_node_id)
	if current_room != null:
		return current_room.floor

	return max(fallback_floor, tower_state.highest_floor)


func _did_reach_boss(tower_state: TowerState) -> bool:
	for room in tower_state.rooms:
		if room.room_type != TowerRoomDatabaseScript.ROOM_BOSS:
			continue

		if room.completed:
			return true

		if room.room_id == RunState.current_node_id or room.room_id == RunState.active_room_id:
			return true

	return false


func _get_ghost_name(class_id: String) -> String:
	if GHOST_NAMES.has(class_id):
		return str(GHOST_NAMES[class_id])

	if class_id == "":
		return "Fallen Wanderer"

	return "Fallen %s" % class_id.capitalize().replace("_", " ")


func _generate_legacy_id() -> String:
	return "legacy_%d_%d" % [int(Time.get_unix_time_from_system()), randi()]


func _trim_legacy_runs() -> void:
	while legacy_runs.size() > max_legacy_runs:
		legacy_runs.pop_front()


func _has_legacy_snapshot_data() -> bool:
	return RunState.selected_class != ""


func _is_valid_save_data(save_data: Dictionary) -> bool:
	if int(save_data.get("save_version", 0)) != SAVE_VERSION:
		return false

	var runs: Variant = save_data.get("legacy_runs", [])
	return runs is Array
