extends Node

const Database := preload("res://scripts/rewards/RunUpgradeDatabase.gd")
const Rules := preload("res://scripts/rewards/RunUpgradeRules.gd")


func _ready() -> void:
	var failed := 0
	failed += _test_catalog()
	failed += _test_stacking_and_offers()
	failed += _test_weighting()
	failed += _test_save_roundtrip()
	failed += _test_combat_hooks()
	failed += _test_screens()
	if failed == 0:
		print("RUN UPGRADE TESTS PASSED")
		get_tree().quit(0)
	else:
		print("RUN UPGRADE TESTS FAILED: %d" % failed)
		get_tree().quit(1)


func _test_catalog() -> int:
	var build_counts := {}
	for theme_id in Database.BUILD_THEMES:
		build_counts[theme_id] = 0

	var new_count := 0
	var foundation := 0
	for upgrade_id in Database.all_ids():
		var data := Database.get_upgrade(upgrade_id)
		if str(data.get("description", "")) == "":
			return _fail("missing description for %s" % upgrade_id)
		var max_stacks := int(data.get("max_stacks", 0))
		if max_stacks < 1:
			return _fail("bad max stacks for %s" % upgrade_id)
		var theme := str(data.get("theme", ""))
		if theme == Database.THEME_FOUNDATION:
			foundation += 1
		elif build_counts.has(theme):
			build_counts[theme] = int(build_counts[theme]) + 1
			new_count += 1
		else:
			return _fail("unknown theme %s" % theme)

	if foundation != 3:
		return _fail("expected 3 foundation rewards, got %d" % foundation)
	if new_count < 12 or new_count > 18:
		return _fail("expected 12-18 new upgrades, got %d" % new_count)
	for theme_id in Database.BUILD_THEMES:
		var count := int(build_counts[theme_id])
		if count < 2 or count > 3:
			return _fail("theme %s has %d upgrades" % [theme_id, count])
	print("catalog ok (%d new upgrades)" % new_count)
	return 0


func _test_stacking_and_offers() -> int:
	_fresh_run()
	if not Rules.apply_upgrade("soul_cache"):
		return _fail("soul cache should apply")
	if RunState.soul != 6 or Rules.get_stacks("soul_cache") != 1:
		return _fail("soul cache on-take failed")
	Rules.apply_upgrade("soul_cache")
	Rules.apply_upgrade("soul_cache")
	if Rules.apply_upgrade("soul_cache"):
		return _fail("soul cache exceeded max stacks")
	if Rules.can_offer("soul_cache"):
		return _fail("maxed soul cache stayed in the pool")

	Rules.apply_upgrade("ash_reserves")
	if RunState.max_hp != 79:
		return _fail("reserves did not grant max hp")

	for _index in range(120):
		var offer := Rules.build_offer(3)
		if offer.size() != 3:
			return _fail("offer size %d" % offer.size())
		var seen := {}
		for upgrade_id in offer:
			if seen.has(upgrade_id):
				return _fail("duplicate offer %s" % upgrade_id)
			if upgrade_id == "soul_cache":
				return _fail("maxed upgrade was offered")
			seen[upgrade_id] = true

	print("stacking and offers ok")
	return 0


func _test_weighting() -> int:
	_fresh_run()
	RunState.upgrade_stacks["grave_call"] = 2
	var chorus := 0
	var step := 0
	for _index in range(700):
		var offer := Rules.build_offer(3)
		if offer.has("chorus_of_ash"):
			chorus += 1
		if offer.has("ember_step"):
			step += 1
	if chorus <= step:
		return _fail("theme weight did not favor chorus (%d) over ember step (%d)" % [chorus, step])
	print("weighting ok chorus=%d ember_step=%d" % [chorus, step])
	return 0


func _test_save_roundtrip() -> int:
	_fresh_run()
	RunState.soul = 11
	RunState.corpses = 3
	RunState.opening_pyre_damage = 8
	RunState.upgrade_stacks["bone_ranks"] = 2
	var data := RunState.serialize()
	RunState.reset_run()
	RunState.deserialize(data)
	if RunState.soul != 11 or RunState.corpses != 3 or RunState.opening_pyre_damage != 8:
		return _fail("save lost run resources")
	if int(RunState.upgrade_stacks.get("bone_ranks", 0)) != 2:
		return _fail("save lost upgrade stacks")
	var summary := Rules.build_summary()
	if not summary.contains("Bone Ranks x2") or not summary.contains("Skeleton"):
		return _fail("build summary missing owned upgrade: %s" % summary)
	print("save and build summary ok")
	return 0


