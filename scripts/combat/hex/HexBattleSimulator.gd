class_name HexBattleSimulator
extends RefCounted

const HexGridScript := preload("res://scripts/combat/hex/HexGrid.gd")
const EncounterScalerScript := preload("res://scripts/combat/hex/EncounterScaler.gd")


static func validate(battle: HexBattle) -> String:
	var terrain_error := _validate_terrain(battle)
	if terrain_error != "":
		return terrain_error

	var sim: Dictionary = play(battle)
	if not bool(sim.get("won", false)):
		return "unwinnable: %s" % str(sim.get("reason", "unknown"))
	return ""


static func play(battle: HexBattle) -> Dictionary:
	var state := _build_state(battle)
	_mark_corpse(state, state["player"])

	for turn in range(1, 41):
		state["turns"] = turn - 1
		if str(state["objective_type"]) == "survive" and _objective_done(state):
			return {"won": true, "reason": "won survive before turn %d" % turn, "hp": state["player_hp"]}

		if not _adjacent_enemies(state).is_empty():
			_player_attack(state)
		else:
			_move_player(state, EncounterScalerScript.PLAYER_MOVE)
			_mark_corpse(state, state["player"])
			if str(state["objective_type"]) == "shatter_core" and state["player"] == state["objective_hex"]:
				state["shattered"] = true
			if str(state["objective_type"]) == "reach_exit" and state["player"] == state["objective_hex"]:
				return {"won": true, "reason": "reached exit turn %d" % turn, "hp": state["player_hp"]}
			if not _adjacent_enemies(state).is_empty():
				_player_attack(state)

		state["player_hp"] = _apply_hazard(state, state["player"], int(state["player_hp"]))
		_mark_corpse(state, state["player"])
		if str(state["objective_type"]) == "shatter_core" and state["player"] == state["objective_hex"]:
			state["shattered"] = true
		if _objective_done(state) and str(state["objective_type"]) != "survive":
			return {
				"won": true,
				"reason": "won %s turn %d hp %d" % [state["objective_type"], turn, state["player_hp"]],
				"hp": state["player_hp"],
			}
		if int(state["player_hp"]) <= 0:
			return {"won": false, "reason": "player died on own turn %d" % turn, "hp": state["player_hp"]}

		for enemy in state["enemies"]:
			_enemy_turn(state, enemy)
			if int(state["player_hp"]) <= 0:
				return {
					"won": false,
					"reason": "player died to %s turn %d at %s" % [enemy["id"], turn, enemy["pos"]],
					"hp": state["player_hp"],
				}

		state["turns"] = turn
		if _objective_done(state):
			return {
				"won": true,
				"reason": "won %s end %d hp %d" % [state["objective_type"], turn, state["player_hp"]],
				"hp": state["player_hp"],
			}

	return {"won": false, "reason": "timeout", "hp": state["player_hp"]}


