extends PanelContainer

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")
const ENEMY_VIEW_SCENE := preload("res://scenes/combat/EnemyView.tscn")
const RewardManagerScript := preload("res://scripts/rewards/RewardManager.gd")

@onready var encounter_title: Label = %EncounterTitle
@onready var player_title: Label = %PlayerTitle
@onready var enemies_container: VBoxContainer = %EnemiesContainer
@onready var player_stats_label: Label = %PlayerStatsLabel
@onready var defeat_panel: PanelContainer = %DefeatPanel
@onready var defeat_message_label: Label = %DefeatMessageLabel
@onready var defeat_continue_button: Button = %DefeatContinueButton
@onready var pile_stats_label: Label = %PileStatsLabel
@onready var hand_container: HBoxContainer = %HandContainer
@onready var combat_log_label: Label = %CombatLogLabel
@onready var end_turn_button: Button = %EndTurnButton

var encounter_id: String = "charred_rat"
var _session: CombatSession
var _combat_started := false
var _outcome_handled := false


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	defeat_continue_button.pressed.connect(_on_defeat_continue_pressed)
	defeat_panel.visible = false
	call_deferred("_start_combat")


func set_payload(payload: Dictionary) -> void:
	encounter_id = payload.get("encounter_id", encounter_id)


func _start_combat() -> void:
	if _combat_started:
		return

	_combat_started = true
	_session = CombatSession.new()
	_session.start(encounter_id)
	encounter_title.text = "Encounter: %s" % encounter_id
	player_title.text = _get_player_display_name()
	print("COMBAT START encounter_id=", encounter_id)
	print("ENEMIES SIZE=", _session.enemies.size())
	print("DRAW PILE SIZE=", _session.draw_pile.size())
	print("HAND SIZE=", _session.hand.size())
	_sync_after_action()


func _on_end_turn_pressed() -> void:
	if _session == null or not _session.is_running():
		return
	_session.end_turn()
	_sync_after_action()


func _on_card_play_requested(card_instance: CardInstance) -> void:
	if _session == null or not _session.is_running():
		return
	if not _session.play_card(card_instance):
		_session.combat_log.append("That card cannot be played right now.")
		if _session.combat_log.size() > 12:
			_session.combat_log.pop_front()
	_sync_after_action()


func _on_enemy_target_pressed(enemy_index: int) -> void:
	if _session == null:
		return
	_session.select_enemy(enemy_index)
	_refresh_enemies()


func _on_enemy_view_target_pressed(enemy: EnemyInstance) -> void:
	if _session == null:
		return
	var enemy_index := _session.enemies.find(enemy)
	if enemy_index == -1:
		return
	_on_enemy_target_pressed(enemy_index)


func _sync_after_action() -> void:
	if _outcome_handled or _session == null:
		return
	if _session.is_victory():
		_handle_victory()
		return
	if _session.is_defeat():
		_handle_defeat()
		return
	_refresh_ui()


func _handle_victory() -> void:
	if _outcome_handled:
		return
	_outcome_handled = true
	var reward_payload := RewardManagerScript.build_combat_reward_payload(encounter_id, RunState.current_floor)
	SceneLoader.change_to_rewards(reward_payload)


func _handle_defeat() -> void:
	if _outcome_handled:
		return
	_outcome_handled = true
	end_turn_button.disabled = true
	defeat_message_label.text = "Your embers fade in the tower's silence."
	defeat_panel.visible = true
	_refresh_ui()


func _on_defeat_continue_pressed() -> void:
	SaveManager.delete_save()
	RunState.reset_run()
	SceneLoader.change_to_main_menu()


func _get_player_display_name() -> String:
	var class_database := ClassDatabase.new()
	var class_definition := class_database.get_class_definition(RunState.selected_class)
	return str(class_definition.get("display_name", "Adventurer"))


func _refresh_ui() -> void:
	if _session == null:
		return

	var max_hp := RunState.max_hp if RunState.max_hp > 0 else 75
	player_stats_label.text = "HP: %d/%d\nBlock: %d\nEnergy: %d/%d\nStrength: %d\n%s" % [
		_session.hp,
		max_hp,
		_session.block,
		_session.energy,
		_session.max_energy(),
		_session.strength,
		_format_minions(),
	]
	pile_stats_label.text = "Draw: %d  Hand: %d  Discard: %d  Exhaust: %d" % [
		_session.draw_pile.size(),
		_session.hand.size(),
		_session.discard_pile.size(),
		_session.exhaust_pile.size(),
	]
	_refresh_enemies()
	_refresh_hand()
	_refresh_log()


func _format_minions() -> String:
	var parts: Array[String] = []
	for minion in _session.minions:
		if not minion.is_alive():
			continue
		parts.append("%s %d/%d atk %d" % [minion.display_name, minion.hp, minion.max_hp, minion.attack])

	if parts.is_empty():
		return "Minions: none   Corpses: %d" % RunState.corpses

	return "Minions: %s\nCorpses: %d" % [", ".join(parts), RunState.corpses]


func _refresh_enemies() -> void:
	for child in enemies_container.get_children():
		child.queue_free()

	for enemy_index in range(_session.enemies.size()):
		var enemy := _session.enemies[enemy_index]
		var enemy_view := ENEMY_VIEW_SCENE.instantiate()
		enemies_container.add_child(enemy_view)
		enemy_view.set_enemy(enemy, enemy_index == _session.selected_enemy_index)
		enemy_view.target_pressed.connect(_on_enemy_view_target_pressed)


func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()

	for card_instance in _session.hand:
		var card_view := CARD_VIEW_SCENE.instantiate()
		hand_container.add_child(card_view)
		card_view.set_card_instance(card_instance)
		card_view.play_pressed.connect(_on_card_play_requested)


func _refresh_log() -> void:
	var text := ""
	for index in range(_session.combat_log.size()):
		if index > 0:
			text += "\n"
		text += _session.combat_log[index]
	combat_log_label.text = text
