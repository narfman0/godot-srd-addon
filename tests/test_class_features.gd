extends GutTest

func _make_injured_char(level: int = 5, damage: int = 20) -> CharacterStats:
	var s := CharacterStats.new()
	s.character_name = "Fighter"
	s.level = level; s.hit_die = 10
	s.strength = 16; s.dexterity = 10; s.constitution = 14
	s.intelligence = 10; s.wisdom = 10; s.charisma = 8
	s.max_hp = 44; s.speed = 30; s.reset()
	s.take_damage(damage)
	return s

func _light_finesse_weapon() -> WeaponData:
	var w := WeaponData.new()
	w.die_count = 1; w.die_sides = 6; w.range_normal = 5
	w.properties = SRD.WeaponProperty.FINESSE | SRD.WeaponProperty.LIGHT
	return w

func test_action_surge_restores_spent_action():
	var ae := ActionEconomy.new(30)
	ae.use_action()
	assert_false(ae.has_action)
	var tracker := ClassFeatureTracker.new(ClassData.make_soldier())
	assert_true(SRDClassFeatures.action_surge(ae, tracker))
	assert_true(ae.has_action)

func test_action_surge_marks_used():
	var ae := ActionEconomy.new(30)
	ae.use_action()
	var tracker := ClassFeatureTracker.new(ClassData.make_soldier())
	SRDClassFeatures.action_surge(ae, tracker)
	assert_true(tracker.action_surge_used)

func test_action_surge_fails_if_already_used():
	var ae := ActionEconomy.new(30)
	ae.use_action()
	var tracker := ClassFeatureTracker.new(ClassData.make_soldier())
	SRDClassFeatures.action_surge(ae, tracker)
	ae.use_action()
	assert_false(SRDClassFeatures.action_surge(ae, tracker))

func test_second_wind_heals():
	var s := _make_injured_char(5, 20)  # 44 - 20 = 24 HP
	var tracker := ClassFeatureTracker.new(ClassData.make_soldier())
	var healed := SRDClassFeatures.second_wind(s, tracker, 8)  # 8 + 5 = 13
	assert_eq(healed, 13)
	assert_eq(s.current_hp, 37)

func test_second_wind_marks_used():
	var s := _make_injured_char()
	var tracker := ClassFeatureTracker.new(ClassData.make_soldier())
	SRDClassFeatures.second_wind(s, tracker, 5)
	assert_true(tracker.second_wind_used)

func test_second_wind_fails_if_already_used():
	var s := _make_injured_char()
	var tracker := ClassFeatureTracker.new(ClassData.make_soldier())
	SRDClassFeatures.second_wind(s, tracker, 5)
	assert_eq(SRDClassFeatures.second_wind(s, tracker, 5), 0)

func test_sneak_attack_dice_scales_with_level():
	assert_eq(SRDClassFeatures.sneak_attack_dice(1), 1)
	assert_eq(SRDClassFeatures.sneak_attack_dice(2), 1)
	assert_eq(SRDClassFeatures.sneak_attack_dice(3), 2)
	assert_eq(SRDClassFeatures.sneak_attack_dice(5), 3)
	assert_eq(SRDClassFeatures.sneak_attack_dice(20), 10)

func test_can_sneak_attack_finesse_with_advantage():
	var w := _light_finesse_weapon()
	assert_true(SRDClassFeatures.can_sneak_attack(w, true, false, false))

func test_can_sneak_attack_finesse_with_ally():
	var w := _light_finesse_weapon()
	assert_true(SRDClassFeatures.can_sneak_attack(w, false, true, false))

func test_can_sneak_attack_denied_no_advantage_or_ally():
	var w := _light_finesse_weapon()
	assert_false(SRDClassFeatures.can_sneak_attack(w, false, false, false))

func test_can_sneak_attack_denied_with_disadvantage():
	var w := _light_finesse_weapon()
	assert_false(SRDClassFeatures.can_sneak_attack(w, true, true, true))

func test_can_sneak_attack_denied_for_non_finesse_melee():
	var w := WeaponData.new()
	w.die_count = 1; w.die_sides = 8; w.range_normal = 5  # longsword, no finesse
	assert_false(SRDClassFeatures.can_sneak_attack(w, true, false, false))

func test_arcane_recovery_restores_slots():
	var slots := EnergySlots.make_full_caster(5)
	slots.use_slot(2); slots.use_slot(3)
	var tracker := ClassFeatureTracker.new(ClassData.make_psion())
	var ok := SRDClassFeatures.arcane_recovery(slots, [2, 1], 5, tracker)
	assert_true(ok)
	assert_true(tracker.arcane_recovery_used)

func test_arcane_recovery_blocked_if_already_used():
	var slots := EnergySlots.make_full_caster(5)
	slots.use_slot(1)
	var tracker := ClassFeatureTracker.new(ClassData.make_psion())
	SRDClassFeatures.arcane_recovery(slots, [1], 5, tracker)
	assert_false(SRDClassFeatures.arcane_recovery(slots, [1], 5, tracker))

func test_arcane_recovery_blocked_for_slot_level_6_plus():
	var slots := EnergySlots.make_full_caster(12)
	var tracker := ClassFeatureTracker.new(ClassData.make_psion())
	assert_false(SRDClassFeatures.arcane_recovery(slots, [6], 12, tracker))

func test_channel_divinity_zero_for_non_warden():
	assert_eq(SRDClassFeatures.channel_divinity_count(ClassData.make_soldier(), 10), 0)
	assert_eq(SRDClassFeatures.channel_divinity_count(ClassData.make_ghost(), 10), 0)

func test_channel_divinity_scales_by_level():
	assert_eq(SRDClassFeatures.channel_divinity_count(ClassData.make_warden(), 1), 1)
	assert_eq(SRDClassFeatures.channel_divinity_count(ClassData.make_warden(), 6), 2)
	assert_eq(SRDClassFeatures.channel_divinity_count(ClassData.make_warden(), 18), 3)

func test_use_channel_divinity_depletes_uses():
	var tracker := ClassFeatureTracker.new(ClassData.make_warden())
	assert_eq(tracker.channel_divinity_max, 1)
	assert_true(SRDClassFeatures.use_channel_divinity(tracker))
	assert_false(SRDClassFeatures.use_channel_divinity(tracker))

func test_short_rest_resets_action_surge_and_second_wind():
	var tracker := ClassFeatureTracker.new(ClassData.make_soldier())
	var ae := ActionEconomy.new(30)
	ae.use_action()
	SRDClassFeatures.action_surge(ae, tracker)
	var s := _make_injured_char()
	SRDClassFeatures.second_wind(s, tracker, 5)
	tracker.short_rest_reset(ClassData.make_soldier(), 5)
	assert_false(tracker.action_surge_used)
	assert_false(tracker.second_wind_used)

func test_long_rest_also_resets_arcane_recovery():
	var slots := EnergySlots.make_full_caster(5)
	slots.use_slot(1)
	var tracker := ClassFeatureTracker.new(ClassData.make_psion())
	SRDClassFeatures.arcane_recovery(slots, [1], 5, tracker)
	assert_true(tracker.arcane_recovery_used)
	tracker.long_rest_reset(ClassData.make_psion(), 5)
	assert_false(tracker.arcane_recovery_used)
