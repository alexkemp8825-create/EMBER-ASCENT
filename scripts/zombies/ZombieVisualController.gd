class_name ZombieVisualController
extends Node2D

## Swaps Sprite2D textures on the shared zombie skeleton.
## Animation continues to move these same child nodes.

const SLOT_NODE_NAMES := {
	ZombieLimbSlots.HEAD: "Head",
	ZombieLimbSlots.BODY: "Body",
	ZombieLimbSlots.LEFT_HAND: "LeftHand",
	ZombieLimbSlots.RIGHT_HAND: "RightHand",
	ZombieLimbSlots.LEFT_FOOT: "LeftFoot",
	ZombieLimbSlots.RIGHT_FOOT: "RightFoot",
	ZombieLimbSlots.ACCESSORY: "Head/Accessory",
	ZombieLimbSlots.BACK_ACCESSORY: "BackAccessory",
}

var active_variant: ZombieVisualVariantData
var _mutation_limbs: Dictionary = {}
var _equipped_limbs: Dictionary = {}
var _rest_positions: Dictionary = {}


func cache_rest_poses() -> void:
	for slot in SLOT_NODE_NAMES:
		var sprite := get_slot_sprite(slot)
		if sprite != null:
			_rest_positions[slot] = sprite.position


func apply_variant(variant: ZombieVisualVariantData) -> void:
	active_variant = variant
	if variant == null:
		return
	modulate = variant.tint
	_refresh_all_slots()


func apply_variant_id(variant_id: String) -> void:
	var library := _library()
	if library == null:
		push_error("ZombieVisualLibrary autoload is missing.")
		return
	apply_variant(library.get_variant(variant_id))


func set_mutation_limb(slot: int, texture: Texture2D) -> void:
	if texture == null:
		_mutation_limbs.erase(slot)
	else:
		_mutation_limbs[slot] = texture
	_refresh_slot(slot)


func set_equipped_limb(slot: int, texture: Texture2D) -> void:
	if texture == null:
		_equipped_limbs.erase(slot)
	else:
		_equipped_limbs[slot] = texture
	_refresh_slot(slot)


func clear_limb_overrides() -> void:
	_mutation_limbs.clear()
	_equipped_limbs.clear()
	_refresh_all_slots()


func get_limb_texture(slot: int) -> Texture2D:
	if _mutation_limbs.has(slot) and _mutation_limbs[slot] != null:
		return _mutation_limbs[slot]
	if _equipped_limbs.has(slot) and _equipped_limbs[slot] != null:
		return _equipped_limbs[slot]
	if active_variant != null:
		return active_variant.get_slot_texture(slot)
	return null


func get_slot_sprite(slot: int) -> Sprite2D:
	var node_name: String = SLOT_NODE_NAMES.get(slot, "")
	if node_name.is_empty():
		return null
	return get_node_or_null(node_name) as Sprite2D


func _refresh_all_slots() -> void:
	for slot in SLOT_NODE_NAMES:
		_refresh_slot(slot)


func _refresh_slot(slot: int) -> void:
	var sprite := get_slot_sprite(slot)
	if sprite == null:
		return
	var texture := get_limb_texture(slot)
	_configure_pixel_sprite(sprite, texture, slot)
	if _rest_positions.has(slot) and active_variant != null:
		sprite.position = _rest_positions[slot] + active_variant.get_slot_offset(slot)
	elif active_variant != null:
		sprite.position = sprite.position
	if slot == ZombieLimbSlots.HEAD and active_variant != null:
		sprite.scale = active_variant.head_scale


func _configure_pixel_sprite(sprite: Sprite2D, texture: Texture2D, slot: int) -> void:
	sprite.texture = texture
	sprite.visible = texture != null
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var pivot := _pivot_for_slot(sprite, slot, texture)
	sprite.offset = -pivot


func _pivot_for_slot(sprite: Sprite2D, slot: int, texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	if slot == ZombieLimbSlots.HEAD and active_variant != null and active_variant.head_pivot != Vector2.ZERO:
		return active_variant.head_pivot
	if slot == ZombieLimbSlots.ACCESSORY and active_variant != null and active_variant.accessory_pivot != Vector2.ZERO:
		return active_variant.accessory_pivot
	return texture.get_size() * 0.5


func _library() -> Node:
	return get_node_or_null("/root/ZombieVisualLibrary")
