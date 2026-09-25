class_name HexGrid
extends RefCounted

# Axial hex coordinates: x = q, y = r.

static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := absi(a.x - b.x)
	var dr := absi(a.y - b.y)
	var ds := absi((a.x + a.y) - (b.x + b.y))
	return (dq + dr + ds) >> 1


static func in_radius(pos: Vector2i, radius: int) -> bool:
	return distance(pos, Vector2i.ZERO) <= radius


static func directions() -> Array:
	return [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
	]


static func neighbors(pos: Vector2i) -> Array:
	var result: Array = []
	for direction in directions():
		result.append(pos + direction)
	return result


static func hexes_in_radius(radius: int) -> Array:
	var result: Array = []
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var pos := Vector2i(q, r)
			if in_radius(pos, radius):
				result.append(pos)
	return result


static func key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
