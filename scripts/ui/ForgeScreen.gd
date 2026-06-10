extends PanelContainer

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")
const ForgeUpgradeManagerScript := preload("res://scripts/forge/ForgeUpgradeManager.gd")

@onready var gold_label: Label = %GoldLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var upgrade_list_container: VBoxContainer = %UpgradeListContainer
@onready var temper_button: Button = %TemperButton
@onready var continue_button: Button = %ContinueButton

var _card_database := CardDatabase.new()
var _upgrade_offers: Array[Dictionary] = []
var _forge_action_used := false


func _ready() -> void:
	temper_button.pressed.connect(_on_temper_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	_upgrade_offers = ForgeUpgradeManagerScript.get_upgradeable_deck_cards(
		RunState.current_floor,
		RunState.current_act
	)
	_build_forge_ui()


func _build_forge_ui() -> void:
	_refresh_gold_label()
	subtitle_label.text = "Choose one service: upgrade a card or temper your body."
	_build_upgrade_list()
	_refresh_action_buttons()


func _refresh_gold_label() -> void:
	gold_label.text = "Gold: %d" % RunState.gold


func _build_upgrade_list() -> void:
	for child in upgrade_list_container.get_children():
		child.queue_free()

	if _upgrade_offers.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards in your deck can be upgraded right now."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_list_container.add_child(empty_label)
		return

	for offer_index in range(_upgrade_offers.size()):
		var offer: Dictionary = _upgrade_offers[offer_index]
		var card_id := str(offer.get("card_id", ""))
		var upgraded_id := str(offer.get("upgraded_id", ""))
		var card_data := _card_database.get_card(card_id)
		var upgraded_data := _card_database.get_card(upgraded_id)
		if card_data == null or upgraded_data == null:
			continue

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		upgrade_list_container.add_child(row)

		var base_column := VBoxContainer.new()
		base_column.alignment = BoxContainer.ALIGNMENT_CENTER
		base_column.add_theme_constant_override("separation", 4)
		row.add_child(base_column)

		var base_card_view := CARD_VIEW_SCENE.instantiate()
		base_column.add_child(base_card_view)
		base_card_view.set_card_data(card_data)

		var count_label := Label.new()
		count_label.text = "x%d in deck" % int(offer.get("count", 1))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		base_column.add_child(count_label)

		var arrow_label := Label.new()
		arrow_label.text = "->"
		arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(arrow_label)

		var upgraded_column := VBoxContainer.new()
		upgraded_column.alignment = BoxContainer.ALIGNMENT_CENTER
		upgraded_column.add_theme_constant_override("separation", 8)
		row.add_child(upgraded_column)

		var upgraded_card_view := CARD_VIEW_SCENE.instantiate()
		upgraded_column.add_child(upgraded_card_view)
		upgraded_card_view.set_card_data(upgraded_data)

		var upgrade_button := Button.new()
		upgrade_button.text = "Upgrade (%dg)" % int(offer.get("price", 0))
		upgrade_button.pressed.connect(_on_upgrade_pressed.bind(offer_index, upgrade_button))
		upgraded_column.add_child(upgrade_button)


func _refresh_action_buttons() -> void:
	temper_button.disabled = _forge_action_used
	temper_button.text = "Tempered (+4 Max HP)" if _forge_action_used else "Temper (+4 Max HP)"

	for row in upgrade_list_container.get_children():
		if row is HBoxContainer:
			for column in row.get_children():
				if column is VBoxContainer:
					for child in column.get_children():
						if child is Button and str(child.text).begins_with("Upgrade"):
							child.disabled = _forge_action_used


func _mark_forge_action_used(message: String) -> void:
	_forge_action_used = true
	subtitle_label.text = message
	_refresh_gold_label()
	_refresh_action_buttons()


func _on_upgrade_pressed(offer_index: int, upgrade_button: Button) -> void:
	if _forge_action_used:
		return

	if offer_index < 0 or offer_index >= _upgrade_offers.size():
		return

	var offer: Dictionary = _upgrade_offers[offer_index]
	var card_id := str(offer.get("card_id", ""))
	var price := int(offer.get("price", 0))
	if not RunState.spend_gold(price):
		subtitle_label.text = "Not enough gold for that upgrade."
		return

	var upgraded_id := RunState.upgrade_card_in_deck(card_id)
	if upgraded_id == "":
		RunState.add_gold(price)
		subtitle_label.text = "That card can no longer be upgraded."
		return

	var upgraded_data := _card_database.get_card(upgraded_id)
	var upgraded_name := upgraded_data.display_name if upgraded_data != null else "card"
	_mark_forge_action_used("Upgraded one copy to %s." % upgraded_name)
	upgrade_button.disabled = true
	_upgrade_offers = ForgeUpgradeManagerScript.get_upgradeable_deck_cards(
		RunState.current_floor,
		RunState.current_act
	)
	_build_upgrade_list()
	_refresh_action_buttons()


func _on_temper_pressed() -> void:
	if _forge_action_used:
		return

	RunState.max_hp += 4
	RunState.current_hp += 4
	_mark_forge_action_used("The smith tempers you. +4 Max HP.")


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
