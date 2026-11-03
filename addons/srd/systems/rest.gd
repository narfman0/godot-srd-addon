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
