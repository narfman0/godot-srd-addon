extends GutTest

func _make_char() -> CharacterStats:
	var c := CharacterStats.new(); c.max_hp = 100; c.level = 1; c.reset()
	return c

func test_normal_damage_applied():
	var c := _make_char()
	DamageResolver.apply(c, 10, SRD.DamageType.FIRE)
	assert_eq(c.current_hp, 90)

func test_resistance_halves_damage():
	var c := _make_char()
	c.set_resistance(SRD.DamageType.FIRE, true)
	DamageResolver.apply(c, 10, SRD.DamageType.FIRE)
	assert_eq(c.current_hp, 95)  # floor(10/2) = 5

func test_resistance_floors_odd_damage():
	var c := _make_char()
	c.set_resistance(SRD.DamageType.FIRE, true)
	DamageResolver.apply(c, 7, SRD.DamageType.FIRE)
	assert_eq(c.current_hp, 97)  # floor(7/2) = 3

func test_immunity_applies_zero_damage():
	var c := _make_char()
	c.set_immunity(SRD.DamageType.POISON, true)
	DamageResolver.apply(c, 20, SRD.DamageType.POISON)
	assert_eq(c.current_hp, 100)

func test_vulnerability_doubles_damage():
	var c := _make_char()
	c.set_vulnerability(SRD.DamageType.COLD, true)
	DamageResolver.apply(c, 8, SRD.DamageType.COLD)
	assert_eq(c.current_hp, 84)  # 8*2 = 16

func test_calculate_does_not_apply_damage():
	var c := _make_char()
	var modified := DamageResolver.calculate(c, 10, SRD.DamageType.FIRE)
	assert_eq(modified, 10)
	assert_eq(c.current_hp, 100)  # untouched

func test_resistance_calculate():
	var c := _make_char()
	c.set_resistance(SRD.DamageType.FIRE, true)
	assert_eq(DamageResolver.calculate(c, 10, SRD.DamageType.FIRE), 5)

func test_immunity_overrides_vulnerability():
	var c := _make_char()
	c.set_immunity(SRD.DamageType.FIRE, true)
	c.set_vulnerability(SRD.DamageType.FIRE, true)  # immunity wins
	assert_eq(DamageResolver.calculate(c, 10, SRD.DamageType.FIRE), 0)
