extends PanelContainer

const MapNavigatorScript := preload("res://scripts/map/MapNavigator.gd")

@onready var subtitle_label: Label = %SubtitleLabel
@onready var stats_label: Label = %StatsLabel
@onready var status_label: Label = %StatusLabel
@onready var version_label: Label = %VersionLabel
@onready var primary_action_button: Button = %PrimaryActionButton
@onready var tower_map_scroll: ScrollContainer = %TowerMapScroll
@onready var tower_map_canvas: Control = %TowerMapCanvas
@onready var available_rooms_container: VBoxContainer = %AvailableRoomsContainer
@onready var victory_panel: PanelContainer = %VictoryPanel
@onready var victory_message_label: Label = %VictoryMessageLabel
@onready var new_run_button: Button = %NewRunButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var abandon_run_button: Button = %AbandonRunButton


func _ready() -> void:
	version_label.text = "Build %s" % GameState.VERSION

	if tower_map_canvas.has_signal("room_pressed"):
		tower_map_canvas.room_pressed.connect(_on_room_pressed)

	primary_action_button.pressed.connect(_on_primary_action_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	abandon_run_button.pressed.connect(_on_abandon_run_pressed)

	_refresh_map()


func _refresh_map() -> void:
	_clear_available_room_buttons()
	MapNavigatorScript._ensure_tower_is_ready()

	var tower_state := RunState.get_tower_state()
	var current_room := tower_state.get_room(tower_state.current_room_id)
	subtitle_label.text = TowerMemoryManager.get_map_subtitle()
	stats_label.text = "HP: %d/%d  |  Gold: %d  |  Act %d Floor %d" % [
		RunState.current_hp,
		RunState.max_hp,
		RunState.gold,
		RunState.current_act,
		current_room.floor if current_room != null else 0,
	]

	if tower_map_canvas.has_method("refresh"):
		tower_map_canvas.refresh(tower_state)

	if RunState.consume_act_transition_message():
		status_label.text = "Act %d begins. The tower heals you for 30%% of your max HP." % RunState.current_act

	if RunState.is_run_complete():
		_show_victory_panel()
		return

	victory_panel.visible = false
	primary_action_button.visible = true
	abandon_run_button.visible = true
	tower_map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP

	var available_rooms := tower_state.get_available_rooms()
	if available_rooms.is_empty():
		primary_action_button.visible = false
		status_label.text = "No paths remain from here."
		return

	var next_room: TowerRoomData = available_rooms[0]
	primary_action_button.text = "Continue: %s (Floor %d)" % [next_room.display_name, next_room.floor]
	_populate_available_room_buttons(available_rooms)

	if status_label.text == "" or not status_label.text.begins_with("Act "):
		status_label.text = "Press Continue to enter the next room."

	call_deferred("_scroll_to_room", next_room)


func _on_room_pressed(room: TowerRoomData) -> void:
	MapNavigatorScript.travel_to_room(room)


func _on_primary_action_pressed() -> void:
	var next_room := MapNavigatorScript.get_first_available_room()
	if next_room != null:
		MapNavigatorScript.travel_to_room(next_room)


func _show_victory_panel() -> void:
	victory_panel.visible = true
	primary_action_button.visible = false
	abandon_run_button.visible = false
	tower_map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_message_label.text = (
		"You have conquered the Ember Spire.\n"
		+ "Class: %s  |  Final HP: %d/%d  |  Gold: %d"
	) % [
		_get_class_display_name(),
		RunState.current_hp,
		RunState.max_hp,
		RunState.gold,
	]
	status_label.text = "Run complete! The tower falls silent."


func _get_class_display_name() -> String:
	var class_database := ClassDatabase.new()
	var class_definition := class_database.get_class_definition(RunState.selected_class)
	return str(class_definition.get("display_name", "Adventurer"))


func _on_new_run_pressed() -> void:
	SaveManager.delete_save()
	RunState.reset_run()
	SceneLoader.change_to_class_select()


func _on_main_menu_pressed() -> void:
	SaveManager.delete_save()
	RunState.reset_run()
	SceneLoader.change_to_main_menu()


func _on_abandon_run_pressed() -> void:
	SaveManager.delete_save()
	RunState.reset_run()
	SceneLoader.change_to_main_menu()


func _clear_available_room_buttons() -> void:
	for child in available_rooms_container.get_children():
		child.queue_free()


func _populate_available_room_buttons(available_rooms: Array) -> void:
	for room in available_rooms:
		if room is TowerRoomData:
			var room_button := Button.new()
			room_button.text = "Enter: %s (Floor %d)" % [room.display_name, room.floor]
			room_button.custom_minimum_size = Vector2(480, 48)
			room_button.pressed.connect(_on_room_pressed.bind(room))
			available_rooms_container.add_child(room_button)


func _scroll_to_room(room: TowerRoomData) -> void:
	if room == null or tower_map_scroll == null or tower_map_canvas == null:
		return

	await get_tree().process_frame

	var canvas_height: float = tower_map_canvas.size.y
	var room_screen_y: float = canvas_height - 80.0 + room.position.y
	var viewport_height: float = tower_map_scroll.size.y
	var scroll_max: float = maxf(0.0, canvas_height - viewport_height)
	var target_scroll: float = clampf(room_screen_y - (viewport_height * 0.45), 0.0, scroll_max)
	tower_map_scroll.scroll_vertical = int(target_scroll)
