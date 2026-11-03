extends GutTest
## Stat-block Spellcasting and save actions.

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func test_glabrezu_book():
	var g := srd.make_monster("glabrezu")
	var b := g.monster_spells
	assert_eq(b.dc, 16)
	assert_eq(b.ability, SRD.Ability.INTELLIGENCE)
	assert_eq(b.at_will.map(func(s): return s.slug), ["darkness", "detect-magic", "dispel-magic"])
	assert_eq(b.daily.map(func(s): return s.slug), ["confusion", "fly", "power-word-stun"])
	assert_true(b.in_multiattack, "Multiattack can use Spellcasting")

func test_mage_versioned_spell_and_per_day():
	var b := srd.make_monster("mage").monster_spells
	var fb: Dictionary = b.daily.filter(func(s): return s.slug == "fireball")[0]
	assert_eq([fb.per_day, fb.level], [2, 4])

func test_every_spellcaster_parses_to_real_spells():
	var missing := []
	var casters := 0
	for slug in srd.pack.slugs("monster"):
		var b := MonsterSpells.parse(srd.pack.get_row("monster", slug).data.get("actions", []))
		if b.is_empty():
			continue
		casters += 1
		for s in b.at_will + b.daily:
			if not srd.pack.has_row("spell", s.slug):
				missing.append("%s:%s" % [slug, s.slug])
	assert_gt(casters, 40)
	assert_eq(missing, [])

func test_daily_uses_run_out():
	var g := srd.make_monster("glabrezu")
	var s: Dictionary = g.monster_spells.daily[0]
	assert_true(MonsterSpells.available(g).has(s))
	MonsterSpells.spend(g, s)
	assert_false(MonsterSpells.available(g).has(s))
	assert_eq(MonsterSpells.available(g).size(), 5)

func test_ability_uses_the_blocks_dc():
	var g := srd.make_monster("glabrezu")
	var ab := MonsterSpells.make_ability(srd, g, {"slug": "confusion"})
	assert_eq(ab.spell_save_dc(g.stats), 16)
	assert_eq(ab.slot_level, 4)

func test_monster_saves_use_the_stat_block_proficiency():
	var g := srd.make_monster("glabrezu")
	var row: Dictionary = srd.pack.get_row("monster", "glabrezu")
	assert_eq(g.stats.saving_throw_bonus(SRD.Ability.CONSTITUTION), int(row.data.abilities.con.save))

func test_breath_weapon_parses_with_area_and_recharge():
	var d := srd.make_monster("young-red-dragon")
	var f: Dictionary = d.save_actions.filter(func(x): return "Breath" in x.name)[0]
	assert_eq(f.area_shape, "cone")
	assert_eq(f.area_size, 30)
	assert_eq(f.recharge, 5)
	assert_true(f.half)
	assert_eq(f.type, "fire")

func test_line_breath():
	var d := srd.make_monster("young-brass-dragon")
	var f: Dictionary = d.save_actions.filter(func(x): return "Breath" in x.name)[0]
	assert_eq([f.area_shape, f.area_size], ["line", 40])

func test_recharge_cycle():
	var d := srd.make_monster("young-red-dragon")
	var f: Dictionary = d.save_actions.filter(func(x): return "Breath" in x.name)[0]
	assert_true(MonsterSpells.save_action_ready(d, f))
	MonsterSpells.spend_save_action(d, f)
	assert_false(MonsterSpells.save_action_ready(d, f))
	for i in 60:
		MonsterSpells.recharge(d)
	assert_true(MonsterSpells.save_action_ready(d, f), "a 5-6 comes up")

func test_save_ability_resolves_like_a_spell():
	var d := srd.make_monster("young-red-dragon")
	var f: Dictionary = d.save_actions.filter(func(x): return "Breath" in x.name)[0]
	var ab := MonsterSpells.save_ability(f)
	var pc := srd.make_character("P", "fighter", 5, [16, 12, 14, 8, 12, 10], "longsword")
	var ev: Dictionary = SpellResolver.new().cast(d, ab, [pc], 1, null, {"save_d20": 1, "average": true})[0]
	assert_eq(ev.dc, f.dc)
	assert_gt(ev.damage_dealt, 0)

func test_extra_damage_parts_become_riders():
	var p := srd.make_monster("priest")
	assert_true(p.hit_riders.any(func(r): return r.type == "radiant"))

func test_planner_saves_slots_in_short_fights():
	var cands := [{"id": "fireball", "value": 30.0, "slot": 3}]
	assert_eq(SpellPlanner.pick(cands, {"baseline": 12.0, "rounds_left": 1.0}), {}, "almost over: keep it")
	assert_eq(SpellPlanner.pick(cands, {"baseline": 12.0, "rounds_left": 5.0}).id, "fireball", "a long fight: spend it")

func test_planner_prefers_the_best_net_value():
	var cands := [{"id": "a", "value": 40.0, "slot": 5}, {"id": "b", "value": 30.0, "slot": 1}]
	assert_eq(SpellPlanner.pick(cands, {"baseline": 5.0, "rounds_left": 2.0}).id, "b")
	assert_eq(SpellPlanner.pick(cands, {"baseline": 5.0, "rounds_left": 6.0}).id, "a")

func test_save_value():
	assert_almost_eq(SpellPlanner.save_value(0.5, 20.0, true), 15.0, 0.01)
	assert_almost_eq(SpellPlanner.save_value(1.0, 0.0, false, 30.0), 30.0, 0.01)
