class_name RunUpgradeRules
extends RefCounted

## Offer, stacking, and build-summary rules for run upgrades.
##
## Draw rules:
## - A post-battle offer is up to 3 different upgrades. No duplicates in one draw.
## - An upgrade at max stacks leaves the pool.
## - Unique upgrades have max_stacks 1. Stackable upgrades can be offered again
##   until they reach max_stacks.
## - If fewer than 3 upgrades remain, the offer is shorter.
## - Skipping does not remove the upgrades from future offers.
##
## Theme weighting:
## - A non-foundation theme with total stacks >= COMMITTED_STACKS is "committed".
## - Upgrades in a committed theme are drawn at THEME_WEIGHT instead of 1.
## - Foundation (Soul / capacity / reserves) is never weighted up.
## - Several committed themes can be weighted at once.

const OFFER_SIZE := 3
const COMMITTED_STACKS := 2
const THEME_WEIGHT := 2
const BASE_WEIGHT := 1

const Database := preload("res://scripts/rewards/RunUpgradeDatabase.gd")


static func get_stacks(upgrade_id: String) -> int:
	return int(RunState.upgrade_stacks.get(upgrade_id, 0))


static func is_maxed(upgrade_id: String) -> bool:
	if not Database.has_upgrade(upgrade_id):
		return true
	return get_stacks(upgrade_id) >= Database.max_stacks(upgrade_id)


static func can_offer(upgrade_id: String) -> bool:
	return Database.has_upgrade(upgrade_id) and not is_maxed(upgrade_id)


static func apply_upgrade(upgrade_id: String) -> bool:
	if not can_offer(upgrade_id):
		return false

	var next_stacks := get_stacks(upgrade_id) + 1
	RunState.upgrade_stacks[upgrade_id] = next_stacks
	_apply_on_take(upgrade_id)
	return true


static func build_offer(count: int = OFFER_SIZE) -> Array[String]:
	var pool: Array = []
	for upgrade_id in Database.all_ids():
		if not can_offer(upgrade_id):
			continue
		pool.append({
			"id": upgrade_id,
			"weight": _offer_weight(upgrade_id),
		})

	var chosen: Array[String] = []
	while chosen.size() < count and not pool.is_empty():
		var index := _pick_weighted_index(pool)
		var entry: Dictionary = pool[index]
		chosen.append(str(entry.get("id", "")))
		pool.remove_at(index)

	return chosen


static func theme_stack_totals() -> Dictionary:
	var totals := {}
	for upgrade_id in RunState.upgrade_stacks.keys():
		var stacks := get_stacks(str(upgrade_id))
		if stacks <= 0:
			continue
		var theme := Database.theme_of(str(upgrade_id))
		totals[theme] = int(totals.get(theme, 0)) + stacks
	return totals


static func dominant_themes() -> Array[String]:
	var totals := theme_stack_totals()
	var best := 0
	for theme_id in totals.keys():
		if str(theme_id) == Database.THEME_FOUNDATION:
			continue
		best = maxi(best, int(totals[theme_id]))

	var dominant: Array[String] = []
	if best <= 0:
		return dominant

	for theme_id in Database.BUILD_THEMES:
		if int(totals.get(theme_id, 0)) == best:
			dominant.append(theme_id)
	return dominant


static func build_summary() -> String:
	var owned: Array[String] = []
	for upgrade_id in Database.all_ids():
		var stacks := get_stacks(upgrade_id)
		if stacks <= 0:
			continue
		var data := Database.get_upgrade(upgrade_id)
		owned.append("%s x%d" % [str(data.get("display_name", upgrade_id)), stacks])

	var upgrade_text := "none"
	if not owned.is_empty():
		upgrade_text = ", ".join(owned)

	var theme_names: Array[String] = []
	for theme_id in dominant_themes():
		theme_names.append(Database.theme_label(theme_id))

	var theme_text := "Unspecialized"
	if not theme_names.is_empty():
		theme_text = ", ".join(theme_names)

	return "Soul %d   Corpses %d\nUpgrades: %s\nBuild: %s" % [
		RunState.soul,
		RunState.corpses,
		upgrade_text,
		theme_text,
	]


static func _apply_on_take(upgrade_id: String) -> void:
	match upgrade_id:
		"soul_cache":
			RunState.soul += Database.effect_int(upgrade_id, "soul_on_take", 6)
		"ash_reserves":
			var bonus := Database.effect_int(upgrade_id, "max_hp_on_take", 4)
			RunState.max_hp += bonus
			RunState.current_hp += bonus
		_:
			pass


static func _offer_weight(upgrade_id: String) -> int:
	var theme := Database.theme_of(upgrade_id)
	if theme == Database.THEME_FOUNDATION:
		return BASE_WEIGHT
	if int(theme_stack_totals().get(theme, 0)) >= COMMITTED_STACKS:
		return THEME_WEIGHT
	return BASE_WEIGHT


static func _pick_weighted_index(pool: Array) -> int:
	var total := 0
	for entry in pool:
		total += int((entry as Dictionary).get("weight", BASE_WEIGHT))

	if total <= 0:
		return 0

	var roll := RNG.rand_int(1, total)
	var cursor := 0
	for index in range(pool.size()):
		cursor += int((pool[index] as Dictionary).get("weight", BASE_WEIGHT))
		if roll <= cursor:
			return index

	return pool.size() - 1
