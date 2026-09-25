class_name RunUpgradeDatabase
extends RefCounted

## Data-driven run upgrades.
## Foundation rewards (Soul, capacity, reserves) stay in the pool.
## The other entries are build-theme upgrades. Magnitudes live in `effect`
## so combat and the simulator share one source of truth.

const THEME_FOUNDATION := "foundation"
const THEME_RAISE := "raise"
const THEME_DETONATION := "detonation"
const THEME_COMMANDER := "commander"
const THEME_CONTROL := "control"
const THEME_SKELETON := "skeleton"
const THEME_BRUTE := "brute"
const THEME_SOUL := "soul"

const SKELETON_BASE_HP := 6
const SKELETON_BASE_ATTACK := 2
const BRUTE_BASE_HP := 14
const BRUTE_BASE_ATTACK := 6
const CORPSE_CAP := 5
const MINION_CAP := 4

const THEME_LABELS := {
	THEME_FOUNDATION: "Foundation",
	THEME_RAISE: "Raise",
	THEME_DETONATION: "Corpse Explosion",
	THEME_COMMANDER: "Commander",
	THEME_CONTROL: "Movement/Control",
	THEME_SKELETON: "Skeleton",
	THEME_BRUTE: "Brute",
	THEME_SOUL: "Soul Economy",
}

const BUILD_THEMES: Array[String] = [
	THEME_RAISE,
	THEME_DETONATION,
	THEME_COMMANDER,
	THEME_CONTROL,
	THEME_SKELETON,
	THEME_BRUTE,
	THEME_SOUL,
]

