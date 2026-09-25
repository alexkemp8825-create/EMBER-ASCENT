extends "res://scripts/dev/RunPolicy.gd"

const RELIC_VALUE := {
	"smoldering_brand": 30.0,
	"ash_shield": 20.0,
	"ember_heart": 16.0,
}


func get_id() -> String:
	return "heuristic"


func choose_room(rooms: Array) -> TowerRoomData:
	var best: TowerRoomData = rooms[0]
	var best_score := -999999.0
	for room in rooms:
		var typed_room: TowerRoomData = room
		var score := _score_room(typed_room)
		if score > best_score:
			best_score = score
			best = typed_room
	return best


func choose_card(combat) -> CardInstance:
	var incoming := _incoming_damage(combat)
	var unprotected := maxi(0, incoming - int(combat.block))
	var best: CardInstance = null
	var best_score := 0.0

	for card in combat.hand:
		var card_instance: CardInstance = card
		var card_data := _cards.get_card(card_instance.card_id)
		if card_data == null or not card_data.is_playable():
			continue
		if int(combat.energy) < card_data.cost:
			continue

		var score := _score_combat_card(card_data, combat, unprotected)
		if score > best_score:
			best_score = score
			best = card_instance

	return best


func choose_reward_card(offered: Array) -> String:
	var best_id := ""
	var best_score := -1.0
	for card_id in offered:
		var score := _reward_score(str(card_id))
		if score > best_score:
			best_score = score
			best_id = str(card_id)

	if best_id == "" or (RunState.deck.size() >= 20 and best_score < 10.0):
		return ""
	return best_id


func choose_reward_relic(offered: Array) -> String:
	var best_id := ""
	var best_score := -1.0
	for relic_id in offered:
		var score := float(RELIC_VALUE.get(str(relic_id), 1.0))
		if score > best_score:
			best_score = score
			best_id = str(relic_id)
	return best_id


func choose_event_choice(event_data: EventData) -> String:
	if event_data == null:
		return ""

	var best_id := ""
	var best_score := -999999.0
	for choice in event_data.choices:
		var choice_id := str(choice.get("id", ""))
		if not EventManager.can_select_choice(event_data, choice_id):
			continue
		var score := _score_event_choice(choice)
		if score > best_score:
			best_score = score
			best_id = choice_id
	return best_id


func choose_shop_action(inventory: Dictionary) -> Dictionary:
	var remove_price := int(inventory.get("remove_card_price", 0))
	var strike_id := "cinder_bolt" if RunState.selected_class == ClassDatabase.CINDER_WITCH else "ember_strike"
	if (
		_count_card(strike_id) >= 4
		and RunState.can_remove_card_from_deck()
		and RunState.gold >= remove_price + 25
	):
		return {"type": "remove_card", "card_id": strike_id}

	var relic_offer: Dictionary = inventory.get("relic_offer", {})
	if not relic_offer.is_empty() and not bool(relic_offer.get("sold", false)):
		var relic_price := int(relic_offer.get("price", 0))
		if RunState.gold >= relic_price + 40:
			return {"type": "buy_relic"}

	var best_index := -1
	var best_score := 11.0
	var card_offers: Array = inventory.get("card_offers", [])
	for offer_index in range(card_offers.size()):
		var offer: Dictionary = card_offers[offer_index]
		if bool(offer.get("sold", false)):
			continue
		var price := int(offer.get("price", 0))
		if RunState.gold < price + 20:
			continue
		var score := _reward_score(str(offer.get("card_id", "")))
		if score > best_score:
			best_score = score
			best_index = offer_index

	if best_index >= 0:
		return {"type": "buy_card", "index": best_index}

	return {"type": "leave"}


