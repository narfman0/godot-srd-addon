## The Chapter 1 slice's spells, built from the SRD 5.2.1 pack and resolved end to end.
extends GutTest

var srd: SRDContent
var resolver: SpellResolver

func before_all():
	srd = SRDContent.new()

func before_each():
	resolver = SpellResolver.new()

func _wizard(level: int = 3) -> Combatant:
	return srd.make_character("Teodor", "wizard", level, [8, 14, 14, 16, 12, 10], "quarterstaff")

func _cleric(level: int = 3) -> Combatant:
	return srd.make_character("Maud", "cleric", level, [14, 10, 14, 10, 16, 12], "mace",
		"chain-shirt", true)

func _dummy(n: String = "Dummy", hp: int = 100, ac: int = 10) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = n
	s.max_hp = hp
	s.reset()
	var eq := EquipmentSlots.new()
	eq.natural_ac = ac
	return Combatant.new(s, null, eq)

func _wiz_spell(slug: String) -> AbilityData:
	return srd.make_spell(slug, SRD.Ability.INTELLIGENCE)

func _clr_spell(slug: String) -> AbilityData:
	return srd.make_spell(slug, SRD.Ability.WISDOM)

func test_slice_spells_carry_no_partial_or_no_mechanics_tags():
	for slug in ["fire-bolt", "ray-of-frost", "shocking-grasp", "magic-missile", "burning-hands",
			"thunderwave", "sleep", "shield", "misty-step", "scorching-ray", "sacred-flame",
			"guidance", "cure-wounds", "healing-word", "bless", "guiding-bolt",
			"shield-of-faith", "spiritual-weapon"]:
		var ab := srd.make_spell(slug)
		assert_does_not_have(ab.tags, SRDContent.TAG_PARTIAL, slug)
		assert_does_not_have(ab.tags, SRDContent.TAG_NO_MECHANICS, slug)

func test_casting_times():
	assert_eq(srd.make_spell("shield").casting_time, "reaction")
	assert_string_contains(srd.make_spell("shield").reaction_trigger, "hit by an attack roll")
	assert_eq(srd.make_spell("healing-word").casting_time, "bonus_action")
	assert_eq(srd.make_spell("fire-bolt").casting_time, "action")

func test_fire_bolt():
	var t := _dummy()
	var ev := resolver.cast(_wizard(), _wiz_spell("fire-bolt"), [t], -1, null, {"d20": 15, "average": true})
	assert_true(ev[0].hit)
	assert_between(ev[0].damage_dealt, 1, 10)
	assert_eq(_wiz_spell("fire-bolt").base_damage_dice(5), 2)

func test_ray_of_frost_slows_until_casters_next_turn():
	var w := _wizard()
	var t := _dummy()
	resolver.cast(w, _wiz_spell("ray-of-frost"), [t], -1, null, {"d20": 15})
	assert_eq(t.speed, 20)
	SRDEffects.turn_started([w, t], t)
	assert_eq(t.speed, 20, "the target's own turn doesn't end it")
	SRDEffects.turn_started([w, t], w)
	assert_eq(t.speed, 30)

func test_shocking_grasp_stops_opportunity_attacks():
	var w := _wizard()
	var t := srd.make_monster("goblin-warrior")
	var ev := resolver.cast(w, _wiz_spell("shocking-grasp"), [t], -1, null, {"d20": 18})
	assert_true(ev[0].hit)
	if t.is_alive:
		assert_false(OpportunityAttack.can_trigger(t, false))
		SRDEffects.turn_started([w, t], t)
		assert_true(t.effects.can_make_opportunity_attacks(), "until the start of its next turn")

func test_magic_missile_darts():
	var w := _wizard()
	var t := _dummy()
	var ev := resolver.cast(w, _wiz_spell("magic-missile"), [t], 1, null, {"average": true})
	assert_eq(ev.size(), 3)
	assert_eq(t.current_hp, 100 - 3 * (2 + 1))
	ev = resolver.cast(w, _wiz_spell("magic-missile"), [t], 2, null, {"average": true})
	assert_eq(ev.size(), 4, "one more dart per slot level above 1")

func test_magic_missile_splits_and_auto_hits():
	var w := _wizard()
	var a := _dummy("A", 100, 30)
	var b := _dummy("B", 100, 30)
	resolver.cast(w, _wiz_spell("magic-missile"), [a, a, b], 1, null, {"average": true})
	assert_eq(a.current_hp, 94)
	assert_eq(b.current_hp, 97)