const UPGRADES := {
	"soul_cache": {
		"id": "soul_cache",
		"display_name": "Soul Cache",
		"theme": THEME_FOUNDATION,
		"max_stacks": 3,
		"summary": "Bank Soul now, and a little more after every victory.",
		"description": "Gain 6 Soul. Each stack also grants 2 Soul whenever you win a fight.",
		"effect": {
			"soul_on_take": 6,
			"soul_per_stack_on_victory": 2,
		},
	},
	"ember_capacity": {
		"id": "ember_capacity",
		"display_name": "Ember Capacity",
		"theme": THEME_FOUNDATION,
		"max_stacks": 1,
		"summary": "Your flame holds more energy on the opening turn.",
		"description": "On the first turn of each combat, gain 1 extra Energy.",
		"effect": {
			"energy_per_stack": 1,
		},
	},
	"ash_reserves": {
		"id": "ash_reserves",
		"display_name": "Ash Reserves",
		"theme": THEME_FOUNDATION,
		"max_stacks": 3,
		"summary": "Stoke a reserve of health and opening block.",
		"description": "Gain 4 Max HP. Each stack grants 3 Block at the start of combat.",
		"effect": {
			"max_hp_on_take": 4,
			"block_per_stack": 3,
		},
	},
	"grave_call": {
		"id": "grave_call",
		"display_name": "Grave Call",
		"theme": THEME_RAISE,
		"max_stacks": 2,
		"summary": "Spend corpses to raise skeletons, or brutes if you know the rite.",
		"description": "At the start of your turn, Raise once per stack. A Raise spends 1 Corpse for a Skeleton, or 2 Corpses for a Brute if you have Brute Summons.",
		"effect": {
			"raises_per_stack": 1,
		},
	},
	"unfinished_rite": {
		"id": "unfinished_rite",
		"display_name": "Unfinished Rite",
		"theme": THEME_RAISE,
		"max_stacks": 1,
		"summary": "The first minion to fall each fight stands back up.",
		"description": "The first time a minion would die each combat, it survives at 1 HP and attacks immediately.",
		"effect": {},
	},
	"chorus_of_ash": {
		"id": "chorus_of_ash",
		"display_name": "Chorus of Ash",
		"theme": THEME_RAISE,
		"max_stacks": 2,
		"summary": "Every raising pulls another card into your hand.",
		"description": "Whenever you Raise a minion, draw 1 card. Each stack allows one such draw per turn.",
		"effect": {
			"draws_per_stack": 1,
		},
	},
	"cinder_corpse": {
		"id": "cinder_corpse",
		"display_name": "Cinder Corpse",
		"theme": THEME_DETONATION,
		"max_stacks": 3,
		"summary": "The dead burst, now or at the next battle's opening.",
		"description": "When an enemy dies with another foe still standing, it explodes for 5 damage per stack to each living enemy. A killing blow instead stores 6 damage per stack as opening pyre for the next fight (max 16).",
		"effect": {
			"splash_per_stack": 5,
			"pyre_per_stack": 6,
			"pyre_cap": 16,
		},
	},
	"pyre_funeral": {
		"id": "pyre_funeral",
		"display_name": "Pyre Funeral",
		"theme": THEME_DETONATION,
		"max_stacks": 2,
		"summary": "When your own dead fall, the enemy catches fire.",
		"description": "When one of your minions dies, deal 6 damage per stack to a living enemy and gain 1 Soul per stack.",
		"effect": {
			"damage_per_stack": 6,
			"soul_per_stack": 1,
		},
	},
	"chain_ash": {
		"id": "chain_ash",
		"display_name": "Chain Ash",
		"theme": THEME_DETONATION,
		"max_stacks": 1,
		"summary": "Explosions leave a burn that keeps eating.",
		"description": "Each victory primes 3 Burn on the next fight. Cinder Corpse and Pyre Funeral also apply 3 Burn to every enemy they damage.",
		"effect": {
			"burn": 3,
		},
	},
	"hold_the_line": {
		"id": "hold_the_line",
		"display_name": "Hold the Line",
		"theme": THEME_COMMANDER,
		"max_stacks": 1,
		"summary": "Your guard does not vanish when the turn turns.",
		"description": "At the start of your turn, keep half of your Block (rounded down) instead of losing it.",
		"effect": {
			"retain_numerator": 1,
			"retain_denominator": 2,
		},
	},
	"interpose": {
		"id": "interpose",
		"display_name": "Interpose",
		"theme": THEME_COMMANDER,
		"max_stacks": 1,
		"summary": "A minion steps into the first blow each enemy turn.",
		"description": "While a minion lives, the first enemy attack each enemy turn hits your lowest-HP minion instead of you.",
		"effect": {},
	},
	"last_ember": {
		"id": "last_ember",
		"display_name": "Last Ember",
		"theme": THEME_COMMANDER,
		"max_stacks": 1,
		"summary": "Once each fight, death refuses you.",
		"description": "The first time you would drop to 0 HP each combat, remain at 1 HP and gain 6 Block.",
		"effect": {
			"survive_hp": 1,
			"block": 6,
		},
	},
	"ember_step": {
		"id": "ember_step",
		"display_name": "Ember Step",
		"theme": THEME_CONTROL,
		"max_stacks": 2,
		"summary": "Move first: more cards, then a cheaper skill.",
		"description": "Draw 1 extra card each turn. At 2 stacks, the first Skill you play each turn costs 1 less Energy.",
		"effect": {
			"bonus_draw": 1,
			"skill_discount_min_stacks": 2,
			"skill_discount": 1,
		},
	},
	"break_intent": {
		"id": "break_intent",
		"display_name": "Break Intent",
		"theme": THEME_CONTROL,
		"max_stacks": 2,
		"summary": "Foes swing lighter, and their first surge falters.",
		"description": "Enemy attacks deal 2 less damage per stack. The first time an enemy would gain Strength each combat, that gain is reduced by 2. At 2 stacks, an attack telegraphed by a heavy breath deals half damage.",
		"effect": {
			"damage_reduction_per_stack": 2,
			"strength_cut": 2,
			"halve_min_stacks": 2,
		},
	},
	"bone_ranks": {
		"id": "bone_ranks",
		"display_name": "Bone Ranks",
		"theme": THEME_SKELETON,
		"max_stacks": 2,
		"summary": "A free skeleton opens the fight, and your dead hit harder.",
		"description": "At the start of combat, Raise one Skeleton for free. Each stack gives your Skeletons +3 HP and +1 attack.",
		"effect": {
			"hp_per_stack": 3,
			"attack_per_stack": 1,
			"free_summon_min_stacks": 1,
		},
	},
	"rattling_volley": {
		"id": "rattling_volley",
		"display_name": "Rattling Volley",
		"theme": THEME_SKELETON,
		"max_stacks": 2,
		"summary": "Cheap attacks drag a volley out of your skeletons.",
		"description": "Whenever you play an Attack that costs 1 or less, each living Skeleton deals 2 damage per stack to the target.",
		"effect": {
			"damage_per_stack": 2,
			"max_card_cost": 1,
		},
	},
	"brute_summons": {
		"id": "brute_summons",
		"display_name": "Brute Summons",
		"theme": THEME_BRUTE,
		"max_stacks": 2,
		"summary": "Spend two corpses on a heavy raised brute.",
		"description": "Raises spend 2 Corpses to summon a Brute instead of a Skeleton when you can. Without Grave Call, you still Raise one Brute per combat if you have the corpses. Each stack gives Brutes +4 HP and +2 attack. At 2 stacks, a Brute gains 4 Block when raised.",
		"effect": {
			"corpse_cost": 2,
			"hp_per_stack": 4,
			"attack_per_stack": 2,
			"block_at_stacks": 2,
			"block_amount": 4,
		},
	},
	"crushing_swing": {
		"id": "crushing_swing",
		"display_name": "Crushing Swing",
		"theme": THEME_BRUTE,
		"max_stacks": 2,
		"summary": "Heavy attacks land harder, and a brute makes them worse.",
		"description": "Attacks that cost 2 or more deal 3 extra damage per stack. While a Brute is alive, they deal 2 more.",
		"effect": {
			"damage_per_stack": 3,
			"brute_bonus": 2,
			"min_cost": 2,
		},
	},
	"soul_interest": {
		"id": "soul_interest",
		"display_name": "Soul Interest",
		"theme": THEME_SOUL,
		"max_stacks": 3,
		"summary": "Soul you already hold earns a dividend after each fight.",
		"description": "On victory, gain 2 Soul per stack plus 1 Soul per 5 Soul you hold, up to 6 bonus Soul.",
		"effect": {
			"flat_per_stack": 2,
			"interest_divisor": 5,
			"interest_cap": 6,
		},
	},
	"tithe_blade": {
		"id": "tithe_blade",
		"display_name": "Tithe Blade",
		"theme": THEME_SOUL,
		"max_stacks": 2,
		"summary": "Attacks tithe Soul, and a full tithe empowers the next blow.",
		"description": "The first time an Attack deals damage each play, gain 1 Soul per stack. When you have 12 Soul, your next Attack spends 12 Soul and deals 5 extra damage.",
		"effect": {
			"soul_per_stack": 1,
			"spend_threshold": 12,
			"bonus_damage": 5,
		},
	},
}


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for upgrade_id in UPGRADES.keys():
		ids.append(str(upgrade_id))
	ids.sort()
	return ids


static func get_upgrade(upgrade_id: String) -> Dictionary:
	var data: Variant = UPGRADES.get(upgrade_id, {})
	if not data is Dictionary:
		return {}
	return (data as Dictionary).duplicate(true)


static func has_upgrade(upgrade_id: String) -> bool:
	return UPGRADES.has(upgrade_id)


static func theme_label(theme_id: String) -> String:
	return str(THEME_LABELS.get(theme_id, theme_id))


static func effect_int(upgrade_id: String, key: String, fallback: int = 0) -> int:
	var data := get_upgrade(upgrade_id)
	var effect: Variant = data.get("effect", {})
	if not effect is Dictionary:
		return fallback
	return int((effect as Dictionary).get(key, fallback))


static func max_stacks(upgrade_id: String) -> int:
	return int(get_upgrade(upgrade_id).get("max_stacks", 1))


static func theme_of(upgrade_id: String) -> String:
	return str(get_upgrade(upgrade_id).get("theme", ""))
