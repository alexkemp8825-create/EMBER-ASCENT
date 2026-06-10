class_name TowerGenerator
extends RefCounted

const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")
const EventDatabaseScript := preload("res://scripts/events/EventDatabase.gd")

const FLOOR_ENTRANCE := 0
const FLOOR_FIRST_BATTLE := 1
const FLOOR_BRANCH_A := 2
const FLOOR_CONVERGENCE_BATTLE := 3
const FLOOR_SPECIAL_BRANCH := 4
const FLOOR_BOSS := 5

const ACT_1 := 1
const ACT_2 := 2


static func generate_act_one(tower_state: TowerState, seed_value: int) -> void:
	_generate_act(tower_state, seed_value, ACT_1)


static func generate_act_two(tower_state: TowerState, seed_value: int) -> void:
	_generate_act(tower_state, seed_value, ACT_2)


static func _generate_act(tower_state: TowerState, seed_value: int, act: int) -> void:
	tower_state.rooms.clear()
	tower_state.connections.clear()
	tower_state.tower_seed = seed_value
	tower_state.act = act

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var event_database := EventDatabaseScript.new()

	var entrance := tower_state.add_room_at(TowerRoomDatabaseScript.ROOM_ENTRANCE, FLOOR_ENTRANCE, 0)
	entrance.completed = true

	var first_battle := tower_state.add_room_at(TowerRoomDatabaseScript.ROOM_BATTLE, FLOOR_FIRST_BATTLE, 0)
	var left_branch := _create_branch_room(
		tower_state,
		_pick_floor_two_left_room(rng, act),
		FLOOR_BRANCH_A,
		-1,
		rng,
		event_database,
		act
	)
	var right_branch := _create_branch_room(
		tower_state,
		_pick_floor_two_right_room(rng, act),
		FLOOR_BRANCH_A,
		1,
		rng,
		event_database,
		act
	)
	var convergence_battle := tower_state.add_room_at(
		TowerRoomDatabaseScript.ROOM_BATTLE,
		FLOOR_CONVERGENCE_BATTLE,
		0
	)

	var special_rooms := _pick_special_rooms(rng)
	var forge_room := tower_state.add_room_at(special_rooms[0], FLOOR_SPECIAL_BRANCH, -1)
	var shrine_room := tower_state.add_room_at(special_rooms[1], FLOOR_SPECIAL_BRANCH, 0)
	var observatory_room := tower_state.add_room_at(special_rooms[2], FLOOR_SPECIAL_BRANCH, 1)
	var boss_room := tower_state.add_room_at(TowerRoomDatabaseScript.ROOM_BOSS, FLOOR_BOSS, 0)

	tower_state.connect_rooms(entrance.room_id, first_battle.room_id)
	tower_state.connect_rooms(first_battle.room_id, left_branch.room_id)
	tower_state.connect_rooms(first_battle.room_id, right_branch.room_id)
	tower_state.connect_rooms(left_branch.room_id, convergence_battle.room_id)
	tower_state.connect_rooms(right_branch.room_id, convergence_battle.room_id)
	tower_state.connect_rooms(convergence_battle.room_id, forge_room.room_id)
	tower_state.connect_rooms(convergence_battle.room_id, shrine_room.room_id)
	tower_state.connect_rooms(convergence_battle.room_id, observatory_room.room_id)
	tower_state.connect_rooms(forge_room.room_id, boss_room.room_id)
	tower_state.connect_rooms(shrine_room.room_id, boss_room.room_id)
	tower_state.connect_rooms(observatory_room.room_id, boss_room.room_id)

	tower_state.current_room_id = entrance.room_id
	tower_state.highest_floor = FLOOR_BOSS


static func _create_branch_room(
	tower_state: TowerState,
	room_type: String,
	floor: int,
	lane: int,
	rng: RandomNumberGenerator,
	event_database: EventDatabase,
	act: int
) -> TowerRoomData:
	if room_type == TowerRoomDatabaseScript.ROOM_EVENT:
		var event_id := event_database.pick_random_event_id(rng)
		return tower_state.add_room_at(room_type, floor, lane, event_id)

	if room_type == TowerRoomDatabaseScript.ROOM_ELITE:
		var encounter_id := _pick_elite_encounter(rng, act)
		return tower_state.add_room_at(room_type, floor, lane, encounter_id)

	return tower_state.add_room_at(room_type, floor, lane)


static func _pick_elite_encounter(rng: RandomNumberGenerator, act: int) -> String:
	if act >= ACT_2:
		var act_two_elites: Array[String] = ["ember_warden", "cinder_colossus"]
		return act_two_elites[rng.randi_range(0, act_two_elites.size() - 1)]

	return "ember_warden"


static func _pick_floor_two_left_room(rng: RandomNumberGenerator, act: int) -> String:
	var options: Array[String] = [
		TowerRoomDatabaseScript.ROOM_REST,
		TowerRoomDatabaseScript.ROOM_SHRINE,
		TowerRoomDatabaseScript.ROOM_EVENT,
		TowerRoomDatabaseScript.ROOM_ELITE,
	]

	if act >= ACT_2:
		options.append(TowerRoomDatabaseScript.ROOM_FORGE)

	return options[rng.randi_range(0, options.size() - 1)]


static func _pick_floor_two_right_room(rng: RandomNumberGenerator, act: int) -> String:
	var options: Array[String] = [
		TowerRoomDatabaseScript.ROOM_MARKET,
		TowerRoomDatabaseScript.ROOM_OBSERVATORY,
		TowerRoomDatabaseScript.ROOM_EVENT,
		TowerRoomDatabaseScript.ROOM_ELITE,
	]

	if act >= ACT_2:
		options.append(TowerRoomDatabaseScript.ROOM_SHRINE)

	return options[rng.randi_range(0, options.size() - 1)]


static func _pick_special_rooms(rng: RandomNumberGenerator) -> Array[String]:
	var room_types: Array[String] = [
		TowerRoomDatabaseScript.ROOM_FORGE,
		TowerRoomDatabaseScript.ROOM_SHRINE,
		TowerRoomDatabaseScript.ROOM_OBSERVATORY,
	]

	for index in range(room_types.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current_value: String = room_types[index]
		room_types[index] = room_types[swap_index]
		room_types[swap_index] = current_value

	return room_types
