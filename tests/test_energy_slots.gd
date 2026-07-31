extends GutTest

func test_use_slot_decrements():
	var s := EnergySlots.make_full_caster(3)  # level 3: 4×L1, 2×L2
	assert_eq(s.slots_remaining_at(1), 4)
	assert_true(s.use_slot(1))
	assert_eq(s.slots_remaining_at(1), 3)

func test_use_slot_fails_when_empty():
	var s := EnergySlots.new()
	assert_false(s.use_slot(1))

func test_recover_all_restores_to_max():
	var s := EnergySlots.make_full_caster(3)
	s.use_slot(1); s.use_slot(1)
	s.recover_all()
	assert_eq(s.slots_remaining_at(1), 4)

func test_recover_single_slot():
	var s := EnergySlots.make_full_caster(3)
	s.use_slot(1); s.use_slot(1)
	s.recover_slot(1, 1)
	assert_eq(s.slots_remaining_at(1), 3)

func test_recover_cannot_exceed_max():
	var s := EnergySlots.make_full_caster(1)  # max 2 L1 slots
	s.recover_slot(1, 99)
	assert_eq(s.slots_remaining_at(1), 2)

func test_full_caster_level_1_has_two_l1_slots():
	var s := EnergySlots.make_full_caster(1)
	assert_eq(s.slots_max_at(1), 2)
	assert_eq(s.slots_max_at(2), 0)

func test_full_caster_level_3_has_l2_slots():
	var s := EnergySlots.make_full_caster(3)
	assert_eq(s.slots_max_at(2), 2)

func test_half_caster_level_1_has_no_slots():
	var s := EnergySlots.make_half_caster(1)
	assert_eq(s.slots_max_at(1), 0)

func test_half_caster_level_2_has_l1_slots():
	var s := EnergySlots.make_half_caster(2)
	assert_eq(s.slots_max_at(1), 2)

func test_has_slot():
	var s := EnergySlots.make_full_caster(5)
	assert_true(s.has_slot(3))
	s.use_slot(3); s.use_slot(3)
	assert_false(s.has_slot(3))

func test_third_caster_no_slots_at_level_2():
	var s := EnergySlots.make_third_caster(2)
	assert_eq(s.slots_max_at(1), 0)

func test_third_caster_has_slots_at_level_3():
	var s := EnergySlots.make_third_caster(3)
	assert_eq(s.slots_max_at(1), 2)
