extends Node

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"

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


func _change_screen(screen_name: String, payload: Variant = null) -> void:
	var main_scene := _get_main_controller()
	if main_scene == null:
		main_scene = _bootstrap_main_scene()

	if main_scene == null or not main_scene.has_method("change_screen"):
		push_error("SceneLoader could not find or create the Main scene controller.")
		return

	main_scene.change_screen(screen_name, payload)


func _get_main_controller() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("change_screen"):
		return current_scene

	for child in get_tree().root.get_children():
		if child.has_method("change_screen"):
			return child

	return _find_main_controller(get_tree().root)


func _find_main_controller(node: Node) -> Node:
	for child in node.get_children():
		if child.has_method("change_screen"):
			return child

		var nested := _find_main_controller(child)
		if nested != null:
			return nested

	return null


func _bootstrap_main_scene() -> Node:
	var tree := get_tree()
	var previous_scene := tree.current_scene
	var main_scene: Node = load(MAIN_SCENE_PATH).instantiate()
	tree.root.add_child(main_scene)
	tree.current_scene = main_scene

	if previous_scene != null and previous_scene != main_scene:
		previous_scene.queue_free()

	return main_scene
