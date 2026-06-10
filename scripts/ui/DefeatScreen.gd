extends PanelContainer

const LegacyRunDataScript := preload("res://scripts/legacy/LegacyRunData.gd")

@onready var summary_label: Label = %SummaryLabel
@onready var main_menu_button: Button = %MainMenuButton

var _payload: Dictionary = {}


func _ready() -> void:
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	_apply_payload()


func set_payload(payload: Dictionary) -> void:
	_payload = payload
	if is_node_ready():
		_apply_payload()


func _apply_payload() -> void:
	var legacy_data: Variant = _payload.get("legacy_run", {})
	if legacy_data is Dictionary and not legacy_data.is_empty():
		var legacy_run := LegacyRunDataScript.deserialize(legacy_data)
		summary_label.text = (
			"Run %d ends on floor %d.\n"
			+ "The tower remembers %d cards and %d relics."
		) % [
			legacy_run.run_number,
			legacy_run.final_floor,
			legacy_run.deck_snapshot.size(),
			legacy_run.relic_snapshot.size(),
		]
		return

	summary_label.text = "Your ascent ends here. The tower remembers."


func _on_main_menu_pressed() -> void:
	SceneLoader.change_to_main_menu()
