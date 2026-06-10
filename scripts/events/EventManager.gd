class_name EventManager
extends RefCounted

const CardDatabaseScript := preload("res://scripts/cards/CardDatabase.gd")


static func apply_choice(event_data: EventData, choice_id: String) -> Dictionary:
	if event_data == null:
		return _result(false, "Unknown event.")

	var choice := event_data.get_choice(choice_id)
	if choice.is_empty():
		return _result(false, "Unknown choice.")

	if not _can_afford_choice(choice):
		return _result(false, "You cannot afford that choice.")

	for effect in choice.get("effects", []):
		if effect is Dictionary:
			_apply_effect(effect)

	return _result(true, _build_outcome_text(choice))


static func _can_afford_choice(choice: Dictionary) -> bool:
	for effect in choice.get("effects", []):
		if effect is Dictionary and str(effect.get("type", "")) == "gold_cost":
			if RunState.gold < int(effect.get("amount", 0)):
				return false

	return true


static func _apply_effect(effect: Dictionary) -> void:
	match str(effect.get("type", "")):
		"gold":
			RunState.add_gold(int(effect.get("amount", 0)))
		"gold_cost":
			RunState.spend_gold(int(effect.get("amount", 0)))
		"heal":
			var heal_amount := int(effect.get("amount", 0))
			RunState.current_hp = min(RunState.current_hp + heal_amount, RunState.max_hp)
		"damage":
			RunState.current_hp = max(RunState.current_hp - int(effect.get("amount", 0)), 0)
		"max_hp":
			var bonus := int(effect.get("amount", 0))
			RunState.max_hp += bonus
			RunState.current_hp += bonus
		"add_card":
			_add_card_effect(str(effect.get("card_id", "")))
		"add_relic":
			RunState.add_relic(str(effect.get("relic_id", "")))
		_:
			pass


static func _add_card_effect(card_id: String) -> void:
	if card_id == "random_shop" or card_id == "random_common":
		var card_database := CardDatabaseScript.new()
		var cards := card_database.get_shop_cards(RunState.selected_class, 1)
		if not cards.is_empty():
			RunState.add_card_to_deck(cards[0].id)
		return

	if card_id != "":
		RunState.add_card_to_deck(card_id)


static func _build_outcome_text(choice: Dictionary) -> String:
	var outcome := str(choice.get("outcome", ""))
	if outcome != "":
		return outcome

	return "You chose: %s" % str(choice.get("text", "Unknown"))


static func _result(success: bool, message: String) -> Dictionary:
	return {
		"success": success,
		"message": message,
	}
