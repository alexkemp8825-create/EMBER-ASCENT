extends PanelContainer

const RunActionsScript := preload("res://scripts/core/RunActions.gd")

@onready var subtitle_label: Label = %SubtitleLabel
@onready var rest_button: Button = %RestButton
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	rest_button.pressed.connect(_on_rest_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	subtitle_label.text = "Recover 25% of your max HP, or continue climbing."


func _on_rest_pressed() -> void:
	var heal_amount := RunActionsScript.rest()
	subtitle_label.text = "You rest and recover %d HP." % heal_amount
	rest_button.disabled = true


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
