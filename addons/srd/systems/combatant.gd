## Bundles all per-character combat state into one object for the BattleSimulator.
class_name Combatant
extends RefCounted

var stats: CharacterStats
var weapon: WeaponData
var equipment: EquipmentSlots
var death_saves: DeathSaveTracker
var action_economy: ActionEconomy
var conditions: ConditionTracker
var energy_slots: EnergySlots
var is_proficient_with_weapon: bool = true

# Flat modifiers layered on top of the SRD math by the host game (feats,
# fighting styles, subclass passives). Defaults are no-ops; callers that
# support expanded crit ranges compare their d20 against crit_threshold.
var bonus_attack: int = 0
var bonus_damage: int = 0
var bonus_ac: int = 0
var crit_threshold: int = 20

# Monster special trait flags
var has_undead_fortitude: bool = false
var undead_fortitude_immune_to_radiant: bool = true

func _init(char_stats: CharacterStats, weapon_data: WeaponData = null,
		equip: EquipmentSlots = null) -> void:
	stats = char_stats
	weapon = weapon_data
	equipment = equip if equip != null else EquipmentSlots.new()
	death_saves = DeathSaveTracker.new()
	action_economy = ActionEconomy.new(stats.speed)
	conditions = ConditionTracker.new()

var name: String:
	get: return stats.character_name

var is_alive: bool:
	get: return stats.is_alive()

var is_down: bool:
	get: return stats.is_at_zero_hp() and not death_saves.is_dead

var is_dead: bool:
	get: return death_saves.is_dead

var is_active: bool:
	get: return is_alive and not is_dead

var current_hp: int:
	get: return stats.current_hp

var armor_class: int:
	get: return equipment.current_ac(stats) + bonus_ac

## Apply damage and handle Undead Fortitude if applicable.
## Returns actual damage dealt.
func take_damage(amount: int, damage_type: SRD.DamageType,
		is_crit: bool = false, fixed_d20: int = -1) -> int:
	var actual := DamageResolver.apply(stats, amount, damage_type)
	if stats.is_at_zero_hp() and has_undead_fortitude and actual > 0:
		if damage_type != SRD.DamageType.RADIANT and not is_crit:
			var dc := 5 + actual
			var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
			var bonus := stats.ability_modifier(SRD.Ability.CONSTITUTION)
			if d20 + bonus >= dc:
				stats.current_hp = 1  # Undead Fortitude saves it
	return actual

## True if this combatant can still meaningfully act.
func can_act() -> bool:
	return is_alive and not conditions.is_incapacitated()

## Attack bonus with the equipped weapon. Unarmed: STR mod + proficiency.
func attack_modifier() -> int:
	if weapon == null:
		return stats.ability_modifier(SRD.Ability.STRENGTH) + stats.proficiency_bonus() + bonus_attack
	return weapon.attack_bonus(stats, is_proficient_with_weapon) + bonus_attack

## Roll damage with the equipped weapon; crits roll the dice an extra time.
## Unarmed strike: 1 + STR mod (minimum 1).
func roll_damage(crit: bool = false) -> int:
	if weapon == null:
		return maxi(1, 1 + stats.ability_modifier(SRD.Ability.STRENGTH) + bonus_damage)
	var dmg := weapon.roll_damage(stats) + bonus_damage
	if crit:
		dmg += weapon.roll_damage_dice_only()
	return maxi(1, dmg)
