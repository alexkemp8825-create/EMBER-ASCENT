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

	if not RunState.start_class_run(class_id):
		status_label.text = "Failed to start the run. Please try again."
		return

	var class_definition := _class_database.get_class_definition(class_id)
	status_label.text = "%s selected. Starting first battle..." % class_definition.get("display_name", class_id)
	print("CLASS SELECTED=", class_id, " -> begin_new_run()")

	if not MapNavigatorScript.begin_new_run():
		status_label.text = "Failed to start the run. Please try again."
		RunState.reset_run()
		return
