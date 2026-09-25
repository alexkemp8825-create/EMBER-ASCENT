extends SceneTree

const EncounterDirectorScript := preload("res://scripts/combat/hex/EncounterDirector.gd")
const EncounterTemplateDatabaseScript := preload("res://scripts/combat/hex/EncounterTemplateDatabase.gd")
const EncounterScalerScript := preload("res://scripts/combat/hex/EncounterScaler.gd")
const HexBattleSimulatorScript := preload("res://scripts/combat/hex/HexBattleSimulator.gd")
const EnemyDatabaseScript := preload("res://scripts/enemies/EnemyDatabase.gd")
const TowerStateScript := preload("res://scripts/tower/TowerState.gd")

const RUN_COUNT := 100
const ACT_SEED_OFFSET := 9973
const MAX_FAILURES := 12


func _init() -> void:
	quit(_run())


func _run() -> int:
	print("=== 100-RUN ENCOUNTER VERIFICATION ===")
	print("Godot: %s" % Engine.get_version_info()["string"])

	var templates: Array = EncounterTemplateDatabaseScript.all_templates()
	if templates.size() < 5 or templates.size() > 8:
		print("FAIL template count %d is outside 5-8" % templates.size())
		return 1

	print("Templates loaded: %d" % templates.size())
	for template in templates:
		print("- %s: %s" % [template["id"], template["summary"]])

	var anchor_error := _verify_difficulty_anchors()
	if anchor_error != "":
		print("FAIL difficulty anchor %s" % anchor_error)
		return 1
	print("Difficulty anchors: PASS")

	var exercise_error := _exercise_every_template()
	if exercise_error != "":
		print("FAIL direct exercise %s" % exercise_error)
		return 1
	print("Direct exercise: %d/%d templates won at easiest and hardest legal context" % [templates.size(), templates.size()])

	var counts := {}
	for template in templates:
		counts[str(template["id"])] = 0

	var battles := 0
	var failures: Array = []
	var enemy_database := EnemyDatabaseScript.new()

	for run_index in range(1, RUN_COUNT + 1):
		var run_seed := 5000 + run_index
		for act_number in [1, 2]:
			var act := int(act_number)
			var tower_seed := run_seed + (act - 1) * ACT_SEED_OFFSET
			var tower: TowerState = TowerStateScript.new()
			tower.create_new_tower(tower_seed, act)
			for room in tower.rooms:
				var role := EncounterDirectorScript.role_for_room_type(room.room_type)
				if role == "":
					continue
				var battle: HexBattle = EncounterDirectorScript.build_for_room(run_seed, room, act)
				battles += 1
				if battle == null:
					_add_failure(failures, "null battle seed=%d floor=%d act=%d role=%s room=%s" % [
						run_seed, room.floor, act, role, room.room_id
					])
					continue
				counts[battle.template_id] = int(counts.get(battle.template_id, 0)) + 1
				var replay: HexBattle = EncounterDirectorScript.build_for_room(run_seed, room, act)
				if replay == null or not _same_battle(battle, replay):
					_add_failure(failures, "seed replay diverged %s" % battle.context_label())
				var reason := HexBattleSimulatorScript.validate(battle)
				if reason != "":
					_add_failure(failures, "%s reason=%s" % [battle.context_label(), reason])
				for enemy in battle.enemies:
					if enemy_database.get_enemy(str(enemy["id"])) == null:
						_add_failure(failures, "card database missing %s on %s" % [enemy["id"], battle.context_label()])
				if failures.size() >= MAX_FAILURES:
					break
			if failures.size() >= MAX_FAILURES:
				break
		if failures.size() >= MAX_FAILURES:
			break

	print("Runs: %d" % RUN_COUNT)
	print("Battles generated: %d" % battles)
	print("Selection counts:")
	var missing: Array = []
	for template in templates:
		var template_id := str(template["id"])
		var count := int(counts.get(template_id, 0))
		print("  %s: %d" % [template_id, count])
		if count <= 0:
			missing.append(template_id)

	if not missing.is_empty():
		print("FAIL templates never selected: %s" % ", ".join(missing))
		failures.append("missing selection")

	if not failures.is_empty():
		print("Failures: %d" % failures.size())
		for failure in failures:
			print("FAIL %s" % failure)
		print("Result: FAIL")
		print("=== END ===")
		enemy_database.free()
		return 1

	print("Spawn violations: 0")
	print("Reachability failures: 0")
	print("Unwinnable battles: 0")
	print("Reproducibility: PASS")
	enemy_database.free()
	print("Result: PASS")
	print("=== END ===")
	return 0


