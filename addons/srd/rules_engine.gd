class_name SRDRules
extends RefCounted
const _BOOT_SRD = preload("res://vendor/godot-srd-addon/addons/srd/srd_enums.gd")

static func ability_modifier(score: int) -> int:
	return floori((score - 10) / 2.0)

static func proficiency_bonus(level: int) -> int:
	return ceili(level / 4.0) + 1

static func check(d20_roll: int, modifier: int, dc: int) -> bool:
	return d20_roll + modifier >= dc

static func attack_hits(d20_roll: int, attack_bonus: int, armor_class: int) -> bool:
	if d20_roll == 20:
		return true
	if d20_roll == 1:
		return false
	return d20_roll + attack_bonus >= armor_class

static func is_critical_hit(d20_roll: int) -> bool:
	return d20_roll == 20

static func is_critical_miss(d20_roll: int) -> bool:
	return d20_roll == 1

static func saving_throw(d20_roll: int, ability_score: int, proficient: bool, prof_bonus: int, dc: int) -> bool:
	var mod := ability_modifier(ability_score)
	var bonus := mod + (prof_bonus if proficient else 0)
	return check(d20_roll, bonus, dc)

static func passive_score(ability_score: int, proficient: bool, prof_bonus: int) -> int:
	var mod := ability_modifier(ability_score)
	return 10 + mod + (prof_bonus if proficient else 0)

## Spell/ability save DC: 8 + proficiency bonus + casting ability modifier.
static func spell_save_dc(casting_ability_score: int, prof_bonus: int) -> int:
	return 8 + prof_bonus + ability_modifier(casting_ability_score)

## DC for a concentration check when taking damage.
static func concentration_check_dc(damage_taken: int) -> int:
	return maxi(10, damage_taken / 2)

## Cover bonus to AC and DEX saving throws.
static func cover_ac_bonus(cover: SRD.Cover) -> int:
	match cover:
		SRD.Cover.HALF:          return 2
		SRD.Cover.THREE_QUARTERS: return 5
		SRD.Cover.FULL:          return 99  # can't be directly targeted
	return 0

## Passive check: 10 + full skill bonus (ability mod + proficiency if any).
## Use for Perception doors, trap detection, hidden enemy awareness, etc.
static func passive_check(char: CharacterStats, skill: SRD.Skill) -> int:
	return 10 + SRDSkills.skill_bonus(char, skill)

## Advantage roll: roll twice, take higher.
static func roll_with_advantage() -> int:
	return Dice.roll_with_advantage(20)

## Disadvantage roll: roll twice, take lower.
static func roll_with_disadvantage() -> int:
	return Dice.roll_with_disadvantage(20)
