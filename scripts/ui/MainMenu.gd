extends PanelContainer

@onready var new_run_button: Button = %NewRunButton
@onready var continue_button: Button = %ContinueRunButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	continue_button.disabled = true
	continue_button.tooltip_text = "Continue Run will be available after save data is implemented."

	new_run_button.pressed.connect(_on_new_run_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_new_run_pressed() -> void:
	RunState.reset_run()
	SceneLoader.change_to_class_select()


func _on_quit_pressed() -> void:
	get_tree().quit()
