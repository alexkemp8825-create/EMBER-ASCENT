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
