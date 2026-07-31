class_name SRDLevelUp
extends RefCounted

## Level up a character from their current level to current+1.
## Returns HP gained this level.
## Pass slots if the character has energy slots that need updating.
static func level_up(char: CharacterStats, class_data: ClassData,
		slots: EnergySlots = null, roll_hp: bool = false) -> int:
	assert(char.level < 20, "Already at max level")
	char.level += 1
	char.hit_dice_remaining += 1  # gain a hit die

	var con_mod := char.ability_modifier(SRD.Ability.CONSTITUTION)
	var hp_gained: int
	if roll_hp:
		hp_gained = maxi(1, Dice.roll(class_data.hit_die) + con_mod)
	else:
		# Average: ceil(hit_die / 2) + 1
		hp_gained = maxi(1, (class_data.hit_die / 2 + 1) + con_mod)

	char.max_hp += hp_gained

	# Update energy slots if provided
	if slots != null:
		var new_slots := class_data.make_slots(char.level)
		for i in 9:
			var gained := new_slots.slots_max[i] - slots.slots_max[i]
			if gained > 0:
				slots.slots_max[i] = new_slots.slots_max[i]
				slots.slots_remaining[i] += gained  # new slots come pre-filled

	return hp_gained

## Apply class save proficiencies to a character at creation.
static func apply_class_proficiencies(char: CharacterStats, class_data: ClassData) -> void:
	char.save_proficiency_mask = 0
	for ability_int in class_data.save_proficiencies:
		char.set_save_proficiency(ability_int as SRD.Ability, true)
