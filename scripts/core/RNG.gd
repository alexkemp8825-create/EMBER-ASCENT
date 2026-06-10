extends Node

var _generator := RandomNumberGenerator.new()


func _ready() -> void:
	_generator.randomize()


func set_seed(value: Variant) -> void:
	if typeof(value) == TYPE_STRING:
		_generator.seed = hash(value)
	else:
		_generator.seed = int(value)


func rand_int(min_value: int, max_value: int) -> int:
	return _generator.randi_range(min_value, max_value)


func choose(array: Array) -> Variant:
	if array.is_empty():
		return null

	return array[rand_int(0, array.size() - 1)]


func shuffle_array(array: Array) -> Array:
	var shuffled := array.duplicate()

	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := rand_int(0, index)
		var current_value: Variant = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = current_value

	return shuffled
