extends GutTest

func _make_char(max_hp: int = 40, level: int = 4, hit_die: int = 10, con: int = 10) -> CharacterStats:
	var c := CharacterStats.new()
	c.max_hp = max_hp; c.level = level; c.hit_die = hit_die
	c.constitution = con; c.reset()
	c.hit_dice_remaining = level
	return c

func test_short_rest_heals_hp():
	var c := _make_char()
	c.current_hp = 10
	SRDRest.short_rest(c, 1)
	assert_true(c.current_hp > 10)

func test_short_rest_decrements_hit_dice():
	var c := _make_char(); c.current_hp = 10
	SRDRest.short_rest(c, 2)
	assert_eq(c.hit_dice_remaining, 2)

func test_short_rest_caps_at_remaining_dice():
	var c := _make_char(); c.current_hp = 10
	c.hit_dice_remaining = 2
	SRDRest.short_rest(c, 10)  # ask for 10 but only 2 available
	assert_eq(c.hit_dice_remaining, 0)

func test_short_rest_cannot_exceed_max_hp():
	var c := _make_char()
	c.current_hp = c.max_hp - 1
	SRDRest.short_rest(c, 4)
	assert_eq(c.current_hp, c.max_hp)

func test_long_rest_restores_full_hp():
	var c := _make_char(); c.current_hp = 5
	SRDRest.long_rest(c)
	assert_eq(c.current_hp, c.max_hp)

func test_long_rest_recovers_half_hit_dice():
	var c := _make_char(40, 4); c.hit_dice_remaining = 0
	SRDRest.long_rest(c)
	assert_eq(c.hit_dice_remaining, 2)  # floor(4/2) = 2

func test_long_rest_hit_dice_capped_at_total():
	var c := _make_char(40, 4)
	c.hit_dice_remaining = 4  # already full
	SRDRest.long_rest(c)
	assert_eq(c.hit_dice_remaining, 4)

func test_long_rest_restores_slots():
	var slots := EnergySlots.make_full_caster(5)
	slots.use_slot(1); slots.use_slot(2)
	var c := _make_char()
	SRDRest.long_rest(c, slots)
	assert_eq(slots.slots_remaining_at(1), slots.slots_max_at(1))
	assert_eq(slots.slots_remaining_at(2), slots.slots_max_at(2))

func test_long_rest_clears_temp_hp():
	var c := _make_char(); c.add_temp_hp(10)
	SRDRest.long_rest(c)
	assert_eq(c.temp_hp, 0)
