class_name EncounterTable
extends RefCounted

## Most tower fights are a single enemy. A few packs exist so corpse
## explosions and minion focus have a real second target.

const PACKS := {
	"cultist_pack": ["furnace_cultist", "charred_rat"],
	"hound_pack": ["furnace_hound", "charred_rat"],
}


static func enemy_ids_for(encounter_id: String) -> Array[String]:
	var ids: Array[String] = []
	var packed: Variant = PACKS.get(encounter_id, [])
	if packed is Array and not (packed as Array).is_empty():
		for enemy_id in packed:
			ids.append(str(enemy_id))
		return ids

	if encounter_id == "":
		ids.append("charred_rat")
		return ids

	ids.append(encounter_id)
	return ids


static func is_pack(encounter_id: String) -> bool:
	return PACKS.has(encounter_id)
