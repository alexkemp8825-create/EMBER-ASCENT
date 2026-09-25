class_name EncounterTemplateDatabase
extends RefCounted

static var _templates: Array = []


static func all_templates() -> Array:
	if _templates.is_empty():
		_templates = _authored_templates()
	return _templates


static func get_template(template_id: String) -> Dictionary:
	for template in all_templates():
		if str(template.get("id", "")) == template_id:
			return template
	return {}


static func eligible(floor: int, act: int, role: String) -> Array:
	var pool: Array = []
	for template in all_templates():
		if _matches(template, floor, act, role):
			pool.append(template)
	return pool


static func _matches(template: Dictionary, floor: int, act: int, role: String) -> bool:
	if floor < int(template.get("min_floor", 1)):
		return false
	if floor > int(template.get("max_floor", 1)):
		return false
	var acts: Array = template.get("acts", [])
	if not acts.has(act):
		return false
	var roles: Array = template.get("roles", [])
	return roles.has(role)


static func objective_label(objective: Dictionary) -> String:
	var objective_type := str(objective.get("type", "kill_all"))
	match objective_type:
		"kill_all":
			return "Slay every foe"
		"reach_exit":
			return "Reach the ember gate"
		"reclaim_corpses":
			return "Reclaim the fallen"
		"shatter_core":
			return "Shatter the furnace core"
		"survive":
			return "Hold for %d turns" % int(objective.get("turns", 1))
		_:
			return objective_type


