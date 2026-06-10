extends PanelContainer

const STARTING_ENERGY := 3
const CARDS_DRAWN_PER_TURN := 5
const PLACEHOLDER_STARTER_DECK := [
	"ember_strike",
	"ember_strike",
	"ember_strike",
	"ember_strike",
	"ember_strike",
	"guard_up",
	"guard_up",
	"guard_up",
	"guard_up",
	"burning_oath",
]

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")

@onready var encounter_title: Label = %EncounterTitle
@onready var enemies_container: VBoxContainer = %EnemiesContainer
@onready var player_stats_label: Label = %PlayerStatsLabel
@onready var pile_stats_label: Label = %PileStatsLabel
@onready var hand_container: HBoxContainer = %HandContainer
@onready var combat_log_label: Label = %CombatLogLabel
@onready var end_turn_button: Button = %EndTurnButton

var encounter_id: String = "phase_7_placeholder"

var hp: int = 0
var block: int = 0
var energy: int = STARTING_ENERGY
var strength: int = 0
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []

var _enemies: Array[Dictionary] = []
var _turn_number: int = 0
var _combat_started := false
var _combat_log: Array[String] = []


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	call_deferred("_start_combat")


func set_payload(payload: Dictionary) -> void:
	encounter_id = payload.get("encounter_id", encounter_id)


func _start_combat() -> void:
	if _combat_started:
		return

	_combat_started = true
	encounter_title.text = "Encounter: %s" % encounter_id
	hp = RunState.current_hp if RunState.current_hp > 0 else 75
	block = 0
	energy = STARTING_ENERGY
	strength = 0
	draw_pile = _create_draw_pile()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	_enemies = _create_placeholder_encounter()

	_log("Combat begins.")
	_log("Your deck is shuffled into the draw pile.")
	_start_player_turn()


func _create_draw_pile() -> Array[CardInstance]:
	var source_deck: Array = RunState.deck.duplicate()

	if source_deck.is_empty():
		source_deck = PLACEHOLDER_STARTER_DECK.duplicate()

	var instances: Array[CardInstance] = []
	for card_id in source_deck:
		instances.append(CardInstance.new().setup(str(card_id)))

	return _shuffle_card_instances(instances)


func _create_placeholder_encounter() -> Array[Dictionary]:
	return [
		{
			"id": "phase_7_training_shade",
			"display_name": "Training Shade",
			"hp": 20,
			"max_hp": 20,
			"block": 0,
			"actions": [
				{"type": "attack", "amount": 5},
				{"type": "block", "amount": 4},
			],
			"action_index": 0,
		},
	]


func _start_player_turn() -> void:
	_turn_number += 1
	energy = STARTING_ENERGY
	block = 0
	_draw_cards(CARDS_DRAWN_PER_TURN)
	_log("Turn %d begins. Drew up to %d cards." % [_turn_number, CARDS_DRAWN_PER_TURN])
	_refresh_ui()


func _draw_cards(amount: int) -> void:
	for _index in range(amount):
		if draw_pile.is_empty():
			_refill_draw_pile_from_discard()

		if draw_pile.is_empty():
			return

		hand.append(draw_pile.pop_back())


func _refill_draw_pile_from_discard() -> void:
	if discard_pile.is_empty():
		return

	draw_pile = _shuffle_card_instances(discard_pile)
	discard_pile.clear()
	_log("Discard pile shuffled into draw pile.")


func _on_end_turn_pressed() -> void:
	_log("Player ends the turn.")
	_discard_hand()
	_resolve_enemy_turn()

	if _is_defeated():
		_handle_defeat()
		return

	_choose_next_enemy_intents()
	_start_player_turn()


func _discard_hand() -> void:
	for card_instance in hand:
		discard_pile.append(card_instance)

	hand.clear()


func _resolve_enemy_turn() -> void:
	for enemy in _enemies:
		if enemy.get("hp", 0) <= 0:
			continue

		var action := _get_enemy_action(enemy)
		match action.get("type", ""):
			"attack":
				_resolve_enemy_attack(enemy, int(action.get("amount", 0)))
			"block":
				var block_amount := int(action.get("amount", 0))
				enemy["block"] = int(enemy.get("block", 0)) + block_amount
				_log("%s gains %d block." % [enemy.get("display_name", "Enemy"), block_amount])
			_:
				_log("%s hesitates." % enemy.get("display_name", "Enemy"))


