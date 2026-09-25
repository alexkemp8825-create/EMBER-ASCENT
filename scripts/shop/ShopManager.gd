class_name ShopManager
extends RefCounted

const CARD_OFFER_COUNT := 3
const COMMON_CARD_BASE_PRICE := 50
const UNCOMMON_CARD_BASE_PRICE := 75
const RELIC_UNCOMMON_BASE_PRICE := 150
const RELIC_RARE_BASE_PRICE := 200
const REMOVE_CARD_BASE_PRICE := 75


static func build_shop_inventory(floor: int, act: int) -> Dictionary:
	var card_database := CardDatabase.new()
	var relic_database := RelicDatabase.new()
	var floor_scale: int = maxi(floor, 0)
	var act_scale: int = maxi(act, 1)

	var card_offers: Array[Dictionary] = []
	for card_data in card_database.get_shop_cards(RunState.selected_class, CARD_OFFER_COUNT):
		card_offers.append({
			"card_id": card_data.id,
			"price": get_card_price(card_data, floor_scale, act_scale),
			"sold": false,
		})

	var relic_offer: Dictionary = {}
	var relic_data := relic_database.get_shop_relic_offer(RunState.relics)
	if relic_data != null:
		relic_offer = {
			"relic_id": relic_data.id,
			"price": get_relic_price(relic_data, floor_scale, act_scale),
			"sold": false,
		}

	return {
		"floor": floor_scale,
		"act": act_scale,
		"card_offers": card_offers,
		"relic_offer": relic_offer,
		"remove_card_price": get_remove_card_price(floor_scale, act_scale),
	}


static func get_card_price(card_data: CardData, floor: int, act: int) -> int:
	var base_price := COMMON_CARD_BASE_PRICE
	var floor_multiplier := 5
	var act_multiplier := 10

	if card_data.rarity == "Uncommon":
		base_price = UNCOMMON_CARD_BASE_PRICE
		floor_multiplier = 8
		act_multiplier = 15

	return base_price + (floor * floor_multiplier) + ((act - 1) * act_multiplier)


static func get_relic_price(relic_data: RelicData, floor: int, act: int) -> int:
	var base_price := RELIC_UNCOMMON_BASE_PRICE
	var floor_multiplier := 10
	var act_multiplier := 20

	if relic_data.rarity == "Rare":
		base_price = RELIC_RARE_BASE_PRICE
		floor_multiplier = 15
		act_multiplier = 30

	return base_price + (floor * floor_multiplier) + ((act - 1) * act_multiplier)


static func get_remove_card_price(floor: int, act: int) -> int:
	return REMOVE_CARD_BASE_PRICE + (floor * 10) + ((act - 1) * 20)


static func try_buy_card(inventory: Dictionary, offer_index: int) -> Dictionary:
	var card_offers: Array = inventory.get("card_offers", [])
	if offer_index < 0 or offer_index >= card_offers.size():
		return {"ok": false, "reason": "missing"}

	var offer: Dictionary = card_offers[offer_index]
	if bool(offer.get("sold", false)):
		return {"ok": false, "reason": "sold"}

	var price := int(offer.get("price", 0))
	if not RunState.spend_gold(price):
		return {"ok": false, "reason": "gold"}

	var card_id := str(offer.get("card_id", ""))
	RunState.add_card_to_deck(card_id)
	offer["sold"] = true
	card_offers[offer_index] = offer
	inventory["card_offers"] = card_offers
	return {"ok": true, "card_id": card_id, "price": price}


static func try_buy_relic(inventory: Dictionary) -> Dictionary:
	var relic_offer: Dictionary = inventory.get("relic_offer", {})
	if relic_offer.is_empty() or bool(relic_offer.get("sold", false)):
		return {"ok": false, "reason": "missing"}

	var price := int(relic_offer.get("price", 0))
	if not RunState.spend_gold(price):
		return {"ok": false, "reason": "gold"}

	var relic_id := str(relic_offer.get("relic_id", ""))
	RunState.add_relic(relic_id)
	relic_offer["sold"] = true
	inventory["relic_offer"] = relic_offer
	return {"ok": true, "relic_id": relic_id, "price": price}


static func try_remove_card(inventory: Dictionary, card_id: String) -> Dictionary:
	var remove_price := int(inventory.get("remove_card_price", 0))
	if not RunState.spend_gold(remove_price):
		return {"ok": false, "reason": "gold"}

	if not RunState.remove_card_from_deck(card_id):
		RunState.add_gold(remove_price)
		return {"ok": false, "reason": "remove"}

	return {"ok": true, "card_id": card_id, "price": remove_price}
