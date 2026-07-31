class_name SRD
extends RefCounted

enum Ability {
	STRENGTH    = 0,
	DEXTERITY   = 1,
	CONSTITUTION = 2,
	INTELLIGENCE = 3,
	WISDOM      = 4,
	CHARISMA    = 5,
}

const ABILITY_NAMES: Array[String] = [
	"Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma",
]
const ABILITY_ABBREV: Array[String] = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

static func ability_name(ability: Ability) -> String:
	return ABILITY_NAMES[int(ability)]

static func ability_abbrev(ability: Ability) -> String:
	return ABILITY_ABBREV[int(ability)]

enum Condition {
	BLINDED        = 0,
	CHARMED        = 1,
	DEAFENED       = 2,
	FRIGHTENED     = 3,
	GRAPPLED       = 4,
	INCAPACITATED  = 5,
	INVISIBLE      = 6,
	PARALYZED      = 7,
	PETRIFIED      = 8,
	POISONED       = 9,
	PRONE          = 10,
	RESTRAINED     = 11,
	STUNNED        = 12,
	UNCONSCIOUS    = 13,
	DEAD           = 14,
}

enum Skill {
	ACROBATICS      = 0,
	ANIMAL_HANDLING = 1,
	ARCANA          = 2,
	ATHLETICS       = 3,
	DECEPTION       = 4,
	HISTORY         = 5,
	INSIGHT         = 6,
	INTIMIDATION    = 7,
	INVESTIGATION   = 8,
	MEDICINE        = 9,
	NATURE          = 10,
	PERCEPTION      = 11,
	PERFORMANCE     = 12,
	PERSUASION      = 13,
	RELIGION        = 14,
	SLEIGHT_OF_HAND = 15,
	STEALTH         = 16,
	SURVIVAL        = 17,
}

enum DamageType {
	ACID         = 0,
	BLUDGEONING  = 1,
	COLD         = 2,
	FIRE         = 3,
	FORCE        = 4,
	LIGHTNING    = 5,
	NECROTIC     = 6,
	PIERCING     = 7,
	POISON       = 8,
	PSYCHIC      = 9,
	RADIANT      = 10,
	SLASHING     = 11,
	THUNDER      = 12,
}

enum Cover { NONE, HALF, THREE_QUARTERS, FULL }

enum ArmorType { NONE, LIGHT, MEDIUM, HEAVY, SHIELD }

enum WeaponType { SIMPLE, MARTIAL }

# Bit flags — combine with bitwise OR
enum WeaponProperty {
	FINESSE     = 1,
	VERSATILE   = 2,
	REACH       = 4,
	THROWN      = 8,
	TWO_HANDED  = 16,
	LIGHT       = 32,
	AMMUNITION  = 64,
	LOADING     = 128,
	SPECIAL     = 256,
}

enum SlotProgression { NONE, FULL, HALF, THIRD }

enum AoEShape { SPHERE, CONE, LINE, CUBE, CYLINDER }

enum SaveEffect { NONE, HALF }
