class_name SRDSkills
extends RefCounted

# Maps SRD.Skill → governing SRD.Ability (static, never changes)
const SKILL_ABILITY: Array[int] = [
	SRD.Ability.DEXTERITY,    # ACROBATICS
	SRD.Ability.WISDOM,       # ANIMAL_HANDLING
	SRD.Ability.INTELLIGENCE, # ARCANA
	SRD.Ability.STRENGTH,     # ATHLETICS
	SRD.Ability.CHARISMA,     # DECEPTION
	SRD.Ability.INTELLIGENCE, # HISTORY
	SRD.Ability.WISDOM,       # INSIGHT
	SRD.Ability.CHARISMA,     # INTIMIDATION
	SRD.Ability.INTELLIGENCE, # INVESTIGATION
	SRD.Ability.WISDOM,       # MEDICINE
	SRD.Ability.INTELLIGENCE, # NATURE
	SRD.Ability.WISDOM,       # PERCEPTION
	SRD.Ability.CHARISMA,     # PERFORMANCE
	SRD.Ability.CHARISMA,     # PERSUASION
	SRD.Ability.INTELLIGENCE, # RELIGION
	SRD.Ability.DEXTERITY,    # SLEIGHT_OF_HAND
	SRD.Ability.DEXTERITY,    # STEALTH
	SRD.Ability.WISDOM,       # SURVIVAL
]

const SKILL_NAMES: Array[String] = [
	"Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception",
	"History", "Insight", "Intimidation", "Investigation", "Medicine",
	"Nature", "Perception", "Performance", "Persuasion", "Religion",
	"Sleight of Hand", "Stealth", "Survival",
]

## Returns the ability that governs a given skill.
static func governing_ability(skill: SRD.Skill) -> SRD.Ability:
	return SKILL_ABILITY[int(skill)] as SRD.Ability

## Display name for a skill.
static func skill_name(skill: SRD.Skill) -> String:
	return SKILL_NAMES[int(skill)]

## Returns the total bonus for a skill check (ability mod + proficiency if any).
static func skill_bonus(char: CharacterStats, skill: SRD.Skill) -> int:
	var ability := governing_ability(skill)
	var mod := char.ability_modifier(ability)
	var prof := char.proficiency_bonus()
	if char.has_skill_expertise(skill):
		return mod + prof * 2
	if char.is_skill_proficient(skill):
		return mod + prof
	return mod + (prof / 2 if char.half_proficiency_unskilled else 0)

## Passive score for a skill (10 + skill_bonus, advantage +5, disadvantage -5).
static func passive_score(char: CharacterStats, skill: SRD.Skill,
		advantage: bool = false, disadvantage: bool = false) -> int:
	var base := 10 + skill_bonus(char, skill)
	if advantage and not disadvantage:
		return base + 5
	if disadvantage and not advantage:
		return base - 5
	return base

## Returns true if the skill check beats or equals the DC.
static func check(char: CharacterStats, skill: SRD.Skill, d20_roll: int, dc: int) -> bool:
	return d20_roll + skill_bonus(char, skill) >= dc
