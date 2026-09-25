extends "res://scripts/dev/RunPolicy.gd"


func get_id() -> String:
	return "random"


func choose_room(rooms: Array) -> TowerRoomData:
	return rooms[_policy_rng.randi_range(0, rooms.size() - 1)]


func choose_card(combat) -> CardInstance:
	var playable: Array[CardInstance] = []
	for card in combat.hand:
		var card_instance: CardInstance = card
		var card_data := _cards.get_card(card_instance.card_id)
		if card_data == null or not card_data.is_playable():
			continue
		if int(combat.energy) < card_data.cost:
			continue
		playable.append(card_instance)

	if playable.is_empty():
		return null

	return playable[_policy_rng.randi_range(0, playable.size() - 1)]


func choose_reward_card(offered: Array) -> String:
	if offered.is_empty():
		return ""

	var roll := _policy_rng.randi_range(0, offered.size())
	if roll >= offered.size():
		return ""
	return str(offered[roll])


func choose_reward_relic(offered: Array) -> String:
	if offered.is_empty():
		return ""
	return str(offered[_policy_rng.randi_range(0, offered.size() - 1)])


func should_rest() -> bool:
	if RunState.current_hp >= RunState.max_hp:
		return false
	return _policy_rng.randf() < 0.5


func should_temper() -> bool:
	return _policy_rng.randf() < 0.5


func should_scout() -> bool:
	return _policy_rng.randf() < 0.5


func should_pray() -> bool:
	return _policy_rng.randf() < 0.5


func choose_event_choice(event_data: EventData) -> String:
	if event_data == null:
		return ""

	var options: Array[String] = []
	for choice in event_data.choices:
		var choice_id := str(choice.get("id", ""))
		if EventManager.can_select_choice(event_data, choice_id):
			options.append(choice_id)

	if options.is_empty():
		return ""
	return options[_policy_rng.randi_range(0, options.size() - 1)]


func choose_shop_action(inventory: Dictionary) -> Dictionary:
	if not _shop_planned:
		_shop_planned = true
		_plan_random_shop(inventory)

	if _queued_shop_actions.is_empty():
		return {"type": "leave"}
	return _queued_shop_actions.pop_front()


func _plan_random_shop(inventory: Dictionary) -> void:
	var card_offers: Array = inventory.get("card_offers", [])
	for offer_index in range(card_offers.size()):
		var offer: Dictionary = card_offers[offer_index]
		if bool(offer.get("sold", false)):
			continue
		if RunState.gold >= int(offer.get("price", 0)) and _policy_rng.randf() < 0.55:
			_queued_shop_actions.append({
				"type": "buy_card",
				"index": offer_index,
			})

	var relic_offer: Dictionary = inventory.get("relic_offer", {})
	if not relic_offer.is_empty() and not bool(relic_offer.get("sold", false)):
		if RunState.gold >= int(relic_offer.get("price", 0)) and _policy_rng.randf() < 0.45:
			_queued_shop_actions.append({"type": "buy_relic"})

	if RunState.can_remove_card_from_deck() and _policy_rng.randf() < 0.4:
		var card_index := _policy_rng.randi_range(0, RunState.deck.size() - 1)
		_queued_shop_actions.append({
			"type": "remove_card",
			"card_id": str(RunState.deck[card_index]),
		})
