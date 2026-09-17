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


func weighted_choice(items: Array, weights: Array) -> Variant:
	if items.is_empty():
		return null

	var total := 0.0
	for weight in weights:
		total += max(float(weight), 0.0)
	if total <= 0.0:
		return choose(items)

	var roll := _generator.randf() * total
	var running := 0.0
	for index in items.size():
		var weight := 1.0
		if index < weights.size():
			weight = max(float(weights[index]), 0.0)
		running += weight
		if roll <= running:
			return items[index]
	return items[items.size() - 1]


func shuffle_array(array: Array) -> Array:
	var shuffled := array.duplicate()

	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := rand_int(0, index)
		var current_value: Variant = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = current_value

	return shuffled
