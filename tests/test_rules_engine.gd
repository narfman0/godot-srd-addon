extends GutTest

func test_ability_modifier_10_is_0():
	assert_eq(SRDRules.ability_modifier(10), 0)

func test_ability_modifier_16_is_3():
	assert_eq(SRDRules.ability_modifier(16), 3)

func test_ability_modifier_8_is_minus_1():
	assert_eq(SRDRules.ability_modifier(8), -1)

func test_ability_modifier_1_is_minus_5():
	assert_eq(SRDRules.ability_modifier(1), -5)

func test_ability_modifier_20_is_5():
	assert_eq(SRDRules.ability_modifier(20), 5)

func test_proficiency_bonus_level_1_is_2():
	assert_eq(SRDRules.proficiency_bonus(1), 2)

func test_proficiency_bonus_level_4_is_2():
	assert_eq(SRDRules.proficiency_bonus(4), 2)

func test_proficiency_bonus_level_5_is_3():
	assert_eq(SRDRules.proficiency_bonus(5), 3)

func test_proficiency_bonus_level_17_is_6():
	assert_eq(SRDRules.proficiency_bonus(17), 6)

func test_attack_natural_20_always_hits():
	assert_true(SRDRules.attack_hits(20, -10, 30))

func test_attack_natural_1_always_misses():
	assert_false(SRDRules.attack_hits(1, 10, 2))

func test_attack_hits_exactly_on_ac():
	assert_true(SRDRules.attack_hits(15, 0, 15))

func test_attack_misses_below_ac():
	assert_false(SRDRules.attack_hits(14, 0, 15))

func test_passive_score_no_proficiency():
	assert_eq(SRDRules.passive_score(14, false, 3), 12)

func test_passive_score_with_proficiency():
	assert_eq(SRDRules.passive_score(14, true, 3), 15)
