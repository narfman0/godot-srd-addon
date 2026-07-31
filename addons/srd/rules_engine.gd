class_name SRDRules
extends RefCounted

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
