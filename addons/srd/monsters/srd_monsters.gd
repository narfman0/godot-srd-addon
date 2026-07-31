## SRD monster preset factories. All stat blocks from the 5e SRD.
class_name SRDMonsters
extends RefCounted

# ── Skeleton (CR 1/4, 50 XP) ────────────────────────────────────────────────
# AC 13, HP 13 (2d8+4), Speed 30
# STR 10, DEX 14, CON 15, INT 6, WIS 8, CHA 5
# Immunities: Poison damage, Exhaustion & Poisoned conditions
# Shortsword: +4 to hit, 1d6+2 piercing

static func make_skeleton(id: int = 0) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Skeleton" + ("" if id == 0 else " %d" % id)
	s.level = 1; s.hit_die = 8
	s.strength = 10; s.dexterity = 14; s.constitution = 15
	s.intelligence = 6; s.wisdom = 8; s.charisma = 5
	s.max_hp = 13; s.speed = 30; s.reset()
	s.set_immunity(SRD.DamageType.POISON, true)

	var shortsword := WeaponData.new()
	shortsword.weapon_name = "Shortsword"
	shortsword.weapon_type = SRD.WeaponType.MARTIAL
	shortsword.damage_type = SRD.DamageType.PIERCING
	shortsword.die_count = 1; shortsword.die_sides = 6
	shortsword.range_normal = 5

	var eq := EquipmentSlots.new()
	# AC 13 from armor scraps — model as studded leather equivalent
	eq.equip_armor(ArmorData.make_studded_leather())  # base 12 + DEX(+2) = 14...
	# Override: skeleton AC is exactly 13 via a flat-AC override approach.
	# We achieve AC 13 with leather (11) + DEX(+2) = 13. Use plain leather.
	eq.equip_armor(ArmorData.make_leather())  # 11 + 2 = 13 ✓

	var c := Combatant.new(s, shortsword, eq)
	c.is_proficient_with_weapon = true  # +4 = DEX mod(+2) + prof(+2)
	return c

# ── Zombie (CR 1/4, 50 XP) ──────────────────────────────────────────────────
# AC 8, HP 22 (3d8+9), Speed 20
# STR 13, DEX 6, CON 16, INT 3, WIS 6, CHA 5
# Immunity: Poison damage, Poisoned condition
# Undead Fortitude: CON save DC = 5 + damage dealt when reduced to 0 (not radiant, not crit)
# Slam: +3 to hit, 1d6+1 bludgeoning

static func make_zombie(id: int = 0) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Zombie" + ("" if id == 0 else " %d" % id)
	s.level = 1; s.hit_die = 8
	s.strength = 13; s.dexterity = 6; s.constitution = 16
	s.intelligence = 3; s.wisdom = 6; s.charisma = 5
	s.max_hp = 22; s.speed = 20; s.reset()
	s.set_immunity(SRD.DamageType.POISON, true)

	var slam := WeaponData.new()
	slam.weapon_name = "Slam"
	slam.weapon_type = SRD.WeaponType.SIMPLE
	slam.damage_type = SRD.DamageType.BLUDGEONING
	slam.die_count = 1; slam.die_sides = 6
	slam.range_normal = 5

	# AC 8: zombie has no armor, DEX -2 → 10 + (-2) = 8
	# We need to set this up so current_ac() returns 8.
	# Unarmored = 10 + DEX mod. DEX 6 → mod -2. So 10-2 = 8. ✓ No armor needed.
	var eq := EquipmentSlots.new()

	var c := Combatant.new(s, slam, eq)
	c.is_proficient_with_weapon = true  # +3 = STR mod(+1) + prof(+2)
	c.has_undead_fortitude = true
	return c

# ── Group factories ──────────────────────────────────────────────────────────

static func make_skeleton_group(count: int) -> Array:
	var group: Array = []
	for i in count:
		group.append(make_skeleton(i + 1))
	return group

static func make_zombie_group(count: int) -> Array:
	var group: Array = []
	for i in count:
		group.append(make_zombie(i + 1))
	return group
