extends GutTest

func test_roll_d20_in_range():
	for i in 100:
		var result := Dice.roll_d20()
		assert_true(result >= 1 and result <= 20, "d20 roll %d out of range" % result)

func test_roll_d6_in_range():
	for i in 100:
		var result := Dice.roll_d6()
		assert_true(result >= 1 and result <= 6, "d6 roll %d out of range" % result)

func test_roll_nd_sums_correctly():
	# 1d1 always equals 1
	assert_eq(Dice.roll_nd(3, 1), 3)

func test_advantage_not_below_disadvantage_over_many_rolls():
	var adv_total := 0
	var dis_total := 0
	var iterations := 1000
	for i in iterations:
		adv_total += Dice.roll_with_advantage(20)
		dis_total += Dice.roll_with_disadvantage(20)
	# advantage average should beat disadvantage average over many samples
	assert_true(adv_total > dis_total, "advantage should average higher than disadvantage")
