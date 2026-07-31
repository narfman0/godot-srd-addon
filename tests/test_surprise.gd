extends GutTest

func _make_combatant(name: String = "C") -> Combatant:
	var s := CharacterStats.new()
	s.character_name = name; s.level = 1
	s.strength = 10; s.dexterity = 10; s.constitution = 10
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 8; s.speed = 30; s.reset()
	return Combatant.new(s)

func test_add_and_is_surprised():
	var tracker := SurpriseTracker.new()
	var c := _make_combatant()
	tracker.add_surprised(c)
	assert_true(tracker.is_surprised(c))

func test_add_duplicate_does_not_double_count():
	var tracker := SurpriseTracker.new()
	var c := _make_combatant()
	tracker.add_surprised(c)
	tracker.add_surprised(c)
	assert_eq(tracker.surprised_count(), 1)

func test_non_added_combatant_not_surprised():
	var tracker := SurpriseTracker.new()
	var a := _make_combatant("A")
	var b := _make_combatant("B")
	tracker.add_surprised(a)
	assert_false(tracker.is_surprised(b))

func test_surprised_count():
	var tracker := SurpriseTracker.new()
	assert_eq(tracker.surprised_count(), 0)
	tracker.add_surprised(_make_combatant("X"))
	tracker.add_surprised(_make_combatant("Y"))
	assert_eq(tracker.surprised_count(), 2)

func test_end_surprise_round_lifts_surprise():
	var tracker := SurpriseTracker.new()
	var c := _make_combatant()
	tracker.add_surprised(c)
	tracker.end_surprise_round()
	assert_false(tracker.is_surprised(c))

func test_apply_to_turn_blocks_action_and_movement():
	var tracker := SurpriseTracker.new()
	var c := _make_combatant()
	tracker.add_surprised(c)
	tracker.apply_to_turn(c)
	assert_false(c.action_economy.has_action)
	assert_false(c.action_economy.has_bonus_action)
	assert_eq(c.action_economy.movement_remaining, 0)
	assert_false(c.action_economy.has_reaction)

func test_apply_to_turn_no_effect_if_not_surprised():
	var tracker := SurpriseTracker.new()
	var c := _make_combatant()
	# not added to tracker
	tracker.apply_to_turn(c)
	assert_true(c.action_economy.has_action)
	assert_eq(c.action_economy.movement_remaining, 30)

func test_surprise_only_lasts_first_round():
	var tracker := SurpriseTracker.new()
	var c := _make_combatant()
	tracker.add_surprised(c)
	tracker.end_surprise_round()
	# after round ends, apply_to_turn should be a no-op
	tracker.apply_to_turn(c)
	assert_true(c.action_economy.has_action)
