class_name ContestedCheck
extends RefCounted

## Grapple attempt: attacker's Athletics vs defender's Athletics or Acrobatics.
## Returns true if attacker wins (defender gains GRAPPLED condition).
## Pass injected d20s for deterministic tests (−1 = random).
static func grapple(attacker: CharacterStats, defender: CharacterStats,
		atk_d20: int = -1, def_d20: int = -1,
		defender_uses_acrobatics: bool = false) -> bool:
	var atk_roll := atk_d20 if atk_d20 >= 1 else Dice.roll_d20()
	var def_roll := def_d20 if def_d20 >= 1 else Dice.roll_d20()
	var atk_total := atk_roll + SRDSkills.skill_bonus(attacker, SRD.Skill.ATHLETICS)
	var def_skill := SRD.Skill.ACROBATICS if defender_uses_acrobatics else SRD.Skill.ATHLETICS
	var def_total := def_roll + SRDSkills.skill_bonus(defender, def_skill)
	return atk_total > def_total  # ties go to defender (attacker must beat, not tie)

## Shove attempt: same contest; on win caller chooses prone or push 5ft.
## Returns true if attacker wins.
static func shove(attacker: CharacterStats, defender: CharacterStats,
		atk_d20: int = -1, def_d20: int = -1,
		defender_uses_acrobatics: bool = false) -> bool:
	return grapple(attacker, defender, atk_d20, def_d20, defender_uses_acrobatics)

## Apply grapple outcome to the defender.
static func apply_grapple(defender_conditions: ConditionTracker, won: bool) -> void:
	if won:
		defender_conditions.add(SRD.Condition.GRAPPLED)

## Apply shove outcome. go_prone=true → Prone; false → pushed (no condition in addon,
## caller handles position in game layer).
static func apply_shove(defender_conditions: ConditionTracker,
		won: bool, go_prone: bool) -> void:
	if won and go_prone:
		defender_conditions.add(SRD.Condition.PRONE)
	# Push 5ft: positional — caller handles in game layer

## Escape grapple: opposed Athletics vs Athletics/Acrobatics. Returns true if escaped.
static func escape_grapple(grappled: CharacterStats, grappler: CharacterStats,
		esc_d20: int = -1, grp_d20: int = -1,
		escapee_uses_acrobatics: bool = false) -> bool:
	return grapple(grappled, grappler, esc_d20, grp_d20, escapee_uses_acrobatics)
