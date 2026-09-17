class_name ZombieAnimator
extends AnimationPlayer

## Shared transform animation for every visual variant. Never replaces textures.

const WALK_STATES := ["walk", "chase", "follow", "move", "attack_move"]
const IDLE_STATES := ["idle", "defend", "recall"]

var _visual: Node2D
var _rest: Dictionary = {}
var _built := false


func setup(visual: Node2D) -> void:
	_visual = visual
	_cache_rest()
	_ensure_animations()
	play_state("idle")


func play_state(state_name: String) -> void:
	_ensure_animations()
	var clip := _clip_for_state(state_name)
	if current_animation == clip and is_playing():
		return
	if has_animation(clip):
		play(clip)


func _clip_for_state(state_name: String) -> String:
	if state_name in WALK_STATES:
		return "walk"
	if state_name in IDLE_STATES:
		return "idle"
	match state_name:
		"attack":
			return "attack"
		"hit":
			return "hit"
		"death":
			return "death"
		"resurrection":
			return "resurrection"
		_:
			return "idle"


func _cache_rest() -> void:
	if _visual == null:
		return
	for part in ["Head", "Body", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
		var node := _visual.get_node_or_null(part) as Node2D
		if node != null:
			_rest[part] = node.position


func _ensure_animations() -> void:
	if _built:
		return
	_built = true
	var library := AnimationLibrary.new()
	library.add_animation("idle", _make_idle())
	library.add_animation("walk", _make_walk())
	library.add_animation("attack", _make_attack())
	library.add_animation("hit", _make_hit())
	library.add_animation("death", _make_death())
	library.add_animation("resurrection", _make_resurrection())
	if has_animation_library(""):
		remove_animation_library("")
	add_animation_library("", library)


func _make_idle() -> Animation:
	var anim := Animation.new()
	anim.length = 1.2
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_position_track(anim, "Head", [
		[0.0, Vector2(0, 0)],
		[0.6, Vector2(0, -6)],
		[1.2, Vector2(0, 0)],
	])
	return anim


func _make_walk() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_position_track(anim, "LeftFoot", [
		[0.0, Vector2(0, 0)],
		[0.125, Vector2(-8, -16)],
		[0.25, Vector2(0, 0)],
		[0.375, Vector2(8, 10)],
		[0.5, Vector2(0, 0)],
	])
	_add_position_track(anim, "RightFoot", [
		[0.0, Vector2(0, 0)],
		[0.125, Vector2(8, 10)],
		[0.25, Vector2(0, 0)],
		[0.375, Vector2(-8, -16)],
		[0.5, Vector2(0, 0)],
	])
	_add_position_track(anim, "LeftHand", [
		[0.0, Vector2(0, 0)],
		[0.25, Vector2(0, 12)],
		[0.5, Vector2(0, 0)],
	])
	_add_position_track(anim, "RightHand", [
		[0.0, Vector2(0, 0)],
		[0.25, Vector2(0, -12)],
		[0.5, Vector2(0, 0)],
	])
	_add_position_track(anim, "Head", [
		[0.0, Vector2(0, 0)],
		[0.25, Vector2(0, -4)],
		[0.5, Vector2(0, 0)],
	])
	return anim


func _make_attack() -> Animation:
	var anim := Animation.new()
	anim.length = 0.4
	_add_position_track(anim, "LeftHand", [
		[0.0, Vector2(0, 0)],
		[0.12, Vector2(36, -8)],
		[0.4, Vector2(0, 0)],
	])
	_add_position_track(anim, "RightHand", [
		[0.0, Vector2(0, 0)],
		[0.12, Vector2(44, 6)],
		[0.4, Vector2(0, 0)],
	])
	_add_position_track(anim, "Head", [
		[0.0, Vector2(0, 0)],
		[0.12, Vector2(8, 4)],
		[0.4, Vector2(0, 0)],
	])
	return anim


func _make_hit() -> Animation:
	var anim := Animation.new()
	anim.length = 0.28
	_add_position_track(anim, "Head", [
		[0.0, Vector2(0, 0)],
		[0.08, Vector2(-14, 4)],
		[0.28, Vector2(0, 0)],
	])
	_add_position_track(anim, "Body", [
		[0.0, Vector2(0, 0)],
		[0.08, Vector2(-10, 0)],
		[0.28, Vector2(0, 0)],
	])
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("Visual:modulate"))
	anim.track_insert_key(track, 0.0, Color.WHITE)
	anim.track_insert_key(track, 0.08, Color(1.0, 0.55, 0.55, 1.0))
	anim.track_insert_key(track, 0.28, Color.WHITE)
	return anim


func _make_death() -> Animation:
	var anim := Animation.new()
	anim.length = 0.45
	_add_position_track(anim, "Head", [
		[0.0, Vector2(0, 0)],
		[0.45, Vector2(18, 40)],
	])
	_add_position_track(anim, "Body", [
		[0.0, Vector2(0, 0)],
		[0.45, Vector2(0, 22)],
	])
	_add_position_track(anim, "LeftHand", [
		[0.0, Vector2(0, 0)],
		[0.45, Vector2(-20, 28)],
	])
	_add_position_track(anim, "RightHand", [
		[0.0, Vector2(0, 0)],
		[0.45, Vector2(20, 28)],
	])
	var rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot, NodePath("Visual:rotation"))
	anim.track_insert_key(rot, 0.0, 0.0)
	anim.track_insert_key(rot, 0.45, 0.7)
	return anim


func _make_resurrection() -> Animation:
	var anim := Animation.new()
	anim.length = 0.55
	_add_position_track(anim, "Head", [
		[0.0, Vector2(18, 40)],
		[0.55, Vector2(0, 0)],
	])
	_add_position_track(anim, "Body", [
		[0.0, Vector2(0, 22)],
		[0.55, Vector2(0, 0)],
	])
	_add_position_track(anim, "LeftHand", [
		[0.0, Vector2(-20, 28)],
		[0.55, Vector2(0, 0)],
	])
	_add_position_track(anim, "RightHand", [
		[0.0, Vector2(20, 28)],
		[0.55, Vector2(0, 0)],
	])
	var rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot, NodePath("Visual:rotation"))
	anim.track_insert_key(rot, 0.0, 0.7)
	anim.track_insert_key(rot, 0.55, 0.0)
	return anim


func _add_position_track(anim: Animation, part: String, keys: Array) -> void:
	var rest: Vector2 = _rest.get(part, Vector2.ZERO)
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("Visual/%s:position" % part))
	for key in keys:
		var time: float = key[0]
		var delta: Vector2 = key[1]
		anim.track_insert_key(track, time, rest + delta)
