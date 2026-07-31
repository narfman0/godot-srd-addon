## Integration test: level 1-5 progression validation for Soldier and Psion.
extends GutTest

func _make_soldier_level1() -> CharacterStats:
	var c := CharacterStats.new()
	c.character_name = "Soldier"
	c.level = 1; c.hit_die = 10
	c.constitution = 14   # +2
	c.strength = 16; c.dexterity = 12
	# Level 1 HP: hit_die max (10) + CON mod (2) = 12
	c.max_hp = 12; c.reset()
	SRDLevelUp.apply_class_proficiencies(c, ClassData.make_soldier())
	return c

func _make_psion_level1() -> CharacterStats:
	var c := CharacterStats.new()
	c.character_name = "Psion"
	c.level = 1; c.hit_die = 6
	c.constitution = 10; c.intelligence = 16  # +3
	# Level 1 HP: 6 + 0 = 6
	c.max_hp = 6; c.reset()
	SRDLevelUp.apply_class_proficiencies(c, ClassData.make_psion())
	return c

## --- Proficiency bonus table ---

func test_proficiency_bonus_levels_1_to_4_is_2():
	var c := _make_soldier_level1()
	for lvl in [1, 2, 3, 4]:
		c.level = lvl
		assert_eq(c.proficiency_bonus(), 2, "Level %d proficiency should be 2" % lvl)

func test_proficiency_bonus_levels_5_to_8_is_3():
	var c := _make_soldier_level1()
	for lvl in [5, 6, 7, 8]:
		c.level = lvl
		assert_eq(c.proficiency_bonus(), 3, "Level %d proficiency should be 3" % lvl)

## --- Soldier progression ---

func test_soldier_hp_increases_each_level():
	var soldier := _make_soldier_level1()
	var cls := ClassData.make_soldier()
	var prev_max := soldier.max_hp
	for lvl in range(2, 6):
		SRDLevelUp.level_up(soldier, cls, null, false)  # take average HP
		assert_true(soldier.max_hp > prev_max,
			"HP should increase at level %d" % lvl)
		prev_max = soldier.max_hp

func test_soldier_has_no_slots_at_any_level():
	var soldier := _make_soldier_level1()
	var cls := ClassData.make_soldier()
	var slots := cls.make_slots(1)
	for _lvl in range(2, 6):
		SRDLevelUp.level_up(soldier, cls, slots, false)
		for slot_level in range(1, 10):
			assert_eq(slots.slots_max_at(slot_level), 0,
				"Soldier should have no L%d slots" % slot_level)

func test_soldier_save_proficiencies():
	var soldier := _make_soldier_level1()
	assert_true(soldier.is_save_proficient(SRD.Ability.STRENGTH))
	assert_true(soldier.is_save_proficient(SRD.Ability.CONSTITUTION))
	assert_false(soldier.is_save_proficient(SRD.Ability.DEXTERITY))

func test_soldier_hit_dice_equals_level():
	var soldier := _make_soldier_level1()
	var cls := ClassData.make_soldier()
	for _lvl in range(2, 6):
		SRDLevelUp.level_up(soldier, cls, null, false)
	assert_eq(soldier.hit_dice_remaining, soldier.level)

## --- Psion slot progression (matches 5e Wizard table) ---

func test_psion_l1_slots_level_1():
	var psion := _make_psion_level1()
	var slots := ClassData.make_psion().make_slots(1)
	assert_eq(slots.slots_max_at(1), 2)

func test_psion_l1_slots_level_2():
	var psion := _make_psion_level1()
	var cls := ClassData.make_psion()
	var slots := cls.make_slots(1)
	SRDLevelUp.level_up(psion, cls, slots, false)  # → level 2
	assert_eq(slots.slots_max_at(1), 3)

func test_psion_gains_l2_slots_at_level_3():
	var psion := _make_psion_level1()
	var cls := ClassData.make_psion()
	var slots := cls.make_slots(1)
	SRDLevelUp.level_up(psion, cls, slots, false)  # → level 2
	SRDLevelUp.level_up(psion, cls, slots, false)  # → level 3
	assert_eq(slots.slots_max_at(2), 2)

func test_psion_gains_l3_slots_at_level_5():
	var psion := _make_psion_level1()
	var cls := ClassData.make_psion()
	var slots := cls.make_slots(1)
	for _i in 4:
		SRDLevelUp.level_up(psion, cls, slots, false)
	assert_eq(psion.level, 5)
	assert_eq(slots.slots_max_at(3), 2)

func test_psion_save_proficiencies():
	var psion := _make_psion_level1()
	assert_true(psion.is_save_proficient(SRD.Ability.INTELLIGENCE))
	assert_true(psion.is_save_proficient(SRD.Ability.WISDOM))
	assert_false(psion.is_save_proficient(SRD.Ability.STRENGTH))
