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

# SRD: monsters die outright at 0 HP; player characters fall unconscious and make death saves
var dies_at_zero_hp: bool = false

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

## Timed buffs, riders, and mastery effects (Bless, Shield, Sap, Vex...).
var effects: ActiveEffects
## Class features, resources, and masteries; null for monsters and bare stat blocks.
var kit: ClassKit = null
## Per-turn state cleared by SRDEffects.turn_started (sneak_attack, cleave, action_surge...).
var turn_flags: Dictionary = {}
## "tiny" .. "gargantuan": Push only moves Large or smaller creatures.
var size: String = "medium"
## Lowercase condition names this creature ignores ("exhaustion" also makes it immune to Sleep).
var condition_immunities: Array[String] = []
## Monster Bonus Actions and Reactions (MonsterActions feature Dictionaries), limited-use
## counters for them ({feature key: uses spent}), and weapon on-hit riders
## ({name, dice, type, condition: "advantage", per_turn}).
var bonus_actions: Array = []
var reactions: Array = []
var monster_uses: Dictionary = {}
var hit_riders: Array = []
## Initiative modifier: the stat block's Initiative for monsters; -999 = use the DEX modifier.
var initiative_override: int = -999
## The last Undead Fortitude save take_damage() rolled (or refused), for the game's log:
## {dc, d20, bonus, total, saved} or {blocked: "radiant" | "critical"}. {} when it didn't apply.
var last_undead_fortitude: Dictionary = {}

func _init(char_stats: CharacterStats, weapon_data: WeaponData = null,
		equip: EquipmentSlots = null) -> void:
	stats = char_stats
	weapon = weapon_data
	equipment = equip if equip != null else EquipmentSlots.new()
	death_saves = DeathSaveTracker.new()
	action_economy = ActionEconomy.new(stats.speed)
	conditions = ConditionTracker.new()
	effects = ActiveEffects.new(conditions)

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
	get: return equipment.current_ac(stats) + effects.ac_bonus() + _style_ac_bonus() + bonus_ac

## Speed after reductions (Ray of Frost, Slow), never below 0.
var speed: int:
	get: return maxi(0, stats.speed - effects.speed_penalty())

## SRD: a creature is Bloodied while at half its Hit Points or fewer.
var is_bloodied: bool:
	get: return stats.current_hp <= stats.max_hp / 2

func _style_ac_bonus() -> int:
	# Defense fighting style: +1 AC while wearing Light, Medium, or Heavy armor
	if kit != null and kit.fighting_style() == "defense" and equipment.armor != null:
		return 1
	return 0

var initiative_bonus: int:
	get: return initiative_override if initiative_override != -999 \
		else stats.ability_modifier(SRD.Ability.DEXTERITY)

## Apply damage and handle Undead Fortitude if applicable.
## Returns actual damage dealt. last_undead_fortitude describes the save, if any.
func take_damage(amount: int, damage_type: SRD.DamageType,
		is_crit: bool = false, fixed_d20: int = -1) -> int:
	var actual := DamageResolver.apply(stats, amount, damage_type)
	last_undead_fortitude = {}
	if actual > 0:
		effects.took_damage()
	if stats.is_at_zero_hp() and has_undead_fortitude and actual > 0:
		last_undead_fortitude = undead_fortitude_save(actual, damage_type, is_crit, fixed_d20)
		if last_undead_fortitude.get("saved", false):
			stats.current_hp = 1  # Undead Fortitude saves it
	if stats.is_at_zero_hp() and dies_at_zero_hp:
		death_saves.is_dead = true
	return actual

## SRD Zombie: "If damage reduces the zombie to 0 Hit Points, it makes a Constitution
## saving throw (DC 5 plus the damage taken) unless the damage is Radiant or from a
## Critical Hit. On a successful save, the zombie drops to 1 Hit Point instead."
## Rolls (or refuses) the save without changing HP.
func undead_fortitude_save(damage_taken: int, damage_type: SRD.DamageType, is_crit: bool,
		fixed_d20: int = -1) -> Dictionary:
	if damage_type == SRD.DamageType.RADIANT and undead_fortitude_immune_to_radiant:
		return {"blocked": "radiant"}
	if is_crit:
		return {"blocked": "critical"}
	var dc := 5 + damage_taken
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var bonus := stats.saving_throw_bonus(SRD.Ability.CONSTITUTION) + effects.roll_bonus("save")
	return {"dc": dc, "d20": d20, "bonus": bonus, "total": d20 + bonus, "saved": d20 + bonus >= dc}

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
