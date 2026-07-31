extends GutTest

func _make_char(dex: int = 14, str_: int = 10) -> CharacterStats:
	var c := CharacterStats.new()
	c.dexterity = dex; c.strength = str_
	c.max_hp = 10; c.level = 1; c.reset()
	return c

func test_unarmored_ac_is_10_plus_dex():
	var c := _make_char(14)
	var eq := EquipmentSlots.new()
	assert_eq(eq.current_ac(c), 12)  # 10 + 2

func test_light_armor_adds_full_dex():
	var c := _make_char(14)
	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_leather())  # base 11
	assert_eq(eq.current_ac(c), 13)  # 11 + 2

func test_medium_armor_caps_dex_at_2():
	var c := _make_char(18)  # DEX +4, but capped at +2
	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_scale_mail())  # base 14
	assert_eq(eq.current_ac(c), 16)  # 14 + 2

func test_heavy_armor_ignores_dex():
	var c := _make_char(18)  # DEX +4 ignored
	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_chain_mail())  # base 16
	assert_eq(eq.current_ac(c), 16)

func test_shield_adds_2_to_ac():
	var c := _make_char(14)
	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_leather())
	eq.equip_shield(ArmorData.make_shield())
	assert_eq(eq.current_ac(c), 15)  # 13 + 2

func test_unequip_armor_reverts_to_unarmored():
	var c := _make_char(14)
	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_leather())
	eq.unequip_armor()
	assert_eq(eq.current_ac(c), 12)

func test_stealth_disadvantage_from_chain_mail():
	var c := _make_char()
	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_chain_mail())
	assert_true(eq.has_stealth_disadvantage())

func test_no_stealth_disadvantage_from_leather():
	var c := _make_char()
	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_leather())
	assert_false(eq.has_stealth_disadvantage())

func test_strength_requirement_met():
	var c := _make_char(10, 15)
	var eq := EquipmentSlots.new()
	eq.equip_armor(ArmorData.make_chain_mail())  # requires STR 13
	assert_true(eq.meets_strength_requirement(c))

func test_weapon_finesse_picks_dex_when_higher():
	var c := CharacterStats.new()
	c.strength = 10; c.dexterity = 16  # DEX +3 > STR +0
	c.level = 1; c.max_hp = 8; c.reset()
	var rapier := WeaponData.new()
	rapier.die_count = 1; rapier.die_sides = 6
	rapier.damage_type = SRD.DamageType.PIERCING
	rapier.properties = SRD.WeaponProperty.FINESSE
	assert_eq(rapier.attack_bonus(c, false), 3)  # uses DEX

func test_weapon_finesse_picks_str_when_higher():
	var c := CharacterStats.new()
	c.strength = 16; c.dexterity = 10  # STR +3 > DEX +0
	c.level = 1; c.max_hp = 8; c.reset()
	var rapier := WeaponData.new()
	rapier.properties = SRD.WeaponProperty.FINESSE
	assert_eq(rapier.attack_bonus(c, false), 3)  # uses STR
