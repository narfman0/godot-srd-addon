class_name DamageResolver
extends RefCounted

const _BOOT_SRD    = preload("res://vendor/godot-srd-addon/addons/srd/srd_enums.gd")
const _BOOT_CSTATS = preload("res://vendor/godot-srd-addon/addons/srd/resources/character_stats.gd")


## Apply typed damage to a character, respecting resistance/immunity/vulnerability.
## Returns actual HP lost.
static func apply(char: CharacterStats, amount: int,
		damage_type: SRD.DamageType, magical: bool = false) -> int:
	var actual := _modify(char, amount, damage_type)
	return char.take_damage(actual)

## Calculate modified damage amount without applying it.
static func calculate(char: CharacterStats, amount: int,
		damage_type: SRD.DamageType) -> int:
	return _modify(char, amount, damage_type)

## Resolve a full attack: roll to hit, then roll damage if it connects.
## Returns { hit: bool, crit: bool, damage: int, damage_dealt: int }
static func resolve_attack(attacker: CharacterStats, target: CharacterStats,
		weapon, attack_bonus: int) -> Dictionary:
	var d20 := Dice.roll_d20()

	# Determine advantage/disadvantage from conditions
	var cond := ConditionTracker.new()
	# (In a full game, pass the actual trackers — here we check basics)
	var natural_crit := SRDRules.is_critical_hit(d20)
	var natural_miss := SRDRules.is_critical_miss(d20)

	var hits := false
	if natural_crit:
		hits = true
	elif natural_miss:
		hits = false
	else:
		var target_ac: int = target.dexterity  # placeholder; EquipmentSlots.current_ac() in real use
		hits = SRDRules.attack_hits(d20, attack_bonus, target_ac)

	if not hits:
		return { "hit": false, "crit": false, "damage": 0, "damage_dealt": 0, "d20": d20 }

	var dmg := _roll_weapon_damage(weapon, attacker, natural_crit)
	var dealt := apply(target, dmg, weapon.damage_type)
	return { "hit": true, "crit": natural_crit, "damage": dmg, "damage_dealt": dealt, "d20": d20 }

# --- Private ---

static func _modify(char: CharacterStats, amount: int, damage_type: SRD.DamageType) -> int:
	if char.has_immunity(damage_type):
		return 0
	if char.has_vulnerability(damage_type):
		return amount * 2
	if char.has_resistance(damage_type):
		return amount / 2  # integer floor per SRD
	return amount

static func _roll_weapon_damage(weapon, attacker: CharacterStats, crit: bool) -> int:
	var total := weapon.roll_damage(attacker)
	if crit:
		# Crit: roll the damage dice an additional time (don't double modifiers)
		total += weapon.roll_damage_dice_only()
	return total
