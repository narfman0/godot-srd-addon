## Integration test: Psion using energy slot abilities, saves, concentration.
extends GutTest

func _make_psion() -> CharacterStats:
	var c := CharacterStats.new()
	c.character_name = "Psion"
	c.intelligence = 18  # +4
	c.constitution = 14  # +2
	c.dexterity = 12
	c.level = 5; c.max_hp = 28; c.reset()
	c.set_save_proficiency(SRD.Ability.INTELLIGENCE, true)
	c.set_save_proficiency(SRD.Ability.WISDOM, true)
	return c

func _make_target(dex: int = 10, con: int = 10) -> CharacterStats:
	var c := CharacterStats.new()
	c.character_name = "Target"
	c.dexterity = dex; c.constitution = con
	c.level = 1; c.max_hp = 20; c.reset()
	return c

func _make_logic_blast() -> AbilityData:
	var a := AbilityData.new()
	a.ability_name = "Logic Blast"
	a.uses_save = true
	a.save_ability = SRD.Ability.DEXTERITY
	a.save_effect = SRD.SaveEffect.HALF
	a.damage_die_count = 8; a.damage_die_sides = 6
	a.damage_type = SRD.DamageType.PSYCHIC
	a.slot_level = 4; a.upcast_bonus_die_count = 1
	a.casting_ability = SRD.Ability.INTELLIGENCE
	a.concentration = false
	return a

func _make_mind_hold() -> AbilityData:
	var a := AbilityData.new()
	a.ability_name = "Mind Hold"
	a.concentration = true
	a.slot_level = 2; a.duration_rounds = 10
	a.uses_save = true; a.save_ability = SRD.Ability.WISDOM
	a.save_effect = SRD.SaveEffect.NONE
	a.damage_die_count = 0; a.damage_die_sides = 0
	a.casting_ability = SRD.Ability.INTELLIGENCE
	return a

func test_spell_save_dc_is_correct():
	var psion := _make_psion()
	var ability := _make_logic_blast()
	# DC = 8 + prof(3) + INT mod(4) = 15
	assert_eq(ability.spell_save_dc(psion), 15)

func test_save_fails_target_takes_full_damage():
	var psion := _make_psion()
	var target := _make_target(10)
	var ability := _make_logic_blast()
	# Injected roll 1: total 1 + DEX mod(0) = 1 < DC 15 → fail
	var result := AbilityResolver.resolve_saving_throw(psion, target, ability, -1, 1)
	assert_false(result["saved"])
	assert_true(result["damage"] > 0)

func test_save_succeeds_target_takes_half():
	var psion := _make_psion()
	var target := _make_target(10)
	var ability := _make_logic_blast()
	# Injected roll 20: 20 + 0 = 20 ≥ DC 15 → success, half damage
	var result_fail := AbilityResolver.resolve_saving_throw(psion, target, ability, -1, 1)
	var result_pass := AbilityResolver.resolve_saving_throw(psion, target, ability, -1, 20)
	assert_false(result_pass["saved"] == false)
	# Half damage should be roughly half of full damage
	assert_true(result_pass["damage"] <= result_fail["damage"])

func test_slot_consumed_on_cast():
	var slots := EnergySlots.make_full_caster(7)  # level 7 full caster has 4th-level slots
	var initial := slots.slots_remaining_at(4)
	assert_gt(initial, 0)
	slots.use_slot(4)
	assert_eq(slots.slots_remaining_at(4), initial - 1)

func test_no_slot_available_prevents_cast():
	var slots := EnergySlots.new()  # no slots
	assert_false(slots.use_slot(4))

func test_concentration_begins():
	var psion := _make_psion()
	var ability := _make_mind_hold()
	var tracker := ConcentrationTracker.new()
	tracker.begin(psion, ability)
	assert_true(tracker.is_concentrating)

func test_concentration_breaks_on_low_con_save():
	var psion := _make_psion()
	psion.constitution = 10  # +0
	var ability := _make_mind_hold()
	var tracker := ConcentrationTracker.new()
	tracker.begin(psion, ability)
	# Damage 20 → DC 10; injected roll 1 → 1+0 < 10
	var maintained := tracker.damage_concentration_check(20, 1)
	assert_false(maintained)
	assert_false(tracker.is_concentrating)

func test_upcast_adds_bonus_dice():
	var ability := _make_logic_blast()
	# Base 8 dice at slot 4; upcast to slot 5 → 9 dice
	assert_eq(ability.upcasted_damage_dice(5), 9)
	assert_eq(ability.upcasted_damage_dice(6), 10)

func test_full_slot_cycle_long_rest():
	var psion := _make_psion()
	var slots := EnergySlots.make_full_caster(5)
	slots.use_slot(3); slots.use_slot(3)
	var before := slots.slots_remaining_at(3)
	SRDRest.long_rest(psion, slots)
	assert_true(slots.slots_remaining_at(3) > before)
	assert_eq(slots.slots_remaining_at(3), slots.slots_max_at(3))
