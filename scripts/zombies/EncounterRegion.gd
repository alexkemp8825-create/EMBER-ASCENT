class_name EncounterRegion
extends Node2D

## Optional biome/encounter filter for zombie looks.
## Empty list = use every globally registered visual variant.
## This does not generate biomes; it only exposes an allow-list hook.

@export var region_id: String = ""
@export var allowed_visual_variants: PackedStringArray = PackedStringArray()


func get_allowed_visual_variants() -> PackedStringArray:
	return allowed_visual_variants
