extends PanelContainer

@onready var subtitle_label: Label = %SubtitleLabel
@onready var temper_button: Button = %TemperButton
@onready var continue_button: Button = %ContinueButton

var _tempered := false


func _ready() -> void:
	temper_button.pressed.connect(_on_temper_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	subtitle_label.text = "The forge glows. Temper your body or continue onward."


func _on_temper_pressed() -> void:
	if _tempered:
		return

	RunState.max_hp += 4
	RunState.current_hp += 4
	_tempered = true
	temper_button.disabled = true
	subtitle_label.text = "The smith tempers you. +4 Max HP."


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
