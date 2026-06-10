extends PanelContainer

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")
const ShopManagerScript := preload("res://scripts/shop/ShopManager.gd")

@onready var gold_label: Label = %GoldLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var card_offers_container: HBoxContainer = %CardOffersContainer
@onready var relic_offer_container: VBoxContainer = %RelicOfferContainer
@onready var services_container: VBoxContainer = %ServicesContainer
@onready var continue_button: Button = %ContinueButton

var _inventory: Dictionary = {}
var _card_database := CardDatabase.new()
var _relic_database := RelicDatabase.new()


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	_inventory = ShopManagerScript.build_shop_inventory(RunState.current_floor, RunState.current_act)
	_build_shop_ui()


func _build_shop_ui() -> void:
	_refresh_gold_label()
	subtitle_label.text = "Spend gold on cards, relics, or deck thinning."
	_build_card_offers()
	_build_relic_offer()
	_build_remove_card_service()


func _refresh_gold_label() -> void:
	gold_label.text = "Gold: %d" % RunState.gold


func _build_card_offers() -> void:
	for child in card_offers_container.get_children():
		child.queue_free()

	var card_offers: Array = _inventory.get("card_offers", [])
	if card_offers.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards in stock today."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_offers_container.add_child(empty_label)
		return

	for offer_index in range(card_offers.size()):
		var offer: Dictionary = card_offers[offer_index]
		var card_data := _card_database.get_card(str(offer.get("card_id", "")))
		if card_data == null:
			continue

		var offer_column := VBoxContainer.new()
		offer_column.alignment = BoxContainer.ALIGNMENT_CENTER
		offer_column.add_theme_constant_override("separation", 8)
		card_offers_container.add_child(offer_column)

		var card_view := CARD_VIEW_SCENE.instantiate()
		offer_column.add_child(card_view)
		card_view.set_card_data(card_data)

		var buy_button := Button.new()
		buy_button.text = "Buy (%dg)" % int(offer.get("price", 0))
		buy_button.pressed.connect(_on_card_buy_pressed.bind(offer_index, buy_button))
		offer_column.add_child(buy_button)


func _build_relic_offer() -> void:
	for child in relic_offer_container.get_children():
		child.queue_free()

	var relic_offer: Dictionary = _inventory.get("relic_offer", {})
	if relic_offer.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No relics available for purchase."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		relic_offer_container.add_child(empty_label)
		return

	var relic_data := _relic_database.get_relic(str(relic_offer.get("relic_id", "")))
	if relic_data == null:
		return

	var relic_button := Button.new()
	relic_button.text = "Buy %s (%dg)\n%s" % [
		relic_data.display_name,
		int(relic_offer.get("price", 0)),
		relic_data.description,
	]
	relic_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	relic_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relic_button.custom_minimum_size = Vector2(640, 72)
	relic_button.pressed.connect(_on_relic_buy_pressed.bind(relic_button))
	relic_offer_container.add_child(relic_button)


func _build_remove_card_service() -> void:
	for child in services_container.get_children():
		child.queue_free()

	var remove_price := int(_inventory.get("remove_card_price", 0))
	var service_label := Label.new()
	service_label.text = "Deck Thinning (%dg per removal)" % remove_price
	service_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	services_container.add_child(service_label)

	if not RunState.can_remove_card_from_deck():
		var warning_label := Label.new()
		warning_label.text = "Your deck is too small to remove cards."
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		services_container.add_child(warning_label)
		return

	for card_id in RunState.get_unique_deck_card_ids():
		var card_data := _card_database.get_card(card_id)
		if card_data == null:
			continue

		var count := _count_cards_in_deck(card_id)
		var remove_button := Button.new()
		remove_button.text = "Remove %s x%d (%dg)" % [
			card_data.display_name,
			count,
			remove_price,
		]
		remove_button.pressed.connect(_on_remove_card_pressed.bind(card_id, remove_button))
		services_container.add_child(remove_button)


func _on_card_buy_pressed(offer_index: int, buy_button: Button) -> void:
	var card_offers: Array = _inventory.get("card_offers", [])
	if offer_index < 0 or offer_index >= card_offers.size():
		return

	var offer: Dictionary = card_offers[offer_index]
	if bool(offer.get("sold", false)):
		return

	var price := int(offer.get("price", 0))
	if not RunState.spend_gold(price):
		subtitle_label.text = "Not enough gold for that card."
		return

	RunState.add_card_to_deck(str(offer.get("card_id", "")))
	offer["sold"] = true
	card_offers[offer_index] = offer
	_inventory["card_offers"] = card_offers

	var card_data := _card_database.get_card(str(offer.get("card_id", "")))
	subtitle_label.text = "Purchased %s." % card_data.display_name if card_data != null else "Card purchased."
	buy_button.disabled = true
	buy_button.text = "Sold"
	_refresh_gold_label()


func _on_relic_buy_pressed(relic_button: Button) -> void:
	var relic_offer: Dictionary = _inventory.get("relic_offer", {})
	if relic_offer.is_empty() or bool(relic_offer.get("sold", false)):
		return

	var price := int(relic_offer.get("price", 0))
	if not RunState.spend_gold(price):
		subtitle_label.text = "Not enough gold for that relic."
		return

	var relic_id := str(relic_offer.get("relic_id", ""))
	RunState.add_relic(relic_id)
	relic_offer["sold"] = true
	_inventory["relic_offer"] = relic_offer

	var relic_data := _relic_database.get_relic(relic_id)
	subtitle_label.text = "Purchased %s." % relic_data.display_name if relic_data != null else "Relic purchased."
	relic_button.disabled = true
	relic_button.text = "Sold"
	_refresh_gold_label()


func _on_remove_card_pressed(card_id: String, remove_button: Button) -> void:
	var remove_price := int(_inventory.get("remove_card_price", 0))
	if not RunState.spend_gold(remove_price):
		subtitle_label.text = "Not enough gold to remove a card."
		return

	if not RunState.remove_card_from_deck(card_id):
		RunState.add_gold(remove_price)
		subtitle_label.text = "That card can no longer be removed."
		return

	var card_data := _card_database.get_card(card_id)
	subtitle_label.text = "Removed %s from your deck." % card_data.display_name if card_data != null else "Card removed."
	_refresh_gold_label()
	_build_remove_card_service()


func _count_cards_in_deck(card_id: String) -> int:
	var count := 0
	for deck_card_id in RunState.deck:
		if deck_card_id == card_id:
			count += 1

	return count


func _on_continue_pressed() -> void:
	RunState.complete_active_room()
	SceneLoader.change_to_map()
