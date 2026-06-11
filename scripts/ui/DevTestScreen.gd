extends PanelContainer

const MapNavigatorScript := preload("res://scripts/map/MapNavigator.gd")
const RewardManagerScript := preload("res://scripts/rewards/RewardManager.gd")

const TEST_ENCOUNTER_ID := "charred_rat"
const TEST_EVENT_ID := "emberscript_scribe"

@onready var ash_knight_combat_button: Button = %AshKnightCombatButton
@onready var cinder_witch_combat_button: Button = %CinderWitchCombatButton
@onready var map_button: Button = %MapButton
@onready var reward_button: Button = %RewardButton
@onready var shop_button: Button = %ShopButton
@onready var event_button: Button = %EventButton
@onready var clear_save_button: Button = %ClearSaveButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	ash_knight_combat_button.pressed.connect(_on_ash_knight_combat_pressed)
	cinder_witch_combat_button.pressed.connect(_on_cinder_witch_combat_pressed)
	map_button.pressed.connect(_on_map_pressed)
	reward_button.pressed.connect(_on_reward_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	event_button.pressed.connect(_on_event_pressed)
	clear_save_button.pressed.connect(_on_clear_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_update_status("Pick a screen to open for testing.")


func _on_back_pressed() -> void:
	SceneLoader.change_to_main_menu()


func _on_ash_knight_combat_pressed() -> void:
	_setup_test_run(ClassDatabase.ASH_KNIGHT)
	_start_test_combat()


func _on_cinder_witch_combat_pressed() -> void:
	_setup_test_run(ClassDatabase.CINDER_WITCH)
	_start_test_combat()


func _on_map_pressed() -> void:
	_setup_test_run(ClassDatabase.ASH_KNIGHT)
	_prepare_map_test_run()
	SceneLoader.change_to_map()


func _on_reward_pressed() -> void:
	_setup_test_run(ClassDatabase.ASH_KNIGHT)
	var payload := RewardManagerScript.build_combat_reward_payload(TEST_ENCOUNTER_ID, 1)
	SceneLoader.change_to_rewards(payload)


func _on_shop_pressed() -> void:
	_setup_test_run(ClassDatabase.ASH_KNIGHT)
	SceneLoader.change_to_shop()


func _on_event_pressed() -> void:
	_setup_test_run(ClassDatabase.ASH_KNIGHT)
	SceneLoader.change_to_event(TEST_EVENT_ID)


func _on_clear_save_pressed() -> void:
	SaveManager.delete_save()
	_update_status("Save cleared.")


func _setup_test_run(class_id: String) -> void:
	var class_database := ClassDatabase.new()
	var class_definition := class_database.get_class_definition(class_id)
	if class_definition.is_empty():
		push_error("Unknown class for dev test: %s" % class_id)
		return

	RunState.reset_run()
	RunState.selected_class = class_id
	RunState.max_hp = int(class_definition.get("max_hp", 0))
	RunState.current_hp = RunState.max_hp
	RunState.gold = int(class_definition.get("starting_gold", 0))
	RunState.current_act = 1
	RunState.run_seed = 424242

	RunState.deck.clear()
	for card_id in class_definition.get("starter_deck", []):
		RunState.deck.append(str(card_id))

	RunState.relics.clear()
	RunState.relics.append(str(class_definition.get("starter_relic", "")))

	RNG.set_seed(RunState.run_seed)
	RunState.create_new_tower()


func _start_test_combat() -> void:
	var first_room := MapNavigatorScript.get_first_available_room()
	if first_room != null:
		RunState.enter_room(first_room.room_id)

	SceneLoader.change_to_combat(TEST_ENCOUNTER_ID)


func _prepare_map_test_run() -> void:
	var first_room := MapNavigatorScript.get_first_available_room()
	if first_room == null:
		return

	RunState.enter_room(first_room.room_id)
	RunState.complete_active_room()


func _update_status(message: String) -> void:
	status_label.text = message