func _test_combat_hooks() -> int:
	_fresh_run()
	RunState.deck = ["guard_up", "guard_up", "guard_up", "guard_up", "ember_strike"]
	RunState.relics.clear()
	RunState.upgrade_stacks["hold_the_line"] = 1
	RNG.set_seed(3)
	var session := CombatSession.new()
	session.start("charred_rat")
	for card_instance in session.hand.duplicate():
		var card_data := CardDatabase.new().get_card(card_instance.card_id)
		if card_data != null and card_data.id == "guard_up":
			session.play_card(card_instance)
	if session.block != 15:
		return _fail("expected 15 block before enemy turn, got %d" % session.block)
	session.end_turn()
	if session.turn_number != 2 or session.block != 5:
		return _fail("hold the line kept block %d on turn %d" % [session.block, session.turn_number])

	_fresh_run()
	RunState.corpses = 1
	RunState.upgrade_stacks["grave_call"] = 1
	RunState.relics.clear()
	session = CombatSession.new()
	session.start("charred_rat")
	if session.living_minion_count() != 1 or RunState.corpses != 0:
		return _fail("grave call did not spend a corpse to raise")

	_fresh_run()
	RunState.upgrade_stacks["ember_capacity"] = 1
	RunState.relics.clear()
	session = CombatSession.new()
	session.start("charred_rat")
	if session.max_energy() != 4 or session.energy != 4:
		return _fail("capacity did not raise energy")

	_fresh_run()
	RunState.upgrade_stacks["cinder_corpse"] = 1
	RunState.relics.clear()
	RunState.deck.clear()
	for _index in range(8):
		RunState.deck.append("ember_strike")
	var ai := CombatAI.new()
	if not ai.fight("charred_rat"):
		return _fail("starter strikes should defeat a charred rat")
	if RunState.opening_pyre_damage != 6 or RunState.corpses != 0:
		return _fail("cinder corpse pyre=%d corpses=%d" % [RunState.opening_pyre_damage, RunState.corpses])

	_fresh_run()
	RunState.upgrade_stacks["cinder_corpse"] = 1
	RunState.relics.clear()
	RunState.deck = ["ember_strike", "ember_strike", "ember_strike", "ember_strike", "ember_strike"]
	session = CombatSession.new()
	session.start("cultist_pack")
	session.enemies[1].hp = 1
	session.select_enemy(1)
	var played := false
	for card_instance in session.hand.duplicate():
		if card_instance.card_id == "ember_strike" and session.play_card(card_instance):
			played = true
			break
	if not played:
		return _fail("could not play a strike into the pack")
	if session.enemies[0].hp != 30:
		return _fail("splash left cultist at %d hp" % session.enemies[0].hp)

	_fresh_run()
	RunState.deck.clear()
	for _index in range(10):
		RunState.deck.append("ember_strike")
	RunState.relics = ["cracked_helm"]
	if not ai.fight("charred_rat"):
		return _fail("baseline combat should win against a charred rat")

	print("combat hooks ok")
	return 0


func _test_screens() -> int:
	_fresh_run()
	RunState.create_new_tower()
	var reward_scene := load("res://scenes/rewards/RewardScreen.tscn") as PackedScene
	var reward := reward_scene.instantiate()
	add_child(reward)
	reward.set_payload({
		"gold": 12,
		"is_boss": false,
		"card_choices": ["heavy_strike"],
		"relic_choices": [],
		"upgrade_choices": ["grave_call", "bone_ranks", "ember_capacity"],
	})
	if reward.get_node_or_null("%UpgradeChoicesContainer") == null:
		return _fail("reward screen is missing upgrade choices")
	if reward.get_node_or_null("%UpgradeChoicesContainer").get_child_count() != 3:
		return _fail("reward screen did not offer 3 upgrades")
	reward._on_upgrade_selected("grave_call")
	if Rules.get_stacks("grave_call") != 1:
		return _fail("reward screen did not apply grave call")
	reward.queue_free()

	var map_scene := load("res://scenes/map/MapScreen.tscn") as PackedScene
	var map_screen := map_scene.instantiate()
	add_child(map_screen)
	var build_text := str(map_screen.get_node("%BuildLabel").text)
	if not build_text.contains("Grave Call x1"):
		return _fail("map build label missing upgrade: %s" % build_text)
	if not build_text.contains("Raise"):
		return _fail("map build label missing theme: %s" % build_text)
	map_screen.queue_free()
	print("screens ok")
	return 0


func _fresh_run() -> void:
	RunState.reset_run()
	RunState.selected_class = "ash_knight"
	RunState.max_hp = 75
	RunState.current_hp = 75
	RunState.gold = 99
	RunState.deck = ["ember_strike", "ember_strike", "guard_up", "guard_up", "burning_oath"]
	RunState.relics = ["cracked_helm"]
	RNG.set_seed(42)


func _fail(message: String) -> int:
	push_error(message)
	print("FAIL: ", message)
	return 1
