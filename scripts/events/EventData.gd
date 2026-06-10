class_name EventData
extends Resource

var id: String = ""
var title: String = ""
var description: String = ""
var choices: Array[Dictionary] = []


func setup(data: Dictionary) -> EventData:
	id = data.get("id", "")
	title = data.get("title", "")
	description = data.get("description", "")
	choices.clear()
	for choice in data.get("choices", []):
		if choice is Dictionary:
			choices.append(choice)
	return self


func get_choice(choice_id: String) -> Dictionary:
	for choice in choices:
		if str(choice.get("id", "")) == choice_id:
			return choice

	return {}
