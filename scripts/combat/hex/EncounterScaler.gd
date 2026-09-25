class_name EncounterScaler
extends RefCounted

const TowerGeneratorScript := preload("res://scripts/tower/TowerGenerator.gd")

# Hex-combat baselines. Card-combat HP stays on EnemyDatabase and is scaled separately.
const HEX_STATS := {
	"charred_rat": {"hp": 10, "attack": 3},
	"furnace_cultist": {"hp": 14, "attack": 4},
	"furnace_hound": {"hp": 12, "attack": 5},
	"molten_guard": {"hp": 18, "attack": 5},
	"ash_zealot": {"hp": 16, "attack": 6},
	"ember_warden": {"hp": 22, "attack": 6},
	"cinder_colossus": {"hp": 26, "attack": 7},
	"bellows_saint": {"hp": 30, "attack": 7},
	"ember_regent": {"hp": 34, "attack": 8},
}

const PLAYER_HP := 78
const PLAYER_ATTACK := 12
const PLAYER_MOVE := 2
const ENEMY_MOVE := 1


static func hex_stats(enemy_id: String) -> Dictionary:
	return HEX_STATS.get(enemy_id, {})


static func hex_multiplier(floor: int, act: int, role: String) -> float:
	var value := 1.0
	value += float(maxi(floor, 1) - 1) * 0.05
	value += float(maxi(act, 1) - 1) * 0.12
	if role == "elite":
		value += 0.10
	elif role == "boss":
		value += 0.15
	return value


static func card_hp_multiplier(floor: int, act: int) -> float:
	return 1.0 + float(maxi(floor, 1) - 1) * 0.08 + float(maxi(act, 1) - 1) * 0.15


static func scale_stat(base: int, multiplier: float) -> int:
	return maxi(1, int(round(float(base) * multiplier)))


static func scale_card_hp(base_hp: int, floor: int, act: int) -> int:
	return scale_stat(base_hp, card_hp_multiplier(floor, act))


# Same floor/act anchors MapNavigator used before templates: the reward and
# fallback identity still climbs from rats to the act boss.
static func signature_encounter_id(floor: int, act: int, role: String) -> String:
	if role == "boss":
		if act >= 2:
			return "ember_regent"
		return "bellows_saint"

	if role == "elite":
		if act >= 2:
			return "cinder_colossus"
		return "ember_warden"

	if act >= 2:
		if floor >= TowerGeneratorScript.FLOOR_CONVERGENCE_BATTLE:
			return "ash_zealot"
		if floor == TowerGeneratorScript.FLOOR_FIRST_BATTLE:
			return "furnace_hound"
		return "molten_guard"

	if floor >= TowerGeneratorScript.FLOOR_CONVERGENCE_BATTLE:
		return "molten_guard"

	if floor == TowerGeneratorScript.FLOOR_FIRST_BATTLE:
		return "charred_rat"

	return "furnace_cultist"
