extends PanelContainer

@onready var subtitle_label: Label = %SubtitleLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	subtitle_label.text = "Market wares will arrive in a later sprint."


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
