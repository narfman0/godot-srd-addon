extends GutTest

func test_add_and_has():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PRONE)
	assert_true(t.has(SRD.Condition.PRONE))
	assert_false(t.has(SRD.Condition.BLINDED))

func test_remove():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.POISONED)
	t.remove(SRD.Condition.POISONED)
	assert_false(t.has(SRD.Condition.POISONED))

func test_clear_all():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.BLINDED)
	t.add(SRD.Condition.PRONE)
	t.clear_all()
	assert_false(t.has(SRD.Condition.BLINDED))
	assert_false(t.has(SRD.Condition.PRONE))

func test_paralyzed_implies_incapacitated():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PARALYZED)
	assert_true(t.has(SRD.Condition.INCAPACITATED))

func test_stunned_implies_incapacitated():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.STUNNED)
	assert_true(t.has(SRD.Condition.INCAPACITATED))

func test_unconscious_implies_incapacitated():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.UNCONSCIOUS)
	assert_true(t.has(SRD.Condition.INCAPACITATED))

func test_remove_paralyzed_clears_incapacitated_when_no_other_source():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PARALYZED)
	t.remove(SRD.Condition.PARALYZED)
	assert_false(t.has(SRD.Condition.INCAPACITATED))

func test_incapacitated_persists_when_multiple_sources():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PARALYZED)
	t.add(SRD.Condition.STUNNED)
	t.remove(SRD.Condition.PARALYZED)
	assert_true(t.has(SRD.Condition.INCAPACITATED))  # stunned still active

func test_exhaustion_stacking():
	var t := ConditionTracker.new()
	t.add_exhaustion()
	t.add_exhaustion()
	assert_eq(t.exhaustion_level, 2)

func test_exhaustion_level_6_kills():
	var t := ConditionTracker.new()
	for i in 6:
		t.add_exhaustion()
	assert_true(t.has(SRD.Condition.DEAD))

func test_exhaustion_cannot_exceed_6():
	var t := ConditionTracker.new()
	for i in 10:
		t.add_exhaustion()
	assert_eq(t.exhaustion_level, 6)

func test_remove_exhaustion():
	var t := ConditionTracker.new()
	t.add_exhaustion(); t.add_exhaustion()
	t.remove_exhaustion(1)
	assert_eq(t.exhaustion_level, 1)

func test_grants_advantage_to_attackers_prone():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PRONE)
	assert_true(t.grants_advantage_to_attackers())

func test_grants_advantage_to_attackers_paralyzed():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PARALYZED)
	assert_true(t.grants_advantage_to_attackers())

func test_attack_disadvantage_from_blinded():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.BLINDED)
	assert_true(t.has_attack_disadvantage())

func test_attack_advantage_from_invisible():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.INVISIBLE)
	assert_true(t.has_attack_advantage())

func test_auto_fails_str_dex_saves_when_paralyzed():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PARALYZED)
	assert_true(t.auto_fails_str_dex_saves())
