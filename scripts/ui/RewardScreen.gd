extends PanelContainer

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")
const RunUpgradeRulesScript := preload("res://scripts/rewards/RunUpgradeRules.gd")
const RunUpgradeDatabaseScript := preload("res://scripts/rewards/RunUpgradeDatabase.gd")

@onready var subtitle_label: Label = %SubtitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var card_choices_container: HBoxContainer = %CardChoicesContainer
@onready var relic_choices_container: VBoxContainer = %RelicChoicesContainer
@onready var upgrade_title_label: Label = %UpgradeTitle
@onready var build_label: Label = %BuildLabel
@onready var upgrade_choices_container: VBoxContainer = %UpgradeChoicesContainer
@onready var skip_button: Button = %SkipButton
@onready var skip_upgrade_button: Button = %SkipUpgradeButton
@onready var continue_button: Button = %ContinueButton

var _payload: Dictionary = {}
var _card_resolved := false
var _upgrade_resolved := false
var _card_database := CardDatabase.new()
var _relic_database := RelicDatabase.new()


func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)
	skip_upgrade_button.pressed.connect(_on_skip_upgrade_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true


func set_payload(payload: Dictionary) -> void:
	_payload = payload
	_card_resolved = false
	_upgrade_resolved = false
	_apply_gold_reward()
	_build_reward_ui()
	_build_upgrade_choices()
	_refresh_build_label()
	_refresh_continue_button()


func _apply_gold_reward() -> void:
	var gold_amount := int(_payload.get("gold", 0))
	if gold_amount > 0:
		RunState.add_gold(gold_amount)

	gold_label.text = "+%d Gold" % gold_amount


func _build_reward_ui() -> void:
	_clear_container(card_choices_container)
	_clear_container(relic_choices_container)

	var is_boss := bool(_payload.get("is_boss", false))
	if is_boss:
		_build_relic_choices()
		skip_button.visible = false
		subtitle_label.text = "The boss is defeated. Choose a relic, then a run upgrade."
		return

	_build_card_choices()
	skip_button.visible = true

	if bool(_payload.get("is_elite", false)):
		subtitle_label.text = "Elite defeated. Choose a card and a run upgrade, or skip either."
	else:
		subtitle_label.text = "Choose a card and a run upgrade, or skip either."


func _build_card_choices() -> void:
	var card_ids: Array = _payload.get("card_choices", [])
	relic_choices_container.visible = false
	card_choices_container.visible = true

	if card_ids.is_empty():
		_card_resolved = true
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
		_card_resolved = true
		subtitle_label.text = "No new relics remain. Choose a run upgrade."
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


func _build_upgrade_choices() -> void:
	_clear_container(upgrade_choices_container)
	var upgrade_ids: Array = _payload.get("upgrade_choices", [])
	if upgrade_ids.is_empty():
		upgrade_title_label.text = "No run upgrades remain."
		skip_upgrade_button.visible = false
		_upgrade_resolved = true
		return

	upgrade_title_label.text = "Run upgrade — choose 1 of %d" % upgrade_ids.size()
	skip_upgrade_button.visible = true
	skip_upgrade_button.disabled = false

	for upgrade_id in upgrade_ids:
		var upgrade := RunUpgradeDatabaseScript.get_upgrade(str(upgrade_id))
		if upgrade.is_empty():
			continue

		var button := Button.new()
		button.text = _format_upgrade_button(upgrade)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(760, 84)
		button.pressed.connect(_on_upgrade_selected.bind(str(upgrade_id)))
		upgrade_choices_container.add_child(button)


func _format_upgrade_button(upgrade: Dictionary) -> String:
	var upgrade_id := str(upgrade.get("id", ""))
	var stacks := RunUpgradeRulesScript.get_stacks(upgrade_id)
	var max_stacks := int(upgrade.get("max_stacks", 1))
	var theme := RunUpgradeDatabaseScript.theme_label(str(upgrade.get("theme", "")))
	return "%s  [%s]  %d/%d → %d/%d\n%s" % [
		str(upgrade.get("display_name", upgrade_id)),
		theme,
		stacks,
		max_stacks,
		stacks + 1,
		max_stacks,
		str(upgrade.get("description", "")),
	]


func _on_card_selected(card_data: CardData) -> void:
	if _card_resolved:
		return

	RunState.add_card_to_deck(card_data.id)
	_card_resolved = true
	subtitle_label.text = "Added %s to your deck." % card_data.display_name
	_disable_card_choices()
	_refresh_continue_button()


func _on_relic_selected(relic_id: String) -> void:
	if _card_resolved:
		return

	var relic_data := _relic_database.get_relic(relic_id)
	RunState.add_relic(relic_id)
	_card_resolved = true
	subtitle_label.text = "Claimed %s." % relic_data.display_name if relic_data != null else "Relic claimed."
	_disable_card_choices()
	_refresh_continue_button()


func _on_upgrade_selected(upgrade_id: String) -> void:
	if _upgrade_resolved:
		return

	if not RunUpgradeRulesScript.apply_upgrade(upgrade_id):
		return

	var upgrade := RunUpgradeDatabaseScript.get_upgrade(upgrade_id)
	_upgrade_resolved = true
	subtitle_label.text = "Learned %s." % str(upgrade.get("display_name", upgrade_id))
	_disable_upgrade_choices()
	_refresh_build_label()
	_refresh_continue_button()


func _on_skip_pressed() -> void:
	if _card_resolved:
		return

	_card_resolved = true
	subtitle_label.text = "You leave the card behind."
	_disable_card_choices()
	_refresh_continue_button()


func _on_skip_upgrade_pressed() -> void:
	if _upgrade_resolved:
		return

	_upgrade_resolved = true
	subtitle_label.text = "You leave the upgrade behind."
	_disable_upgrade_choices()
	_refresh_continue_button()


func _disable_card_choices() -> void:
	skip_button.disabled = true
	for child in card_choices_container.get_children():
		if child.has_method("set_selection_mode"):
			child.set_selection_mode(false)
		child.disabled = true

	for child in relic_choices_container.get_children():
		child.disabled = true


func _disable_upgrade_choices() -> void:
	skip_upgrade_button.disabled = true
	for child in upgrade_choices_container.get_children():
		child.disabled = true


func _refresh_build_label() -> void:
	build_label.text = RunUpgradeRulesScript.build_summary()


func _refresh_continue_button() -> void:
	continue_button.disabled = not (_card_resolved and _upgrade_resolved)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_continue_pressed() -> void:
	if not (_card_resolved and _upgrade_resolved):
		return
	RunState.complete_active_room()
	SceneLoader.change_to_map()
