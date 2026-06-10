extends PanelContainer

signal target_pressed(enemy_instance)

@onready var name_label: Label = %NameLabel
@onready var hp_label: Label = %HPLabel
@onready var block_label: Label = %BlockLabel
@onready var intent_label: Label = %IntentLabel
@onready var target_button: Button = %TargetButton

var enemy: EnemyInstance
var selected: bool = false


func _ready() -> void:
	target_button.pressed.connect(_on_target_button_pressed)
	_refresh()


func set_enemy(enemy_instance: EnemyInstance, is_selected: bool = false) -> void:
	enemy = enemy_instance
	selected = is_selected
	_refresh()


func set_selected(is_selected: bool) -> void:
	selected = is_selected
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return

	if enemy == null:
		name_label.text = "Unknown Enemy"
		hp_label.text = "HP: -"
		block_label.text = "Block: -"
		intent_label.text = "Intent: -"
		target_button.disabled = true
		return

	name_label.text = "%s%s" % ["> " if selected else "", enemy.display_name]
	hp_label.text = "HP: %d/%d" % [enemy.hp, enemy.max_hp]
	if enemy.burn_stacks > 0:
		block_label.text = "Block: %d  |  Burn: %d" % [enemy.block, enemy.burn_stacks]
	else:
		block_label.text = "Block: %d" % enemy.block
	intent_label.text = "Intent: %s" % _format_intent(enemy.get_current_action())
	target_button.disabled = not enemy.is_alive()


func _format_intent(action: Dictionary) -> String:
	match action.get("type", ""):
		"attack":
			return "Attack %d" % (int(action.get("amount", 0)) + enemy.strength)
		"block":
			return "Defend %d" % int(action.get("amount", 0))
		"buff_strength":
			return "Gain %d Strength" % int(action.get("amount", 0))
		"add_burn":
			return "Add Burn"
		"attack_block":
			return "Attack %d + Defend %d" % [
				int(action.get("attack_amount", 0)) + enemy.strength,
				int(action.get("block_amount", 0)),
			]
		"big_attack_warning":
			return "Charging"
		_:
			return "Unknown"


func _on_target_button_pressed() -> void:
	if enemy == null or not enemy.is_alive():
		return

	target_pressed.emit(enemy)
