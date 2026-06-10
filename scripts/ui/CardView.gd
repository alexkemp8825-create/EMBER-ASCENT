extends PanelContainer

signal play_pressed(card_instance)

@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel
@onready var type_label: Label = %TypeLabel
@onready var description_label: Label = %DescriptionLabel
@onready var play_button: Button = %PlayButton

var card_instance: CardInstance
var card_data: CardData
var _card_database := CardDatabase.new()


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	_refresh()


func set_card_instance(instance: CardInstance) -> void:
	card_instance = instance
	card_data = _card_database.get_card(card_instance.card_id) if card_instance != null else null
	_refresh()


func set_card_data(data: CardData) -> void:
	card_data = data

	if card_data != null and card_instance == null:
		card_instance = CardInstance.new().setup(card_data.id)

	_refresh()


func clear() -> void:
	card_instance = null
	card_data = null
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return

	if card_data == null:
		name_label.text = "Empty"
		cost_label.text = "-"
		type_label.text = ""
		description_label.text = ""
		play_button.disabled = true
		return

	name_label.text = card_data.display_name
	cost_label.text = _format_cost(card_data.cost)
	type_label.text = card_data.card_type
	description_label.text = card_data.description
	play_button.disabled = not card_data.is_playable()


func _format_cost(cost: int) -> String:
	if cost < 0:
		return "-"

	return str(cost)


func _on_play_button_pressed() -> void:
	if card_instance == null or card_data == null or not card_data.is_playable():
		return

	play_pressed.emit(card_instance)
