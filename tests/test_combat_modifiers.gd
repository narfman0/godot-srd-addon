extends GutTest

func test_ranged_attacker_in_melee_gives_disadvantage():
	assert_true(CombatModifiers.ranged_into_melee_disadvantage(true, false))

func test_ranged_target_in_melee_gives_disadvantage():
	assert_true(CombatModifiers.ranged_into_melee_disadvantage(false, true))

func test_ranged_neither_in_melee_no_disadvantage():
	assert_false(CombatModifiers.ranged_into_melee_disadvantage(false, false))

func test_ranged_both_in_melee_gives_disadvantage():
	assert_true(CombatModifiers.ranged_into_melee_disadvantage(true, true))

func test_movement_cost_normal_terrain():
	assert_eq(CombatModifiers.movement_cost(30, false), 30)

func test_movement_cost_difficult_terrain_doubles():
	assert_eq(CombatModifiers.movement_cost(30, true), 60)

func test_movement_cost_single_step_difficult():
	assert_eq(CombatModifiers.movement_cost(5, true), 10)

func test_lighting_disadvantage_when_cant_see_target():
	assert_true(CombatModifiers.lighting_attack_disadvantage(false))

func test_no_lighting_disadvantage_when_can_see_target():
	assert_false(CombatModifiers.lighting_attack_disadvantage(true))

func test_lighting_advantage_when_target_cant_see_attacker():
	assert_true(CombatModifiers.lighting_attack_advantage(false))

func test_no_lighting_advantage_when_target_can_see():
	assert_false(CombatModifiers.lighting_attack_advantage(true))

func test_cover_bonus_none():
	assert_eq(CombatModifiers.cover_bonus(SRD.Cover.NONE), 0)

func test_cover_bonus_half():
	assert_eq(CombatModifiers.cover_bonus(SRD.Cover.HALF), 2)

func test_cover_bonus_three_quarters():
	assert_eq(CombatModifiers.cover_bonus(SRD.Cover.THREE_QUARTERS), 5)

func test_cover_bonus_full_prevents_targeting():
	assert_gt(CombatModifiers.cover_bonus(SRD.Cover.FULL), 10)
