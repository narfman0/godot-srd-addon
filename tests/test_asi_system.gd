extends GutTest

func _make_char() -> CharacterStats:
	var s := CharacterStats.new()
	s.strength = 10; s.dexterity = 10; s.constitution = 10
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 8; s.speed = 30; s.reset()
	return s

func test_soldier_has_extra_asi_levels():
	var cd := ClassData.make_soldier()
	assert_true(ASISystem.is_asi_level(cd, 4))
	assert_true(ASISystem.is_asi_level(cd, 6))   # soldier extra
	assert_true(ASISystem.is_asi_level(cd, 14))  # soldier extra
	assert_false(ASISystem.is_asi_level(cd, 5))

func test_ghost_has_extra_asi_at_10():
	var cd := ClassData.make_ghost()
	assert_true(ASISystem.is_asi_level(cd, 10))  # ghost extra
	assert_false(ASISystem.is_asi_level(cd, 6))

func test_psion_uses_standard_asi_levels():
	var cd := ClassData.make_psion()
	assert_true(ASISystem.is_asi_level(cd, 4))
	assert_true(ASISystem.is_asi_level(cd, 8))
	assert_false(ASISystem.is_asi_level(cd, 6))

func test_apply_single_increases_by_2():
	var s := _make_char()
	var ok := ASISystem.apply_single(s, SRD.Ability.STRENGTH)
	assert_true(ok)
	assert_eq(s.strength, 12)

func test_apply_single_fails_at_cap():
	var s := _make_char()
	s.strength = 20
	var ok := ASISystem.apply_single(s, SRD.Ability.STRENGTH)
	assert_false(ok)
	assert_eq(s.strength, 20)

func test_apply_single_clamps_to_cap():
	var s := _make_char()
	s.strength = 19
	ASISystem.apply_single(s, SRD.Ability.STRENGTH)
	assert_eq(s.strength, 20)  # +2 would overshoot but clamped

func test_apply_split_adds_1_to_each():
	var s := _make_char()
	ASISystem.apply_split(s, SRD.Ability.STRENGTH, SRD.Ability.DEXTERITY)
	assert_eq(s.strength, 11)
	assert_eq(s.dexterity, 11)

func test_improvable_abilities_excludes_capped():
	var s := _make_char()
	s.strength = 20
	var improvable := ASISystem.improvable_abilities(s)
	assert_false(improvable.has(SRD.Ability.STRENGTH))
	assert_true(improvable.has(SRD.Ability.DEXTERITY))

func test_improvable_abilities_empty_when_all_capped():
	var s := _make_char()
	for ability in SRD.Ability.values():
		s.set_ability(ability as SRD.Ability, 20)
	assert_eq(ASISystem.improvable_abilities(s).size(), 0)