static func _validate_terrain(battle: HexBattle) -> String:
	if battle == null:
		return "battle was not built"
	if battle.template_id == "":
		return "missing template id"
	if battle.enemies.is_empty():
		return "battle has no enemies"

	var hexes := _hex_set(battle.radius)
	var blocked := _pos_set(battle.blocked)
	var pits := _pos_set(battle.pits)

	for key in blocked.keys():
		if not hexes.has(key):
			return "blocked hex off map %s" % key
		if pits.has(key):
			return "hex is both blocked and a pit %s" % key
	for key in pits.keys():
		if not hexes.has(key):
			return "pit hex off map %s" % key

	var occupied := {}
	var spawn_error := _check_spawn("player", battle.player_spawn, hexes, blocked, pits, occupied)
	if spawn_error != "":
		return spawn_error

	for enemy in battle.enemies:
		var enemy_id := str(enemy.get("id", ""))
		if EncounterScalerScript.hex_stats(enemy_id).is_empty():
			return "unknown enemy %s" % enemy_id
		if int(enemy.get("hp", 0)) <= 0:
			return "enemy %s has no hp" % enemy_id
		var pos: Vector2i = enemy.get("pos", Vector2i.ZERO)
		spawn_error = _check_spawn(enemy_id, pos, hexes, blocked, pits, occupied)
		if spawn_error != "":
			return spawn_error

	var reach := _reachable(battle.player_spawn, hexes, blocked, pits)
	for enemy in battle.enemies:
		var pos: Vector2i = enemy["pos"]
		if not reach.has(HexGridScript.key(pos)):
			return "enemy %s unreachable at %s" % [enemy["id"], pos]

	if battle.has_objective_hex:
		var objective_key := HexGridScript.key(battle.objective_hex)
		if not hexes.has(objective_key) or blocked.has(objective_key) or pits.has(objective_key):
			return "objective hex impassable %s" % battle.objective_hex
		if not reach.has(objective_key):
			return "objective hex unreachable %s" % battle.objective_hex

	for corpse in battle.corpses:
		var pos: Vector2i = corpse["pos"]
		var corpse_key := HexGridScript.key(pos)
		if not hexes.has(corpse_key) or blocked.has(corpse_key) or pits.has(corpse_key):
			return "corpse %s on impassable hex %s" % [corpse.get("kind", ""), pos]
		if not reach.has(corpse_key):
			return "corpse %s unreachable at %s" % [corpse.get("kind", ""), pos]

	for hazard in battle.hazards:
		var pos: Vector2i = hazard["pos"]
		var hazard_key := HexGridScript.key(pos)
		if not hexes.has(hazard_key) or blocked.has(hazard_key) or pits.has(hazard_key):
			return "hazard %s on impassable hex %s" % [hazard.get("kind", ""), pos]
		if int(hazard.get("damage", 0)) <= 0:
			return "hazard %s has no damage" % hazard.get("kind", "")

	var known_objectives := ["kill_all", "reach_exit", "reclaim_corpses", "shatter_core", "survive"]
	if not known_objectives.has(battle.objective_type):
		return "unknown objective %s" % battle.objective_type
	if battle.objective_type == "reclaim_corpses" and battle.corpses.is_empty():
		return "reclaim objective has no corpses"
	if battle.objective_type == "survive" and battle.objective_turns <= 0:
		return "survive objective has no turn count"
	return ""


static func _check_spawn(
	label: String,
	pos: Vector2i,
	hexes: Dictionary,
	blocked: Dictionary,
	pits: Dictionary,
	occupied: Dictionary
) -> String:
	var pos_key := HexGridScript.key(pos)
	if not hexes.has(pos_key):
		return "%s spawned off map at %s" % [label, pos]
	if blocked.has(pos_key):
		return "%s spawned on blocked hex %s" % [label, pos]
	if pits.has(pos_key):
		return "%s spawned on pit hex %s" % [label, pos]
	if occupied.has(pos_key):
		return "%s spawned on another unit at %s" % [label, pos]
	occupied[pos_key] = true
	return ""


static func _build_state(battle: HexBattle) -> Dictionary:
	var hazards := {}
	for hazard in battle.hazards:
		hazards[HexGridScript.key(hazard["pos"])] = int(hazard["damage"])

	var corpses: Array = []
	for corpse in battle.corpses:
		corpses.append(corpse["pos"])

	var enemies: Array = []
	for enemy in battle.enemies:
		enemies.append({
			"id": str(enemy["id"]),
			"pos": enemy["pos"],
			"hp": int(enemy["hp"]),
			"attack": int(enemy["attack"]),
		})

	return {
		"hexes": _hex_set(battle.radius),
		"blocked": _pos_set(battle.blocked),
		"pits": _pos_set(battle.pits),
		"player": battle.player_spawn,
		"player_hp": EncounterScalerScript.PLAYER_HP,
		"enemies": enemies,
		"hazards": hazards,
		"corpses": corpses,
		"visited": {},
		"objective_type": battle.objective_type,
		"objective_hex": battle.objective_hex,
		"objective_turns": battle.objective_turns,
		"shattered": false,
		"turns": 0,
	}


static func _hex_set(radius: int) -> Dictionary:
	var hexes := {}
	for pos in HexGridScript.hexes_in_radius(radius):
		hexes[HexGridScript.key(pos)] = pos
	return hexes


static func _pos_set(positions: Array) -> Dictionary:
	var result := {}
	for pos in positions:
		result[HexGridScript.key(pos)] = pos
	return result


static func _passable(state: Dictionary, pos: Vector2i) -> bool:
	var pos_key := HexGridScript.key(pos)
	return state["hexes"].has(pos_key) and not state["blocked"].has(pos_key) and not state["pits"].has(pos_key)


static func _reachable(start: Vector2i, hexes: Dictionary, blocked: Dictionary, pits: Dictionary) -> Dictionary:
	var state := {"hexes": hexes, "blocked": blocked, "pits": pits}
	var seen := {}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_key := HexGridScript.key(current)
		if seen.has(current_key):
			continue
		if not _passable(state, current):
			continue
		seen[current_key] = true
		for nxt in HexGridScript.neighbors(current):
			if not seen.has(HexGridScript.key(nxt)):
				queue.append(nxt)
	return seen


