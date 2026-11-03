## SRD 5.2.1 content pack → runtime resources.
extends GutTest

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

# ── Pack loading ─────────────────────────────────────────────────────────────

func test_pack_meta():
	assert_eq(srd.pack.meta.get("version"), "5.2.1")
	assert_eq(srd.pack.meta.get("sha256", "").length(), 64)

func test_pack_has_all_twelve_classes():
	assert_eq(srd.pack.count("class"), 12)
	for slug in ["barbarian", "bard", "cleric", "druid", "fighter", "monk",
			"paladin", "ranger", "rogue", "sorcerer", "warlock", "wizard"]:
		assert_true(srd.pack.has_row("class", slug), slug)

func test_pack_has_every_srd_spell():
	assert_eq(srd.pack.count("spell"), 339)
	for slug in ["wish", "divine-smite", "hunters-mark", "sorcerous-burst", "starry-wisp"]:
		assert_true(srd.pack.has_row("spell", slug), slug)
	assert_false(srd.pack.has_row("spell", "toll-the-dead"), "not SRD")

func test_pack_equipment_and_monsters():
	assert_eq(srd.pack.count("weapon"), 38)
	assert_eq(srd.pack.count("armor"), 13)
	assert_gt(srd.pack.count("monster"), 320)

# ── Classes ──────────────────────────────────────────────────────────────────

func test_fighter():
	var c := srd.make_class("fighter")
	assert_eq(c.class_name_str, "Fighter")
	assert_eq(c.hit_die, 10)
	assert_eq(c.slot_progression, SRD.SlotProgression.NONE)
	assert_has(c.save_proficiencies, int(SRD.Ability.STRENGTH))
	assert_has(c.save_proficiencies, int(SRD.Ability.CONSTITUTION))
	assert_has(c.armor_proficiencies, "heavy")

func test_wizard_is_full_caster_with_int():
	var c := srd.make_class("wizard")
	assert_eq(c.hit_die, 6)
	assert_eq(c.slot_progression, SRD.SlotProgression.FULL)
	assert_eq(srd.spellcasting_ability("wizard"), int(SRD.Ability.INTELLIGENCE))
	assert_has(c.primary_abilities, int(SRD.Ability.INTELLIGENCE))
	assert_eq(c.skill_choices_count, 2)
	assert_has(c.skill_options, int(SRD.Skill.ARCANA))
	assert_eq(c.make_slots(5).slots_remaining_at(3), 2)

func test_paladin_is_half_caster():
	assert_eq(srd.make_class("paladin").slot_progression, SRD.SlotProgression.HALF)

func test_non_caster_has_no_spellcasting_ability():
	assert_eq(srd.spellcasting_ability("barbarian"), -1)

func test_warlock_pact_magic():
	var c := srd.make_class("warlock")
	assert_eq(c.slot_progression, SRD.SlotProgression.PACT)
	var l1 := c.make_slots(1)
	assert_eq(l1.slots_remaining_at(1), 1)
	var l5 := c.make_slots(5)
	assert_eq(l5.slots_remaining_at(3), 2)  # two 3rd-level pact slots
	assert_eq(l5.slots_remaining_at(1), 0)  # and nothing else
	assert_eq(c.make_slots(17).slots_remaining_at(5), 4)

func test_every_class_builds():
	for slug in srd.pack.slugs("class"):
		var c := srd.make_class(slug)
		assert_not_null(c, slug)
		assert_true(c.hit_die in [6, 8, 10, 12], "%s hit die" % slug)
		assert_eq(c.save_proficiencies.size(), 2, "%s saves" % slug)

func test_bard_picks_any_three_skills():
	var c := srd.make_class("bard")
	assert_eq(c.skill_choices_count, 3)
	assert_eq(c.skill_options.size(), SRD.Skill.size())

# ── Equipment ────────────────────────────────────────────────────────────────

func test_longsword_versatile():
	var w := srd.make_weapon("longsword")
	assert_eq(w.weapon_type, SRD.WeaponType.MARTIAL)
	assert_eq([w.die_count, w.die_sides], [1, 8])
	assert_eq([w.versatile_die_count, w.versatile_die_sides], [1, 10])
	assert_true(w.has_property(SRD.WeaponProperty.VERSATILE))
	assert_eq(w.damage_type, SRD.DamageType.SLASHING)

func test_rapier_finesse_uses_dex():
	var w := srd.make_weapon("rapier")
	var s := CharacterStats.new()
	s.strength = 10; s.dexterity = 16
	assert_true(w.has_property(SRD.WeaponProperty.FINESSE))
	assert_eq(w.attack_bonus(s, true), 3 + 2)

