extends GutTest

func _make_char(str: int = 10, dex: int = 10) -> CharacterStats:
	var s := CharacterStats.new()
	s.level = 1
	s.strength = str; s.dexterity = dex; s.constitution = 10
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 8; s.speed = 30; s.reset()
	return s

func test_grapple_attacker_wins_high_roll():
	var atk := _make_char(10)
	var def := _make_char(10)
	# atk d20=20 vs def d20=5 → 20 > 5, attacker wins
	assert_true(ContestedCheck.grapple(atk, def, 20, 5))

func test_grapple_defender_wins_on_tie():
	var atk := _make_char(10)
	var def := _make_char(10)
	# equal rolls → defender wins (attacker must beat, not tie)
	assert_false(ContestedCheck.grapple(atk, def, 10, 10))

func test_grapple_defender_wins_higher_roll():
	var atk := _make_char(10)
	var def := _make_char(10)
	assert_false(ContestedCheck.grapple(atk, def, 5, 15))

func test_grapple_strength_bonus_helps_attacker():
	var atk := _make_char(20)  # +5 STR
	var def := _make_char(10)  # +0 STR
	# atk: 5 + 5 = 10, def: 14 + 0 = 14 → defender wins despite low atk d20
	# atk: 15 + 5 = 20, def: 14 + 0 = 14 → attacker wins
	assert_true(ContestedCheck.grapple(atk, def, 15, 14))

func test_apply_grapple_adds_condition_on_win():
	var cond := ConditionTracker.new()
	ContestedCheck.apply_grapple(cond, true)
	assert_true(cond.has(SRD.Condition.GRAPPLED))

func test_apply_grapple_no_condition_on_loss():
	var cond := ConditionTracker.new()
	ContestedCheck.apply_grapple(cond, false)
	assert_false(cond.has(SRD.Condition.GRAPPLED))

func test_apply_shove_prone_on_win():
	var cond := ConditionTracker.new()
	ContestedCheck.apply_shove(cond, true, true)
	assert_true(cond.has(SRD.Condition.PRONE))

func test_apply_shove_push_no_prone_condition():
	var cond := ConditionTracker.new()
	ContestedCheck.apply_shove(cond, true, false)
	assert_false(cond.has(SRD.Condition.PRONE))  # push = positional, not a condition

func test_apply_shove_no_effect_on_loss():
	var cond := ConditionTracker.new()
	ContestedCheck.apply_shove(cond, false, true)
	assert_false(cond.has(SRD.Condition.PRONE))

func test_escape_grapple_succeeds_with_high_roll():
	var grappled := _make_char(10)
	var grappler := _make_char(10)
	assert_true(ContestedCheck.escape_grapple(grappled, grappler, 20, 5))

func test_escape_grapple_fails_on_tie():
	var grappled := _make_char(10)
	var grappler := _make_char(10)
	assert_false(ContestedCheck.escape_grapple(grappled, grappler, 10, 10))

func test_grapple_defender_using_acrobatics():
	var atk := _make_char(10)
	var def := _make_char(10)
	def.dexterity = 20  # +5 DEX / Acrobatics
	# atk: 15 + 0 = 15, def: 5 + 5 = 10 → atk wins
	assert_true(ContestedCheck.grapple(atk, def, 15, 5, true))
