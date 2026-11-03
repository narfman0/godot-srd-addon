## Extracted class features, subclasses, class tables, origins, and feats; level-17 kits.
extends GutTest

var srd: SRDContent

const PRIMARY := {
	"fighter": [16, 12, 14, 8, 12, 10],
	"rogue": [8, 16, 14, 12, 12, 10],
	"cleric": [14, 10, 14, 10, 16, 12],
	"wizard": [8, 14, 14, 16, 12, 10],
}

func before_all():
	srd = SRDContent.new()

# ── Extraction ───────────────────────────────────────────────────────────────

func test_counts():
	assert_eq(srd.pack.count("subclass"), 12)
	assert_gt(srd.pack.count("feature"), 220)
	assert_eq(srd.pack.count("species"), 9)
	assert_eq(srd.pack.count("background"), 4)
	assert_eq(srd.pack.count("feat"), 17)
	assert_eq(srd.pack.count("weapon_property"), 18)
	assert_eq(srd.pack.count("class_option"), 38)  # 10 Metamagic + 28 Eldritch Invocations

func test_every_class_has_a_twenty_level_table_and_a_subclass():
	for slug in srd.pack.slugs("class"):
		var table: Array = srd.pack.get_row("class", slug).data.table
		assert_eq(table.size(), 20, slug)
		assert_eq(int(table[16].proficiency_bonus), 6, slug)
		assert_eq(srd.subclass_slugs(slug).size(), 1, slug)
		assert_gt(srd.features_at(slug, 20).size(), 8, slug)

func test_class_table_columns():
	assert_eq(srd.class_table_row("rogue", 3).sneak_attack, "2d6")
	assert_eq(int(srd.class_table_row("barbarian", 9).rages), 4)
	assert_eq(srd.class_table_row("fighter", 1).features, ["Fighting Style", "Second Wind", "Weapon Mastery"])
	assert_eq(int(srd.class_table_row("cleric", 6).channel_divinity), 3)
	assert_eq(int(srd.class_table_row("wizard", 17).slot_9), 1)
	assert_eq(int(srd.class_table_row("warlock", 11).slot_level), 5)

func test_feature_text_matches_pdf():
	var sw := srd.pack.get_row("feature", "fighter-second-wind")
	assert_eq(int(sw.data.level), 1)
	assert_string_contains(sw.data.text, "regain Hit Points equal to 1d10 plus your Fighter level")
	assert_string_contains(sw.data.text, "You can use this feature twice")
	var asi := srd.pack.get_row("feature", "fighter-ability-score-improvement")
	assert_eq(asi.data.levels.map(func(l): return int(l)), [4, 6, 8, 12, 14, 16])
	var ds: Dictionary = srd.pack.get_row("feature", "cleric-channel-divinity").data
	assert_eq(ds.entries.map(func(e): return e.name), ["Divine Spark", "Turn Undead"])
	assert_eq(int(srd.pack.get_row("feature", "wizard-evoker-potent-cantrip").data.level), 3)

func test_features_gained_at():
	var names := srd.features_gained_at("fighter", 17, "champion").map(func(r): return r.name)
	assert_has(names, "Action Surge")
	assert_has(names, "Indomitable")
	var l3 := srd.features_gained_at("cleric", 3, "life-domain").map(func(r): return r.name)
	assert_eq(l3, ["Cleric Subclass", "Disciple of Life", "Life Domain Spells", "Preserve Life"])

func test_subclass_rows():
	var life := srd.subclass_row("life-domain")
	assert_eq(life.data["class"], "cleric")
	assert_eq(life.data.tagline, "Soothe the Hurts of the World")
	assert_eq(srd.subclass_slugs("wizard"), ["evoker"])

