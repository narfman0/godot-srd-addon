extends GutTest

func test_add_timed_sets_condition():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.STUNNED, 2)
	assert_true(t.has(SRD.Condition.STUNNED))

func test_rounds_remaining_returns_correct_value():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.BLINDED, 3)
	assert_eq(t.rounds_remaining(SRD.Condition.BLINDED), 3)

func test_rounds_remaining_returns_minus1_for_permanent():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PRONE)
	assert_eq(t.rounds_remaining(SRD.Condition.PRONE), -1)

func test_rounds_remaining_returns_minus1_when_absent():
	var t := ConditionTracker.new()
	assert_eq(t.rounds_remaining(SRD.Condition.BLINDED), -1)

func test_tick_round_decrements_counter():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.BLINDED, 2)
	t.tick_round()
	assert_eq(t.rounds_remaining(SRD.Condition.BLINDED), 1)
	assert_true(t.has(SRD.Condition.BLINDED))

func test_tick_round_removes_expired_condition():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.BLINDED, 1)
	var expired := t.tick_round()
	assert_false(t.has(SRD.Condition.BLINDED))
	assert_true(expired.has(SRD.Condition.BLINDED))

func test_tick_round_returns_only_expired():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.BLINDED, 1)
	t.add_timed(SRD.Condition.FRIGHTENED, 3)
	var expired := t.tick_round()
	assert_eq(expired.size(), 1)
	assert_true(expired.has(SRD.Condition.BLINDED))
	assert_true(t.has(SRD.Condition.FRIGHTENED))  # still active

func test_permanent_condition_not_affected_by_tick():
	var t := ConditionTracker.new()
	t.add(SRD.Condition.PRONE)
	t.tick_round()
	assert_true(t.has(SRD.Condition.PRONE))

func test_multiple_timed_conditions_tick_independently():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.BLINDED, 2)
	t.add_timed(SRD.Condition.FRIGHTENED, 1)
	t.tick_round()
	assert_true(t.has(SRD.Condition.BLINDED))   # 1 round left
	assert_false(t.has(SRD.Condition.FRIGHTENED))  # expired

func test_timed_condition_cleared_by_clear_all():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.STUNNED, 5)
	t.clear_all()
	assert_false(t.has(SRD.Condition.STUNNED))
	assert_eq(t.rounds_remaining(SRD.Condition.STUNNED), -1)

func test_add_timed_then_manual_remove_clears_timer():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.POISONED, 3)
	t.remove(SRD.Condition.POISONED)
	assert_false(t.has(SRD.Condition.POISONED))
	# Timer entry should not cause issues next tick (removed condition, timer orphaned but harmless)
	var expired := t.tick_round()
	assert_false(expired.has(SRD.Condition.POISONED))

func test_stunned_timed_implies_incapacitated():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.STUNNED, 2)
	assert_true(t.is_incapacitated())

func test_tick_stunned_expired_removes_incapacitated():
	var t := ConditionTracker.new()
	t.add_timed(SRD.Condition.STUNNED, 1)
	t.tick_round()
	assert_false(t.has(SRD.Condition.STUNNED))
	assert_false(t.is_incapacitated())
