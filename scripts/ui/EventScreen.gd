extends PanelContainer

const EventManagerScript := preload("res://scripts/events/EventManager.gd")
const LegacyRunDataScript := preload("res://scripts/legacy/LegacyRunData.gd")

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var outcome_label: Label = %OutcomeLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var continue_button: Button = %ContinueButton

var _event_id: String = ""
var _event_database := EventDatabase.new()
var _choice_applied := false


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true


func set_payload(payload: Dictionary) -> void:
	_event_id = str(payload.get("event_id", ""))
	_build_event_ui()


func _build_event_ui() -> void:
	var event_data := _event_database.get_event(_event_id)
	if event_data == null:
		title_label.text = "Unknown Event"
		description_label.text = "Nothing stirs in this room."
		continue_button.disabled = false
		return

	title_label.text = event_data.title
	description_label.text = event_data.description
	outcome_label.text = "What do you do?"

	for choice in event_data.choices:
		var choice_button := Button.new()
		choice_button.text = str(choice.get("text", "Choose"))
		choice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.custom_minimum_size = Vector2(640, 56)
		choice_button.pressed.connect(_on_choice_pressed.bind(event_data, str(choice.get("id", ""))))
		choices_container.add_child(choice_button)


func _on_choice_pressed(event_data: EventData, choice_id: String) -> void:
	if _choice_applied:
		return

	var result: Dictionary = EventManagerScript.apply_choice(event_data, choice_id)
	outcome_label.text = str(result.get("message", "The moment passes."))

	if not bool(result.get("success", false)):
		return

	_choice_applied = true
	_disable_choice_buttons()
	continue_button.disabled = false

	if RunState.current_hp <= 0:
		var legacy_run := LegacyManager.finalize_run_end(LegacyRunDataScript.RESULT_DEFEAT)
		RunState.reset_run()
		SceneLoader.change_to_defeat(LegacyManager.build_run_end_payload(legacy_run))


func _disable_choice_buttons() -> void:
	for child in choices_container.get_children():
		child.disabled = true


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