func _score_room(room: TowerRoomData) -> float:
	var missing_hp := RunState.max_hp - RunState.current_hp
	var hp_ratio := float(RunState.current_hp) / float(maxi(RunState.max_hp, 1))
	match room.room_type:
		TowerRoomDatabase.ROOM_BOSS:
			return 1000.0
		TowerRoomDatabase.ROOM_SHRINE:
			return 90.0
		TowerRoomDatabase.ROOM_REST:
			return 20.0 + float(missing_hp) * 0.8
		TowerRoomDatabase.ROOM_FORGE:
			return 60.0
		TowerRoomDatabase.ROOM_MARKET:
			return 55.0 if RunState.gold >= 80 else 28.0
		TowerRoomDatabase.ROOM_OBSERVATORY:
			return 45.0
		TowerRoomDatabase.ROOM_EVENT:
			return 36.0
		TowerRoomDatabase.ROOM_ELITE:
			return 50.0 if hp_ratio >= 0.65 else 12.0
		TowerRoomDatabase.ROOM_BATTLE:
			return 30.0
		_:
			return 0.0


func _incoming_damage(combat) -> int:
	var total := 0
	for enemy in combat.get_living_enemies():
		var action: Dictionary = enemy.get_current_action()
		var action_type := str(action.get("type", ""))
		if action_type == "attack":
			total += int(action.get("amount", 0)) + int(enemy.strength)
		elif action_type == "attack_block":
			total += int(action.get("attack_amount", 0)) + int(enemy.strength)
	return total


func _score_combat_card(card_data: CardData, combat, unprotected: int) -> float:
	var score := 0.0
	var damage_amount := 0
	var strength_amount := 0
	var draw_amount := 0
	var lethal_threat := unprotected >= int(combat.hp) and int(combat.hp) > 0

	for effect in card_data.effects:
		var amount := int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"damage":
				damage_amount = amount + int(combat.strength)
				score += float(damage_amount) * 3.0
			"block":
				if lethal_threat:
					score += float(amount) * 5.0
				elif unprotected > 0:
					score += float(mini(amount, unprotected)) * 2.0
					score += float(maxi(0, amount - unprotected)) * 0.25
				else:
					score += float(amount) * 0.3
			"draw":
				draw_amount += amount
				score += float(amount) * 2.5
			"temp_strength":
				strength_amount += amount
				score += float(amount) * 4.0
			"enemy_burn", "enemy_burn_all":
				score += float(amount) * 2.4
			"heal":
				var missing := maxi(0, RunState.max_hp - int(combat.hp))
				score += float(mini(amount, missing)) * 2.0

	var energy_after := int(combat.energy) - card_data.cost
	if strength_amount > 0:
		if energy_after >= 1:
			score += 25.0
		else:
			score -= 15.0
	elif draw_amount > 0 and energy_after >= 1:
		score += 8.0

	var enemy := _lowest_hp_enemy(combat)
	if enemy != null and damage_amount >= enemy.hp + enemy.block and damage_amount > 0:
		score += 30.0

	return score


func _lowest_hp_enemy(combat) -> EnemyInstance:
	var best: EnemyInstance = null
	for enemy in combat.get_living_enemies():
		var typed: EnemyInstance = enemy
		if best == null or typed.hp < best.hp:
			best = typed
	return best


func _score_event_choice(choice: Dictionary) -> float:
	var score := 1.0
	var missing_hp := maxi(0, RunState.max_hp - RunState.current_hp)
	for effect in choice.get("effects", []):
		if not effect is Dictionary:
			continue
		var amount := int(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"gold":
				score += float(amount) * 0.45
			"gold_cost":
				score -= float(amount) * 0.55
			"heal":
				score += float(mini(amount, missing_hp)) * 1.4
			"damage":
				if amount >= RunState.current_hp:
					score -= 1000.0
				elif RunState.current_hp - amount < int(float(RunState.max_hp) * 0.45):
					score -= float(amount) * 2.4
				else:
					score -= float(amount) * 1.1
			"max_hp":
				score += float(amount) * 4.0
			"add_card":
				score += 12.0
			"add_relic":
				score += 28.0
	return score
