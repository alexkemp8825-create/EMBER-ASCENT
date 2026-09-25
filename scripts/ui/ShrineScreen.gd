extends PanelContainer

const RunActionsScript := preload("res://scripts/core/RunActions.gd")

@onready var subtitle_label: Label = %SubtitleLabel
@onready var pray_button: Button = %PrayButton
@onready var continue_button: Button = %ContinueButton

var _prayed := false


func _ready() -> void:
	pray_button.pressed.connect(_on_pray_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	subtitle_label.text = "A shrine flickers with ember-light. Pray for relief or press on."


func _on_pray_pressed() -> void:
	if _prayed:
		return

	var result := RunActionsScript.pray()
	var heal_amount := int(result.get("heal_amount", 0))
	var relic_name := str(result.get("relic_name", ""))
	if relic_name == "":
		subtitle_label.text = "The shrine restores %d HP." % heal_amount
	else:
		subtitle_label.text = "The shrine restores %d HP and grants %s." % [
			heal_amount,
			relic_name,
		]

	_prayed = true
	pray_button.disabled = true


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
