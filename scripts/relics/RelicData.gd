class_name RelicData
extends Resource

var id: String = ""
var display_name: String = ""
var description: String = ""
var rarity: String = ""


func setup(data: Dictionary) -> RelicData:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	description = data.get("description", "")
	rarity = data.get("rarity", "")
	return self
