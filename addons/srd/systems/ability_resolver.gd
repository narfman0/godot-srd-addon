class_name AbilityResolver
extends RefCounted

## Resolve an ability that uses an attack roll against a target's AC.
## Returns { hit, crit, damage, d20 }
static func resolve_attack_roll(caster: CharacterStats, target: CharacterStats,
		ability: AbilityData, target_ac: int, cast_at_level: int = -1) -> Dictionary:
	var d20 := Dice.roll_d20()
	var crit := SRDRules.is_critical_hit(d20)
	var miss := SRDRules.is_critical_miss(d20)
	var attack_bonus := ability.spell_attack_bonus(caster)

	var hit := false
	if crit:
		hit = true
	elif miss:
		hit = false
	else:
		hit = SRDRules.attack_hits(d20, attack_bonus, target_ac)

	if not hit:
		return { "hit": false, "crit": false, "damage": 0, "d20": d20 }

	var level := cast_at_level if cast_at_level > 0 else ability.slot_level
	var dmg := ability.roll_damage(caster.level, level)
	if crit:
		dmg += ability.roll_damage(caster.level, level)  # double dice on crit

	return { "hit": true, "crit": crit, "damage": dmg, "d20": d20 }

## Resolve an ability that calls for a saving throw from the target.
## Returns { saved, damage, d20 } where d20 is the target's save roll.
static func resolve_saving_throw(caster: CharacterStats, target: CharacterStats,
		ability: AbilityData, cast_at_level: int = -1,
		injected_d20: int = -1) -> Dictionary:
	var dc := ability.spell_save_dc(caster)
	var d20 := injected_d20 if injected_d20 >= 1 else Dice.roll_d20()
	var save_bonus := target.saving_throw_bonus(ability.save_ability)

	# Auto-fail STR/DEX saves when paralyzed or unconscious
	var auto_fail := target.has_immunity(SRD.DamageType.FORCE) == false and \
		(ability.save_ability == SRD.Ability.STRENGTH or
		 ability.save_ability == SRD.Ability.DEXTERITY)
	# (Actual auto-fail check should come from condition tracker — caller responsibility)

	var saved := d20 + save_bonus >= dc
	var level := cast_at_level if cast_at_level > 0 else ability.slot_level
	var full_dmg := ability.roll_damage(caster.level, level)

	var damage: int
	match ability.save_effect:
		SRD.SaveEffect.HALF:
			damage = full_dmg / 2 if saved else full_dmg
		SRD.SaveEffect.NONE:
			damage = 0 if saved else full_dmg
		_:
			damage = full_dmg

	return { "saved": saved, "damage": damage, "d20": d20, "dc": dc }
