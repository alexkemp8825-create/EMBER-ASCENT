extends RefCounted

var _policy_rng := RandomNumberGenerator.new()
var _cards: CardDatabase
var _shop_planned := false
var _queued_shop_actions: Array = []


func setup(seed_value: int) -> void:
	_policy_rng.seed = int(seed_value) + 17
	_cards = CardDatabase.new()


func cleanup() -> void:
	if is_instance_valid(_cards):
		_cards.free()
		_cards = null


func get_id() -> String:
	return "base"


func begin_shop() -> void:
	_shop_planned = false
	_queued_shop_actions.clear()


func choose_room(rooms: Array) -> TowerRoomData:
	return rooms[0]


func choose_card(_combat) -> CardInstance:
	return null


func choose_reward_card(_offered: Array) -> String:
	return ""


func choose_reward_relic(offered: Array) -> String:
	if offered.is_empty():
		return ""
	return str(offered[0])


func should_rest() -> bool:
	return RunState.current_hp < RunState.max_hp


func should_temper() -> bool:
	return true


func should_scout() -> bool:
	return true


func should_pray() -> bool:
	return true


func choose_event_choice(event_data: EventData) -> String:
	if event_data == null:
		return ""

	for choice in event_data.choices:
		var choice_id := str(choice.get("id", ""))
		if EventManager.can_select_choice(event_data, choice_id):
			return choice_id
	return ""


func choose_shop_action(_inventory: Dictionary) -> Dictionary:
	return {"type": "leave"}


func _reward_score(card_id: String) -> float:
	if _cards == null:
		return 0.0

	var card_data := _cards.get_card(card_id)
	if card_data == null:
		return 0.0

	var score := 0.0
	for effect in card_data.effects:
		var amount := float(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"damage":
				score += amount * 3.0
			"block":
				score += amount * 1.3
			"draw":
				score += amount * 3.2
			"temp_strength":
				score += amount * 3.5
			"heal":
				score += amount * 2.0
			"enemy_burn", "enemy_burn_all":
				score += amount * 2.6
	if card_data.rarity == "Uncommon":
		score += 1.0
	return score


func _count_card(card_id: String) -> int:
	var count := 0
	for deck_card_id in RunState.deck:
		if str(deck_card_id) == card_id:
			count += 1
	return count
