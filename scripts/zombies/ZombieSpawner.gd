class_name ZombieSpawner
extends Node2D

## Spawns the single shared zombie scene and applies a visual variant.
## Do not maintain one PackedScene per costume.

const ZOMBIE_SCENE := preload("res://scenes/zombies/Zombie.tscn")

@export var region: Node
@export var spawn_parent: NodePath
@export var gallery_spacing: float = 140.0


func spawn_random(at: Vector2 = Vector2.ZERO, allowed_ids: PackedStringArray = PackedStringArray()) -> ZombieUnit:
	var resolved := allowed_ids if not allowed_ids.is_empty() else _region_allow_list()
	var variant_id := _library_pick(resolved)
	return spawn_variant(variant_id, at)


func spawn_variant(variant_id: String, at: Vector2 = Vector2.ZERO) -> ZombieUnit:
	var zombie := ZOMBIE_SCENE.instantiate() as ZombieUnit
	if zombie == null:
		push_error("Zombie.tscn did not instantiate as ZombieUnit.")
		return null
	_parent_for_spawn().add_child(zombie)
	zombie.global_position = at
	zombie.setup(variant_id)
	return zombie


func spawn_gallery(origin: Vector2 = Vector2.ZERO, spacing: float = -1.0) -> Array:
	if spacing <= 0.0:
		spacing = gallery_spacing
	var spawned: Array = []
	var library := get_node_or_null("/root/ZombieVisualLibrary")
	var ids: PackedStringArray = PackedStringArray()
	if library != null and library.has_method("get_registered_ids"):
		ids = library.get_registered_ids()
	else:
		ids = PackedStringArray(["office", "punk", "nurse", "forest", "pirate", "chef", "builder", "sleeping"])
	var index := 0
	for variant_id in ids:
		var zombie := spawn_variant(variant_id, origin + Vector2(spacing * index, 0))
		if zombie != null:
			zombie.play_state("walk")
			spawned.append(zombie)
		index += 1
	return spawned


func _region_allow_list() -> PackedStringArray:
	var source := region
	if source == null:
		source = _find_region()
	if source != null and source.has_method("get_allowed_visual_variants"):
		return source.get_allowed_visual_variants()
	if source != null and "allowed_visual_variants" in source:
		return source.allowed_visual_variants
	return PackedStringArray()


func _find_region() -> Node:
	var current: Node = self
	while current != null:
		if current is EncounterRegion:
			return current
		current = current.get_parent()
	return null


func _parent_for_spawn() -> Node:
	if spawn_parent != NodePath():
		var node := get_node_or_null(spawn_parent)
		if node != null:
			return node
	return self


func _library_pick(allowed_ids: PackedStringArray) -> String:
	var library := get_node_or_null("/root/ZombieVisualLibrary")
	if library != null and library.has_method("pick_variant_id"):
		return library.pick_variant_id(allowed_ids)
	return "office"
