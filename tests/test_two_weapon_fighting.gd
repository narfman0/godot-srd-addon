extends GutTest

func _light_weapon(sides: int = 6) -> WeaponData:
	var w := WeaponData.new()
	w.die_count = 1; w.die_sides = sides
	w.damage_type = SRD.DamageType.SLASHING
	w.range_normal = 5
	w.properties = SRD.WeaponProperty.LIGHT | SRD.WeaponProperty.FINESSE
	return w

func _heavy_weapon() -> WeaponData:
	var w := WeaponData.new()
	w.die_count = 1; w.die_sides = 8
	w.damage_type = SRD.DamageType.SLASHING
	w.range_normal = 5  # melee but no LIGHT
	return w

func _make_combatant(dex: int = 16, hp: int = 20) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Dual"; s.level = 3
	s.strength = 10; s.dexterity = dex; s.constitution = 12
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = hp; s.speed = 30; s.reset()
	return Combatant.new(s, _light_weapon())

func _make_target() -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Target"; s.level = 1
	s.strength = 10; s.dexterity = 10; s.constitution = 10
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 30; s.speed = 30; s.reset()
	return Combatant.new(s)

func test_can_use_both_light():
	assert_true(TwoWeaponFighting.can_use(_light_weapon(), _light_weapon()))

func test_cannot_use_main_hand_not_light():
	assert_false(TwoWeaponFighting.can_use(_heavy_weapon(), _light_weapon()))

func test_cannot_use_off_hand_not_light():
	assert_false(TwoWeaponFighting.can_use(_light_weapon(), _heavy_weapon()))

func test_cannot_use_null_weapon():
	assert_false(TwoWeaponFighting.can_use(null, _light_weapon()))
	assert_false(TwoWeaponFighting.can_use(_light_weapon(), null))

func test_off_hand_damage_no_style_excludes_positive_mod():
	var s := CharacterStats.new()
	s.dexterity = 16  # +3 mod
	s.strength = 10; s.constitution = 10; s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 8; s.speed = 30; s.reset()
	var w := _light_weapon()
	# fixed_roll=4, no style → 4 + min(0, +3) = 4 + 0 = 4
	var dmg := TwoWeaponFighting.off_hand_damage(w, s, false, 4)
	assert_eq(dmg, 4)

func test_off_hand_damage_with_style_includes_mod():
	var s := CharacterStats.new()
	s.dexterity = 16  # +3
	s.strength = 10; s.constitution = 10; s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 8; s.speed = 30; s.reset()
	var w := _light_weapon()
	# fixed_roll=4, with style → 4 + 3 = 7
	var dmg := TwoWeaponFighting.off_hand_damage(w, s, true, 4)
	assert_eq(dmg, 7)

func test_off_hand_damage_negative_mod_always_applied():
	var s := CharacterStats.new()
	s.dexterity = 6  # -2 mod
	s.strength = 10; s.constitution = 10; s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 8; s.speed = 30; s.reset()
	var w := _light_weapon()
	# fixed_roll=4, no style → 4 + min(0, -2) = 4 - 2 = 2
	var dmg := TwoWeaponFighting.off_hand_damage(w, s, false, 4)
	assert_eq(dmg, 2)

func test_resolve_off_hand_attack_hit_deals_damage():
	var attacker := _make_combatant()
	var target := _make_target()
	var off_hand := _light_weapon()
	var ev := TwoWeaponFighting.resolve_off_hand_attack(attacker, target, off_hand, true, false, 20)
	assert_true(ev["hit"])
	assert_true(ev["crit"])
	assert_gt(ev["damage"], 0)
	assert_lt(target.stats.current_hp, 30)

func test_resolve_off_hand_attack_consumes_bonus_action():
	var attacker := _make_combatant()
	var target := _make_target()
	var off_hand := _light_weapon()
	TwoWeaponFighting.resolve_off_hand_attack(attacker, target, off_hand, true, false, 15)
	assert_false(attacker.action_economy.has_bonus_action)

func test_resolve_off_hand_attack_fails_not_light():
	var attacker := _make_combatant()
	attacker.weapon = _heavy_weapon()  # main hand not light
	var target := _make_target()
	var off_hand := _heavy_weapon()
	var ev := TwoWeaponFighting.resolve_off_hand_attack(attacker, target, off_hand, true, false, 15)
	assert_false(ev["hit"])
	assert_eq(ev["reason"], "not_light_weapons")

func test_resolve_off_hand_attack_fails_no_bonus_action():
	var attacker := _make_combatant()
	attacker.action_economy.use_bonus_action()
	var target := _make_target()
	var off_hand := _light_weapon()
	var ev := TwoWeaponFighting.resolve_off_hand_attack(attacker, target, off_hand, true, false, 15)
	assert_false(ev["hit"])
	assert_eq(ev["reason"], "no_bonus_action")
