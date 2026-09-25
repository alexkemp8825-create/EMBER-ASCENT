class_name HexBattle
extends RefCounted

var template_id: String = ""
var template_name: String = ""
var summary: String = ""
var seed: int = 0
var room_key: String = ""
var floor: int = 1
var act: int = 1
var role: String = "battle"
var radius: int = 3
var player_spawn: Vector2i = Vector2i.ZERO
var enemies: Array = []
var blocked: Array = []
var pits: Array = []
var hazards: Array = []
var corpses: Array = []
var objective_type: String = "kill_all"
var objective_label: String = ""
var objective_hex: Vector2i = Vector2i.ZERO
var objective_turns: int = 0
var has_objective_hex: bool = false
var hex_stat_multiplier: float = 1.0
var card_hp_multiplier: float = 1.0
var signature_encounter_id: String = ""


func context_label() -> String:
	return "template=%s seed=%d floor=%d act=%d role=%s room=%s" % [
		template_id,
		seed,
		floor,
		act,
		role,
		room_key,
	]


func foe_names() -> String:
	var names: Array = []
	for enemy in enemies:
		names.append(str(enemy.get("id", "")))
	return ", ".join(names)


func briefing() -> String:
	return "Objective: %s. Foes: %s. Blocked %d, pits %d, hazards %d, corpses %d." % [
		objective_label,
		foe_names(),
		blocked.size(),
		pits.size(),
		hazards.size(),
		corpses.size(),
	]
