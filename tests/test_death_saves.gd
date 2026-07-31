extends GutTest

func test_success_on_10_or_higher():
	var t := DeathSaveTracker.new()
	t.roll(15)
	assert_eq(t.successes, 1)
	assert_eq(t.failures, 0)

func test_failure_on_9_or_lower():
	var t := DeathSaveTracker.new()
	t.roll(9)
	assert_eq(t.failures, 1)

func test_nat_1_adds_two_failures():
	var t := DeathSaveTracker.new()
	t.roll(1)
	assert_eq(t.failures, 2)

func test_nat_20_stabilises():
	var t := DeathSaveTracker.new()
	t.roll(20)
	assert_true(t.is_stable)

func test_three_successes_stabilise():
	var t := DeathSaveTracker.new()
	t.roll(10); t.roll(11); t.roll(12)
	assert_true(t.is_stable)
	assert_false(t.is_dead)

func test_three_failures_kill():
	var t := DeathSaveTracker.new()
	t.roll(5); t.roll(6); t.roll(7)
	assert_true(t.is_dead)
	assert_false(t.is_stable)

func test_nat_1_can_kill_in_two_rolls():
	var t := DeathSaveTracker.new()
	t.roll(1)   # 2 failures
	t.roll(1)   # 4 failures → dead
	assert_true(t.is_dead)

func test_damage_at_zero_adds_failure():
	var t := DeathSaveTracker.new()
	t.on_damage_taken(false)
	assert_eq(t.failures, 1)

func test_crit_at_zero_adds_two_failures():
	var t := DeathSaveTracker.new()
	t.on_damage_taken(true)
	assert_eq(t.failures, 2)

func test_stabilise_sets_flag():
	var t := DeathSaveTracker.new()
	t.stabilise()
	assert_true(t.is_stable)
	assert_true(t.is_resolved())

func test_revive_resets_tracker():
	var t := DeathSaveTracker.new()
	t.roll(5); t.roll(6)
	t.revive()
	assert_eq(t.successes, 0)
	assert_eq(t.failures, 0)
	assert_false(t.is_dead)
	assert_false(t.is_stable)