func test_shield_reaction():
	var w := _wizard()
	var ac := w.armor_class
	var ev := resolver.cast(w, _wiz_spell("shield"), [])
	assert_eq(ev[0].type, "spell_self")
	assert_eq(w.armor_class, ac + 5)
	var foe := _dummy("Foe")
	var mm := resolver.cast(foe, _wiz_spell("magic-missile"), [w], 1, null, {"average": true})
	assert_true(mm[0].blocked, "no damage from Magic Missile")
	assert_eq(w.current_hp, w.stats.max_hp)
	SRDEffects.turn_started([w, foe], w)
	assert_eq(w.armor_class, ac)

func test_burning_hands_shares_one_roll():
	var w := _wizard()
	var a := _dummy("A")
	var b := _dummy("B")
	var ev := resolver.cast(w, _wiz_spell("burning-hands"), [a, b], 1, null, {"save_d20": 1})
	var full: int = ev[0].damage_dealt
	ev = resolver.cast(w, _wiz_spell("burning-hands"), [a, b], 1, null, {"save_d20": 20})
	assert_eq(ev[0].damage_dealt, ev[1].damage_dealt, "one damage roll for the cast")
	assert_between(full, 3, 18)

func test_burning_hands_upcast():
	var ab := _wiz_spell("burning-hands")
	assert_eq(ab.upcasted_damage_dice(2), 4)

func test_thunderwave_pushes_on_failed_save():
	var w := _wizard()
	var ev := resolver.cast(w, _wiz_spell("thunderwave"), [_dummy("A"), _dummy("B")], 1, null,
		{"save_d20": 1, "average": true})
	assert_eq(ev[0].push_feet, 10)
	assert_eq(ev[0].damage_dealt, 8)
	ev = resolver.cast(w, _wiz_spell("thunderwave"), [_dummy("C")], 1, null, {"save_d20": 20, "average": true})
	assert_false(ev[0].has("push_feet"))
	assert_eq(ev[0].damage_dealt, 4)

func test_sleep_2024():
	var w := _wizard()
	var t := _dummy("Guard")
	var conc := ConcentrationTracker.new()
	var ev := resolver.cast(w, _wiz_spell("sleep"), [t], 1, conc, {"save_d20": 1})
	assert_false(ev[0].saved)
	assert_true(t.conditions.is_incapacitated())
	assert_false(t.conditions.has(SRD.Condition.UNCONSCIOUS))
	# End of the target's next turn: repeat the save; failing means Unconscious
	var rs := SRDEffects.turn_ended([w, t], t, 1)
	assert_eq(rs.size(), 1)
	assert_false(rs[0].saved)
	assert_true(t.conditions.has(SRD.Condition.UNCONSCIOUS))
	# Damage ends it
	t.take_damage(1, SRD.DamageType.PIERCING)
	assert_false(t.conditions.has(SRD.Condition.UNCONSCIOUS))
	assert_false(t.conditions.is_incapacitated())

func test_sleep_repeat_save_success_wakes():
	var w := _wizard()
	var t := _dummy("Guard")
	resolver.cast(w, _wiz_spell("sleep"), [t], 1, null, {"save_d20": 1})
	var rs := SRDEffects.turn_ended([w, t], t, 20)
	assert_true(rs[0].saved)
	assert_false(t.conditions.is_incapacitated())

func test_sleep_ends_with_concentration():
	var w := _wizard()
	var t := _dummy("Guard")
	var conc := ConcentrationTracker.new()
	resolver.cast(w, _wiz_spell("sleep"), [t], 1, conc, {"save_d20": 1})
	conc.end()
	assert_false(t.conditions.is_incapacitated())

func test_sleep_fails_on_creatures_immune_to_exhaustion():
	var ev := resolver.cast(_wizard(), _wiz_spell("sleep"), [srd.make_monster("zombie")], 1, null, {"save_d20": 1})
	assert_true(ev[0].saved)
	assert_eq(ev[0].auto, "immune")

func test_misty_step():
	var ev := resolver.cast(_wizard(), _wiz_spell("misty-step"), [])
	assert_eq(ev[0].teleport_feet, 30)

func test_scorching_ray():
	var w := _wizard()
	var t := _dummy()
	var ev := resolver.cast(w, _wiz_spell("scorching-ray"), [t], 2, null, {"d20": 15, "average": true})
	assert_eq(ev.size(), 3)
	assert_true(ev.all(func(e): return e.hit and e.type == "spell_projectile"))
	assert_eq(t.current_hp, 100 - 3 * 6)
	assert_eq(resolver.cast(w, _wiz_spell("scorching-ray"), [t], 3, null, {"d20": 15}).size(), 4)