func test_longbow_range():
	var w := srd.make_weapon("longbow")
	assert_eq([w.range_normal, w.range_long], [150, 600])
	assert_true(w.has_property(SRD.WeaponProperty.TWO_HANDED))

func test_javelin_thrown_stays_str():
	var w := srd.make_weapon("javelin")
	assert_true(w.has_property(SRD.WeaponProperty.THROWN))
	assert_eq(w.range_normal, 5)
	assert_eq(w.weapon_type, SRD.WeaponType.SIMPLE)

func test_armor_ac():
	var s := CharacterStats.new()
	s.dexterity = 16  # +3
	assert_eq(srd.make_armor("leather-armor").equipped_ac(s), 14)
	assert_eq(srd.make_armor("half-plate-armor").equipped_ac(s), 17)  # 15 + capped 2
	var plate := srd.make_armor("plate-armor")
	assert_eq(plate.equipped_ac(s), 18)
	assert_eq(plate.strength_requirement, 15)
	assert_true(plate.stealth_disadvantage)

# ── Spells ───────────────────────────────────────────────────────────────────

func test_fireball():
	var ab := srd.make_spell("fireball", SRD.Ability.INTELLIGENCE)
	assert_eq(ab.slot_level, 3)
	assert_true(ab.uses_save)
	assert_eq(ab.save_ability, SRD.Ability.DEXTERITY)
	assert_eq(ab.save_effect, SRD.SaveEffect.HALF)
	assert_eq([ab.damage_die_count, ab.damage_die_sides], [8, 6])
	assert_eq(ab.damage_type, SRD.DamageType.FIRE)
	assert_eq(ab.upcast_bonus_die_count, 1)
	assert_eq(ab.upcasted_damage_dice(5), 10)
	assert_eq(ab.target_type, "area")
	assert_eq(ab.area_size, 20)
	assert_eq(ab.range_feet, 150)

func test_fire_bolt_cantrip_scales():
	var ab := srd.make_spell("fire-bolt")
	assert_eq(ab.slot_level, 0)
	assert_false(ab.uses_save)
	assert_eq(ab.base_damage_dice(1), 1)
	assert_eq(ab.base_damage_dice(11), 3)

func test_magic_missile_fully_expressed():
	# Darts and the flat +1 are modelled now (was tagged partial before projectiles existed)
	var ab := srd.make_spell("magic-missile")
	assert_does_not_have(ab.tags, SRDContent.TAG_PARTIAL)
	assert_eq(ab.damage_type, SRD.DamageType.FORCE)
	assert_eq([ab.projectiles, ab.damage_bonus], [3, 1])

func test_utility_spell_flagged():
	assert_has(srd.make_spell("knock").tags, SRDContent.TAG_NO_MECHANICS)
	assert_does_not_have(srd.make_spell("cure-wounds").tags, SRDContent.TAG_NO_MECHANICS)

func test_spell_resolver_casts_pack_spell():
	var caster := Combatant.new(_wizard_stats())
	var target := srd.make_monster("goblin-warrior")
	var ab := srd.make_spell("fireball", SRD.Ability.INTELLIGENCE)
	var events := SpellResolver.new().cast(caster, ab, [target])
	assert_eq(events.size(), 1)
	assert_lt(target.current_hp, 10 + 1)

func test_class_spell_list():
	var cantrips := srd.class_spell_slugs("wizard", 0)
	assert_has(cantrips, "fire-bolt")
	assert_does_not_have(cantrips, "sacred-flame")
	assert_has(srd.class_spell_slugs("paladin", 1), "divine-smite")
	assert_does_not_have(srd.class_spell_slugs("cleric", 3), "fireball")

func test_every_spell_builds():
	for slug in srd.pack.slugs("spell"):
		assert_not_null(srd.make_spell(slug), slug)

# ── Monsters ─────────────────────────────────────────────────────────────────

func test_goblin_warrior_stat_block():
	var g := srd.make_monster("goblin-warrior", 2)
	assert_eq(g.name, "Goblin Warrior 2")
	assert_eq(g.armor_class, 15)
	assert_eq(g.stats.max_hp, 10)
	assert_eq(g.stats.dexterity, 15)
	assert_eq(g.attack_modifier(), 4)
	assert_eq(g.weapon.weapon_name, "Scimitar")
	assert_eq(g.weapon._damage_mod(g.stats), 2)
	assert_eq(srd.monster_xp("goblin-warrior"), 50)
	assert_almost_eq(srd.monster_cr("goblin-warrior"), 0.25, 0.001)

