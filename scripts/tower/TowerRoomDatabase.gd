extends RefCounted
class_name TowerRoomDatabase

const ROOM_ENTRANCE := "entrance"
const ROOM_BATTLE := "battle"
const ROOM_FORGE := "forge"
const ROOM_OBSERVATORY := "observatory"
const ROOM_MARKET := "market"
const ROOM_SHRINE := "shrine"
const ROOM_REST := "rest"
const ROOM_EVENT := "event"
const ROOM_BOSS := "boss"
const ROOM_GHOST := "ghost"

const GHOST_STRENGTH_LOW := "low"
const GHOST_STRENGTH_MEDIUM := "medium"
const GHOST_STRENGTH_HIGH := "high"

const ROOM_TYPES: Array[String] = [
	ROOM_ENTRANCE,
	ROOM_BATTLE,
	ROOM_FORGE,
	ROOM_OBSERVATORY,
	ROOM_MARKET,
	ROOM_SHRINE,
	ROOM_REST,
	ROOM_EVENT,
	ROOM_BOSS,
	ROOM_GHOST,
]

const DEFAULT_DISPLAY_NAMES := {
	ROOM_ENTRANCE: "Entrance",
	ROOM_BATTLE: "Battle",
	ROOM_FORGE: "Forge",
	ROOM_OBSERVATORY: "Observatory",
	ROOM_MARKET: "Market",
	ROOM_SHRINE: "Shrine",
	ROOM_REST: "Rest Chamber",
	ROOM_EVENT: "Strange Event",
	ROOM_BOSS: "Boss",
	ROOM_GHOST: "Ghost Echo",
}


static func is_valid_room_type(room_type: String) -> bool:
	return ROOM_TYPES.has(room_type)


static func get_default_display_name(room_type: String) -> String:
	return DEFAULT_DISPLAY_NAMES.get(room_type, room_type.capitalize())
