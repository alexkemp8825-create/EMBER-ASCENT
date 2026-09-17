extends SceneTree

## Headless checks for the shared zombie visual-variant stack.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	var library: Node = root.get_node_or_null("ZombieVisualLibrary")
	if library == null:
		library = load("res://scripts/zombies/ZombieVisualLibrary.gd").new()
		root.add_child(library)
		if library.has_method("reload"):
			library.reload()
	failed += _expect(library != null, "ZombieVisualLibrary available")
	if library.has_method("reload"):
		library.reload()

	var ids: PackedStringArray = library.get_registered_ids()
	failed += _expect(ids.size() == 8, "eight registered variants, got %s" % ids.size())

	var seen := {}
	for _i in 80:
		seen[library.pick_variant_id()] = true
	failed += _expect(seen.size() == 8, "weighted pick should hit every variant, got %s" % seen.size())

	for variant_id in ids:
		var variant = library.get_variant(variant_id)
		failed += _expect(variant != null, "%s resource exists" % variant_id)
		if variant != null:
			failed += _expect(variant.has_required_sprites(), "%s has required sprites" % variant_id)
			failed += _expect(variant.spawn_weight == 1.0, "%s weight is 1" % variant_id)

	var scene := load("res://scenes/zombies/Zombie.tscn") as PackedScene
	failed += _expect(scene != null, "Zombie.tscn loads")
	var holder := Node2D.new()
	holder.name = "ValidateRoot"
	root.add_child(holder)

	for variant_id in ids:
		var zombie = scene.instantiate()
		holder.add_child(zombie)
		if zombie.has_method("setup"):
			zombie.setup(variant_id)
		failed += _expect(zombie.visual_variant_id == variant_id, "%s id applied" % variant_id)
		var visual = zombie.get_node_or_null("Visual")
		failed += _expect(visual != null and visual.active_variant != null, "%s visual assigned" % variant_id)
		if visual != null:
			var head: Sprite2D = visual.get_node_or_null("Head")
			var body: Sprite2D = visual.get_node_or_null("Body")
			var left_hand: Sprite2D = visual.get_node_or_null("LeftHand")
			failed += _expect(head != null and head.texture != null, "%s head texture" % variant_id)
			failed += _expect(body != null and body.texture != null, "%s body texture" % variant_id)
			failed += _expect(left_hand != null and left_hand.texture != null, "%s left hand" % variant_id)
			if head != null:
				failed += _expect(head.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s nearest filter" % variant_id)
		if zombie.has_method("play_state"):
			zombie.play_state("walk")
			zombie.play_state("attack")
		if zombie.has_method("die"):
			zombie.die()
		failed += _expect(zombie.corpse_visual_variant_id == variant_id, "%s corpse keeps id" % variant_id)
		if zombie.has_method("resurrect"):
			zombie.resurrect()
		failed += _expect(zombie.visual_variant_id == variant_id, "%s resurrect keeps id" % variant_id)
		failed += _expect(not zombie.is_corpse, "%s resurrect clears corpse" % variant_id)
		zombie.queue_free()

	var allowed := PackedStringArray(["chef", "nurse"])
	var restricted := {}
	for _i in 20:
		restricted[library.pick_variant_id(allowed)] = true
	failed += _expect(restricted.size() <= 2, "region allow-list leaked: %s" % str(restricted.keys()))
	failed += _expect(restricted.has("chef") or restricted.has("nurse"), "region allow-list produced a valid id")

	var gallery_spawner: Node = load("res://scripts/zombies/ZombieSpawner.gd").new()
	holder.add_child(gallery_spawner)
	var gallery: Array = gallery_spawner.spawn_gallery(Vector2(100, 200), 160.0)
	failed += _expect(gallery.size() == 8, "F9-style gallery spawns 8 zombies, got %s" % gallery.size())
	var gallery_ids := {}
	for item in gallery:
		gallery_ids[item.visual_variant_id] = true
	failed += _expect(gallery_ids.size() == 8, "gallery contains every variant")

	if failed == 0:
		print("GODOT_VALIDATE_OK")
		quit(0)
	else:
		print("GODOT_VALIDATE_FAILED %d" % failed)
		quit(1)


func _expect(condition: bool, message: String) -> int:
	if condition:
		print("  ok  ", message)
		return 0
	print("  FAIL ", message)
	return 1
