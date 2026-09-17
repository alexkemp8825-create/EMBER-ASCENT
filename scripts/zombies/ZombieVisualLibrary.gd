extends Node

## Registers every zombie visual variant and picks one with weighted randomness.
## Empty region allow-lists fall back to this global pool.

const VARIANT_ORDER := [
	"office",
	"punk",
	"nurse",
	"forest",
	"pirate",
	"chef",
	"builder",
	"sleeping",
]

const VARIANT_DEFINITIONS := {
	"office": {
		"id": "office",
		"display_name": "Office",
		"spawn_weight": 1.0,
		"head_path": "res://assets/zombies/parts/office/head.png",
		"body_path": "res://assets/zombies/parts/office/body.png",
		"left_hand_path": "res://assets/zombies/parts/office/left_hand.png",
		"right_hand_path": "res://assets/zombies/parts/office/right_hand.png",
		"left_foot_path": "res://assets/zombies/parts/office/left_foot.png",
		"right_foot_path": "res://assets/zombies/parts/office/right_foot.png",
		"head_pivot": Vector2(153, 139),
	},
	"punk": {
		"id": "punk",
		"display_name": "Punk",
		"spawn_weight": 1.0,
		"head_path": "res://assets/zombies/parts/punk/head.png",
		"body_path": "res://assets/zombies/parts/punk/body.png",
		"left_hand_path": "res://assets/zombies/parts/punk/left_hand.png",
		"right_hand_path": "res://assets/zombies/parts/punk/right_hand.png",
		"left_foot_path": "res://assets/zombies/parts/punk/left_foot.png",
		"right_foot_path": "res://assets/zombies/parts/punk/right_foot.png",
		"head_pivot": Vector2(148, 194),
	},
	"nurse": {
		"id": "nurse",
		"display_name": "Nurse",
		"spawn_weight": 1.0,
		"head_path": "res://assets/zombies/parts/nurse/head.png",
		"body_path": "res://assets/zombies/parts/nurse/body.png",
		"left_hand_path": "res://assets/zombies/parts/nurse/left_hand.png",
		"right_hand_path": "res://assets/zombies/parts/nurse/right_hand.png",
		"left_foot_path": "res://assets/zombies/parts/nurse/left_foot.png",
		"right_foot_path": "res://assets/zombies/parts/nurse/right_foot.png",
		"head_pivot": Vector2(144, 150),
	},
	"forest": {
		"id": "forest",
		"display_name": "Forest",
		"spawn_weight": 1.0,
		"head_path": "res://assets/zombies/parts/forest/head.png",
		"body_path": "res://assets/zombies/parts/forest/body.png",
		"left_hand_path": "res://assets/zombies/parts/forest/left_hand.png",
		"right_hand_path": "res://assets/zombies/parts/forest/right_hand.png",
		"left_foot_path": "res://assets/zombies/parts/forest/left_foot.png",
		"right_foot_path": "res://assets/zombies/parts/forest/right_foot.png",
		"head_pivot": Vector2(152, 185),
	},
	"pirate": {
		"id": "pirate",
		"display_name": "Pirate",
		"spawn_weight": 1.0,
		"head_path": "res://assets/zombies/parts/pirate/head.png",
		"body_path": "res://assets/zombies/parts/pirate/body.png",
		"left_hand_path": "res://assets/zombies/parts/pirate/left_hand.png",
		"right_hand_path": "res://assets/zombies/parts/pirate/right_hand.png",
		"left_foot_path": "res://assets/zombies/parts/pirate/left_foot.png",
		"right_foot_path": "res://assets/zombies/parts/pirate/right_foot.png",
		"head_pivot": Vector2(190, 160),
	},
	"chef": {
		"id": "chef",
		"display_name": "Chef",
		"spawn_weight": 1.0,
		"head_path": "res://assets/zombies/parts/chef/head.png",
		"body_path": "res://assets/zombies/parts/chef/body.png",
		"left_hand_path": "res://assets/zombies/parts/chef/left_hand.png",
		"right_hand_path": "res://assets/zombies/parts/chef/right_hand.png",
		"left_foot_path": "res://assets/zombies/parts/chef/left_foot.png",
		"right_foot_path": "res://assets/zombies/parts/chef/right_foot.png",
		"head_pivot": Vector2(154, 204),
	},
	"builder": {
		"id": "builder",
		"display_name": "Builder",
		"spawn_weight": 1.0,
		"head_path": "res://assets/zombies/parts/builder/head.png",
		"body_path": "res://assets/zombies/parts/builder/body.png",
		"left_hand_path": "res://assets/zombies/parts/builder/left_hand.png",
		"right_hand_path": "res://assets/zombies/parts/builder/right_hand.png",
		"left_foot_path": "res://assets/zombies/parts/builder/left_foot.png",
		"right_foot_path": "res://assets/zombies/parts/builder/right_foot.png",
		"head_pivot": Vector2(164, 182),
	},
	"sleeping": {
		"id": "sleeping",
		"display_name": "Sleeping",
		"spawn_weight": 1.0,
		"head_path": "res://assets/zombies/parts/sleeping/head.png",
		"body_path": "res://assets/zombies/parts/sleeping/body.png",
		"left_hand_path": "res://assets/zombies/parts/sleeping/left_hand.png",
		"right_hand_path": "res://assets/zombies/parts/sleeping/right_hand.png",
		"left_foot_path": "res://assets/zombies/parts/sleeping/left_foot.png",
		"right_foot_path": "res://assets/zombies/parts/sleeping/right_foot.png",
		"head_pivot": Vector2(195, 177),
	},
}

