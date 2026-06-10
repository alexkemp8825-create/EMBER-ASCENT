extends Node

const SAVE_PATH := "user://ember_ascent_run.save"
const SAVE_VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_run() -> bool:
	if not RunState.has_active_run():
		delete_save()
		return false

	if RunState.active_room_id != "":
		return false

	var save_data := RunState.serialize()
	save_data["save_version"] = SAVE_VERSION
	save_data["game_version"] = GameState.VERSION

	var json_text := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % SAVE_PATH)
		return false

	file.store_string(json_text)
	return true


func load_run() -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for reading: %s" % SAVE_PATH)
		return false

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Failed to parse save file.")
		delete_save()
		return false

	var save_data: Variant = json.data
	if not save_data is Dictionary:
		delete_save()
		return false

	if not _is_valid_save_data(save_data):
		push_error("Save file failed validation.")
		delete_save()
		return false

	RunState.deserialize(save_data)
	RNG.set_seed(RunState.run_seed)
	return true


func delete_save() -> void:
	if not has_save():
		return

	var save_dir := DirAccess.open("user://")
	if save_dir == null:
		return

	save_dir.remove("ember_ascent_run.save")


func _is_valid_save_data(save_data: Dictionary) -> bool:
	if int(save_data.get("save_version", 0)) != SAVE_VERSION:
		return false

	if str(save_data.get("selected_class", "")) == "":
		return false

	if int(save_data.get("current_hp", 0)) <= 0:
		return false

	var tower_data: Variant = save_data.get("tower_state", {})
	if not tower_data is Dictionary:
		return false

	var rooms: Variant = tower_data.get("rooms", [])
	if not rooms is Array or rooms.is_empty():
		return false

	return true