func test_sacred_flame():
	var c := _cleric()
	var ab := _clr_spell("sacred-flame")
	assert_true(ab.uses_save)
	assert_eq(ab.save_ability, SRD.Ability.DEXTERITY)
	var ev := resolver.cast(c, ab, [_dummy()], -1, null, {"save_d20": 20, "average": true})
	assert_eq(ev[0].damage_dealt, 0, "no damage on a success")
	ev = resolver.cast(c, ab, [_dummy()], -1, null, {"save_d20": 1, "average": true})
	assert_eq(ev[0].damage_dealt, 4)

func test_guidance():
	var c := _cleric()
	var ally := _dummy("Ally")
	resolver.cast(c, _clr_spell("guidance"), [ally])
	assert_eq(ally.effects.bonus_dice("check"), [4])
	assert_eq(ally.effects.bonus_dice("attack"), [])

func test_cure_wounds_and_upcast():
	var c := _cleric()
	var ally := _dummy("Ally", 60)
	ally.stats.current_hp = 1
	var ev := resolver.cast(c, _clr_spell("cure-wounds"), [ally], 2, null, {"average": true})
	assert_eq(ev[0].amount, 4 * 4 + 3 + (2 + 2))  # 4d8 avg + Wis + Disciple of Life

func test_healing_word_revives_a_downed_ally():
	var c := _cleric()
	var ally := srd.make_character("Ilse", "fighter", 3, [16, 12, 14, 8, 12, 10])
	ally.stats.current_hp = 0
	ally.death_saves.roll(5)
	var ev := resolver.cast(c, _clr_spell("healing-word"), [ally], 1, null, {"average": true})
	assert_gt(ally.current_hp, 0)
	assert_eq(ally.death_saves.failures, 0)
	assert_eq(ev[0].type, "spell_heal")

func test_bless():
	var c := _cleric()
	var allies := [_dummy("A"), _dummy("B"), _dummy("C"), _dummy("D")]
	var conc := ConcentrationTracker.new()
	var ev := resolver.cast(c, _clr_spell("bless"), allies, 1, conc)
	assert_eq(ev.size(), 3, "up to three creatures")
	assert_eq(allies[0].effects.bonus_dice("attack"), [4])
	assert_eq(allies[0].effects.bonus_dice("save"), [4])
	assert_eq(allies[3].effects.bonus_dice("attack"), [])
	assert_eq(resolver.cast(c, _clr_spell("bless"), allies, 2).size(), 4, "+1 target per slot level")
	var atk := AttackResolver.weapon_attack(allies[1], _dummy(), {"d20": 10})
	assert_between(atk.bonus_dice, 1, 4)
	conc.end()
	assert_eq(allies[0].effects.bonus_dice("attack"), [], "ends with Concentration")

func test_guiding_bolt_advantage_rider():
	var c := _cleric()
	var t := _dummy("Foe")
	var ev := resolver.cast(c, _clr_spell("guiding-bolt"), [t], 1, null, {"d20": 15, "average": true})
	assert_eq(ev[0].damage_dealt, 4 * 3)
	assert_true(t.effects.has_rider("advantage_to_attackers"))
	var ally := _dummy("Ally")
	var atk := AttackResolver.weapon_attack(ally, t, {"d20": 2, "d20_2": 18})
	assert_true(atk.advantage)
	assert_false(t.effects.has_rider("advantage_to_attackers"), "only the next attack roll")

func test_guiding_bolt_rider_expires_after_casters_next_turn():
	var c := _cleric()
	var t := _dummy("Foe")
	resolver.cast(c, _clr_spell("guiding-bolt"), [t], 1, null, {"d20": 15})
	SRDEffects.turn_ended([c, t], c)
	assert_true(t.effects.has_rider("advantage_to_attackers"))
	SRDEffects.turn_ended([c, t], c)
	assert_false(t.effects.has_rider("advantage_to_attackers"))

func test_shield_of_faith():
	var c := _cleric()
	var ally := _dummy("Ally", 20, 15)
	resolver.cast(c, _clr_spell("shield-of-faith"), [ally])
	assert_eq(ally.armor_class, 17)

func test_spiritual_weapon():
	var c := _cleric()
	var ab := _clr_spell("spiritual-weapon")
	assert_eq(ab.casting_time, "bonus_action")
	var t := _dummy()
	var ev := resolver.cast(c, ab, [t], 2, null, {"d20": 15, "average": true})
	assert_true(ev[0].hit)
	assert_eq(ev[0].damage_dealt, 4 + 3, "1d8 + spellcasting modifier")
	assert_eq(ev[0].summon.repeat_as, "bonus_action")
	assert_eq(ab.upcasted_damage_dice(3), 2)
