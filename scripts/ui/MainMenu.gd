extends PanelContainer

const BalanceRunSimulatorScript := preload("res://scripts/dev/BalanceRunSimulator.gd")

@onready var subtitle_label: Label = %Subtitle
@onready var new_run_button: Button = %NewRunButton
@onready var continue_button: Button = %ContinueRunButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel
@onready var status_label: Label = %StatusLabel

var _balance_button: Button


func _ready() -> void:
	var build_text := "Build %s" % GameState.VERSION
	version_label.text = build_text
	subtitle_label.text = "Climb the living volcanic tower.\n%s" % build_text
	status_label.text = _get_launch_hint()
	new_run_button.pressed.connect(_on_new_run_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_refresh_continue_button()
	_add_balance_button()


func _refresh_continue_button() -> void:
	var can_continue := SaveManager.has_save()
	continue_button.disabled = not can_continue
	continue_button.tooltip_text = (
		"Resume your saved run."
		if can_continue
		else "No saved run found."
	)


func _on_new_run_pressed() -> void:
	status_label.text = "Starting new run..."
	SaveManager.delete_save()
	RunState.reset_run()
	SceneLoader.change_to_class_select()


func _get_launch_hint() -> String:
	if get_tree().current_scene != null and get_tree().current_scene.has_method("change_screen"):
		return "Press New Run to begin."

	return "Tip: press F5 (Run Project), not F6 (Run Current Scene)."


func _on_continue_pressed() -> void:
	if not SaveManager.load_run():
		_refresh_continue_button()
		return

	SceneLoader.change_to_map()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _add_balance_button() -> void:
	if not GameState.debug_mode:
		return

	var content := $MarginContainer/Content
	_balance_button = Button.new()
	_balance_button.text = "Balance Sim (100 runs)"
	_balance_button.tooltip_text = "Runs 100 seeded full climbs with the heuristic policy and writes a balance report."
	_balance_button.custom_minimum_size = Vector2(320, 56)
	_balance_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(_balance_button)
	content.move_child(_balance_button, quit_button.get_index() + 1)
	_balance_button.pressed.connect(_on_balance_sim_pressed)


func _on_balance_sim_pressed() -> void:
	if _balance_button != null:
		_balance_button.disabled = true
	status_label.text = "Running 100 seeded runs..."
	await get_tree().process_frame
	var simulator = BalanceRunSimulatorScript.new()
	var result: Dictionary = simulator.run(BalanceRunSimulatorScript.default_config())
	status_label.text = str(result.get("status_line", "Balance sim finished."))
	if _balance_button != null:
		_balance_button.disabled = false
	_refresh_continue_button()
