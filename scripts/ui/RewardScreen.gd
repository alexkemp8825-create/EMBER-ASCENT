extends PanelContainer

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")

@onready var subtitle_label: Label = %SubtitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var card_choices_container: HBoxContainer = %CardChoicesContainer
@onready var relic_choices_container: VBoxContainer = %RelicChoicesContainer
@onready var skip_button: Button = %SkipButton
@onready var continue_button: Button = %ContinueButton

var _payload: Dictionary = {}
var _reward_applied := false
var _card_database := CardDatabase.new()
var _relic_database := RelicDatabase.new()


func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true


func set_payload(payload: Dictionary) -> void:
	_payload = payload
	_apply_gold_reward()
	_build_reward_ui()


func _apply_gold_reward() -> void:
	var gold_amount := int(_payload.get("gold", 0))
	if gold_amount > 0:
		RunState.add_gold(gold_amount)

	gold_label.text = "+%d Gold" % gold_amount


func _build_reward_ui() -> void:
	_clear_choices()

	var is_boss := bool(_payload.get("is_boss", false))
	if is_boss:
		_build_relic_choices()
		skip_button.visible = false
		subtitle_label.text = "The boss is defeated. Choose a relic."
		return

	_build_card_choices()
	skip_button.visible = true

	if bool(_payload.get("is_elite", false)):
		subtitle_label.text = "Elite defeated. Choose a card from enhanced rewards, or skip."
	else:
		subtitle_label.text = "Choose a card to add to your deck, or skip."


func _build_card_choices() -> void:
	var card_ids: Array = _payload.get("card_choices", [])
	relic_choices_container.visible = false
	card_choices_container.visible = true

	if card_ids.is_empty():
		subtitle_label.text = "No card rewards are available. Continue climbing."
		_reward_applied = true
		continue_button.disabled = false
		return

	for card_id in card_ids:
		var card_data := _card_database.get_card(str(card_id))
		if card_data == null:
			continue

		var card_view := CARD_VIEW_SCENE.instantiate()
		card_choices_container.add_child(card_view)
		card_view.set_card_data(card_data)
		card_view.set_selection_mode(true, "Take")
		card_view.select_pressed.connect(_on_card_selected)


func _build_relic_choices() -> void:
	var relic_ids: Array = _payload.get("relic_choices", [])
	card_choices_container.visible = false
	relic_choices_container.visible = true

	if relic_ids.is_empty():
		subtitle_label.text = "No new relics remain. Continue climbing."
		_reward_applied = true
		continue_button.disabled = false
		return

	for relic_id in relic_ids:
		var relic_data := _relic_database.get_relic(str(relic_id))
		if relic_data == null:
			continue

		var relic_button := Button.new()
		relic_button.text = "%s\n%s" % [relic_data.display_name, relic_data.description]
		relic_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		relic_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		relic_button.custom_minimum_size = Vector2(640, 72)
		relic_button.pressed.connect(_on_relic_selected.bind(relic_data.id))
		relic_choices_container.add_child(relic_button)


func _on_card_selected(card_data: CardData) -> void:
	if _reward_applied:
		return

	RunState.add_card_to_deck(card_data.id)
	_reward_applied = true
	subtitle_label.text = "Added %s to your deck." % card_data.display_name
	_disable_choice_buttons()
	continue_button.disabled = false


func _on_relic_selected(relic_id: String) -> void:
	if _reward_applied:
		return

	var relic_data := _relic_database.get_relic(relic_id)
	RunState.add_relic(relic_id)
	_reward_applied = true
	subtitle_label.text = "Claimed %s." % relic_data.display_name if relic_data != null else "Relic claimed."
	_disable_choice_buttons()
	continue_button.disabled = false


func _on_skip_pressed() -> void:
	if _reward_applied:
		return

	_reward_applied = true
	subtitle_label.text = "You leave the spoils behind."
	_disable_choice_buttons()
	continue_button.disabled = false


func _disable_choice_buttons() -> void:
	skip_button.disabled = true

	for child in card_choices_container.get_children():
		if child is Button or child.has_method("set_selection_mode"):
			if child.has_method("set_selection_mode"):
				child.set_selection_mode(false)
			child.disabled = true

	for child in relic_choices_container.get_children():
		child.disabled = true


func _clear_choices() -> void:
	for child in card_choices_container.get_children():
		child.queue_free()

	for child in relic_choices_container.get_children():
		child.queue_free()


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
