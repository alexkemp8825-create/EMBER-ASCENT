extends PanelContainer

const LegacyRunDataScript := preload("res://scripts/legacy/LegacyRunData.gd")

@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var back_button: Button = %BackButton

var _legacy_id: String = ""


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_apply_payload()


func set_payload(payload: Dictionary) -> void:
	_legacy_id = str(payload.get("legacy_id", ""))
	if is_node_ready():
		_apply_payload()


func _apply_payload() -> void:
	var legacy_run := LegacyManager.get_legacy_run_by_id(_legacy_id)
	if legacy_run == null:
		title_label.text = "Ghost Echo"
		summary_label.text = "A faint memory stirs in the stone."
		return

	title_label.text = "Echo of Run %d" % legacy_run.run_number
	summary_label.text = (
		"This chamber remembers %s.\n"
		+ "They reached floor %d carrying %d cards and %d relics.\n\n"
		+ "Full encounters arrive in the next sprint."
	) % [
		legacy_run.ghost_name,
		legacy_run.final_floor,
		legacy_run.deck_snapshot.size(),
		legacy_run.relic_snapshot.size(),
	]


func _on_back_pressed() -> void:
	RunState.complete_ghost_active_room()
	SceneLoader.change_to_map()
