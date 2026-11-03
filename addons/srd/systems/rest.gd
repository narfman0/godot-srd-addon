class_name SRDRest
extends RefCounted

## Short rest: spend hit dice to recover HP.
## Returns total HP restored.
static func short_rest(char: CharacterStats, dice_to_spend: int,
		slots: EnergySlots = null) -> int:
	if slots != null and slots.recovers_on_short_rest:
		slots.recover_all()
	dice_to_spend = mini(dice_to_spend, char.hit_dice_remaining)
	if dice_to_spend <= 0:
		return 0
	var con_mod := char.ability_modifier(SRD.Ability.CONSTITUTION)
	var total_healed := 0
	for i in dice_to_spend:
		var rolled := Dice.roll(char.hit_die)
		var heal_amount := maxi(1, rolled + con_mod)
		total_healed += char.heal(heal_amount)
	char.hit_dice_remaining -= dice_to_spend
	return total_healed

## Long rest: full HP, recover half total hit dice (min 1), restore all slots.
static func long_rest(char: CharacterStats, slots: EnergySlots = null) -> void:
	char.current_hp = char.max_hp
	char.temp_hp = 0
	var total_dice := char.level
	var recover_dice := maxi(1, total_dice / 2)
	char.hit_dice_remaining = mini(total_dice, char.hit_dice_remaining + recover_dice)
	if slots != null:
		slots.recover_all()

## SRD 5.2.1 Short Rest for a whole character: spend up to `dice` Hit Point Dice (each d(hit die)
## + CON modifier, minimum 1), and short-rest resources. Pact slots return; the class's
## rest-time features fire (Arcane Recovery, Sorcerous Restoration...).
## Returns {healed, dice_spent, lines}.
static func short_rest_combatant(c: Combatant, dice: int = 0) -> Dictionary:
	var s := c.stats
	var spend := mini(dice, s.hit_dice_remaining)
	var healed := 0
	var con := s.ability_modifier(SRD.Ability.CONSTITUTION)
	if s.current_hp > 0:
		for i in spend:
			healed += s.heal(maxi(1, Dice.roll(s.hit_die) + con))
		s.hit_dice_remaining -= spend
	else:
		spend = 0
	if c.energy_slots != null and c.energy_slots.recovers_on_short_rest:
		c.energy_slots.recover_all()
	var lines := []
	if c.kit != null:
		c.kit.short_rest()
		lines = c.kit.rest_recoveries(c)
	return {"healed": healed, "dice_spent": spend, "lines": lines}

## SRD 5.2.1 Long Rest for a whole character: all Hit Points and all Hit Point Dice back, spell
## slots and limited features back, one Exhaustion level gone, timed effects over, Temporary
## Hit Points lost. A character at 0 HP who is alive wakes (a dead one needs more than rest).
static func long_rest_combatant(c: Combatant) -> void:
	var s := c.stats
	if c.is_dead:
		return
	s.current_hp = s.max_hp
	s.temp_hp = 0
	s.hit_dice_remaining = s.level
	c.death_saves.revive()
	c.conditions.remove(SRD.Condition.UNCONSCIOUS)
	c.conditions.remove(SRD.Condition.PRONE)
	c.effects.clear()
	if c.energy_slots != null:
		c.energy_slots.recover_all()
	if c.kit != null:
		c.kit.long_rest()
