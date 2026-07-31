extends GutTest

func test_starts_with_all_resources():
	var ae := ActionEconomy.new(30)
	assert_true(ae.has_action)
	assert_true(ae.has_bonus_action)
	assert_true(ae.has_reaction)
	assert_eq(ae.movement_remaining, 30)

func test_use_action():
	var ae := ActionEconomy.new()
	assert_true(ae.use_action())
	assert_false(ae.has_action)

func test_use_action_twice_fails():
	var ae := ActionEconomy.new()
	ae.use_action()
	assert_false(ae.use_action())

func test_use_bonus_action():
	var ae := ActionEconomy.new()
	assert_true(ae.use_bonus_action())
	assert_false(ae.has_bonus_action)

func test_use_reaction():
	var ae := ActionEconomy.new()
	assert_true(ae.use_reaction())
	assert_false(ae.has_reaction)

func test_spend_movement():
	var ae := ActionEconomy.new(30)
	assert_true(ae.spend_movement(15))
	assert_eq(ae.movement_remaining, 15)

func test_spend_movement_exact():
	var ae := ActionEconomy.new(30)
	assert_true(ae.spend_movement(30))
	assert_eq(ae.movement_remaining, 0)

func test_spend_movement_overdraft_fails():
	var ae := ActionEconomy.new(30)
	assert_false(ae.spend_movement(35))
	assert_eq(ae.movement_remaining, 30)  # unchanged

func test_reset_restores_action_and_movement():
	var ae := ActionEconomy.new(30)
	ae.use_action(); ae.use_bonus_action(); ae.spend_movement(30)
	ae.reset_turn()
	assert_true(ae.has_action)
	assert_true(ae.has_bonus_action)
	assert_eq(ae.movement_remaining, 30)

func test_reaction_not_reset_by_reset_turn():
	var ae := ActionEconomy.new()
	ae.use_reaction()
	ae.reset_turn()
	assert_false(ae.has_reaction)  # reaction resets at round level

func test_reset_reaction():
	var ae := ActionEconomy.new()
	ae.use_reaction()
	ae.reset_reaction()
	assert_true(ae.has_reaction)

func test_apply_incapacitated_blocks_action():
	var ae := ActionEconomy.new()
	ae.apply_incapacitated()
	assert_false(ae.has_action)
	assert_false(ae.has_bonus_action)
