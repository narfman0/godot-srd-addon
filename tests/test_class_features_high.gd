extends GutTest
## Levels 3 to 17: the features added for the classes the game uses.

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func _pc(cls: String, lvl: int, scores := [14, 14, 14, 14, 14, 14], weapon := "", armor := "", opts := {}) -> Combatant:
	return srd.make_character(cls, cls, lvl, scores, weapon, armor, false, [], "", opts)

func _ogre() -> Combatant:
	return srd.make_monster("ogre")

func test_monk_unarmored_defense_and_speed():
	var m := _pc("monk", 6, [10, 16, 12, 10, 16, 10], "spear")
	assert_eq(m.armor_class, 16, "10 + DEX 3 + WIS 3")
	assert_eq(m.stats.speed, 45, "+15 at Monk 6")

func test_monk_weapon_uses_dex_and_the_martial_die():
	var m := _pc("monk", 5, [10, 18, 12, 10, 14, 10], "spear")
	assert_eq(m.attack_modifier(), 4 + 3)
	assert_eq(m.weapon.die_sides, 8, "Martial Arts d8 at 5 replaces the spear's d6")

func test_flurry_spends_focus():
	var m := _pc("monk", 5, [10, 16, 12, 10, 14, 10], "spear")
	var ev := m.kit.use_feature("flurry_of_blows", m)
	assert_eq(ev.attacks, 2)
	assert_eq(m.kit.uses_left("focus_points"), 4)
	assert_eq(_pc("monk", 10).kit.use_feature("flurry_of_blows", _pc("monk", 10)).attacks, 3, "Heightened Focus")

func test_stunning_strike_stuns_on_a_failed_save():
	var m := _pc("monk", 5, [10, 16, 12, 10, 16, 10], "spear")
	var o := _ogre()
	var ev := m.kit.stunning_strike(m, o, 1)
	assert_false(ev.saved)
	assert_true(o.conditions.has(SRD.Condition.STUNNED))
	assert_false(m.kit.stunning_strike(m, o, 1).used, "once per turn")

func test_lay_on_hands_draws_from_the_pool():
	var p := _pc("paladin", 5, [16, 10, 14, 8, 10, 14], "longsword")
	var ally := _pc("fighter", 5)
	ally.stats.current_hp = ally.stats.max_hp - 7
	var ev := p.kit.use_feature("lay_on_hands", p, ally)
	assert_eq(ev.heal, 7)
	assert_eq(p.kit.uses_left("lay_on_hands"), 25 - 7)

func test_radiant_strikes_add_on_melee_hits():
	var p := _pc("paladin", 11, [18, 10, 14, 8, 10, 14], "longsword")
	var o := _ogre()
	var ev := AttackResolver.weapon_attack(p, o, {"d20": 19, "average": true, "mastery": false})
	assert_eq(ev.extras[0].name, "Radiant Strikes")
	assert_eq(ev.extras[0].type, "radiant")

func test_sacred_weapon_adds_cha_to_hit():
	var p := _pc("paladin", 5, [16, 10, 14, 8, 10, 16], "longsword")
	p.kit.use_feature("sacred_weapon", p)
	var ev := AttackResolver.weapon_attack(p, _ogre(), {"d20": 10})
	assert_eq(ev.attack_bonus, p.attack_modifier() + 3)

func test_aura_of_courage_blocks_frightened():
	assert_true("frightened" in _pc("paladin", 10).condition_immunities)

func test_colossus_slayer_needs_a_wounded_target_once_a_turn():
	var r := _pc("ranger", 5, [10, 16, 14, 10, 14, 8], "shortsword")
	var o := _ogre()
	var ev := AttackResolver.weapon_attack(r, o, {"d20": 19, "average": true, "mastery": false})
	assert_false(ev.has("extras"), "full HP")
	ev = AttackResolver.weapon_attack(r, o, {"d20": 19, "average": true, "mastery": false})
	assert_eq(ev.extras[0].name, "Colossus Slayer")
	ev = AttackResolver.weapon_attack(r, o, {"d20": 19, "average": true, "mastery": false})
	assert_false(ev.has("extras"), "once per turn")

func test_hunters_mark_rides_every_hit():
	var r := _pc("ranger", 3, [10, 16, 14, 10, 14, 8], "shortsword")
	var o := _ogre()
	var hm := srd.make_spell("hunters-mark", SRD.Ability.WISDOM)
	assert_true(hm.hostile)
	assert_false(hm.has_damage())
	SpellResolver.new().cast(r, hm, [o], 1)
	var ev := AttackResolver.weapon_attack(r, o, {"d20": 19, "average": true, "mastery": false})
	assert_eq(ev.extras[0].name, "Hunters Mark")

