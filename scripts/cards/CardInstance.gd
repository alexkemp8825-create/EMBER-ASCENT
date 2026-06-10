class_name CardInstance
extends Resource

var card_id: String = ""
var upgraded: bool = false
var temporary: bool = false


func setup(id: String, is_upgraded: bool = false, is_temporary: bool = false) -> CardInstance:
	card_id = id
	upgraded = is_upgraded
	temporary = is_temporary
	return self


func duplicate_instance() -> CardInstance:
	return CardInstance.new().setup(card_id, upgraded, temporary)
