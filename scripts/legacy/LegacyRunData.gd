extends RefCounted
class_name LegacyRunData

const RESULT_VICTORY := "victory"
const RESULT_DEFEAT := "defeat"
const RESULT_ABANDONED := "abandoned"

var legacy_id: String = ""
var run_number: int = 0
var class_id: String = ""
var final_hp: int = 0
var max_hp: int = 0
var result: String = ""
var death_room_id: String = ""
var final_floor: int = 0
var deck_snapshot: Array[String] = []
var relic_snapshot: Array[String] = []
var rooms_built_snapshot: Array = []
var path_taken: Array[String] = []
var boss_reached: bool = false
var created_at: int = 0
var ghost_name: String = ""


func serialize() -> Dictionary:
	return {
		"legacy_id": legacy_id,
		"run_number": run_number,
		"class_id": class_id,
		"final_hp": final_hp,
		"max_hp": max_hp,
		"result": result,
		"death_room_id": death_room_id,
		"final_floor": final_floor,
		"deck_snapshot": deck_snapshot.duplicate(),
		"relic_snapshot": relic_snapshot.duplicate(),
		"rooms_built_snapshot": rooms_built_snapshot.duplicate(true),
		"path_taken": path_taken.duplicate(),
		"boss_reached": boss_reached,
		"created_at": created_at,
		"ghost_name": ghost_name,
	}


static func deserialize(data: Dictionary) -> LegacyRunData:
	var legacy_run := LegacyRunData.new()
	legacy_run.legacy_id = str(data.get("legacy_id", ""))
	legacy_run.run_number = int(data.get("run_number", 0))
	legacy_run.class_id = str(data.get("class_id", ""))
	legacy_run.final_hp = int(data.get("final_hp", 0))
	legacy_run.max_hp = int(data.get("max_hp", 0))
	legacy_run.result = str(data.get("result", ""))
	legacy_run.death_room_id = str(data.get("death_room_id", ""))
	legacy_run.final_floor = int(data.get("final_floor", 0))
	legacy_run.boss_reached = bool(data.get("boss_reached", false))
	legacy_run.created_at = int(data.get("created_at", 0))
	legacy_run.ghost_name = str(data.get("ghost_name", ""))

	legacy_run.deck_snapshot.clear()
	for card_id in data.get("deck_snapshot", []):
		legacy_run.deck_snapshot.append(str(card_id))

	legacy_run.relic_snapshot.clear()
	for relic_id in data.get("relic_snapshot", []):
		legacy_run.relic_snapshot.append(str(relic_id))

	legacy_run.rooms_built_snapshot.clear()
	for room_data in data.get("rooms_built_snapshot", []):
		if room_data is Dictionary:
			legacy_run.rooms_built_snapshot.append(room_data.duplicate(true))

	legacy_run.path_taken.clear()
	for room_id in data.get("path_taken", []):
		legacy_run.path_taken.append(str(room_id))

	return legacy_run


static func is_valid_result(result_value: String) -> bool:
	return result_value in [RESULT_VICTORY, RESULT_DEFEAT, RESULT_ABANDONED]
