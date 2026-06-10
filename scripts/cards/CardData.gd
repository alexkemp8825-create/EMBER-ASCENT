class_name CardData
extends Resource

var id: String = ""
var display_name: String = ""
var card_type: String = ""
var cost: int = 0
var rarity: String = ""
var description: String = ""
var target_type: String = ""
var effects: Array[Dictionary] = []
var upgraded_id: String = ""


func setup(data: Dictionary) -> CardData:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	card_type = data.get("card_type", "")
	cost = data.get("cost", 0)
	rarity = data.get("rarity", "")
	description = data.get("description", "")
	target_type = data.get("target_type", "")
	effects = data.get("effects", []).duplicate(true)
	upgraded_id = data.get("upgraded_id", "")
	return self


func is_playable() -> bool:
	return cost >= 0 and card_type != "Status"