func test_cunning_strike_forgoes_a_die_and_trips():
	var r := _pc("rogue", 5, [8, 18, 14, 10, 10, 10], "rapier")
	var o := _ogre()
	r.kit.use_feature("cs_trip", r)
	var ev := AttackResolver.weapon_attack(r, o, {"d20": 19, "average": true, "mastery": false, "ally_adjacent": true, "save_d20": 1})
	assert_eq(ev.cunning_strike, ["trip"])
	assert_eq(ev.sneak_attack, 2 * 3, "3d6 less one at average 3")
	assert_true(o.conditions.has(SRD.Condition.PRONE))

func test_slippery_mind_saves():
	var r := _pc("rogue", 15)
	assert_true(r.stats.is_save_proficient(SRD.Ability.WISDOM))

func test_bardic_inspiration_is_one_shot():
	var b := _pc("bard", 5, [8, 14, 14, 12, 10, 16], "rapier")
	var ally := _pc("fighter", 5)
	assert_eq(b.kit.uses_left("bardic_inspiration"), 3)
	b.kit.use_feature("bardic_inspiration", b, ally)
	assert_eq(ally.effects.bonus_dice("attack"), [8] as Array[int], "d8 at Bard 5")
	ally.effects.roll_bonus("attack")
	assert_eq(ally.effects.bonus_dice("attack").size(), 0, "spent when rolled")

func test_font_of_inspiration_recovers_on_short_rest():
	var b := _pc("bard", 5, [8, 14, 14, 12, 10, 16])
	b.kit.spend("bardic_inspiration")
	SRDRest.short_rest_combatant(b)
	assert_eq(b.kit.uses_left("bardic_inspiration"), 3)

func test_jack_of_all_trades():
	var b := _pc("bard", 5, [8, 14, 14, 12, 10, 16])
	assert_eq(SRDSkills.skill_bonus(b.stats, SRD.Skill.ARCANA), 1 + 1)

func test_draconic_resilience():
	var s := _pc("sorcerer", 5, [8, 14, 14, 10, 12, 16])
	assert_eq(s.armor_class, 10 + 2 + 3)
	var plain := SRDContent.new().make_character("x", "fighter", 1, [8, 14, 14, 10, 12, 16])
	assert_eq(s.stats.max_hp, 6 + 2 + 4 * (4 + 2) + 5, "d6 + average + level")
	assert_not_null(plain)

func test_innate_sorcery_raises_dc_and_gives_advantage():
	var s := _pc("sorcerer", 5, [8, 14, 14, 10, 12, 16], "dagger")
	s.kit.use_feature("innate_sorcery", s)
	assert_eq(s.effects.total("spell_dc_bonus"), 1)
	var o := _ogre()
	var res := SpellResolver.new()
	var ev: Dictionary = res.cast(s, srd.make_spell("fire-bolt", SRD.Ability.CHARISMA), [o], 0, null, {"d20": 5, "d20_2": 18})[0]
	assert_eq(ev.d20, 18, "Advantage")

func test_metamagic_needs_the_option_known():
	var s := _pc("sorcerer", 5, [8, 14, 14, 10, 12, 16])
	assert_false(s.kit.feature_actions().any(func(f): return f.id == "mm_quickened"))
	var t := _pc("sorcerer", 5, [8, 14, 14, 10, 12, 16], "", "", {"metamagic": ["sorcerer-quickened-spell"]})
	assert_true(t.kit.feature_actions().any(func(f): return f.id == "mm_quickened"))
	t.kit.use_feature("mm_quickened", t)
	assert_eq(t.turn_flags.metamagic, "quickened")
	assert_eq(t.kit.uses_left("sorcery_points"), 3)

func test_agonizing_blast_adds_cha():
	var w := _pc("warlock", 5, [8, 14, 14, 12, 10, 16], "dagger", "", {"invocations": ["warlock-agonizing-blast"]})
	var eb := srd.make_spell("eldritch-blast", SRD.Ability.CHARISMA)
	assert_eq(w.kit.cantrip_damage_bonus(w, eb), 3)

func test_dark_ones_blessing_on_kill():
	var w := _pc("warlock", 5, [8, 14, 14, 12, 10, 16])
	assert_eq(w.kit.on_kill(w), 3 + 5)
	assert_eq(w.stats.temp_hp, 8)

