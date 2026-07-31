class_name OpportunityAttack
extends RefCounted

## Returns true if watcher can make an opportunity attack against mover.
## Preconditions (caller must verify positional logic — addon is grid-agnostic):
##   - mover is voluntarily leaving watcher's melee reach (5ft)
##   - watcher has a melee weapon equipped or can make unarmed strikes
static func can_trigger(watcher: Combatant, mover_is_disengaging: bool) -> bool:
	if mover_is_disengaging:
		return false  # Disengage prevents opportunity attacks
	if not watcher.action_economy.has_reaction:
		return false
	if watcher.conditions.is_incapacitated():
		return false
	if not watcher.can_act():
		return false
	# Must have a melee-range weapon (range_normal == 5) or unarmed (weapon == null treated as reach 5)
	var weapon_reach := 5
	if watcher.weapon != null:
		weapon_reach = watcher.weapon.range_normal
	return weapon_reach <= 5

## Execute the opportunity attack. Consumes watcher's reaction.
## Returns an attack event dict (same format as BattleSimulator events).
static func trigger(watcher: Combatant, mover: Combatant,
		fixed_d20: int = -1) -> Dictionary:
	assert(watcher.action_economy.use_reaction(), "OA should only fire when reaction is available")
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var weapon := watcher.weapon
	if weapon == null:
		# Unarmed strike: STR mod damage, 1 bludgeoning
		var atk_bonus := watcher.stats.ability_modifier(SRD.Ability.STRENGTH) \
			+ watcher.stats.proficiency_bonus()
		var hit := SRDRules.attack_hits(d20, atk_bonus, mover.armor_class) \
			or SRDRules.is_critical_hit(d20)
		var dmg := 1 + watcher.stats.ability_modifier(SRD.Ability.STRENGTH) if hit else 0
		if hit:
			DamageResolver.apply(mover.stats, dmg, SRD.DamageType.BLUDGEONING)
		return { "type": "opportunity_attack", "hit": hit, "d20": d20, "damage": dmg,
			"attacker": watcher.name, "target": mover.name }

	var atk_bonus := weapon.attack_bonus(watcher.stats, watcher.is_proficient_with_weapon)
	var crit := SRDRules.is_critical_hit(d20)
	var miss := SRDRules.is_critical_miss(d20)
	var hit := false
	if crit: hit = true
	elif miss: hit = false
	else: hit = SRDRules.attack_hits(d20, atk_bonus, mover.armor_class)

	var dmg := 0; var dealt := 0
	if hit:
		dmg = weapon.roll_damage(watcher.stats)
		if crit: dmg += weapon.roll_damage_dice_only()
		dealt = DamageResolver.apply(mover.stats, dmg, weapon.damage_type)

	return {
		"type": "opportunity_attack",
		"attacker": watcher.name, "target": mover.name,
		"d20": d20, "hit": hit, "crit": crit,
		"damage": dmg, "damage_dealt": dealt,
		"target_hp_after": mover.stats.current_hp,
	}
