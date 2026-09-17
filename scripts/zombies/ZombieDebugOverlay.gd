extends CanvasLayer

## F8 toggles variant name labels. F9 spawns one of every registered look.

const GALLERY_KEY := KEY_F9
const OVERLAY_KEY := KEY_F8

var overlay_visible: bool = false
var _gallery: Array = []
var _status: Label
var _spawner: ZombieSpawner
var _gallery_root: Node2D


func _ready() -> void:
	layer = 80
	_status = Label.new()
	_status.name = "ZombieDebugStatus"
	_status.visible = false
	_status.position = Vector2(16, 16)
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color(1, 0.92, 0.55, 1))
	add_child(_status)
	_gallery_root = Node2D.new()
	_gallery_root.name = "ZombieGalleryRoot"
	add_child(_gallery_root)
	_spawner = ZombieSpawner.new()
	_spawner.name = "DebugZombieSpawner"
	add_child(_spawner)
	_spawner.spawn_parent = _gallery_root.get_path()
	_refresh_overlay()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == OVERLAY_KEY:
		overlay_visible = not overlay_visible
		_refresh_overlay()
		get_viewport().set_input_as_handled()
	elif event.keycode == GALLERY_KEY:
		_spawn_gallery()
		get_viewport().set_input_as_handled()


func _spawn_gallery() -> void:
	for zombie in _gallery:
		if is_instance_valid(zombie):
			zombie.queue_free()
	_gallery.clear()
	var viewport_size := get_viewport().get_visible_rect().size
	var origin := Vector2(140, viewport_size.y - 160)
	_gallery = _spawner.spawn_gallery(origin, 160.0)
	overlay_visible = true
	_refresh_overlay()


func _refresh_overlay() -> void:
	for zombie in _collect_zombies():
		var label := zombie.get_node_or_null("DebugLabel") as Label
		if label != null:
			label.visible = overlay_visible
			if overlay_visible and zombie.has_method("get_variant_display_name"):
				label.text = "Variant: %s" % zombie.get_variant_display_name()
	if overlay_visible:
		_status.visible = true
		_status.text = "Zombie debug  F8 overlay  F9 gallery\n%s" % _status_lines()
	else:
		_status.visible = false


func _status_lines() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for zombie in _collect_zombies():
		if zombie.has_method("get_variant_display_name"):
			lines.append("Variant: %s" % zombie.get_variant_display_name())
	if lines.is_empty():
		return "No zombies. Press F9 to spawn every visual variant."
	return "\n".join(lines)


func _collect_zombies() -> Array:
	var found: Array = []
	var tree := get_tree()
	if tree == null:
		return found
	for node in tree.get_nodes_in_group("zombie_units"):
		if is_instance_valid(node):
			found.append(node)
	# Gallery zombies may not have been grouped yet if the scene predates the group.
	for child in _gallery_root.get_children():
		if child is ZombieUnit and child not in found:
			found.append(child)
	return found