var _variants: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_variants.clear()
	for variant_id in VARIANT_ORDER:
		var definition: Dictionary = VARIANT_DEFINITIONS[variant_id]
		_variants[variant_id] = ZombieVisualVariantData.new().setup(definition)


func get_variant(variant_id: String) -> ZombieVisualVariantData:
	if _variants.is_empty():
		reload()
	return _variants.get(variant_id)


func get_registered_ids() -> PackedStringArray:
	return PackedStringArray(VARIANT_ORDER)


func get_variants(allowed_ids: PackedStringArray = PackedStringArray()) -> Array:
	if _variants.is_empty():
		reload()
	var pool: Array = []
	if allowed_ids.is_empty():
		for variant_id in VARIANT_ORDER:
			var variant: ZombieVisualVariantData = _variants.get(variant_id)
			if variant != null:
				pool.append(variant)
		return pool
	for variant_id in allowed_ids:
		var variant: ZombieVisualVariantData = _variants.get(variant_id)
		if variant != null:
			pool.append(variant)
	return pool


func pick_variant_id(allowed_ids: PackedStringArray = PackedStringArray()) -> String:
	var variant := pick_variant(allowed_ids)
	if variant == null:
		return "office"
	return variant.id


func pick_variant(allowed_ids: PackedStringArray = PackedStringArray()) -> ZombieVisualVariantData:
	var pool := get_variants(allowed_ids)
	if pool.is_empty():
		push_warning("ZombieVisualLibrary has no variants for allow-list %s" % [allowed_ids])
		return get_variant("office")

	var total_weight := 0.0
	for item in pool:
		var variant: ZombieVisualVariantData = item
		total_weight += max(variant.spawn_weight, 0.0)
	if total_weight <= 0.0:
		return pool[0]

	var roll := _randf() * total_weight
	var running := 0.0
	for item in pool:
		var variant: ZombieVisualVariantData = item
		running += max(variant.spawn_weight, 0.0)
		if roll <= running:
			return variant
	return pool[pool.size() - 1]


func _randf() -> float:
	var rng := get_node_or_null("/root/RNG")
	if rng != null and rng.has_method("rand_int"):
		return float(rng.rand_int(0, 1_000_000)) / 1_000_000.0
	return randf()
