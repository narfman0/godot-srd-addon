class_name ASISystem
extends RefCounted

# Standard ASI levels for most classes
const STANDARD_ASI_LEVELS: Array[int] = [4, 8, 12, 16, 19]
# Fighter (Soldier) gets extras
const SOLDIER_ASI_LEVELS: Array[int] = [4, 6, 8, 12, 14, 16, 19]
# Rogue (Ghost) gets an extra at 10
const GHOST_ASI_LEVELS: Array[int] = [4, 8, 10, 12, 16, 19]

const ABILITY_SCORE_CAP: int = 20  # normal cap; some features raise this

static func is_asi_level(class_data: ClassData, level: int) -> bool:
	match class_data.class_name_str:
		"Soldier": return level in SOLDIER_ASI_LEVELS
		"Ghost":   return level in GHOST_ASI_LEVELS
	return level in STANDARD_ASI_LEVELS

## Apply a single +2 (or custom amount) to one ability.
static func apply_single(char: CharacterStats, ability: SRD.Ability,
		amount: int = 2) -> bool:
	var current := char.get_ability(ability)
	if current >= ABILITY_SCORE_CAP:
		return false  # already capped
	char.set_ability(ability, mini(ABILITY_SCORE_CAP, current + amount))
	return true

## Apply +1 to two different abilities.
static func apply_split(char: CharacterStats,
		ability1: SRD.Ability, ability2: SRD.Ability) -> bool:
	assert(ability1 != ability2, "Split ASI must target two different abilities")
	apply_single(char, ability1, 1)
	apply_single(char, ability2, 1)
	return true

## Which abilities can still be improved (not yet at cap)?
static func improvable_abilities(char: CharacterStats) -> Array:
	var result: Array = []
	for ability in SRD.Ability.values():
		if char.get_ability(ability as SRD.Ability) < ABILITY_SCORE_CAP:
			result.append(ability)
	return result