func test_origins_and_feats():
	var elf := srd.pack.get_row("species", "elf")
	assert_eq(int(elf.data.speed), 30)
	assert_eq(int(elf.data.darkvision), 60)
	assert_has(elf.data.traits.map(func(t): return t.name), "Trance")
	var sage := srd.pack.get_row("background", "sage")
	assert_eq(sage.data.ability_scores, ["con", "int", "wis"])
	assert_eq(sage.data.feat_slug, "magic-initiate")
	var alert := srd.pack.get_row("feat", "alert")
	assert_eq(alert.data.category, "origin")
	var defense := srd.pack.get_row("feat", "defense")
	assert_eq(defense.data.category, "fighting_style")
	assert_eq(int(srd.pack.get_row("feat", "boon-of-fate").data.min_level), 19)

func test_slots_follow_the_2024_tables():
	assert_eq(srd.make_class("paladin").make_slots(1).slots_max_at(1), 2, "2024 half casters cast at 1")
	assert_eq(srd.make_class("ranger").make_slots(17).slots_max_at(5), 1)
	var wiz := srd.make_class("wizard")
	for lvl in range(1, 21):
		assert_eq(wiz.make_slots(lvl).slots_max, EnergySlots.make_full_caster(lvl).slots_max, "wizard %d" % lvl)

func test_every_class_builds_a_kit_at_every_level():
	for slug in srd.pack.slugs("class"):
		for lvl in [1, 3, 5, 11, 17, 20]:
			var c := srd.make_character("X", slug, lvl, [12, 12, 12, 12, 12, 12])
			assert_not_null(c.kit, "%s %d" % [slug, lvl])
			assert_eq(c.kit.level, lvl)

# ── Level 17 (flashback) ─────────────────────────────────────────────────────

func _l17(cls: String) -> Combatant:
	return srd.make_character("P", cls, 17, PRIMARY[cls])

func test_level_17_hp_and_proficiency():
	# Level 1: full hit die + Con; levels 2-17: average (die / 2 + 1) + Con. Con 14 (+2) for all.
	var expect := {"fighter": 10 + 2 + 16 * 8, "rogue": 8 + 2 + 16 * 7,
		"cleric": 8 + 2 + 16 * 7, "wizard": 6 + 2 + 16 * 6}
	for cls in PRIMARY:
		var c := _l17(cls)
		assert_eq(c.stats.max_hp, expect[cls], cls)
		assert_eq(c.stats.proficiency_bonus(), 6, cls)

func test_level_17_slots():
	for cls in ["cleric", "wizard"]:
		var c := _l17(cls)
		var got := []
		for i in range(1, 10):
			got.append(c.energy_slots.slots_max_at(i))
		assert_eq(got, [4, 3, 3, 3, 2, 1, 1, 1, 1], cls)
	assert_eq(_l17("fighter").energy_slots.slots_max_at(1), 0)

func test_level_17_feature_lists():
	var f := _l17("fighter").kit
	for n in ["Two Extra Attacks", "Indomitable", "Studied Attacks", "Tactical Master", "Superior Critical"]:
		assert_has(f.feature_names(), n)
	assert_eq(f.uses_left("action_surge"), 2)
	assert_eq(f.uses_left("indomitable"), 3)
	assert_eq(f.uses_left("second_wind"), 4)
	var armed := srd.make_character("P", "fighter", 17, PRIMARY.fighter, "greatsword")
	assert_eq(armed.kit.weapon_masteries, ["greatsword"], "the wielded weapon by default")
	var r := _l17("rogue").kit
	assert_eq(r.sneak_attack_dice(), 9)
	assert_has(r.feature_names(), "Thief’s Reflexes")
	var c := _l17("cleric").kit
	assert_has(c.feature_names(), "Supreme Healing")
	assert_eq(c.uses_left("channel_divinity"), 3)
	var w := _l17("wizard").kit
	assert_has(w.feature_names(), "Overchannel")
	assert_eq(w.casting_ability, SRD.Ability.INTELLIGENCE)

func test_level_17_feature_report():
	for cls in PRIMARY:
		var report := _l17(cls).kit.feature_report()
		var implemented := report.filter(func(f): return f.implemented)
		assert_gt(implemented.size(), 4, cls)
		assert_lt(implemented.size(), report.size(), "%s keeps some text-only features" % cls)
