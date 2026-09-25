class_name EncounterDirector
extends RefCounted

const HexGridScript := preload("res://scripts/combat/hex/HexGrid.gd")
const EncounterScalerScript := preload("res://scripts/combat/hex/EncounterScaler.gd")
const EncounterTemplateDatabaseScript := preload("res://scripts/combat/hex/EncounterTemplateDatabase.gd")
const TowerRoomDatabaseScript := preload("res://scripts/tower/TowerRoomDatabase.gd")


static func role_for_room_type(room_type: String) -> String:
	match room_type:
		TowerRoomDatabaseScript.ROOM_BATTLE:
			return "battle"
		TowerRoomDatabaseScript.ROOM_ELITE:
			return "elite"
		TowerRoomDatabaseScript.ROOM_BOSS:
			return "boss"
		_:
			return ""


static func build_for_room(run_seed: int, room: TowerRoomData, act: int) -> HexBattle:
	if room == null:
		return null
	var role := role_for_room_type(room.room_type)
	if role == "":
		return null
	return build_battle(run_seed, room.floor, act, role, room.room_id)


static func build_battle(run_seed: int, floor: int, act: int, role: String, room_key: String) -> HexBattle:
	var pool: Array = EncounterTemplateDatabaseScript.eligible(floor, act, role)
	if pool.is_empty():
		push_error(
			"No hex encounter templates for floor=%d act=%d role=%s room=%s seed=%d"
			% [floor, act, role, room_key, run_seed]
		)
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = mix_seed(run_seed, floor, act, role, room_key)
	var index := rng.randi_range(0, pool.size() - 1)
	return build_from_template(pool[index], run_seed, floor, act, role, room_key)


static func build_from_template(
	template: Dictionary,
	run_seed: int,
	floor: int,
	act: int,
	role: String,
	room_key: String
) -> HexBattle:
	var battle := HexBattle.new()
	battle.template_id = str(template.get("id", ""))
	battle.template_name = str(template.get("name", battle.template_id))
	battle.summary = str(template.get("summary", ""))
	battle.seed = mix_seed(run_seed, floor, act, role, room_key)
	battle.room_key = room_key
	battle.floor = floor
	battle.act = act
	battle.role = role
	battle.radius = int(template.get("radius", 3))
	battle.player_spawn = template.get("player", Vector2i.ZERO)
	battle.hex_stat_multiplier = EncounterScalerScript.hex_multiplier(floor, act, role)
	battle.card_hp_multiplier = EncounterScalerScript.card_hp_multiplier(floor, act)
	battle.signature_encounter_id = EncounterScalerScript.signature_encounter_id(floor, act, role)

	var objective: Dictionary = template.get("objective", {})
	battle.objective_type = str(objective.get("type", "kill_all"))
	battle.objective_label = EncounterTemplateDatabaseScript.objective_label(objective)
	battle.objective_turns = int(objective.get("turns", 0))
	battle.has_objective_hex = objective.has("hex")
	if battle.has_objective_hex:
		battle.objective_hex = objective["hex"]

	var terrain := _materialize(template)
	battle.blocked = terrain["blocked"]
	battle.pits = terrain["pits"]

	for hazard in template.get("hazards", []):
		battle.hazards.append({
			"pos": hazard["pos"],
			"kind": str(hazard.get("kind", "hazard")),
			"damage": int(hazard.get("damage", 0)),
		})

	for corpse in template.get("corpses", []):
		battle.corpses.append({
			"pos": corpse["pos"],
			"kind": str(corpse.get("kind", "corpse")),
		})

	for enemy in template.get("enemies", []):
		var enemy_id := str(enemy.get("id", ""))
		var stats := EncounterScalerScript.hex_stats(enemy_id)
		if stats.is_empty():
			push_error("Template %s references unknown enemy %s" % [battle.template_id, enemy_id])
			continue
		battle.enemies.append({
			"id": enemy_id,
			"pos": enemy["pos"],
			"hp": EncounterScalerScript.scale_stat(int(stats["hp"]), battle.hex_stat_multiplier),
			"attack": EncounterScalerScript.scale_stat(int(stats["attack"]), battle.hex_stat_multiplier),
		})

	return battle


static func mix_seed(run_seed: int, floor: int, act: int, role: String, room_key: String) -> int:
	var mixed := run_seed & 0x7fffffff
	mixed = _mix(mixed, floor + 1)
	mixed = _mix(mixed, act + 3)
	mixed = _mix(mixed, _role_code(role))
	mixed = _mix(mixed, _string_code(room_key))
	return mixed


static func _materialize(template: Dictionary) -> Dictionary:
	var radius := int(template.get("radius", 3))
	var blocked: Array = []
	for pos in template.get("blocked", []):
		blocked.append(pos)

	var pits: Array = []
	if str(template.get("pit_fill", "listed")) == "all_except_keep":
		var keep := {}
		for pos in template.get("keep", []):
			keep[HexGridScript.key(pos)] = true
		for pos in HexGridScript.hexes_in_radius(radius):
			if not keep.has(HexGridScript.key(pos)):
				pits.append(pos)
	else:
		for pos in template.get("pits", []):
			pits.append(pos)

	return {"blocked": blocked, "pits": pits}


static func _role_code(role: String) -> int:
	match role:
		"battle":
			return 11
		"elite":
			return 23
		"boss":
			return 37
		_:
			return 5


static func _string_code(value: String) -> int:
	var code := 0
	for index in value.length():
		code = ((code * 33) + value.unicode_at(index)) & 0x7fffffff
	return code


static func _mix(value: int, salt: int) -> int:
	var mixed := (value ^ (salt & 0x7fffffff)) & 0x7fffffff
	mixed = (mixed * 1664525 + 1013904223) & 0x7fffffff
	return mixed
