extends PanelContainer

const SCOUT_GOLD := 18

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

	RunState.add_gold(SCOUT_GOLD)
	_scouted = true
	scout_button.disabled = true
	subtitle_label.text = "You chart hidden caches. +%d Gold." % SCOUT_GOLD


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
