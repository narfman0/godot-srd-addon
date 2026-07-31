class_name AbilityData
extends Resource

@export var ability_name: String = ""
@export var description: String = ""

# Tags: psionic, tech, combat, support (free-form strings for scifi layer)
@export var tags: Array[String] = []

@export var range_feet: int = 30  # 0 = self, -1 = touch
@export var target_type: String = "single"  # single | area

# AoE
@export var area_shape: SRD.AoEShape = SRD.AoEShape.SPHERE
@export var area_size: int = 0  # radius/length in feet; 0 = no AoE

@export var duration_rounds: int = 0  # 0 = instantaneous
@export var concentration: bool = false

@export var slot_level: int = 0  # 0 = at-will / cantrip

# Damage
@export var damage_die_count: int = 1
@export var damage_die_sides: int = 6
@export var damage_type: SRD.DamageType = SRD.DamageType.FORCE
@export var upcast_bonus_die_count: int = 0  # extra dice per slot level above minimum

# Resolution
## If save_ability is set, it's a saving throw. Otherwise it's an attack roll.
@export var save_ability: SRD.Ability = SRD.Ability.DEXTERITY
@export var uses_save: bool = false
@export var save_effect: SRD.SaveEffect = SRD.SaveEffect.HALF  # on success

# Casting ability for this ability (set by class data)
var casting_ability: SRD.Ability = SRD.Ability.INTELLIGENCE

## Base damage dice at minimum slot level.
func base_damage_dice(caster_level: int = 1) -> int:
	# Cantrips scale by caster level
	if slot_level == 0:
		return _cantrip_scale(caster_level)
	return damage_die_count

## Damage dice when cast at a higher slot level.
func upcasted_damage_dice(cast_at_level: int) -> int:
	if slot_level == 0 or upcast_bonus_die_count == 0:
		return damage_die_count
	var extra_levels := maxi(0, cast_at_level - slot_level)
	return damage_die_count + extra_levels * upcast_bonus_die_count

## Roll damage for this ability.
func roll_damage(caster_level: int = 1, cast_at_level: int = -1) -> int:
	var count: int
	if cast_at_level > slot_level and slot_level > 0:
		count = upcasted_damage_dice(cast_at_level)
	else:
		count = base_damage_dice(caster_level)
	return Dice.roll_nd(count, damage_die_sides)

## Spell save DC for the caster (8 + prof + casting ability mod).
func spell_save_dc(caster: CharacterStats) -> int:
	return 8 + caster.proficiency_bonus() + caster.ability_modifier(casting_ability)

## Spell attack bonus (prof + casting ability mod).
func spell_attack_bonus(caster: CharacterStats) -> int:
	return caster.proficiency_bonus() + caster.ability_modifier(casting_ability)

# --- Private ---

func _cantrip_scale(level: int) -> int:
	# Standard cantrip scaling: 1/1, 2/5, 3/11, 4/17
	if level >= 17:
		return damage_die_count * 4
	if level >= 11:
		return damage_die_count * 3
	if level >= 5:
		return damage_die_count * 2
	return damage_die_count
