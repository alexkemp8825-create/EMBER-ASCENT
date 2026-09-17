class_name ZombieLimbSlots
extends Object

## Shared limb slot ids. Mutation (later) overrides equipped, which overrides
## the visual variant default. Do not invent a second sprite hierarchy.

const HEAD := 0
const BODY := 1
const LEFT_HAND := 2
const RIGHT_HAND := 3
const LEFT_FOOT := 4
const RIGHT_FOOT := 5
const ACCESSORY := 6
const BACK_ACCESSORY := 7

const ALL := [
	HEAD,
	BODY,
	LEFT_HAND,
	RIGHT_HAND,
	LEFT_FOOT,
	RIGHT_FOOT,
	ACCESSORY,
	BACK_ACCESSORY,
]


static func slot_name(slot: int) -> String:
	match slot:
		HEAD:
			return "head"
		BODY:
			return "body"
		LEFT_HAND:
			return "left_hand"
		RIGHT_HAND:
			return "right_hand"
		LEFT_FOOT:
			return "left_foot"
		RIGHT_FOOT:
			return "right_foot"
		ACCESSORY:
			return "accessory"
		BACK_ACCESSORY:
			return "back_accessory"
		_:
			return "unknown"
