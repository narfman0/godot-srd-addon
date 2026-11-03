## The 2024 Unarmed Strike's Grapple and Shove options (SRD 5.2.1 Rules Glossary): the
## target makes a Strength or Dexterity saving throw (it chooses which) against
## DC 8 + the attacker's Strength modifier + Proficiency Bonus. A Shove pushes the target
## 5 feet away or knocks it Prone; a Grapple gives it the Grappled condition. Both work
## only on a target no more than one size larger, within 5 feet. The Damage option is
## Combatant.attack_modifier() / roll_damage() with no weapon.
##
## Each use replaces one attack of the Attack action (the game spends it). Space is the
## game's: a Shove that pushes returns push_feet and the game moves the target.
class_name UnarmedStrike
extends RefCounted

const SIZES := ["tiny", "small", "medium", "large", "huge", "gargantuan"]

static func save_dc(attacker: Combatant) -> int:
	return 8 + attacker.stats.ability_modifier(SRD.Ability.STRENGTH) + attacker.stats.proficiency_bonus()

## "Possible only if the target is no more than one size larger than you."
static func size_allows(attacker: Combatant, target: Combatant) -> bool:
	var a := SIZES.find(attacker.size)
	var t := SIZES.find(target.size)
	return a < 0 or t < 0 or t - a <= 1

## The save the target picks: its better of Strength and Dexterity.
static func save_ability(target: Combatant) -> SRD.Ability:
	var s := target.stats
	return SRD.Ability.STRENGTH if s.saving_throw_bonus(SRD.Ability.STRENGTH) >= \
		s.saving_throw_bonus(SRD.Ability.DEXTERITY) else SRD.Ability.DEXTERITY

## Chance the target fails (for hit-chance style previews). save_advantage: Dodge on DEX.
static func fail_chance(attacker: Combatant, target: Combatant, save_advantage: bool = false) -> float:
	if target.conditions.auto_fails_str_dex_saves():
		return 1.0
	var ab := save_ability(target)
	var need := save_dc(attacker) - target.stats.saving_throw_bonus(ab)
	var p_ok := clampf((21 - need) / 20.0, 0.0, 1.0)
	if save_advantage and ab == SRD.Ability.DEXTERITY:
		p_ok = 1.0 - (1.0 - p_ok) * (1.0 - p_ok)
	return 1.0 - p_ok

## Shove: push 5 ft. (prone = false) or knock Prone.
## opts: save_d20, save_d20_2 (fixed rolls), save_advantage (bool: Dodge gives it on DEX).
## Returns {type: "shove", attacker, target, effect: "push" | "prone", dc, ability, rolls,
##   d20, bonus, total, saved, auto_fail, push_feet?, prone?, refused?: "size" | "immune"}.
static func shove(attacker: Combatant, target: Combatant, prone: bool, opts: Dictionary = {}) -> Dictionary:
	var ev := _contest(attacker, target, "shove", opts)
	ev["effect"] = "prone" if prone else "push"
	if ev.has("refused") or ev.saved:
		return ev
	if prone:
		if "prone" in target.condition_immunities:
			ev["refused"] = "immune"
		else:
			target.conditions.add(SRD.Condition.PRONE)
			ev["prone"] = true
	else:
		ev["push_feet"] = 5
	return ev

## Grapple: the Grappled condition (escape DC = the same DC), tracked as an effect.
static func grapple(attacker: Combatant, target: Combatant, opts: Dictionary = {}) -> Dictionary:
	var ev := _contest(attacker, target, "grapple", opts)
	if ev.has("refused") or ev.saved:
		return ev
	if "grappled" in target.condition_immunities:
		ev["refused"] = "immune"
		return ev
	target.effects.add({"id": "grappled-by-" + attacker.name, "type": "condition", "condition": "grappled",
		"source": attacker.name, "escape_dc": ev.dc})
	ev["grappled"] = true
	return ev

static func _contest(attacker: Combatant, target: Combatant, what: String, opts: Dictionary) -> Dictionary:
	var ab := save_ability(target)
	var dc := save_dc(attacker)
	var ev := {"type": what, "attacker": attacker.name, "target": target.name, "dc": dc,
		"ability": ab, "saved": false, "auto_fail": false}
	if not size_allows(attacker, target):
		ev["refused"] = "size"
		ev["saved"] = true
		return ev
	var bonus := target.stats.saving_throw_bonus(ab) + target.effects.roll_bonus("save")
	var a := int(opts.get("save_d20", -1))
	a = a if a >= 1 else Dice.roll_d20()
	var rolls := [a]
	var kept := a
	if opts.get("save_advantage", false) and ab == SRD.Ability.DEXTERITY:
		var b := int(opts.get("save_d20_2", -1))
		b = b if b >= 1 else Dice.roll_d20()
		rolls.append(b)
		kept = maxi(a, b)
	ev.merge({"rolls": rolls, "d20": kept, "bonus": bonus, "total": kept + bonus})
	if target.conditions.auto_fails_str_dex_saves():
		ev["auto_fail"] = true
		return ev
	ev["saved"] = kept + bonus >= dc
	return ev
