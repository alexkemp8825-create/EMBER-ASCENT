class_name GhostRoomPlacer
extends RefCounted

const LegacyRunDataScript := preload("res://scripts/legacy/LegacyRunData.gd")
const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")
const TowerGeneratorScript := preload("res://scripts/tower/TowerGenerator.gd")

const MIN_GHOST_FLOOR := 2
const MAX_GHOST_FLOOR := 5
const GHOST_LANE_OFFSET := 2


static func add_ghost_rooms(tower_state: TowerState, seed_value: int) -> void:
	if tower_state == null or not LegacyManager.has_legacy_data():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x6D7F4754
	var legacy_pool := _build_legacy_pool()
	if legacy_pool.is_empty():
		return

	var ghost_count := rng.randi_range(1, mini(3, legacy_pool.size()))
	var anchor_rooms := _get_anchor_rooms(tower_state)
	if anchor_rooms.is_empty():
		return

	for ghost_index in range(ghost_count):
		if legacy_pool.is_empty() or anchor_rooms.is_empty():
			break

		var legacy_run: LegacyRunData = legacy_pool.pop_at(rng.randi_range(0, legacy_pool.size() - 1))
		var anchor_room: TowerRoomData = anchor_rooms.pop_at(rng.randi_range(0, anchor_rooms.size() - 1))
		var ghost_lane := _pick_ghost_lane(anchor_room, rng)
		var ghost_strength := _resolve_ghost_strength(legacy_run)
		var original_room_type := _pick_original_room_type(legacy_run, rng)

		var ghost_room := tower_state.add_ghost_room_at(
			anchor_room.floor,
			ghost_lane,
			legacy_run.legacy_id,
			legacy_run.run_number,
			original_room_type,
			ghost_strength,
			anchor_room.room_id
		)
		tower_state.connect_rooms(anchor_room.room_id, ghost_room.room_id)


static func _build_legacy_pool() -> Array:
	var legacy_pool: Array = []
	var seen_legacy_ids := {}

	for legacy_run in LegacyManager.legacy_runs:
		if legacy_run is LegacyRunDataScript and legacy_run.legacy_id != "":
			if seen_legacy_ids.has(legacy_run.legacy_id):
				continue

			seen_legacy_ids[legacy_run.legacy_id] = true
			legacy_pool.append(legacy_run)

	return legacy_pool


static func _get_anchor_rooms(tower_state: TowerState) -> Array:
	var anchor_rooms: Array = []

	for room in tower_state.rooms:
		if room.is_ghost:
			continue

		if room.room_type in [
			TowerRoomDatabaseScript.ROOM_ENTRANCE,
			TowerRoomDatabaseScript.ROOM_BOSS,
		]:
			continue

		if room.floor < MIN_GHOST_FLOOR or room.floor > MAX_GHOST_FLOOR:
			continue

		anchor_rooms.append(room)

	return anchor_rooms


static func _pick_ghost_lane(anchor_room: TowerRoomData, rng: RandomNumberGenerator) -> int:
	var anchor_lane := _get_room_lane(anchor_room)
	if anchor_lane < 0:
		return anchor_lane - GHOST_LANE_OFFSET

	if anchor_lane > 0:
		return anchor_lane + GHOST_LANE_OFFSET

	if rng.randi_range(0, 1) == 0:
		return -GHOST_LANE_OFFSET

	return GHOST_LANE_OFFSET


static func _get_room_lane(room: TowerRoomData) -> int:
	return int(round(room.position.x / TowerState.HORIZONTAL_LANE_SPACING))


static func _resolve_ghost_strength(legacy_run: LegacyRunData) -> String:
	if legacy_run.boss_reached or legacy_run.final_floor >= TowerGeneratorScript.FLOOR_BOSS:
		return TowerRoomDatabaseScript.GHOST_STRENGTH_HIGH

	if legacy_run.final_floor >= TowerGeneratorScript.FLOOR_CONVERGENCE_BATTLE:
		return TowerRoomDatabaseScript.GHOST_STRENGTH_MEDIUM

	return TowerRoomDatabaseScript.GHOST_STRENGTH_LOW


static func _pick_original_room_type(legacy_run: LegacyRunData, rng: RandomNumberGenerator) -> String:
	var room_types: Array[String] = []

	for room_data in legacy_run.rooms_built_snapshot:
		if not room_data is Dictionary:
			continue

		var room_type := str(room_data.get("room_type", ""))
		if room_type in [
			TowerRoomDatabaseScript.ROOM_ENTRANCE,
			TowerRoomDatabaseScript.ROOM_BOSS,
			TowerRoomDatabaseScript.ROOM_GHOST,
		]:
			continue

		if TowerRoomDatabaseScript.is_valid_room_type(room_type):
			room_types.append(room_type)

	if room_types.is_empty():
		return TowerRoomDatabaseScript.ROOM_BATTLE

	return room_types[rng.randi_range(0, room_types.size() - 1)]
