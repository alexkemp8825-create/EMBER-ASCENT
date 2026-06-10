extends Node

const SAVE_PATH := "user://tower_memory.save"
const SAVE_VERSION := 1
const ENEMY_REMEMBERED_THRESHOLD := 3
const CARD_TACTIC_THRESHOLD := 4
const CARD_TACTIC_CHANCE := 0.35

const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")

var total_runs_started: int = 0
var total_deaths: int = 0
var bosses_defeated: int = 0
var rooms_completed_by_type: Dictionary = {}
var enemies_defeated: Dictionary = {}
var cards_played_by_id: Dictionary = {}


func _ready() -> void:
	load_memory()


func record_run_started() -> void:
	total_runs_started += 1
	save_memory()


func record_death() -> void:
	total_deaths += 1
	save_memory()


func record_room_completed(room_type: String) -> void:
	var room_key := str(room_type)
	if room_key == "":
		return

	rooms_completed_by_type[room_key] = int(rooms_completed_by_type.get(room_key, 0)) + 1

	if room_key == TowerRoomDatabaseScript.ROOM_BOSS:
		bosses_defeated += 1

	save_memory()


func record_enemy_defeated(enemy_id: String) -> void:
	if enemy_id == "":
		return

	enemies_defeated[enemy_id] = int(enemies_defeated.get(enemy_id, 0)) + 1
	save_memory()


func record_card_played(card_id: String) -> String:
	if card_id == "":
		return ""

	var play_count := int(cards_played_by_id.get(card_id, 0)) + 1
	cards_played_by_id[card_id] = play_count
	save_memory()

	if play_count >= CARD_TACTIC_THRESHOLD and RNG.randf() <= CARD_TACTIC_CHANCE:
		return "The tower remembers this tactic..."

	return ""


func get_fallen_climbs_line() -> String:
	if total_deaths <= 0:
		return ""

	var climb_word := "climb" if total_deaths == 1 else "climbs"
	return "The Tower remembers %d fallen %s." % [total_deaths, climb_word]


func get_map_subtitle() -> String:
	if total_deaths <= 0:
		return "Choose your path upward."

	if total_deaths < 3:
		return "The stone still holds the warmth of your last failure."

	return "Ash marks the walls where other climbers fell."


func get_remembered_enemy_name(enemy_id: String, base_name: String) -> String:
	if enemy_id == "" or base_name == "":
		return base_name

	if int(enemies_defeated.get(enemy_id, 0)) >= ENEMY_REMEMBERED_THRESHOLD:
		return "%s, Remembered" % base_name

	return base_name


func get_enemy_defeat_count(enemy_id: String) -> int:
	return int(enemies_defeated.get(enemy_id, 0))


func clear_memory() -> void:
	total_runs_started = 0
	total_deaths = 0
	bosses_defeated = 0
	rooms_completed_by_type.clear()
	enemies_defeated.clear()
	cards_played_by_id.clear()
	save_memory()


func save_memory() -> bool:
	var save_data := {
		"save_version": SAVE_VERSION,
		"total_runs_started": total_runs_started,
		"total_deaths": total_deaths,
		"bosses_defeated": bosses_defeated,
		"rooms_completed_by_type": rooms_completed_by_type.duplicate(true),
		"enemies_defeated": enemies_defeated.duplicate(true),
		"cards_played_by_id": cards_played_by_id.duplicate(true),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open tower memory file for writing: %s" % SAVE_PATH)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	return true


func load_memory() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open tower memory file for reading: %s" % SAVE_PATH)
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse tower memory file.")
		return false

	var save_data: Variant = json.data
	if not save_data is Dictionary:
		return false

	if int(save_data.get("save_version", 0)) != SAVE_VERSION:
		return false

	total_runs_started = int(save_data.get("total_runs_started", 0))
	total_deaths = int(save_data.get("total_deaths", 0))
	bosses_defeated = int(save_data.get("bosses_defeated", 0))
	rooms_completed_by_type = _deserialize_count_dict(save_data.get("rooms_completed_by_type", {}))
	enemies_defeated = _deserialize_count_dict(save_data.get("enemies_defeated", {}))
	cards_played_by_id = _deserialize_count_dict(save_data.get("cards_played_by_id", {}))
	return true


func _deserialize_count_dict(data: Variant) -> Dictionary:
	var counts := {}
	if not data is Dictionary:
		return counts

	for key in data:
		counts[str(key)] = int(data[key])

	return counts
