extends Node

const MAIN_MENU := "main_menu"
const CLASS_SELECT := "class_select"
const MAP := "map"
const COMBAT := "combat"
const REWARDS := "rewards"
const SHOP := "shop"
const REST := "rest"
const FORGE := "forge"
const OBSERVATORY := "observatory"
const SHRINE := "shrine"
const EVENT := "event"
const DEFEAT := "defeat"
const VICTORY := "victory"
const GHOST_ROOM := "ghost_room"


func change_to_main_menu() -> void:
	_change_screen(MAIN_MENU)


func change_to_class_select() -> void:
	_change_screen(CLASS_SELECT)


func change_to_map() -> void:
	_change_screen(MAP)


func change_to_combat(encounter_id: String) -> void:
	_change_screen(COMBAT, {"encounter_id": encounter_id})


func change_to_rewards(reward_data: Dictionary) -> void:
	_change_screen(REWARDS, reward_data)


func change_to_shop() -> void:
	_change_screen(SHOP)


func change_to_rest() -> void:
	_change_screen(REST)


func change_to_forge() -> void:
	_change_screen(FORGE)


func change_to_observatory() -> void:
	_change_screen(OBSERVATORY)


func change_to_shrine() -> void:
	_change_screen(SHRINE)


func change_to_event(event_id: String) -> void:
	_change_screen(EVENT, {"event_id": event_id})


func change_to_defeat(payload: Dictionary = {}) -> void:
	_change_screen(DEFEAT, payload)


func change_to_victory(payload: Dictionary = {}) -> void:
	_change_screen(VICTORY, payload)


func change_to_ghost_room(payload: Dictionary = {}) -> void:
	_change_screen(GHOST_ROOM, payload)


func _change_screen(screen_name: String, payload: Variant = null) -> void:
	var main_scene := get_tree().current_scene

	if main_scene == null or not main_scene.has_method("change_screen"):
		push_error("SceneLoader expected the current scene to provide change_screen().")
		return

	main_scene.change_screen(screen_name, payload)