static func _occupied(state: Dictionary, ignore: Variant = null) -> Dictionary:
	var occ := {}
	var player: Vector2i = state["player"]
	var skip_player := ignore is Vector2i and (ignore as Vector2i) == player
	if not skip_player:
		occ[HexGridScript.key(player)] = true
	for enemy in state["enemies"]:
		if int(enemy["hp"]) <= 0:
			continue
		var pos: Vector2i = enemy["pos"]
		if ignore is Vector2i and pos == (ignore as Vector2i):
			continue
		occ[HexGridScript.key(pos)] = true
	return occ


static func _shortest_path(state: Dictionary, start: Vector2i, goal: Vector2i, occupied: Dictionary) -> Array:
	if start == goal:
		return [start]
	var start_key := HexGridScript.key(start)
	var came := {start_key: ""}
	var pos_of := {start_key: start}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for nxt in HexGridScript.neighbors(current):
			var nxt_key := HexGridScript.key(nxt)
			if came.has(nxt_key):
				continue
			if not _passable(state, nxt):
				continue
			if occupied.has(nxt_key) and nxt != goal:
				continue
			came[nxt_key] = HexGridScript.key(current)
			pos_of[nxt_key] = nxt
			if nxt == goal:
				var path: Array = []
				var cursor := nxt_key
				while cursor != "":
					path.append(pos_of[cursor])
					cursor = str(came[cursor])
				path.reverse()
				return path
			queue.append(nxt)
	return []


static func _nearest_step(state: Dictionary, start: Vector2i, goal: Vector2i, occupied: Dictionary) -> Variant:
	var path := _shortest_path(state, start, goal, occupied)
	if path.size() < 2:
		return null
	return path[1]


static func _adjacent_enemies(state: Dictionary) -> Array:
	var foes: Array = []
	var player: Vector2i = state["player"]
	for enemy in state["enemies"]:
		if int(enemy["hp"]) <= 0:
			continue
		if HexGridScript.distance(player, enemy["pos"]) == 1:
			foes.append(enemy)
	return foes


static func _living_enemies(state: Dictionary) -> Array:
	var living: Array = []
	for enemy in state["enemies"]:
		if int(enemy["hp"]) > 0:
			living.append(enemy)
	return living


static func _objective_done(state: Dictionary) -> bool:
	var objective_type := str(state["objective_type"])
	if objective_type == "kill_all":
		return _living_enemies(state).is_empty()
	if objective_type == "reach_exit":
		return state["player"] == state["objective_hex"]
	if objective_type == "reclaim_corpses":
		for corpse in state["corpses"]:
			if not state["visited"].has(HexGridScript.key(corpse)):
				return false
		return not state["corpses"].is_empty()
	if objective_type == "shatter_core":
		return bool(state["shattered"])
	if objective_type == "survive":
		return int(state["turns"]) >= int(state["objective_turns"])
	return false


static func _goal_hex(state: Dictionary) -> Vector2i:
	var objective_type := str(state["objective_type"])
	var player: Vector2i = state["player"]
	if objective_type == "kill_all":
		var living := _living_enemies(state)
		if living.is_empty():
			return player
		_sort_enemies_by_distance(living, player)
		return living[0]["pos"]
	if objective_type == "reach_exit" or objective_type == "shatter_core":
		return state["objective_hex"]
	if objective_type == "reclaim_corpses":
		var remaining: Array = []
		for corpse in state["corpses"]:
			if not state["visited"].has(HexGridScript.key(corpse)):
				remaining.append(corpse)
		if remaining.is_empty():
			return player
		_sort_hexes(remaining, player)
		return remaining[0]
	return player


static func _player_attack(state: Dictionary) -> void:
	var foes := _adjacent_enemies(state)
	if foes.is_empty():
		return
	_sort_enemies_by_hp(foes)
	foes[0]["hp"] = int(foes[0]["hp"]) - EncounterScalerScript.PLAYER_ATTACK


