extends GutTest

func test_level_1_threshold_is_0():
	assert_eq(SRDExperience.xp_for_level(1), 0)

func test_level_2_threshold():
	assert_eq(SRDExperience.xp_for_level(2), 300)

func test_level_5_threshold():
	assert_eq(SRDExperience.xp_for_level(5), 6500)

func test_level_20_threshold():
	assert_eq(SRDExperience.xp_for_level(20), 355000)

func test_level_for_0_xp_is_1():
	assert_eq(SRDExperience.level_for_xp(0), 1)

func test_level_for_xp_at_level_2_boundary():
	assert_eq(SRDExperience.level_for_xp(300), 2)

func test_level_for_xp_just_below_boundary():
	assert_eq(SRDExperience.level_for_xp(299), 1)

func test_level_for_max_xp():
	assert_eq(SRDExperience.level_for_xp(355000), 20)

func test_add_xp_returns_true_on_level_up():
	var c := CharacterStats.new(); c.max_hp = 10; c.level = 1; c.reset()
	c.xp = 0
	var levelled := SRDExperience.add_xp(c, 300)
	assert_true(levelled)

func test_add_xp_returns_false_without_level_up():
	var c := CharacterStats.new(); c.max_hp = 10; c.level = 1; c.reset()
	c.xp = 0
	var levelled := SRDExperience.add_xp(c, 100)
	assert_false(levelled)

func test_add_xp_accumulates():
	var c := CharacterStats.new(); c.max_hp = 10; c.level = 1; c.reset()
	c.xp = 0
	SRDExperience.add_xp(c, 150)
	SRDExperience.add_xp(c, 150)  # total 300
	assert_eq(SRDExperience.level_for_xp(c.xp), 2)
