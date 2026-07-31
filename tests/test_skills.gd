extends GutTest

func _make_char(dex: int = 10, wis: int = 10, str_: int = 10, level: int = 1) -> CharacterStats:
	var c := CharacterStats.new()
	c.dexterity = dex; c.wisdom = wis; c.strength = str_
	c.level = level; c.max_hp = 8; c.reset()
	return c

func test_governing_ability_acrobatics_is_dex():
	assert_eq(SRDSkills.governing_ability(SRD.Skill.ACROBATICS), SRD.Ability.DEXTERITY)

func test_governing_ability_athletics_is_str():
	assert_eq(SRDSkills.governing_ability(SRD.Skill.ATHLETICS), SRD.Ability.STRENGTH)

func test_governing_ability_perception_is_wis():
	assert_eq(SRDSkills.governing_ability(SRD.Skill.PERCEPTION), SRD.Ability.WISDOM)

func test_unproficient_skill_bonus_is_just_modifier():
	var c := _make_char(14)  # DEX 14 → +2
	assert_eq(SRDSkills.skill_bonus(c, SRD.Skill.ACROBATICS), 2)

func test_proficient_skill_bonus_adds_prof():
	var c := _make_char(14)
	c.set_skill_proficiency(SRD.Skill.ACROBATICS, true)
	# DEX +2, prof +2 = 4
	assert_eq(SRDSkills.skill_bonus(c, SRD.Skill.ACROBATICS), 4)

func test_expertise_doubles_proficiency():
	var c := _make_char(14)
	c.set_skill_proficiency(SRD.Skill.ACROBATICS, true, true)
	# DEX +2, prof*2 = +4, total 6
	assert_eq(SRDSkills.skill_bonus(c, SRD.Skill.ACROBATICS), 6)

func test_passive_perception_no_proficiency():
	var c := _make_char(10, 14)  # WIS 14 → +2
	assert_eq(SRDSkills.passive_score(c, SRD.Skill.PERCEPTION), 12)

func test_passive_perception_with_proficiency():
	var c := _make_char(10, 14)
	c.set_skill_proficiency(SRD.Skill.PERCEPTION, true)
	# 10 + 2 (wis) + 2 (prof) = 14
	assert_eq(SRDSkills.passive_score(c, SRD.Skill.PERCEPTION), 14)

func test_passive_score_advantage_adds_5():
	var c := _make_char(10, 14)
	var base := SRDSkills.passive_score(c, SRD.Skill.PERCEPTION)
	var adv := SRDSkills.passive_score(c, SRD.Skill.PERCEPTION, true)
	assert_eq(adv, base + 5)

func test_passive_score_disadvantage_subtracts_5():
	var c := _make_char(10, 14)
	var base := SRDSkills.passive_score(c, SRD.Skill.PERCEPTION)
	var dis := SRDSkills.passive_score(c, SRD.Skill.PERCEPTION, false, true)
	assert_eq(dis, base - 5)

func test_skill_check_pass():
	var c := _make_char(18)  # DEX +4
	assert_true(SRDSkills.check(c, SRD.Skill.ACROBATICS, 15, 19))  # 15+4=19 ≥ 19

func test_skill_check_fail():
	var c := _make_char(10)  # DEX +0
	assert_false(SRDSkills.check(c, SRD.Skill.ACROBATICS, 10, 15))  # 10+0=10 < 15

func test_expertise_requires_proficiency():
	var c := _make_char(14)
	c.set_skill_proficiency(SRD.Skill.STEALTH, false, true)  # expertise without prof — should be ignored
	assert_false(c.has_skill_expertise(SRD.Skill.STEALTH))
