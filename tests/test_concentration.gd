extends GutTest

func _make_caster(con: int = 14) -> CharacterStats:
	var c := CharacterStats.new()
	c.constitution = con; c.level = 1; c.max_hp = 20; c.reset()
	return c

func _make_concentration_ability() -> AbilityData:
	var a := AbilityData.new()
	a.ability_name = "Mind Hold"
	a.concentration = true
	a.slot_level = 1
	a.duration_rounds = 10
	return a

func test_begin_sets_concentrating():
	var caster := _make_caster()
	var ability := _make_concentration_ability()
	var tracker := ConcentrationTracker.new()
	tracker.begin(caster, ability)
	assert_true(tracker.is_concentrating)
	assert_eq(tracker.active_ability.ability_name, "Mind Hold")

func test_end_clears_concentration():
	var caster := _make_caster()
	var ability := _make_concentration_ability()
	var tracker := ConcentrationTracker.new()
	tracker.begin(caster, ability)
	tracker.end()
	assert_false(tracker.is_concentrating)
	assert_null(tracker.active_ability)

func test_new_ability_replaces_old():
	var caster := _make_caster()
	var a1 := _make_concentration_ability()
	var a2 := _make_concentration_ability(); a2.ability_name = "Gravity Well"
	var tracker := ConcentrationTracker.new()
	tracker.begin(caster, a1)
	tracker.begin(caster, a2)
	assert_eq(tracker.active_ability.ability_name, "Gravity Well")

func test_dc_is_max_10_or_half_damage():
	assert_eq(SRDRules.concentration_check_dc(10), 10)
	assert_eq(SRDRules.concentration_check_dc(20), 10)
	assert_eq(SRDRules.concentration_check_dc(22), 11)
	assert_eq(SRDRules.concentration_check_dc(30), 15)

func test_concentration_maintained_on_high_roll():
	var caster := _make_caster(16)  # CON +3; save prof not set → +3
	var ability := _make_concentration_ability()
	var tracker := ConcentrationTracker.new()
	tracker.begin(caster, ability)
	# Damage 10 → DC 10; roll 20 + 3 = 23 ≥ 10
	var maintained := tracker.damage_concentration_check(10, 20)
	assert_true(maintained)
	assert_true(tracker.is_concentrating)

func test_concentration_broken_on_low_roll():
	var caster := _make_caster(10)  # CON +0
	var ability := _make_concentration_ability()
	var tracker := ConcentrationTracker.new()
	tracker.begin(caster, ability)
	# Damage 20 → DC 10; roll 1 + 0 = 1 < 10
	var maintained := tracker.damage_concentration_check(20, 1)
	assert_false(maintained)
	assert_false(tracker.is_concentrating)

func test_check_without_concentration_always_returns_true():
	var caster := _make_caster()
	var tracker := ConcentrationTracker.new()
	assert_true(tracker.damage_concentration_check(100))
