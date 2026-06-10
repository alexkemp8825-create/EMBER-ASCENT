extends Control

const MAIN_MENU := "main_menu"
const CLASS_SELECT := "class_select"
const MAP := "map"
const COMBAT := "combat"
const REWARDS := "rewards"
const SHOP := "shop"
const REST := "rest"

const SCREEN_SCENES := {
	MAIN_MENU: preload("res://scenes/ui/MainMenu.tscn"),
	CLASS_SELECT: preload("res://scenes/ui/ClassSelect.tscn"),
	MAP: preload("res://scenes/map/MapScreen.tscn"),
	COMBAT: preload("res://scenes/combat/Combat.tscn"),
	REWARDS: preload("res://scenes/rewards/RewardScreen.tscn"),
	SHOP: preload("res://scenes/shop/ShopScreen.tscn"),
	REST: preload("res://scenes/rest/RestScreen.tscn"),
}

@onready var screen_root: Control = %ScreenRoot

var current_screen: Node


func _ready() -> void:
	change_screen(MAIN_MENU)


func change_screen(screen_name: String, payload: Variant = null) -> void:
	if not SCREEN_SCENES.has(screen_name):
		push_error("Unknown screen requested: %s" % screen_name)
		return

	if current_screen != null:
		current_screen.queue_free()

	current_screen = SCREEN_SCENES[screen_name].instantiate()
	screen_root.add_child(current_screen)

	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("set_current_screen"):
		game_state.set_current_screen(screen_name)

	if payload != null and current_screen.has_method("set_payload"):
		current_screen.set_payload(payload)


func change_to_main_menu() -> void:
	change_screen(MAIN_MENU)


func change_to_class_select() -> void:
	change_screen(CLASS_SELECT)


func change_to_map() -> void:
	change_screen(MAP)


func change_to_combat(encounter_id: String = "") -> void:
	change_screen(COMBAT, {"encounter_id": encounter_id})


func change_to_rewards(reward_data: Dictionary = {}) -> void:
	change_screen(REWARDS, reward_data)


func change_to_shop() -> void:
	change_screen(SHOP)


func change_to_rest() -> void:
	change_screen(REST)
