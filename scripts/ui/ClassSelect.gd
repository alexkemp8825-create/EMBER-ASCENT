extends PanelContainer

const ASH_KNIGHT_ID := "ash_knight"
const ASH_KNIGHT_MAX_HP := 75
const ASH_KNIGHT_STARTING_GOLD := 99
const ASH_KNIGHT_STARTER_RELIC := "cracked_helm"
const ASH_KNIGHT_STARTER_DECK := [
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

@onready var ash_knight_button: Button = %AshKnightButton
@onready var cinder_witch_button: Button = %CinderWitchButton
@onready var glass_monk_button: Button = %GlassMonkButton
@onready var root_warden_button: Button = %RootWardenButton
@onready var chain_prophet_button: Button = %ChainProphetButton
@onready var hollow_thief_button: Button = %HollowThiefButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	ash_knight_button.pressed.connect(_on_ash_knight_pressed)
	_disable_coming_soon_buttons()


func _disable_coming_soon_buttons() -> void:
	var coming_soon_buttons: Array[Button] = [
		cinder_witch_button,
		glass_monk_button,
		root_warden_button,
		chain_prophet_button,
		hollow_thief_button,
	]

	for button in coming_soon_buttons:
		button.disabled = true
		button.tooltip_text = "Coming Soon"


func _on_ash_knight_pressed() -> void:
	_start_ash_knight_run()
	status_label.text = "Ash Knight selected. Entering The Ember Spire..."
	SceneLoader.change_to_map()


func _start_ash_knight_run() -> void:
	RunState.reset_run()
	RunState.selected_class = ASH_KNIGHT_ID
	RunState.max_hp = ASH_KNIGHT_MAX_HP
	RunState.current_hp = ASH_KNIGHT_MAX_HP
	RunState.gold = ASH_KNIGHT_STARTING_GOLD
	RunState.current_act = 1
	RunState.current_floor = 0
	RunState.current_node_id = ""
	RunState.run_seed = int(Time.get_unix_time_from_system())

	RunState.deck.clear()
	for card_id in ASH_KNIGHT_STARTER_DECK:
		RunState.deck.append(card_id)

	RunState.relics.clear()
	RunState.relics.append(ASH_KNIGHT_STARTER_RELIC)

	RNG.set_seed(RunState.run_seed)
	RunState.map_data = _create_phase_four_map()
	RunState.completed_nodes.clear()


func _create_phase_four_map() -> Array:
	return [
		{
			"id": "floor_0_battle_0",
			"floor": 0,
			"type": "battle",
			"connected_to": [],
			"available": true,
		},
	]