static func _move_player(state: Dictionary, steps: int) -> void:
	if str(state["objective_type"]) == "survive":
		var player: Vector2i = state["player"]
		if not state["hazards"].has(HexGridScript.key(player)):
			return
		for nxt in HexGridScript.neighbors(player):
			if not _passable(state, nxt):
				continue
			if _occupied(state, player).has(HexGridScript.key(nxt)):
				continue
			if state["hazards"].has(HexGridScript.key(nxt)):
				continue
			state["player"] = nxt
			return
		return

	for _step in range(steps):
		if not _adjacent_enemies(state).is_empty():
			return
		var goal := _goal_hex(state)
		var target := goal
		var living_positions := {}
		for enemy in _living_enemies(state):
			living_positions[HexGridScript.key(enemy["pos"])] = true
		if living_positions.has(HexGridScript.key(goal)):
			var options: Array = []
			for nxt in HexGridScript.neighbors(goal):
				if _passable(state, nxt) and not _occupied(state, null).has(HexGridScript.key(nxt)):
					options.append(nxt)
			var already_adjacent := false
			for nxt in HexGridScript.neighbors(goal):
				if nxt == state["player"]:
					already_adjacent = true
			if already_adjacent:
				return
			if options.is_empty():
				return
			_sort_hexes(options, state["player"])
			target = options[0]
		var step = _nearest_step(state, state["player"], target, _occupied(state, target))
		if step == null:
			var living := _living_enemies(state)
			if living.is_empty():
				return
			_sort_enemies_by_distance(living, state["player"])
			var enemy_goal: Vector2i = living[0]["pos"]
			var approach: Array = []
			for nxt in HexGridScript.neighbors(enemy_goal):
				if _passable(state, nxt) and not _occupied(state).has(HexGridScript.key(nxt)):
					approach.append(nxt)
			if approach.is_empty():
				return
			_sort_hexes(approach, state["player"])
			var approach_hex: Vector2i = approach[0]
			step = _nearest_step(state, state["player"], approach_hex, _occupied(state, approach_hex))
			if step == null:
				return
		state["player"] = step
		_mark_corpse(state, state["player"])


static func _enemy_turn(state: Dictionary, enemy: Dictionary) -> void:
	if int(enemy["hp"]) <= 0:
		return
	if HexGridScript.distance(enemy["pos"], state["player"]) == 1:
		state["player_hp"] = int(state["player_hp"]) - int(enemy["attack"])
		return

	var occ := _occupied(state, enemy["pos"])
	var options: Array = []
	for nxt in HexGridScript.neighbors(state["player"]):
		if _passable(state, nxt) and not occ.has(HexGridScript.key(nxt)):
			options.append(nxt)
	var target: Vector2i = state["player"]
	if not options.is_empty():
		_sort_hexes(options, enemy["pos"])
		target = options[0]
	var step = _nearest_step(state, enemy["pos"], target, occ)
	if step != null and step != state["player"]:
		enemy["pos"] = step
	if HexGridScript.distance(enemy["pos"], state["player"]) == 1:
		state["player_hp"] = int(state["player_hp"]) - int(enemy["attack"])
	enemy["hp"] = _apply_hazard(state, enemy["pos"], int(enemy["hp"]))


static func _apply_hazard(state: Dictionary, pos: Vector2i, hp: int) -> int:
	var pos_key := HexGridScript.key(pos)
	if state["hazards"].has(pos_key):
		return hp - int(state["hazards"][pos_key])
	return hp


static func _mark_corpse(state: Dictionary, pos: Vector2i) -> void:
	for corpse in state["corpses"]:
		if corpse == pos:
			state["visited"][HexGridScript.key(pos)] = true
			return


static func _sort_hexes(items: Array, origin: Vector2i) -> void:
	items.sort_custom(func(a, b) -> bool:
		var pa: Vector2i = a
		var pb: Vector2i = b
		var da := HexGridScript.distance(origin, pa)
		var db := HexGridScript.distance(origin, pb)
		if da != db:
			return da < db
		if pa.x != pb.x:
			return pa.x < pb.x
		return pa.y < pb.y
	)


static func _sort_enemies_by_distance(items: Array, origin: Vector2i) -> void:
	items.sort_custom(func(a, b) -> bool:
		var pa: Vector2i = a["pos"]
		var pb: Vector2i = b["pos"]
		var da := HexGridScript.distance(origin, pa)
		var db := HexGridScript.distance(origin, pb)
		if da != db:
			return da < db
		if pa.x != pb.x:
			return pa.x < pb.x
		return pa.y < pb.y
	)


static func _sort_enemies_by_hp(items: Array) -> void:
	items.sort_custom(func(a, b) -> bool:
		var ha := int(a["hp"])
		var hb := int(b["hp"])
		if ha != hb:
			return ha < hb
		var pa: Vector2i = a["pos"]
		var pb: Vector2i = b["pos"]
		if pa.x != pb.x:
			return pa.x < pb.x
		return pa.y < pb.y
	)
