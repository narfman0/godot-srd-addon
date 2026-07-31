extends GutTest

func _make_char(dex: int, name: String) -> CharacterStats:
	var c := CharacterStats.new()
	c.dexterity = dex; c.character_name = name
	c.max_hp = 20; c.level = 1; c.reset()
	return c

func test_build_orders_all_combatants():
	var a := _make_char(10, "A"); var b := _make_char(10, "B")
	var order := CombatOrder.new()
	order.build([a, b])
	assert_eq(order.count(), 2)

func test_set_order_deterministic():
	var a := _make_char(10, "A"); var b := _make_char(14, "B")
	var order := CombatOrder.new()
	order.set_order([
		{ "char": a, "roll": 5, "total": 5 },
		{ "char": b, "roll": 15, "total": 17 },
	])
	assert_eq(order.current().character_name, "A")  # index 0 in our manual array

func test_higher_total_goes_first():
	var fast := _make_char(16, "Fast"); var slow := _make_char(8, "Slow")
	var order := CombatOrder.new()
	# Manual order — sorted descending
	order.set_order([
		{ "char": fast, "roll": 18, "total": 21 },
		{ "char": slow, "roll": 5, "total": 4 },
	])
	assert_eq(order.current().character_name, "Fast")

func test_advance_cycles_to_next():
	var a := _make_char(10, "A"); var b := _make_char(10, "B")
	var order := CombatOrder.new()
	order.set_order([
		{ "char": a, "roll": 10, "total": 10 },
		{ "char": b, "roll": 8, "total": 8 },
	])
	order.advance()
	assert_eq(order.current().character_name, "B")

func test_advance_wraps_and_increments_round():
	var a := _make_char(10, "A"); var b := _make_char(10, "B")
	var order := CombatOrder.new()
	order.set_order([
		{ "char": a, "roll": 10, "total": 10 },
		{ "char": b, "roll": 8, "total": 8 },
	])
	var new_round := order.advance()  # → B; not a new round yet
	assert_false(new_round)
	new_round = order.advance()       # wraps → A; new round
	assert_true(new_round)
	assert_eq(order.round_number, 2)
	assert_eq(order.current().character_name, "A")
