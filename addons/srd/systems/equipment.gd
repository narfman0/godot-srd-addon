class_name EquipmentSlots
extends RefCounted

var armor: ArmorData = null
var shield: ArmorData = null
var main_hand: WeaponData = null
var off_hand: WeaponData = null  # light weapon or shield stored here too

## Monster stat-block AC; 0 = derive from armor/shield/DEX.
var natural_ac: int = 0
## Unarmored Defense and the like: this ability's modifier joins 10 + DEX while wearing no
## armor (-1 = none). unarmored_no_shield: only without a shield as well (Monk).
var unarmored_ability: int = -1
var unarmored_no_shield: bool = false
## Gear: AC bonus while wearing no armor and no shield (Bracers of Defense).
var unarmored_bonus: int = 0
## Gear: the worn armor has no Strength requirement or Stealth Disadvantage (Mithral).
var ignore_armor_penalties: bool = false

## Compute total AC for a character given their equipped armor + shield.
func current_ac(char: CharacterStats) -> int:
	if natural_ac > 0:
		return natural_ac  # stat-block AC already includes armor, shield, and DEX
	var base := 10 + char.ability_modifier(SRD.Ability.DEXTERITY)  # unarmored
	if armor != null and armor.armor_type != SRD.ArmorType.SHIELD:
		base = armor.equipped_ac(char)
	elif unarmored_ability >= 0 and not (unarmored_no_shield and shield != null):
		base += char.ability_modifier(unarmored_ability as SRD.Ability)
	if armor == null and shield == null:
		base += unarmored_bonus
	if shield != null:
		base += 2  # shield bonus is always flat +2
	return base

func equip_armor(new_armor: ArmorData) -> void:
	if new_armor != null and new_armor.armor_type == SRD.ArmorType.SHIELD:
		push_warning("Use equip_shield() for shields")
		return
	armor = new_armor

func equip_shield(new_shield: ArmorData) -> void:
	shield = new_shield

func unequip_armor() -> void:
	armor = null

func unequip_shield() -> void:
	shield = null

func equip_main_hand(weapon: WeaponData) -> void:
	main_hand = weapon

func equip_off_hand(weapon: WeaponData) -> void:
	off_hand = weapon

## True if the character has stealth disadvantage from their armor.
func has_stealth_disadvantage() -> bool:
	return armor != null and armor.stealth_disadvantage and not ignore_armor_penalties

## True if the character meets the strength requirement of their armor.
func meets_strength_requirement(char: CharacterStats) -> bool:
	if armor == null or ignore_armor_penalties:
		return true
	return char.strength >= armor.strength_requirement
