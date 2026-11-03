class_name WeaponData
extends Resource

@export var weapon_name: String = ""
## Pack slug ("longsword"); Weapon Mastery choices are made per kind of weapon.
@export var slug: String = ""
## SRD 5.2.1 mastery property: cleave | graze | nick | push | sap | slow | topple | vex | "".
@export var mastery: String = ""
@export var weapon_type: SRD.WeaponType = SRD.WeaponType.SIMPLE
@export var damage_type: SRD.DamageType = SRD.DamageType.BLUDGEONING

# Damage dice: e.g. die_count=1, die_sides=6 → 1d6
@export var die_count: int = 1
@export var die_sides: int = 4

# Versatile: alternative damage when wielded two-handed
@export var versatile_die_count: int = 0
@export var versatile_die_sides: int = 0

@export var range_normal: int = 5    # feet; 5 = melee
@export var range_long: int = 5

# WeaponProperty bitmask (SRD.WeaponProperty flags OR'd together)
@export var properties: int = 0

## Monster stat blocks state attack and damage bonuses outright; NO_FIXED derives them from stats.
const NO_FIXED := -1000
@export var fixed_attack_bonus: int = NO_FIXED
@export var fixed_damage_bonus: int = NO_FIXED

## Ranged weapons have a long range beyond their normal range; melee weapons (including
## monster reach attacks) have range_long == range_normal.
func is_ranged() -> bool:
	return range_long > range_normal

func has_property(prop: SRD.WeaponProperty) -> bool:
	return (properties & int(prop)) != 0

## Compute attack bonus for a character using this weapon.
func attack_bonus(char: CharacterStats, proficient: bool, two_handed: bool = false) -> int:
	if fixed_attack_bonus != NO_FIXED:
		return fixed_attack_bonus
	var ability := _attack_ability(char)
	var mod := char.ability_modifier(ability)
	var prof := char.proficiency_bonus() if proficient else 0
	return mod + prof

## Roll full damage (dice + ability modifier).
func roll_damage(char: CharacterStats, two_handed: bool = false) -> int:
	return roll_damage_dice_only(two_handed) + _damage_mod(char)

## Roll only the damage dice (no modifier) — used for critical hit extra dice.
func roll_damage_dice_only(two_handed: bool = false) -> int:
	var count := die_count
	var sides := die_sides
	if two_handed and _is_versatile():
		count = versatile_die_count
		sides = versatile_die_sides
	return Dice.roll_nd(count, sides)

## Average damage (for expected value calculations / tests).
func average_damage(char: CharacterStats, two_handed: bool = false) -> float:
	var sides := versatile_die_sides if two_handed and _is_versatile() else die_sides
	var count := versatile_die_count if two_handed and _is_versatile() else die_count
	return count * (sides + 1) / 2.0 + _damage_mod(char)

# --- Predefined SRD weapon presets ---

static func _make(wname: String, wtype: SRD.WeaponType, dtype: SRD.DamageType,
		count: int, sides: int, props: int = 0) -> WeaponData:
	var w := WeaponData.new()
	w.weapon_name = wname
	w.weapon_type = wtype
	w.damage_type = dtype
	w.die_count = count
	w.die_sides = sides
	w.properties = props
	return w

static func make_dagger() -> WeaponData:
	return _make("Dagger", SRD.WeaponType.SIMPLE, SRD.DamageType.PIERCING, 1, 4,
		int(SRD.WeaponProperty.FINESSE) | int(SRD.WeaponProperty.LIGHT) | int(SRD.WeaponProperty.THROWN))

static func make_mace() -> WeaponData:
	return _make("Mace", SRD.WeaponType.SIMPLE, SRD.DamageType.BLUDGEONING, 1, 6)

static func make_quarterstaff() -> WeaponData:
	var w := _make("Quarterstaff", SRD.WeaponType.SIMPLE, SRD.DamageType.BLUDGEONING, 1, 6,
		int(SRD.WeaponProperty.VERSATILE))
	w.versatile_die_count = 1; w.versatile_die_sides = 8
	return w

static func make_longsword() -> WeaponData:
	var w := _make("Longsword", SRD.WeaponType.MARTIAL, SRD.DamageType.SLASHING, 1, 8,
		int(SRD.WeaponProperty.VERSATILE))
	w.versatile_die_count = 1; w.versatile_die_sides = 10
	return w

static func make_greatsword() -> WeaponData:
	return _make("Greatsword", SRD.WeaponType.MARTIAL, SRD.DamageType.SLASHING, 2, 6,
		int(SRD.WeaponProperty.TWO_HANDED))

static func make_rapier() -> WeaponData:
	return _make("Rapier", SRD.WeaponType.MARTIAL, SRD.DamageType.PIERCING, 1, 8,
		int(SRD.WeaponProperty.FINESSE))

static func make_shortsword() -> WeaponData:
	return _make("Shortsword", SRD.WeaponType.MARTIAL, SRD.DamageType.PIERCING, 1, 6,
		int(SRD.WeaponProperty.FINESSE) | int(SRD.WeaponProperty.LIGHT))

## The ability modifier this weapon attacks with (Graze damage, Topple DC).
func attack_ability_modifier(char: CharacterStats) -> int:
	if fixed_damage_bonus != NO_FIXED:
		return fixed_damage_bonus
	return char.ability_modifier(_attack_ability(char))

# --- Private ---

func _attack_ability(char: CharacterStats) -> SRD.Ability:
	if has_property(SRD.WeaponProperty.FINESSE):
		var str_mod := char.ability_modifier(SRD.Ability.STRENGTH)
		var dex_mod := char.ability_modifier(SRD.Ability.DEXTERITY)
		return SRD.Ability.DEXTERITY if dex_mod >= str_mod else SRD.Ability.STRENGTH
	if range_normal > 5:
		return SRD.Ability.DEXTERITY  # ranged weapons use DEX
	return SRD.Ability.STRENGTH

func _damage_mod(char: CharacterStats) -> int:
	if fixed_damage_bonus != NO_FIXED:
		return fixed_damage_bonus
	return char.ability_modifier(_attack_ability(char))

func _is_versatile() -> bool:
	return has_property(SRD.WeaponProperty.VERSATILE) \
		and versatile_die_count > 0 and versatile_die_sides > 0
