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

# ── SRD 5.2.1 spell mechanics (SRDContent.make_spell fills these from the pack) ──
## Pack slug ("magic-missile"); effects use it as their id so recasting replaces them.
@export var spell_id: String = ""
## "action" | "bonus_action" | "reaction" | "minute" ... (the casting time's first words).
@export var casting_time: String = "action"
## Reaction spells: the trigger text ("when you are hit by an attack roll ...").
@export var reaction_trigger: String = ""
## Flat damage per roll (Magic Missile's +1), and whether the caster's spellcasting
## modifier is added (Spiritual Weapon).
@export var damage_bonus: int = 0
@export var damage_add_modifier: bool = false
## Healing: dice + flat + optional spellcasting modifier; upcast adds dice per slot level.
@export var heal_die_count: int = 0
@export var heal_die_sides: int = 0
@export var heal_bonus: int = 0
@export var heal_add_modifier: bool = false
@export var upcast_heal_die_count: int = 0
## Darts and rays: each projectile rolls damage (and an attack roll unless auto_hit).
@export var projectiles: int = 0
@export var upcast_projectiles: int = 0
@export var auto_hit: bool = false
## Buff targets (Bless: 3, +1 per slot level above 1); 0 = whatever the caller passes.
@export var max_targets: int = 0
@export var upcast_targets: int = 0
## Effect templates from data: {on: "hit"|"fail"|"apply", type, expires, of, turns, ...}.
## "hit" applies on an attack hit, "fail" on a failed save, "apply" always (buffs, self).
var effects: Array = []
## Condition immunities that make a target auto-succeed (Sleep: "exhaustion").
var immune_if: Array = []
## "melee" | "ranged" spell attack ("" = infer from range: beyond 5 ft. is ranged).
@export var attack_kind: String = ""
## Summoned force the caster keeps using (Spiritual Weapon): {repeat_as, move_feet, rounds}.
var summon: Dictionary = {}

func is_ranged_attack() -> bool:
	if attack_kind != "":
		return attack_kind == "ranged"
	return range_feet > 5

func is_healing() -> bool:
	return heal_die_count > 0 or heal_bonus > 0

func has_damage() -> bool:
	return damage_die_count > 0

## Projectiles at a slot level (Magic Missile: 3, +1 per level above 1).
func projectile_count(cast_at_level: int) -> int:
	return projectiles + maxi(0, cast_at_level - slot_level) * upcast_projectiles if slot_level > 0 else projectiles

func target_limit(cast_at_level: int) -> int:
	if max_targets <= 0:
		return 0
	return max_targets + maxi(0, cast_at_level - slot_level) * upcast_targets

func heal_dice(cast_at_level: int) -> int:
	return heal_die_count + maxi(0, cast_at_level - slot_level) * upcast_heal_die_count

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