func test_zombie_2024_stat_block():
	var z := srd.make_monster("zombie")
	assert_true(z.has_undead_fortitude)
	assert_true(z.stats.has_immunity(SRD.DamageType.POISON))
	assert_eq(z.armor_class, 8)
	assert_eq(z.stats.max_hp, 15)  # 2024: 2d8 + 6 (2014 was 22)
	assert_true(z.stats.is_save_proficient(SRD.Ability.WISDOM))  # Wis 6, save +0

func test_monster_dies_at_zero_hp():
	var g := srd.make_monster("goblin-warrior")
	g.take_damage(50, SRD.DamageType.SLASHING)
	assert_true(g.is_dead)
	assert_false(g.is_down)

func test_every_monster_builds():
	var unarmed := []
	for slug in srd.pack.slugs("monster"):
		var m := srd.make_monster(slug)
		assert_gt(m.armor_class, 0, slug)
		assert_gt(m.stats.max_hp, 0, slug)
		if m.weapon == null:
			unarmed.append(slug)
	# Only creatures whose every action is a save or special effect lack an attack
	assert_lt(unarmed.size(), 20, "monsters without a parsed attack: %s" % [unarmed])

func test_pack_monsters_fight_in_simulator():
	var sim := BattleSimulator.new()
	sim.fixed_d20 = 12
	sim.use_average_damage = true
	var result := sim.run(SRDFixtures.make_party_of_5(),
		[srd.make_monster("goblin-warrior", 1), srd.make_monster("goblin-warrior", 2), srd.make_monster("wolf", 1)])
	assert_true(result.party_won)

# ── Characters ───────────────────────────────────────────────────────────────

func test_make_fighter_level_5():
	var f := srd.make_character("Rynn", "fighter", 5, [16, 12, 14, 10, 10, 8],
		"longsword", "chain-mail", true, ["athletics", "perception"])
	assert_eq(f.stats.level, 5)
	assert_eq(f.stats.max_hp, 10 + 2 + 4 * (6 + 2))  # d10: 10+CON at 1, avg 6+CON after
	assert_eq(f.armor_class, 16 + 2 + 1)  # chain mail, shield, Defense (the default Fighting Style)
	assert_eq(f.attack_modifier(), 3 + 3)
	assert_true(f.stats.is_save_proficient(SRD.Ability.STRENGTH))
	assert_true(f.stats.is_skill_proficient(SRD.Skill.ATHLETICS))
	assert_eq(f.energy_slots.slots_remaining_at(1), 0)

func test_make_wizard_has_slots():
	var w := srd.make_character("Vex", "wizard", 3, [8, 14, 14, 16, 12, 10], "quarterstaff")
	assert_eq(w.energy_slots.slots_remaining_at(2), 2)
	assert_eq(w.armor_class, 12)

func test_monk_and_rogue_restricted_martial():
	var monk := srd.make_class("monk")
	var rogue := srd.make_class("rogue")
	assert_true(SRDContent.is_weapon_proficient(monk, srd.make_weapon("scimitar")))
	assert_false(SRDContent.is_weapon_proficient(monk, srd.make_weapon("rapier")))
	assert_true(SRDContent.is_weapon_proficient(rogue, srd.make_weapon("rapier")))
	assert_false(SRDContent.is_weapon_proficient(rogue, srd.make_weapon("greatsword")))

func test_warlock_short_rest_restores_pact_slots():
	var w := srd.make_character("Hex", "warlock", 3, [8, 14, 14, 10, 12, 16])
	w.energy_slots.use_slot(2)
	w.energy_slots.use_slot(2)
	SRDRest.short_rest(w.stats, 0, w.energy_slots)
	assert_eq(w.energy_slots.slots_remaining_at(2), 2)

# ── Parsing ──────────────────────────────────────────────────────────────────

func test_parse_dice():
	assert_eq(SRDContent.parse_dice("2d6+3"), { "count": 2, "sides": 6, "bonus": 3 })
	assert_eq(SRDContent.parse_dice("1d4 - 1"), { "count": 1, "sides": 4, "bonus": -1 })
	assert_eq(SRDContent.parse_dice("d20"), { "count": 1, "sides": 20, "bonus": 0 })
	assert_eq(SRDContent.parse_dice("5"), { "count": 0, "sides": 0, "bonus": 5 })

func _wizard_stats() -> CharacterStats:
	var s := CharacterStats.new()
	s.character_name = "Wizard"
	s.level = 5; s.intelligence = 16; s.max_hp = 22; s.reset()
	return s
