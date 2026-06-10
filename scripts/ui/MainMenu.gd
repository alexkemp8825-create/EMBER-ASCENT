extends PanelContainer

@onready var new_run_button: Button = %NewRunButton
@onready var continue_button: Button = %ContinueRunButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	new_run_button.pressed.connect(_on_new_run_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
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
	SaveManager.delete_save()
	RunState.reset_run()
	SceneLoader.change_to_class_select()


func _on_continue_pressed() -> void:
	if not SaveManager.load_run():
		_refresh_continue_button()
		return

	SceneLoader.change_to_map()


func _on_quit_pressed() -> void:
	get_tree().quit()
