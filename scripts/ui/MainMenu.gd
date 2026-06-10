extends PanelContainer

@onready var subtitle_label: Label = %Subtitle
@onready var new_run_button: Button = %NewRunButton
@onready var continue_button: Button = %ContinueRunButton
@onready var dev_test_button: Button = %DevTestButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	var build_text := "Build %s" % GameState.VERSION
	version_label.text = build_text
	subtitle_label.text = "Climb the living volcanic tower.\n%s" % build_text
	status_label.text = _get_launch_hint()
	new_run_button.pressed.connect(_on_new_run_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	dev_test_button.pressed.connect(_on_dev_test_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_refresh_continue_button()


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


func _on_dev_test_pressed() -> void:
	SceneLoader.change_to_dev_test()


func _on_quit_pressed() -> void:
	get_tree().quit()
