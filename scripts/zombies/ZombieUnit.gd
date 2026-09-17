class_name ZombieUnit
extends CharacterBody2D

## Shared zombie archetype. Visual variants only change sprites.

signal died(zombie)
signal resurrected(zombie)

const DEFAULT_VARIANT := "office"

@onready var visual: ZombieVisualController = $Visual
@onready var animator: ZombieAnimator = $AnimationPlayer
@onready var debug_label: Label = $DebugLabel

var visual_variant_id: String = DEFAULT_VARIANT
var corpse_visual_variant_id: String = DEFAULT_VARIANT
var is_corpse: bool = false
var current_anim_state: String = "idle"


func _ready() -> void:
	add_to_group("zombie_units")
	if visual != null:
		visual.cache_rest_poses()
	if animator != null:
		animator.setup(visual)
	_refresh_debug_label()
	if visual != null and visual.active_variant == null:
		apply_visual_variant(visual_variant_id)


func setup(variant_id: String = "", allowed_ids: PackedStringArray = PackedStringArray()) -> void:
	if variant_id.is_empty():
		variant_id = _pick_variant_id(allowed_ids)
	apply_visual_variant(variant_id)
	if visual != null:
		visual.cache_rest_poses()
	if animator != null:
		animator.setup(visual)


func apply_visual_variant(variant_id: String) -> void:
	if variant_id.is_empty():
		variant_id = DEFAULT_VARIANT
	visual_variant_id = variant_id
	if not is_corpse:
		corpse_visual_variant_id = variant_id
	if visual != null:
		visual.apply_variant_id(variant_id)
	_refresh_debug_label()


func play_state(state_name: String) -> void:
	if is_corpse and state_name != "resurrection":
		return
	current_anim_state = state_name
	if animator != null:
		animator.play_state(state_name)


func die() -> void:
	is_corpse = true
	corpse_visual_variant_id = visual_variant_id
	play_state("death")
	died.emit(self)


func resurrect() -> void:
	is_corpse = false
	apply_visual_variant(corpse_visual_variant_id)
	play_state("resurrection")
	resurrected.emit(self)
	if animator != null and not animator.animation_finished.is_connected(_on_resurrect_finished):
		animator.animation_finished.connect(_on_resurrect_finished, CONNECT_ONE_SHOT)


func set_facing(direction_x: float) -> void:
	if visual == null:
		return
	if absf(direction_x) < 0.01:
		return
	var visual_scale := visual.scale
	visual_scale.x = absf(visual_scale.x) * (-1.0 if direction_x < 0.0 else 1.0)
	visual.scale = visual_scale


func get_variant_display_name() -> String:
	if visual != null and visual.active_variant != null:
		return visual.active_variant.display_name
	return visual_variant_id.capitalize()


func _pick_variant_id(allowed_ids: PackedStringArray) -> String:
	var library := get_node_or_null("/root/ZombieVisualLibrary")
	if library != null and library.has_method("pick_variant_id"):
		return library.pick_variant_id(allowed_ids)
	return DEFAULT_VARIANT


func _refresh_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.text = "Variant: %s" % get_variant_display_name()


func _on_resurrect_finished(_anim_name: StringName) -> void:
	if not is_corpse:
		play_state("idle")