func _resolve_enemy_attack(enemy: Dictionary, amount: int) -> void:
	var blocked_damage: int = min(block, amount)
	var damage: int = amount - blocked_damage
	block -= blocked_damage
	hp -= damage
	_log("%s attacks for %d. Block absorbs %d. You take %d damage." % [
		enemy.get("display_name", "Enemy"),
		amount,
		blocked_damage,
		damage,
	])


func _choose_next_enemy_intents() -> void:
	for enemy in _enemies:
		var action_count: int = enemy.get("actions", []).size()
		if action_count <= 0:
			continue

		enemy["action_index"] = (int(enemy.get("action_index", 0)) + 1) % action_count


func _get_enemy_action(enemy: Dictionary) -> Dictionary:
	var actions: Array = enemy.get("actions", [])
	if actions.is_empty():
		return {}

	return actions[int(enemy.get("action_index", 0))]


func _shuffle_card_instances(cards: Array[CardInstance]) -> Array[CardInstance]:
	var shuffled: Array = RNG.shuffle_array(cards)
	var typed_cards: Array[CardInstance] = []

	for card in shuffled:
		typed_cards.append(card)

	return typed_cards


func _on_card_play_requested(card_instance: CardInstance) -> void:
	_log("Selected %s. Card effects arrive in Phase 8." % card_instance.card_id)


func _is_defeated() -> bool:
	return hp <= 0


func _are_all_enemies_defeated() -> bool:
	for enemy in _enemies:
		if enemy.get("hp", 0) > 0:
			return false

	return true


func _handle_victory() -> void:
	RunState.current_hp = max(hp, 1)
	_log("Victory.")
	SceneLoader.change_to_rewards({})


func _handle_defeat() -> void:
	_log("Defeat.")
	SceneLoader.change_to_main_menu()


func _refresh_ui() -> void:
	if _are_all_enemies_defeated():
		_handle_victory()
		return

	player_stats_label.text = "HP: %d/%d\nBlock: %d\nEnergy: %d/%d\nStrength: %d" % [
		hp,
		RunState.max_hp if RunState.max_hp > 0 else 75,
		block,
		energy,
		STARTING_ENERGY,
		strength,
	]
	pile_stats_label.text = "Draw: %d  Hand: %d  Discard: %d  Exhaust: %d" % [
		draw_pile.size(),
		hand.size(),
		discard_pile.size(),
		exhaust_pile.size(),
	]
	_refresh_enemies()
	_refresh_hand()
	_refresh_log()


func _refresh_enemies() -> void:
	for child in enemies_container.get_children():
		child.queue_free()

	for enemy in _enemies:
		var action := _get_enemy_action(enemy)
		var enemy_label := Label.new()
		enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		enemy_label.text = "%s\nHP: %d/%d  Block: %d\nIntent: %s" % [
			enemy.get("display_name", "Enemy"),
			enemy.get("hp", 0),
			enemy.get("max_hp", 0),
			enemy.get("block", 0),
			_format_intent(action),
		]
		enemies_container.add_child(enemy_label)


func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()

	for card_instance in hand:
		var card_view := CARD_VIEW_SCENE.instantiate()
		hand_container.add_child(card_view)
		card_view.set_card_instance(card_instance)
		card_view.play_pressed.connect(_on_card_play_requested)


func _refresh_log() -> void:
	combat_log_label.text = "\n".join(_combat_log)


func _format_intent(action: Dictionary) -> String:
	match action.get("type", ""):
		"attack":
			return "Attack %d" % action.get("amount", 0)
		"block":
			return "Defend %d" % action.get("amount", 0)
		_:
			return "Unknown"


func _log(message: String) -> void:
	_combat_log.append(message)
	if _combat_log.size() > 12:
		_combat_log.pop_front()

	if is_node_ready():
		_refresh_log()
