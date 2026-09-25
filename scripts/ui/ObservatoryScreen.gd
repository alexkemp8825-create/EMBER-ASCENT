extends PanelContainer

const RunActionsScript := preload("res://scripts/core/RunActions.gd")

@onready var subtitle_label: Label = %SubtitleLabel
@onready var scout_button: Button = %ScoutButton
@onready var continue_button: Button = %ContinueButton

var _scouted := false


func _ready() -> void:
	scout_button.pressed.connect(_on_scout_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	subtitle_label.text = "The observatory overlooks the tower. Scout for spoils ahead."


func _on_scout_pressed() -> void:
	if _scouted:
		return

	var scout_gold := RunActionsScript.scout()
	_scouted = true
	scout_button.disabled = true
	subtitle_label.text = "You chart hidden caches. +%d Gold." % scout_gold


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
