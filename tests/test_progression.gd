extends GutTest
## SRDProgression: what each level grants and asks for, levels 3 to 17 for every class in use.

const CLASSES := ["bard", "cleric", "druid", "fighter", "monk", "paladin", "ranger", "rogue",
	"sorcerer", "warlock", "wizard"]

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func _build(cls: String) -> Dictionary:
	return {"class": cls, "scores": [14, 14, 14, 14, 14, 14], "skills": ["stealth", "arcana", "insight"], "choices": {}}

func test_summary_lists_hp_features_and_slots():
	var s := SRDProgression.summary(srd, "wizard", 5, "evoker", 2)
	assert_eq(s.hp_gain, 6, "d6: 4 + CON 2")
	assert_true(s.pb_up, "proficiency rises at 5")
	assert_eq(s.proficiency_bonus, 3)
	assert_eq(s.slots_gained, [{"level": 3, "gain": 2}])
	assert_true(s.features.any(func(f): return f.name == "Memorize Spell"))

func test_rogue_gets_its_extra_asi_and_fighter_its_masteries():
	assert_true(SRDProgression.choices(srd, _build("rogue"), 10).any(func(c): return c.id == "asi"))
	assert_true(SRDProgression.choices(srd, _build("fighter"), 6).any(func(c): return c.id == "asi"))
	assert_false(SRDProgression.choices(srd, _build("wizard"), 6).any(func(c): return c.id == "asi"))
	assert_true(SRDProgression.choices(srd, _build("fighter"), 10).any(func(c): return c.id == "weapon_mastery"))

func test_spell_choices_stay_within_castable_levels():
	var c: Dictionary = SRDProgression.choices(srd, _build("wizard"), 5).filter(func(x): return x.id == "spells")[0]
	assert_eq(c.options.map(func(o): return o.level).max(), 3)
	assert_eq(c.count, 2, "wizard prepared spells rise by 2 at 5")
	assert_true(c.options.any(func(o): return o.id == "fireball"))

func test_paladin_slots_cap_at_half_caster_levels():
	assert_eq(SRDProgression.max_spell_level(srd, "paladin", 17), 5)
	assert_eq(SRDProgression.max_spell_level(srd, "warlock", 9), 5)

func test_asi_raises_scores_and_caps_at_20():
	var b := _build("fighter")
	b.scores = [19, 10, 10, 10, 10, 10]
	b.choices = {"4": {"asi": ["ability-score-improvement", "str", "str"]},
		"6": {"asi": ["alert"]}, "8": {"asi": ["skilled", "arcana", "history", "nature"]}}
	var r := SRDProgression.resolve(srd, b, 8)
	assert_eq(r.scores[0], 20, "capped")
	assert_eq(r.feats, ["ability-score-improvement", "alert", "skilled"])
	assert_eq(r.options.extra_skills, ["arcana", "history", "nature"])
	assert_eq(SRDProgression.resolve(srd, b, 5).feats, ["ability-score-improvement"], "only choices up to the level")

func test_alert_adds_proficiency_to_initiative():
	var c := srd.make_character("A", "wizard", 5, [10, 14, 10, 16, 10, 10], "", "", false, [], "", {"feats": ["alert"]})
	assert_eq(c.initiative_bonus, 2 + 3)

func test_auto_answer_prefers_the_list_then_modelled_spells():
	var c: Dictionary = SRDProgression.choices(srd, _build("wizard"), 5).filter(func(x): return x.id == "spells")[0]
	var a := SRDProgression.auto_answer(c, {"spells": ["counterspell", "fireball"]}, [])
	assert_eq(a, ["counterspell", "fireball"])

func test_auto_answer_takes_the_highest_level_listed():
	var c: Dictionary = SRDProgression.choices(srd, _build("wizard"), 5).filter(func(x): return x.id == "spells")[0]
	assert_eq(SRDProgression.auto_answer(c, {"spells": ["shield", "web", "fireball", "fly"]}, []), ["fireball", "fly"])

func test_auto_asi_spreads_past_the_cap():
	var a := SRDProgression.auto_answer({"id": "asi", "kind": "asi"}, {"asi": ["int", "con"]}, [8, 14, 14, 19, 12, 10])
	assert_eq(a, ["ability-score-improvement", "int", "con"])

func test_every_class_levels_3_to_17_with_auto_choices():
	for cls in CLASSES:
		var b := _build(cls)
		b.scores = [15, 15, 15, 15, 15, 15]
		for lvl in range(4, 18):
			var answers := {}
			for ch in SRDProgression.choices(srd, b, lvl):
				answers[ch.id] = SRDProgression.auto_answer(ch, {}, SRDProgression.resolve(srd, b, lvl - 1).scores)
				assert_true(ch.kind == "asi" or answers[ch.id].size() == ch.count or ch.count > ch.options.size(),
					"%s %d %s full" % [cls, lvl, ch.id])
			b.choices[str(lvl)] = answers
			var r := SRDProgression.resolve(srd, b, lvl)
			var c := srd.make_character("X", cls, lvl, r.scores, "dagger", "", false, b.skills, "", r.options)
			assert_eq(c.stats.level, lvl)
			assert_gt(c.stats.max_hp, 0)
		var scores: Array = SRDProgression.resolve(srd, b, 17).scores
		assert_true(scores.all(func(s): return s <= 20), "%s scores capped" % cls)

func test_warlock_gets_arcana_and_sorcerer_metamagic():
	assert_true(SRDProgression.choices(srd, _build("warlock"), 11).any(func(c): return c.id == "arcanum"))
	assert_true(SRDProgression.choices(srd, _build("sorcerer"), 10).any(func(c): return c.id == "metamagic"))
	var k := srd.make_kit("warlock", 13)
	assert_eq(k.uses_left("arcanum_7"), 1)

func test_implemented_table_only_names_real_features():
	var keys := {}
	for cls in CLASSES:
		var sub: String = srd.subclass_slugs(cls)[0]
		for f in srd.features_at(cls, 20, sub):
			var prefix: String = cls + "-" + (sub + "-" if f.data.subclass != "" else "")
			keys[str(f.slug).trim_prefix(prefix)] = true
	for k in ClassKit.IMPLEMENTED:
		assert_true(keys.has(k) or k in ["three-extra-attacks", "ability-score-improvement"], "%s is a feature" % k)
