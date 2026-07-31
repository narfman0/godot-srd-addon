extends GutTest

func _make_char(str_: int = 10, dex: int = 10, con: int = 10,
		int_: int = 10, wis: int = 10, cha: int = 10) -> CharacterStats:
	var c := CharacterStats.new()
	c.strength = str_; c.dexterity = dex; c.constitution = con
	c.intelligence = int_; c.wisdom = wis; c.charisma = cha
	c.max_hp = 20; c.level = 1; c.reset()
	return c

func test_default_hp_equals_max_hp():
	var c := CharacterStats.new()
	c.max_hp = 15; c.reset()
	assert_eq(c.current_hp, 15)

func test_take_damage_reduces_hp():
	var c := _make_char(); c.max_hp = 20; c.reset()
	c.take_damage(8)
	assert_eq(c.current_hp, 12)

func test_hp_cannot_go_below_zero():
	var c := _make_char(); c.max_hp = 10; c.reset()
	c.take_damage(999)
	assert_eq(c.current_hp, 0)

func test_temp_hp_absorbs_damage_first():
	var c := _make_char(); c.max_hp = 20; c.reset()
	c.add_temp_hp(5)
	c.take_damage(3)
	assert_eq(c.temp_hp, 2)
	assert_eq(c.current_hp, 20)

func test_temp_hp_overflow_hits_real_hp():
	var c := _make_char(); c.max_hp = 20; c.reset()
	c.add_temp_hp(5)
	c.take_damage(8)
	assert_eq(c.temp_hp, 0)
	assert_eq(c.current_hp, 17)

func test_temp_hp_does_not_stack():
	var c := _make_char(); c.max_hp = 20; c.reset()
	c.add_temp_hp(5)
	c.add_temp_hp(3)
	assert_eq(c.temp_hp, 5)  # higher value wins

func test_temp_hp_replaces_when_higher():
	var c := _make_char(); c.max_hp = 20; c.reset()
	c.add_temp_hp(3)
	c.add_temp_hp(10)
	assert_eq(c.temp_hp, 10)

func test_heal_restores_hp():
	var c := _make_char(); c.max_hp = 20; c.reset()
	c.take_damage(10)
	var healed := c.heal(6)
	assert_eq(healed, 6)
	assert_eq(c.current_hp, 16)

func test_heal_capped_at_max_hp():
	var c := _make_char(); c.max_hp = 20; c.reset()
	c.take_damage(5)
	c.heal(100)
	assert_eq(c.current_hp, 20)

func test_heal_returns_zero_at_zero_hp():
	var c := _make_char(); c.max_hp = 20; c.reset()
	c.take_damage(20)
	var healed := c.heal(10)
	assert_eq(healed, 0)  # must be raised/stabilised first

func test_get_ability_returns_correct_scores():
	var c := _make_char(16, 14, 12, 10, 8, 6)
	assert_eq(c.get_ability(SRD.Ability.STRENGTH), 16)
	assert_eq(c.get_ability(SRD.Ability.DEXTERITY), 14)
	assert_eq(c.get_ability(SRD.Ability.CONSTITUTION), 12)
	assert_eq(c.get_ability(SRD.Ability.INTELLIGENCE), 10)
	assert_eq(c.get_ability(SRD.Ability.WISDOM), 8)
	assert_eq(c.get_ability(SRD.Ability.CHARISMA), 6)

func test_ability_modifier_derived_correctly():
	var c := _make_char(16, 10, 8)
	assert_eq(c.ability_modifier(SRD.Ability.STRENGTH), 3)
	assert_eq(c.ability_modifier(SRD.Ability.DEXTERITY), 0)
	assert_eq(c.ability_modifier(SRD.Ability.CONSTITUTION), -1)

func test_proficiency_bonus_scales_with_level():
	var c := CharacterStats.new(); c.level = 1; c.max_hp = 1; c.reset()
	assert_eq(c.proficiency_bonus(), 2)
	c.level = 5
	assert_eq(c.proficiency_bonus(), 3)

func test_save_proficiency_flag():
	var c := _make_char()
	c.set_save_proficiency(SRD.Ability.STRENGTH, true)
	assert_true(c.is_save_proficient(SRD.Ability.STRENGTH))
	assert_false(c.is_save_proficient(SRD.Ability.DEXTERITY))

func test_saving_throw_bonus_with_proficiency():
	var c := _make_char(16) # STR 16 → mod +3
	c.level = 1  # prof +2
	c.reset()
	c.set_save_proficiency(SRD.Ability.STRENGTH, true)
	assert_eq(c.saving_throw_bonus(SRD.Ability.STRENGTH), 5)  # +3 +2

func test_saving_throw_bonus_without_proficiency():
	var c := _make_char(16)
	assert_eq(c.saving_throw_bonus(SRD.Ability.STRENGTH), 3)  # just +3

func test_resistance_immunity_vulnerability_flags():
	var c := _make_char()
	c.set_resistance(SRD.DamageType.FIRE, true)
	c.set_immunity(SRD.DamageType.POISON, true)
	c.set_vulnerability(SRD.DamageType.COLD, true)
	assert_true(c.has_resistance(SRD.DamageType.FIRE))
	assert_true(c.has_immunity(SRD.DamageType.POISON))
	assert_true(c.has_vulnerability(SRD.DamageType.COLD))
	assert_false(c.has_resistance(SRD.DamageType.COLD))

func test_is_alive_and_at_zero():
	var c := _make_char(); c.max_hp = 10; c.reset()
	assert_true(c.is_alive())
	c.take_damage(10)
	assert_false(c.is_alive())
	assert_true(c.is_at_zero_hp())
