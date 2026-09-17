class_name ZombieVisualVariantData
extends Resource

## Visual-only data for one zombie appearance. AI, animation, and colliders stay
## on the shared Zombie unit; this resource only swaps artwork and small offsets.

@export var id: String = ""
@export var display_name: String = ""
@export var spawn_weight: float = 1.0

@export var head: Texture2D
@export var body: Texture2D
@export var left_hand: Texture2D
@export var right_hand: Texture2D
@export var left_foot: Texture2D
@export var right_foot: Texture2D
@export var accessory: Texture2D
@export var back_accessory: Texture2D

@export var tint: Color = Color.WHITE
@export var head_pivot: Vector2 = Vector2.ZERO
@export var head_offset: Vector2 = Vector2.ZERO
@export var head_scale: Vector2 = Vector2.ONE
@export var accessory_offset: Vector2 = Vector2.ZERO
@export var accessory_pivot: Vector2 = Vector2.ZERO
@export var body_offset: Vector2 = Vector2.ZERO
@export var left_hand_offset: Vector2 = Vector2.ZERO
@export var right_hand_offset: Vector2 = Vector2.ZERO
@export var left_foot_offset: Vector2 = Vector2.ZERO
@export var right_foot_offset: Vector2 = Vector2.ZERO


func setup(data: Dictionary) -> ZombieVisualVariantData:
	id = data.get("id", "")
	display_name = data.get("display_name", id.capitalize())
	spawn_weight = float(data.get("spawn_weight", 1.0))
	head = _load_texture(data.get("head_path", ""))
	body = _load_texture(data.get("body_path", ""))
	left_hand = _load_texture(data.get("left_hand_path", ""))
	right_hand = _load_texture(data.get("right_hand_path", ""))
	left_foot = _load_texture(data.get("left_foot_path", ""))
	right_foot = _load_texture(data.get("right_foot_path", ""))
	accessory = _load_texture(data.get("accessory_path", ""))
	back_accessory = _load_texture(data.get("back_accessory_path", ""))
	tint = data.get("tint", Color.WHITE)
	head_pivot = data.get("head_pivot", Vector2.ZERO)
	head_offset = data.get("head_offset", Vector2.ZERO)
	head_scale = data.get("head_scale", Vector2.ONE)
	accessory_offset = data.get("accessory_offset", Vector2.ZERO)
	accessory_pivot = data.get("accessory_pivot", Vector2.ZERO)
	body_offset = data.get("body_offset", Vector2.ZERO)
	left_hand_offset = data.get("left_hand_offset", Vector2.ZERO)
	right_hand_offset = data.get("right_hand_offset", Vector2.ZERO)
	left_foot_offset = data.get("left_foot_offset", Vector2.ZERO)
	right_foot_offset = data.get("right_foot_offset", Vector2.ZERO)
	return self


func has_required_sprites() -> bool:
	return (
		head != null
		and body != null
		and left_hand != null
		and right_hand != null
		and left_foot != null
		and right_foot != null
	)


func get_slot_texture(slot: int) -> Texture2D:
	match slot:
		ZombieLimbSlots.HEAD:
			return head
		ZombieLimbSlots.BODY:
			return body
		ZombieLimbSlots.LEFT_HAND:
			return left_hand
		ZombieLimbSlots.RIGHT_HAND:
			return right_hand
		ZombieLimbSlots.LEFT_FOOT:
			return left_foot
		ZombieLimbSlots.RIGHT_FOOT:
			return right_foot
		ZombieLimbSlots.ACCESSORY:
			return accessory
		ZombieLimbSlots.BACK_ACCESSORY:
			return back_accessory
		_:
			return null


func get_slot_offset(slot: int) -> Vector2:
	match slot:
		ZombieLimbSlots.HEAD:
			return head_offset
		ZombieLimbSlots.BODY:
			return body_offset
		ZombieLimbSlots.LEFT_HAND:
			return left_hand_offset
		ZombieLimbSlots.RIGHT_HAND:
			return right_hand_offset
		ZombieLimbSlots.LEFT_FOOT:
			return left_foot_offset
		ZombieLimbSlots.RIGHT_FOOT:
			return right_foot_offset
		ZombieLimbSlots.ACCESSORY:
			return accessory_offset
		_:
			return Vector2.ZERO


func _load_texture(path: Variant) -> Texture2D:
	if typeof(path) != TYPE_STRING or String(path).is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("Zombie visual part missing: %s" % path)
		return null
	return load(path) as Texture2D