func test_favored_enemy_uses():
	assert_eq(_pc("ranger", 5).kit.uses_left("favored_enemy"), 3)

func test_elemental_fury_potent_spellcasting():
	var d := _pc("druid", 7, [10, 12, 14, 12, 16, 10])
	assert_eq(d.kit.cantrip_damage_bonus(d, srd.make_spell("produce-flame", SRD.Ability.WISDOM)), 3)

func test_natures_ward():
	var d := _pc("druid", 10, [10, 12, 14, 12, 16, 10])
	assert_true(d.stats.has_immunity(SRD.DamageType.POISON))
	assert_true("poisoned" in d.condition_immunities)

func test_remarkable_athlete_initiative():
	assert_true(_pc("fighter", 3).initiative_advantage)

func test_additional_fighting_style():
	var f := _pc("fighter", 7, [16, 12, 14, 8, 12, 10], "greatsword", "", {"fighting_style_2": "great-weapon-fighting"})
	assert_true(f.kit.has_style("defense"))
	assert_true(f.kit.has_style("great-weapon-fighting"))

func test_savage_attacker_once_a_turn():
	var f := _pc("fighter", 4, [16, 12, 14, 8, 12, 10], "longsword", "", {"feats": ["savage-attacker"]})
	AttackResolver.weapon_attack(f, _ogre(), {"d20": 19, "mastery": false})
	assert_true(f.turn_flags.get("savage_attacker", false))

func test_hold_person_paralyzes_and_repeats():
	var w := _pc("wizard", 5, [8, 14, 14, 16, 12, 10], "dagger")
	var o := _ogre()
	var hp := srd.make_spell("hold-person", SRD.Ability.INTELLIGENCE)
	assert_true(hp.uses_save)
	var res := SpellResolver.new()
	res.cast(w, hp, [o], 2, null, {"save_d20": 1})
	assert_true(o.conditions.has(SRD.Condition.PARALYZED))
	SRDEffects.turn_ended([o], o, 1)
	assert_true(o.conditions.has(SRD.Condition.PARALYZED), "failed the repeat: still held")
	SRDEffects.turn_ended([o], o, 20)
	assert_false(o.conditions.has(SRD.Condition.PARALYZED), "saved: free")

func test_mage_armor_and_barkskin():
	var w := _pc("wizard", 5, [8, 14, 14, 16, 12, 10], "dagger")
	var res := SpellResolver.new()
	res.cast(w, srd.make_spell("mage-armor", SRD.Ability.INTELLIGENCE), [w], 1)
	assert_eq(w.armor_class, 13 + 2)
	res.cast(w, srd.make_spell("barkskin", SRD.Ability.WISDOM), [w], 2)
	assert_eq(w.armor_class, 17)

func test_stoneskin_halves_weapon_damage():
	var w := _pc("wizard", 9, [8, 14, 14, 16, 12, 10], "dagger")
	var res := SpellResolver.new()
	res.cast(w, srd.make_spell("stoneskin", SRD.Ability.INTELLIGENCE), [w], 4)
	var hp := w.current_hp
	w.take_damage(10, SRD.DamageType.SLASHING)
	assert_eq(hp - w.current_hp, 5)

func test_heal_is_flat_seventy():
	var c := _pc("cleric", 11, [14, 10, 14, 10, 16, 12], "mace")
	var f := _pc("fighter", 11)
	f.stats.current_hp = 1
	SpellResolver.new().cast(c, srd.make_spell("heal", SRD.Ability.WISDOM), [f], 7)
	assert_gte(f.current_hp, 1 + 80)

func test_smites_are_not_ordinary_spells():
	assert_false(srd.spell_has_mechanics("divine-smite"))
	assert_true(SRDContent.TAG_NO_MECHANICS in srd.make_spell("divine-smite").tags)

func test_empowered_rerolls_stay_in_range():
	var w := _pc("sorcerer", 9, [8, 14, 14, 10, 12, 16])
	var fb := srd.make_spell("fireball", SRD.Ability.CHARISMA)
	var res := SpellResolver.new()
	for i in 20:
		var d: int = res._spell_dice(w, fb, 3, {"empowered": 3})
		assert_true(d >= 8 and d <= 48)

func test_paladin_and_ranger_have_a_default_style():
	assert_true(_pc("paladin", 3).kit.has_style("defense"))
	assert_true(_pc("ranger", 3).kit.has_style("defense"))
