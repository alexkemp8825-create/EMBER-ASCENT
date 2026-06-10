extends PanelContainer

const MapNavigatorScript := preload("res://scripts/map/MapNavigator.gd")

@onready var ash_knight_button: Button = %AshKnightButton
@onready var cinder_witch_button: Button = %CinderWitchButton
@onready var glass_monk_button: Button = %GlassMonkButton
@onready var root_warden_button: Button = %RootWardenButton
@onready var chain_prophet_button: Button = %ChainProphetButton
@onready var hollow_thief_button: Button = %HollowThiefButton
@onready var status_label: Label = %StatusLabel

var _class_database := ClassDatabase.new()


func _ready() -> void:
	ash_knight_button.pressed.connect(_on_class_selected.bind(ClassDatabase.ASH_KNIGHT))
	cinder_witch_button.pressed.connect(_on_class_selected.bind(ClassDatabase.CINDER_WITCH))
	_disable_coming_soon_buttons()


func _disable_coming_soon_buttons() -> void:
	var coming_soon_buttons: Array[Button] = [
		glass_monk_button,
		root_warden_button,
		chain_prophet_button,
		hollow_thief_button,
	]

	for button in coming_soon_buttons:
		button.disabled = true
		button.tooltip_text = "Coming Soon"


func _on_class_selected(class_id: String) -> void:
	if not _class_database.is_playable(class_id):
		status_label.text = "That class is not playable yet."
		return

	_start_run(class_id)

	if not SaveManager.save_run():
		status_label.text = "Failed to save your run. Please try again."
		RunState.reset_run()
		return

	var class_definition := _class_database.get_class_definition(class_id)
	status_label.text = "%s selected. Starting first battle..." % class_definition.get("display_name", class_id)

	if not MapNavigatorScript.begin_new_run():
		status_label.text = "Failed to start the run. Please try again."
		RunState.reset_run()
		return


func _start_run(class_id: String) -> void:
	var class_definition := _class_database.get_class_definition(class_id)
	if class_definition.is_empty():
		push_error("Unknown class requested: %s" % class_id)
		return

	RunState.reset_run()
	RunState.selected_class = class_id
	RunState.max_hp = int(class_definition.get("max_hp", 0))
	RunState.current_hp = RunState.max_hp
	RunState.gold = int(class_definition.get("starting_gold", 0))
	RunState.current_act = 1
	RunState.run_seed = int(Time.get_unix_time_from_system())

	RunState.deck.clear()
	for card_id in class_definition.get("starter_deck", []):
		RunState.deck.append(str(card_id))

	RunState.relics.clear()
	RunState.relics.append(str(class_definition.get("starter_relic", "")))

	RNG.set_seed(RunState.run_seed)
	RunState.create_new_tower()
	RunState.completed_nodes.clear()
