class_name ArmorData
extends Resource
const _BOOT_SRD = preload("res://vendor/godot-srd-addon/addons/srd/srd_enums.gd")

@export var armor_name: String = ""
@export var armor_type: SRD.ArmorType = SRD.ArmorType.LIGHT
@export var base_ac: int = 11
## -1 = no cap (light), 0 = no DEX bonus (heavy), 2 = medium cap
@export var max_dex_bonus: int = -1
@export var strength_requirement: int = 0
@export var stealth_disadvantage: bool = false

## Calculate the AC this armor provides for a given character.
func equipped_ac(char: CharacterStats) -> int:
	match armor_type:
		SRD.ArmorType.NONE:
			return 10 + char.ability_modifier(SRD.Ability.DEXTERITY)
		SRD.ArmorType.LIGHT:
			return base_ac + char.ability_modifier(SRD.Ability.DEXTERITY)
		SRD.ArmorType.MEDIUM:
			var dex_bonus := mini(char.ability_modifier(SRD.Ability.DEXTERITY), 2)
			return base_ac + dex_bonus
		SRD.ArmorType.HEAVY:
			return base_ac
		SRD.ArmorType.SHIELD:
			return 2  # shields add to existing AC, not a standalone AC
	return base_ac

## Predefined armor presets for convenience.
static func make_leather() -> ArmorData:
	var a := ArmorData.new()
	a.armor_name = "Leather Armor"
	a.armor_type = SRD.ArmorType.LIGHT
	a.base_ac = 11
	a.max_dex_bonus = -1
	return a

static func make_chain_mail() -> ArmorData:
	var a := ArmorData.new()
	a.armor_name = "Chain Mail"
	a.armor_type = SRD.ArmorType.HEAVY
	a.base_ac = 16
	a.strength_requirement = 13
	a.stealth_disadvantage = true
	return a

static func make_shield() -> ArmorData:
	var a := ArmorData.new()
	a.armor_name = "Shield"
	a.armor_type = SRD.ArmorType.SHIELD
	a.base_ac = 2
	return a

static func make_studded_leather() -> ArmorData:
	var a := ArmorData.new()
	a.armor_name = "Studded Leather"
	a.armor_type = SRD.ArmorType.LIGHT
	a.base_ac = 12
	return a

static func make_scale_mail() -> ArmorData:
	var a := ArmorData.new()
	a.armor_name = "Scale Mail"
	a.armor_type = SRD.ArmorType.MEDIUM
	a.base_ac = 14
	a.stealth_disadvantage = true
	return a
