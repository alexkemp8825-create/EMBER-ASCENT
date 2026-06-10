extends PanelContainer

const RelicDatabaseScript := preload("res://scripts/relics/RelicDatabase.gd")

@onready var subtitle_label: Label = %SubtitleLabel
@onready var pray_button: Button = %PrayButton
@onready var continue_button: Button = %ContinueButton

var _prayed := false
var _relic_database := RelicDatabaseScript.new()


func _ready() -> void:
	pray_button.pressed.connect(_on_pray_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	subtitle_label.text = "A shrine flickers with ember-light. Pray for relief or press on."


func _on_pray_pressed() -> void:
	if _prayed:
		return

	var heal_amount := int(ceil(float(RunState.max_hp) * 0.4))
	RunState.current_hp = min(RunState.current_hp + heal_amount, RunState.max_hp)

	var relic_choices := _relic_database.get_boss_reward_choices(1, RunState.relics)
	if relic_choices.is_empty():
		subtitle_label.text = "The shrine restores %d HP." % heal_amount
	else:
		var relic_data: RelicData = relic_choices[0]
		RunState.add_relic(relic_data.id)
		subtitle_label.text = "The shrine restores %d HP and grants %s." % [
			heal_amount,
			relic_data.display_name,
		]

	_prayed = true
	pray_button.disabled = true


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
