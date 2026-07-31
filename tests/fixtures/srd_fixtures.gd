## Reusable test fixtures: a balanced party of 5 level-3 characters.
class_name SRDFixtures
extends RefCounted

## Build a balanced party of 5 at level 3.
## Returns Array[Combatant].
static func make_party_of_5() -> Array:
	return [
		_make_soldier(),
		_make_ghost(),
		_make_psion(),
		_make_warden(),
		_make_soldier_2(),
	]

# ── Party members ────────────────────────────────────────────────────────────

static func _make_soldier() -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Mira (Soldier)"
	s.level = 3; s.hit_die = 10
	s.strength = 16; s.dexterity = 12; s.constitution = 14
	s.intelligence = 10; s.wisdom = 10; s.charisma = 8
	# HP: 10 + (5+2)*2 = 10 + 14 = 24
	s.max_hp = 24; s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.STRENGTH, true)
	s.set_save_proficiency(SRD.Ability.CONSTITUTION, true)

	var longsword := WeaponData.new()
	longsword.weapon_name = "Longsword"
	longsword.weapon_type = SRD.WeaponType.MARTIAL
	longsword.damage_type = SRD.DamageType.SLASHING
	longsword.die_count = 1; longsword.die_sides = 8
	longsword.properties = SRD.WeaponProperty.VERSATILE
	longsword.versatile_die_count = 1; longsword.versatile_die_sides = 10

	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_chain_mail())  # AC 16
	eq.equip_shield(ArmorData.make_shield())     # +2 → AC 18

	return Combatant.new(s, longsword, eq)

static func _make_ghost() -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Kael (Ghost)"
	s.level = 3; s.hit_die = 8
	s.strength = 10; s.dexterity = 16; s.constitution = 12
	s.intelligence = 14; s.wisdom = 12; s.charisma = 10
	# HP: 8 + (4+1)*2 = 8 + 10 = 18
	s.max_hp = 18; s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.DEXTERITY, true)
	s.set_save_proficiency(SRD.Ability.INTELLIGENCE, true)

	var shortsword := WeaponData.new()
	shortsword.weapon_name = "Shortsword"
	shortsword.weapon_type = SRD.WeaponType.MARTIAL
	shortsword.damage_type = SRD.DamageType.PIERCING
	shortsword.die_count = 1; shortsword.die_sides = 6
	shortsword.properties = SRD.WeaponProperty.FINESSE | SRD.WeaponProperty.LIGHT

	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_studded_leather())  # 12 + DEX(+3) = 15

	return Combatant.new(s, shortsword, eq)

static func _make_psion() -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Vex (Psion)"
	s.level = 3; s.hit_die = 6
	s.strength = 8; s.dexterity = 14; s.constitution = 12
	s.intelligence = 16; s.wisdom = 12; s.charisma = 10
	# HP: 6 + (3+1)*2 = 6 + 8 = 14
	s.max_hp = 14; s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.INTELLIGENCE, true)
	s.set_save_proficiency(SRD.Ability.WISDOM, true)

	# Psion uses a dagger as melee backup
	var dagger := WeaponData.new()
	dagger.weapon_name = "Dagger"
	dagger.weapon_type = SRD.WeaponType.SIMPLE
	dagger.damage_type = SRD.DamageType.PIERCING
	dagger.die_count = 1; dagger.die_sides = 4
	dagger.properties = SRD.WeaponProperty.FINESSE | SRD.WeaponProperty.LIGHT

	var eq := EquipmentSlots.new()
	# No armor — unarmored: 10 + DEX(+2) = 12

	return Combatant.new(s, dagger, eq)

static func _make_warden() -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Sova (Warden)"
	s.level = 3; s.hit_die = 8
	s.strength = 12; s.dexterity = 10; s.constitution = 13
	s.intelligence = 10; s.wisdom = 16; s.charisma = 12
	# HP: 8 + (4+1)*2 = 8 + 10 = 18
	s.max_hp = 18; s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.WISDOM, true)
	s.set_save_proficiency(SRD.Ability.CHARISMA, true)

	var mace := WeaponData.new()
	mace.weapon_name = "Mace"
	mace.weapon_type = SRD.WeaponType.SIMPLE
	mace.damage_type = SRD.DamageType.BLUDGEONING
	mace.die_count = 1; mace.die_sides = 6

	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_scale_mail())  # 14 + DEX(0) = 14
	eq.equip_shield(ArmorData.make_shield())     # +2 → 16

	return Combatant.new(s, mace, eq)

static func _make_soldier_2() -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Rynn (Soldier)"
	s.level = 3; s.hit_die = 10
	s.strength = 14; s.dexterity = 14; s.constitution = 14
	s.intelligence = 10; s.wisdom = 12; s.charisma = 10
	# HP: 10 + (5+2)*2 = 24
	s.max_hp = 24; s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.STRENGTH, true)
	s.set_save_proficiency(SRD.Ability.CONSTITUTION, true)

	var handaxe := WeaponData.new()
	handaxe.weapon_name = "Handaxe"
	handaxe.weapon_type = SRD.WeaponType.SIMPLE
	handaxe.damage_type = SRD.DamageType.SLASHING
	handaxe.die_count = 1; handaxe.die_sides = 6
	handaxe.properties = SRD.WeaponProperty.LIGHT | SRD.WeaponProperty.THROWN
	handaxe.range_normal = 20; handaxe.range_long = 60

	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_chain_mail())  # AC 16

	return Combatant.new(s, handaxe, eq)
