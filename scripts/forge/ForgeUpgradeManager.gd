class_name ForgeUpgradeManager
extends RefCounted

const STARTER_UPGRADE_BASE_PRICE := 50
const COMMON_UPGRADE_BASE_PRICE := 75
const UNCOMMON_UPGRADE_BASE_PRICE := 100


static func get_upgrade_price(card_data: CardData, floor: int, act: int) -> int:
	var base_price := COMMON_UPGRADE_BASE_PRICE
	var floor_multiplier := 8
	var act_multiplier := 15

	if card_data.rarity == "Starter":
		base_price = STARTER_UPGRADE_BASE_PRICE
		floor_multiplier = 5
		act_multiplier = 10
	elif card_data.rarity == "Uncommon":
		base_price = UNCOMMON_UPGRADE_BASE_PRICE
		floor_multiplier = 10
		act_multiplier = 20

	var floor_scale := max(floor, 0)
	var act_scale := max(act, 1)
	return base_price + (floor_scale * floor_multiplier) + ((act_scale - 1) * act_multiplier)


static func get_upgradeable_deck_cards(floor: int, act: int) -> Array[Dictionary]:
	var card_database := CardDatabase.new()
	var offers: Array[Dictionary] = []

	for card_id in RunState.get_unique_deck_card_ids():
		var card_data := card_database.get_card(card_id)
		if card_data == null or card_data.upgraded_id == "":
			continue

		offers.append({
			"card_id": card_id,
			"upgraded_id": card_data.upgraded_id,
			"price": get_upgrade_price(card_data, floor, act),
			"count": RunState.count_cards_in_deck(card_id),
		})

	return offers
