class_name RunActions
extends RefCounted

const REST_HEAL_FRACTION := 0.25
const SHRINE_HEAL_FRACTION := 0.4
const FORGE_MAX_HP_BONUS := 4
const OBSERVATORY_SCOUT_GOLD := 18


static func rest() -> int:
	var heal_amount := int(ceil(float(RunState.max_hp) * REST_HEAL_FRACTION))
	RunState.current_hp = min(RunState.current_hp + heal_amount, RunState.max_hp)
	return heal_amount


static func temper() -> int:
	RunState.max_hp += FORGE_MAX_HP_BONUS
	RunState.current_hp += FORGE_MAX_HP_BONUS
	return FORGE_MAX_HP_BONUS


static func scout() -> int:
	RunState.add_gold(OBSERVATORY_SCOUT_GOLD)
	return OBSERVATORY_SCOUT_GOLD


static func pray() -> Dictionary:
	var heal_amount := int(ceil(float(RunState.max_hp) * SHRINE_HEAL_FRACTION))
	RunState.current_hp = min(RunState.current_hp + heal_amount, RunState.max_hp)

	var relic_database := RelicDatabase.new()
	var relic_choices := relic_database.get_boss_reward_choices(1, RunState.relics)
	if relic_choices.is_empty():
		relic_database.free()
		return {
			"heal_amount": heal_amount,
			"relic_id": "",
			"relic_name": "",
		}

	var relic_data: RelicData = relic_choices[0]
	RunState.add_relic(relic_data.id)
	var relic_name := relic_data.display_name
	var relic_id := relic_data.id
	relic_database.free()
	return {
		"heal_amount": heal_amount,
		"relic_id": relic_id,
		"relic_name": relic_name,
	}
