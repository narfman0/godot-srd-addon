class_name EquipmentSlots
extends RefCounted
const _BOOT_SRD    = preload("res://vendor/godot-srd-addon/addons/srd/srd_enums.gd")
const _BOOT_CSTATS = preload("res://vendor/godot-srd-addon/addons/srd/resources/character_stats.gd")
const _BOOT_ARMOR  = preload("res://vendor/godot-srd-addon/addons/srd/resources/armor_data.gd")
const _BOOT_WEAPON = preload("res://vendor/godot-srd-addon/addons/srd/resources/weapon_data.gd")

var armor: ArmorData = null
var shield: ArmorData = null
var main_hand: WeaponData = null
var off_hand: WeaponData = null  # light weapon or shield stored here too

## Compute total AC for a character given their equipped armor + shield.
func current_ac(char: CharacterStats) -> int:
	var base := 10 + char.ability_modifier(SRD.Ability.DEXTERITY)  # unarmored
	if armor != null and armor.armor_type != SRD.ArmorType.SHIELD:
		base = armor.equipped_ac(char)
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
	return armor != null and armor.stealth_disadvantage

## True if the character meets the strength requirement of their armor.
func meets_strength_requirement(char: CharacterStats) -> bool:
	if armor == null:
		return true
	return char.strength >= armor.strength_requirement