func _exercise_every_template() -> String:
	for template in EncounterTemplateDatabaseScript.all_templates():
		var roles: Array = template["roles"]
		var acts: Array = template["acts"]
		var contexts: Array = [
			{
				"floor": int(template["min_floor"]),
				"act": int(acts[0]),
				"role": str(roles[0]),
			},
			{
				"floor": int(template["max_floor"]),
				"act": int(acts[acts.size() - 1]),
				"role": _hardest_role(roles),
			},
		]
		for context in contexts:
			var battle: HexBattle = EncounterDirectorScript.build_from_template(
				template,
				9100,
				int(context["floor"]),
				int(context["act"]),
				str(context["role"]),
				"direct_%s" % template["id"]
			)
			if battle == null or battle.template_id != str(template["id"]):
				return "failed to load %s" % template["id"]
			var reason := HexBattleSimulatorScript.validate(battle)
			if reason != "":
				return "%s %s" % [battle.context_label(), reason]
	return ""


func _verify_difficulty_anchors() -> String:
	var expected := [
		[1, 1, "battle", "charred_rat"],
		[2, 1, "battle", "furnace_cultist"],
		[3, 1, "battle", "molten_guard"],
		[1, 2, "battle", "furnace_hound"],
		[2, 2, "battle", "molten_guard"],
		[3, 2, "battle", "ash_zealot"],
		[2, 1, "elite", "ember_warden"],
		[2, 2, "elite", "cinder_colossus"],
		[5, 1, "boss", "bellows_saint"],
		[5, 2, "boss", "ember_regent"],
	]
	for row in expected:
		var actual := EncounterScalerScript.signature_encounter_id(int(row[0]), int(row[1]), str(row[2]))
		if actual != str(row[3]):
			return "floor %s act %s role %s got %s expected %s" % [row[0], row[1], row[2], actual, row[3]]
		var low := EncounterScalerScript.hex_multiplier(1, 1, "battle")
		var high := EncounterScalerScript.hex_multiplier(int(row[0]), int(row[1]), str(row[2]))
		if int(row[0]) > 1 or int(row[1]) > 1 or str(row[2]) != "battle":
			if high <= low:
				return "multiplier did not increase for %s" % row
	var early_hp := EncounterScalerScript.scale_card_hp(22, 1, 1)
	var late_hp := EncounterScalerScript.scale_card_hp(22, 5, 2)
	if early_hp != 22 or late_hp <= early_hp:
		return "card hp scale early=%d late=%d" % [early_hp, late_hp]
	return ""


func _hardest_role(roles: Array) -> String:
	if roles.has("boss"):
		return "boss"
	if roles.has("elite"):
		return "elite"
	return "battle"


func _same_battle(left: HexBattle, right: HexBattle) -> bool:
	if left.template_id != right.template_id:
		return false
	if left.player_spawn != right.player_spawn:
		return false
	if left.enemies.size() != right.enemies.size():
		return false
	if left.objective_type != right.objective_type:
		return false
	for index in left.enemies.size():
		if left.enemies[index]["id"] != right.enemies[index]["id"]:
			return false
		if int(left.enemies[index]["hp"]) != int(right.enemies[index]["hp"]):
			return false
		if left.enemies[index]["pos"] != right.enemies[index]["pos"]:
			return false
	return true


func _add_failure(failures: Array, message: String) -> void:
	failures.append(message)
	push_error(message)
