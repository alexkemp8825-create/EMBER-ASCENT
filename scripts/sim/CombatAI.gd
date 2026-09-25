class_name CombatAI
extends RefCounted

## Greedy combat policy used by the run simulator.
## It reuses CombatSession, so upgrade hooks match the real fight.

const Database := preload("res://scripts/rewards/RunUpgradeDatabase.gd")

var _cards := CardDatabase.new()


func fight(encounter_id: String) -> bool:
	var session := CombatSession.new()
	session.start(encounter_id)
	var guard := 0
	while session.is_running() and guard < 30:
		guard += 1
		_play_turn(session)
	return session.is_victory()


func _play_turn(session: CombatSession) -> void:
	var safety := 0
	while session.is_running() and safety < 16:
		safety += 1
		session.focus_lowest_hp_enemy()
		var incoming := session.get_incoming_damage()
		var best_card: CardInstance = null
		var best_score := 0
		for card_instance in session.hand:
			var score := _score_card(session, card_instance, incoming)
			if score > best_score:
				best_score = score
				best_card = card_instance
		if best_card == null:
			break
		if not session.play_card(best_card):
			break

	if session.is_running():
		session.end_turn()


func _score_card(session: CombatSession, card_instance: CardInstance, incoming: int) -> int:
	var card_data := _cards.get_card(card_instance.card_id)
	if card_data == null or not card_data.is_playable():
		return 0
	if session.get_play_cost(card_data) > session.energy:
		return 0

	var score := 0
	var attack_bonus := session.attack_bonus_for(card_data)
	for effect in card_data.effects:
		match str(effect.get("type", "")):
			"damage":
				var damage := int(effect.get("amount", 0)) + session.strength + attack_bonus
				score += damage * 3
				if _is_lethal(session, damage):
					score += 22
			"block":
				var amount := int(effect.get("amount", 0))
				var needed := maxi(0, incoming - session.block)
				score += mini(amount, needed) * 3
				if needed <= 0:
					score += 1
					if int(RunState.upgrade_stacks.get("hold_the_line", 0)) > 0:
						score += 2
			"draw":
				score += int(effect.get("amount", 0)) * 4
			"temp_strength":
				var later_attacks := _other_attack_count(session, card_instance)
				score += int(effect.get("amount", 0)) * 4 * maxi(1, later_attacks)
			"heal":
				var missing := maxi(0, RunState.max_hp - session.hp)
				score += mini(int(effect.get("amount", 0)), missing) * 2
			"enemy_burn", "enemy_burn_all":
				var burn := int(effect.get("amount", 0))
				var targets := 1
				if str(effect.get("type", "")) == "enemy_burn_all":
					targets = maxi(1, _living_enemies(session))
				score += burn * 3 * targets
			_:
				pass

	return score


func _is_lethal(session: CombatSession, damage: int) -> bool:
	if session.selected_enemy_index < 0 or session.selected_enemy_index >= session.enemies.size():
		return false
	var enemy := session.enemies[session.selected_enemy_index]
	if not enemy.is_alive():
		return false
	return damage > enemy.block and (damage - enemy.block) >= enemy.hp


func _other_attack_count(session: CombatSession, except_card: CardInstance) -> int:
	var count := 0
	for card_instance in session.hand:
		if card_instance == except_card:
			continue
		var card_data := _cards.get_card(card_instance.card_id)
		if card_data != null and card_data.card_type == "Attack":
			count += 1
	return count


func _living_enemies(session: CombatSession) -> int:
	var count := 0
	for enemy in session.enemies:
		if enemy.is_alive():
			count += 1
	return count
