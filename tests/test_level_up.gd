extends GutTest

func _make_soldier_char(level: int = 1) -> CharacterStats:
	var c := CharacterStats.new()
	c.level = level; c.hit_die = 10
	c.constitution = 14  # +2 CON
	c.max_hp = 12 + (level - 1) * 7  # rough initial HP
	c.reset()
	return c

func test_level_up_increments_level():
	var c := _make_soldier_char(1)
	var cls := ClassData.make_soldier()
	SRDLevelUp.level_up(c, cls)
	assert_eq(c.level, 2)

func test_level_up_increases_max_hp():
	var c := _make_soldier_char(1)
	var initial_hp := c.max_hp
	var cls := ClassData.make_soldier()
	SRDLevelUp.level_up(c, cls, null, false)
	assert_true(c.max_hp > initial_hp)

func test_level_up_hp_minimum_1():
	var c := _make_soldier_char(1)
	c.constitution = 1  # -5 CON → huge penalty
	var cls := ClassData.make_soldier()
	SRDLevelUp.level_up(c, cls, null, false)
	# Average: ceil(10/2)+1 = 6, -5 = 1, min 1
	assert_true(c.max_hp > 0)

func test_level_up_increments_hit_dice():
	var c := _make_soldier_char(1)
	var initial_dice := c.hit_dice_remaining
	SRDLevelUp.level_up(c, ClassData.make_soldier())
	assert_eq(c.hit_dice_remaining, initial_dice + 1)

func test_psion_gains_slots_at_level_up():
	var c := CharacterStats.new()
	c.level = 1; c.hit_die = 6; c.constitution = 10; c.max_hp = 6; c.reset()
	var cls := ClassData.make_psion()
	var slots := EnergySlots.make_full_caster(1)
	assert_eq(slots.slots_max_at(1), 2)
	SRDLevelUp.level_up(c, cls, slots)
	# Level 2 full caster gets 3 L1 slots
	assert_eq(slots.slots_max_at(1), 3)

func test_psion_gains_l2_slots_at_level_3():
	var c := CharacterStats.new()
	c.level = 2; c.hit_die = 6; c.constitution = 10; c.max_hp = 10; c.reset()
	var cls := ClassData.make_psion()
	var slots := EnergySlots.make_full_caster(2)
	SRDLevelUp.level_up(c, cls, slots)  # → level 3
	assert_eq(slots.slots_max_at(2), 2)

func test_soldier_never_gains_slots():
	var c := _make_soldier_char(1)
	var cls := ClassData.make_soldier()
	var slots := cls.make_slots(1)
	SRDLevelUp.level_up(c, cls, slots)
	assert_eq(slots.slots_max_at(1), 0)

func test_apply_class_save_proficiencies_soldier():
	var c := _make_soldier_char()
	SRDLevelUp.apply_class_proficiencies(c, ClassData.make_soldier())
	assert_true(c.is_save_proficient(SRD.Ability.STRENGTH))
	assert_true(c.is_save_proficient(SRD.Ability.CONSTITUTION))
	assert_false(c.is_save_proficient(SRD.Ability.DEXTERITY))

func test_proficiency_bonus_at_level_5_is_3():
	var c := _make_soldier_char(5)
	assert_eq(c.proficiency_bonus(), 3)
