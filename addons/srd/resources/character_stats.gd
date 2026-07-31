class_name CharacterStats
extends Resource

@export var character_name: String = ""
@export var level: int = 1
@export var hit_die: int = 8

# Ability scores — access via get_ability(SRD.Ability) for generic code
@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10

# HP — max is the derived ceiling; current & temp are runtime state
@export var max_hp: int = 8
var current_hp: int = -1   # -1 = uninitialised; call reset() after setting max_hp
var temp_hp: int = 0
var hit_dice_remaining: int = -1  # -1 = uninitialised

# Saving throw proficiencies — 6-bit mask indexed by SRD.Ability
var save_proficiency_mask: int = 0

# Skill proficiency / expertise — 18-bit masks indexed by SRD.Skill
var skill_proficiency_mask: int = 0
var skill_expertise_mask: int = 0

# Damage modifiers — 13-bit masks indexed by SRD.DamageType
var resistance_mask: int = 0
var immunity_mask: int = 0
var vulnerability_mask: int = 0

# Speed in feet
@export var speed: int = 30

# XP
var xp: int = 0

func _init() -> void:
	reset()

# Call after changing max_hp or level from code (not needed when loading a saved Resource).
func reset() -> void:
	if current_hp < 0:
		current_hp = max_hp
	if hit_dice_remaining < 0:
		hit_dice_remaining = level

# --- Ability scores ---

func get_ability(ability: SRD.Ability) -> int:
	match ability:
		SRD.Ability.STRENGTH:     return strength
		SRD.Ability.DEXTERITY:    return dexterity
		SRD.Ability.CONSTITUTION: return constitution
		SRD.Ability.INTELLIGENCE: return intelligence
		SRD.Ability.WISDOM:       return wisdom
		SRD.Ability.CHARISMA:     return charisma
	return 10

func set_ability(ability: SRD.Ability, value: int) -> void:
	value = clampi(value, 1, 30)
	match ability:
		SRD.Ability.STRENGTH:     strength = value
		SRD.Ability.DEXTERITY:    dexterity = value
		SRD.Ability.CONSTITUTION: constitution = value
		SRD.Ability.INTELLIGENCE: intelligence = value
		SRD.Ability.WISDOM:       wisdom = value
		SRD.Ability.CHARISMA:     charisma = value

func ability_modifier(ability: SRD.Ability) -> int:
	return SRDRules.ability_modifier(get_ability(ability))

func proficiency_bonus() -> int:
	return SRDRules.proficiency_bonus(level)

# --- Hit Points ---

## Returns actual damage dealt (after temp HP absorption).
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var remaining := amount
	if temp_hp > 0:
		var absorbed := mini(temp_hp, remaining)
		temp_hp -= absorbed
		remaining -= absorbed
	var actual := mini(current_hp, remaining)
	current_hp -= actual
	return amount

## Returns HP actually restored.
func heal(amount: int) -> int:
	if current_hp <= 0:
		return 0  # unconscious/dead — healing handled separately (stabilise / raise)
	var before := current_hp
	current_hp = mini(max_hp, current_hp + amount)
	return current_hp - before

## Temp HP doesn't stack — only the higher value applies.
func add_temp_hp(amount: int) -> void:
	temp_hp = maxi(temp_hp, amount)

func is_alive() -> bool:
	return current_hp > 0

func is_at_zero_hp() -> bool:
	return current_hp == 0

# --- Saving throws ---

func is_save_proficient(ability: SRD.Ability) -> bool:
	return (save_proficiency_mask >> int(ability)) & 1 == 1

func set_save_proficiency(ability: SRD.Ability, proficient: bool) -> void:
	if proficient:
		save_proficiency_mask |= (1 << int(ability))
	else:
		save_proficiency_mask &= ~(1 << int(ability))

func saving_throw_bonus(ability: SRD.Ability) -> int:
	var mod := ability_modifier(ability)
	return mod + (proficiency_bonus() if is_save_proficient(ability) else 0)

# --- Skill proficiencies ---

func is_skill_proficient(skill: SRD.Skill) -> bool:
	return (skill_proficiency_mask >> int(skill)) & 1 == 1

func has_skill_expertise(skill: SRD.Skill) -> bool:
	return (skill_expertise_mask >> int(skill)) & 1 == 1

func set_skill_proficiency(skill: SRD.Skill, proficient: bool, expertise: bool = false) -> void:
	if proficient:
		skill_proficiency_mask |= (1 << int(skill))
	else:
		skill_proficiency_mask &= ~(1 << int(skill))
		expertise = false  # expertise requires proficiency
	if expertise:
		skill_expertise_mask |= (1 << int(skill))
	else:
		skill_expertise_mask &= ~(1 << int(skill))

# --- Damage modifiers ---

func has_resistance(damage_type: SRD.DamageType) -> bool:
	return (resistance_mask >> int(damage_type)) & 1 == 1

func has_immunity(damage_type: SRD.DamageType) -> bool:
	return (immunity_mask >> int(damage_type)) & 1 == 1

func has_vulnerability(damage_type: SRD.DamageType) -> bool:
	return (vulnerability_mask >> int(damage_type)) & 1 == 1

func set_resistance(damage_type: SRD.DamageType, active: bool) -> void:
	if active: resistance_mask |= (1 << int(damage_type))
	else: resistance_mask &= ~(1 << int(damage_type))

func set_immunity(damage_type: SRD.DamageType, active: bool) -> void:
	if active: immunity_mask |= (1 << int(damage_type))
	else: immunity_mask &= ~(1 << int(damage_type))

func set_vulnerability(damage_type: SRD.DamageType, active: bool) -> void:
	if active: vulnerability_mask |= (1 << int(damage_type))
	else: vulnerability_mask &= ~(1 << int(damage_type))
