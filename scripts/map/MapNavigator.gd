class_name MapNavigator
extends RefCounted

const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")
const TowerGeneratorScript := preload("res://scripts/tower/TowerGenerator.gd")
const RewardManagerScript := preload("res://scripts/rewards/RewardManager.gd")


static func travel_to_room(room: TowerRoomData) -> void:
	if room == null:
		push_error("MapNavigator.travel_to_room called with null room.")
		return

	RunState.enter_room(room.room_id)

	match room.room_type:
		TowerRoomDatabaseScript.ROOM_BATTLE:
			SceneLoader.change_to_combat(get_battle_encounter_id(room.floor))
		TowerRoomDatabaseScript.ROOM_ELITE:
			SceneLoader.change_to_combat(get_elite_encounter_id(room))
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
		_:
			push_warning("Unhandled room type: %s" % room.room_type)


static func get_first_available_room() -> TowerRoomData:
	_ensure_tower_is_ready()
	var available_rooms := RunState.get_tower_state().get_available_rooms()
	if available_rooms.is_empty():
		return null

	return available_rooms[0]


static func begin_new_run() -> bool:
	_ensure_tower_is_ready()
	var first_room := get_first_available_room()
	if first_room == null:
		return false

	travel_to_room(first_room)
	return true


static func _ensure_tower_is_ready() -> void:
	if RunState.tower_state == null or RunState.get_tower_state().rooms.is_empty():
		RunState.create_new_tower()


static func get_elite_encounter_id(room: TowerRoomData) -> String:
	if room.source_card_id != "":
		return room.source_card_id

	if RunState.current_act >= 2:
		return "cinder_colossus"

	return "ember_warden"


static func get_battle_encounter_id(floor: int) -> String:
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