static func _authored_templates() -> Array:
	return [
		{
			"id": "ash_corridor",
			"name": "Ash Corridor",
			"summary": "Walled lane with a side corpse alcove, a center ember vent, and a rat blocking a cultist at the far end.",
			"radius": 3,
			"min_floor": 1,
			"max_floor": 3,
			"acts": [1, 2],
			"roles": ["battle"],
			"player": Vector2i(0, 3),
			"enemies": [
				{"id": "charred_rat", "pos": Vector2i(0, -1)},
				{"id": "furnace_cultist", "pos": Vector2i(0, -3)},
			],
			"blocked": [
				Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(-1, -2),
				Vector2i(-2, 1), Vector2i(-2, 0), Vector2i(-2, -1),
				Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1), Vector2i(1, -2),
				Vector2i(2, 0), Vector2i(2, -1), Vector2i(2, -2),
				Vector2i(1, -3),
			],
			"pit_fill": "listed",
			"pits": [Vector2i(2, 1), Vector2i(-2, 3)],
			"keep": [],
			"hazards": [
				{"pos": Vector2i(0, 0), "kind": "ember_vent", "damage": 2},
			],
			"corpses": [
				{"pos": Vector2i(-2, 2), "kind": "ash_remains"},
			],
			"objective": {"type": "kill_all"},
		},
		{
			"id": "pit_bridge",
			"name": "Pit Bridge",
			"summary": "A one-hex bridge over pits; cross a cinder crack and a corpse, cut through a hound and a rat, and reach the east gate.",
			"radius": 3,
			"min_floor": 1,
			"max_floor": 3,
			"acts": [1, 2],
			"roles": ["battle"],
			"player": Vector2i(-3, 0),
			"enemies": [
				{"id": "furnace_hound", "pos": Vector2i(1, 0)},
				{"id": "charred_rat", "pos": Vector2i(2, 0)},
			],
			"blocked": [],
			"pit_fill": "all_except_keep",
			"pits": [],
			"keep": [
				Vector2i(-3, 0), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0),
				Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
			],
			"hazards": [
				{"pos": Vector2i(-1, 0), "kind": "cinder_crack", "damage": 2},
			],
			"corpses": [
				{"pos": Vector2i(0, 0), "kind": "bridge_fallen"},
			],
			"objective": {"type": "reach_exit", "hex": Vector2i(3, 0)},
		},
		{
			"id": "ember_crossroads",
			"name": "Ember Crossroads",
			"summary": "Burning center tiles and a collapsed north road; reclaim a west pyre and an east pyre while a cultist and a hound hold the flanks.",
			"radius": 3,
			"min_floor": 2,
			"max_floor": 4,
			"acts": [1, 2],
			"roles": ["battle"],
			"player": Vector2i(0, 3),
			"enemies": [
				{"id": "furnace_cultist", "pos": Vector2i(-2, 0)},
				{"id": "furnace_hound", "pos": Vector2i(2, 0)},
			],
			"blocked": [
				Vector2i(0, -1), Vector2i(0, -2), Vector2i(-1, -2), Vector2i(1, -2),
			],
			"pit_fill": "listed",
			"pits": [Vector2i(0, -3), Vector2i(-3, 0), Vector2i(3, 0)],
			"keep": [],
			"hazards": [
				{"pos": Vector2i(0, 1), "kind": "ember_cross", "damage": 3},
				{"pos": Vector2i(0, 0), "kind": "ember_cross", "damage": 3},
			],
			"corpses": [
				{"pos": Vector2i(-3, 1), "kind": "west_pyre"},
				{"pos": Vector2i(3, -1), "kind": "east_pyre"},
			],
			"objective": {"type": "reclaim_corpses"},
		},
		{
			"id": "collapsed_gallery",
			"name": "Collapsed Gallery",
			"summary": "Central rubble forces a detour around a heated gallery; a hound and a rat wait on the far side of the collapse.",
			"radius": 3,
			"min_floor": 1,
			"max_floor": 3,
			"acts": [1, 2],
			"roles": ["battle"],
			"player": Vector2i(2, 1),
			"enemies": [
				{"id": "furnace_hound", "pos": Vector2i(-2, 0)},
				{"id": "charred_rat", "pos": Vector2i(-1, -2)},
			],
			"blocked": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
			"pit_fill": "listed",
			"pits": [Vector2i(2, -1)],
			"keep": [],
			"hazards": [
				{"pos": Vector2i(-1, 1), "kind": "rubble_heat", "damage": 2},
			],
			"corpses": [
				{"pos": Vector2i(0, 2), "kind": "gallery_dead"},
			],
			"objective": {"type": "kill_all"},
		},
		{
			"id": "brazier_ring",
			"name": "Brazier Ring",
			"summary": "Six braziers ring a furnace core that must be shattered, while a molten guard and an ash zealot close from opposite edges.",
			"radius": 3,
			"min_floor": 2,
			"max_floor": 4,
			"acts": [1, 2],
			"roles": ["battle", "elite"],
			"player": Vector2i(0, 3),
			"enemies": [
				{"id": "molten_guard", "pos": Vector2i(-3, 2)},
				{"id": "ash_zealot", "pos": Vector2i(3, -1)},
			],
			"blocked": [Vector2i(2, 1), Vector2i(-2, -1), Vector2i(1, -2)],
			"pit_fill": "listed",
			"pits": [Vector2i(0, -3), Vector2i(-3, 0)],
			"keep": [],
			"hazards": [
				{"pos": Vector2i(1, 0), "kind": "brazier", "damage": 2},
				{"pos": Vector2i(1, -1), "kind": "brazier", "damage": 2},
				{"pos": Vector2i(0, -1), "kind": "brazier", "damage": 2},
				{"pos": Vector2i(-1, 0), "kind": "brazier", "damage": 2},
				{"pos": Vector2i(-1, 1), "kind": "brazier", "damage": 2},
				{"pos": Vector2i(0, 1), "kind": "brazier", "damage": 2},
			],
			"corpses": [
				{"pos": Vector2i(2, -1), "kind": "ring_warden"},
			],
			"objective": {"type": "shatter_core", "hex": Vector2i(0, 0)},
		},
		{
			"id": "grave_ash",
			"name": "Grave Ash",
			"summary": "Three graves to reclaim, split by a blocked center and pits, with an ash zealot and a molten guard between the plots.",
			"radius": 3,
			"min_floor": 3,
			"max_floor": 5,
			"acts": [1, 2],
			"roles": ["battle", "elite"],
			"player": Vector2i(0, 3),
			"enemies": [
				{"id": "ash_zealot", "pos": Vector2i(-2, -1)},
				{"id": "molten_guard", "pos": Vector2i(2, -1)},
			],
			"blocked": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0)],
			"pit_fill": "listed",
			"pits": [Vector2i(0, -2), Vector2i(-1, -1), Vector2i(1, -2)],
			"keep": [],
			"hazards": [
				{"pos": Vector2i(-2, 1), "kind": "grave_heat", "damage": 2},
				{"pos": Vector2i(2, 1), "kind": "grave_heat", "damage": 2},
			],
			"corpses": [
				{"pos": Vector2i(-3, 2), "kind": "north_grave"},
				{"pos": Vector2i(3, -2), "kind": "south_grave"},
				{"pos": Vector2i(-1, 2), "kind": "near_grave"},
			],
			"objective": {"type": "reclaim_corpses"},
		},
		{
			"id": "regent_threshold",
			"name": "Regent Threshold",
			"summary": "A one-hex throat of threshold fire leads to the Ember Regent, with an ash zealot packed behind them and pits off both shoulders.",
			"radius": 3,
			"min_floor": 4,
			"max_floor": 5,
			"acts": [1, 2],
			"roles": ["elite", "boss"],
			"player": Vector2i(0, 3),
			"enemies": [
				{"id": "ember_regent", "pos": Vector2i(0, -2)},
				{"id": "ash_zealot", "pos": Vector2i(0, -3)},
			],
			"blocked": [
				Vector2i(-1, 2), Vector2i(1, 2),
				Vector2i(-1, 1), Vector2i(1, 1),
				Vector2i(-1, 0), Vector2i(1, 0),
				Vector2i(-1, -1), Vector2i(1, -1),
				Vector2i(-2, 0), Vector2i(2, 0),
			],
			"pit_fill": "listed",
			"pits": [Vector2i(-2, 3), Vector2i(3, -2), Vector2i(-3, 1), Vector2i(3, -1)],
			"keep": [],
			"hazards": [
				{"pos": Vector2i(0, 1), "kind": "threshold_fire", "damage": 3},
			],
			"corpses": [
				{"pos": Vector2i(-1, 3), "kind": "threshold_fallen"},
			],
			"objective": {"type": "kill_all"},
		},
		{
			"id": "hold_the_furnace",
			"name": "Hold the Furnace",
			"summary": "Hold a half-walled furnace mouth for four turns while a molten guard and a hound close in past pits and open flame.",
			"radius": 3,
			"min_floor": 2,
			"max_floor": 5,
			"acts": [1, 2],
			"roles": ["battle", "elite", "boss"],
			"player": Vector2i(0, 2),
			"enemies": [
				{"id": "molten_guard", "pos": Vector2i(0, -3)},
				{"id": "furnace_hound", "pos": Vector2i(3, -3)},
			],
			"blocked": [Vector2i(-1, 2), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 2)],
			"pit_fill": "listed",
			"pits": [Vector2i(-3, 3), Vector2i(3, 0), Vector2i(-2, -1)],
			"keep": [],
			"hazards": [
				{"pos": Vector2i(0, 0), "kind": "furnace_mouth", "damage": 4},
				{"pos": Vector2i(2, -1), "kind": "furnace_mouth", "damage": 3},
			],
			"corpses": [
				{"pos": Vector2i(2, 1), "kind": "furnace_dead"},
			],
			"objective": {"type": "survive", "turns": 4},
		},
	]
