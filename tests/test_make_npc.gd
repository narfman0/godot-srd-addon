extends GutTest
## make_npc: SRD NPC stat blocks with species traits.

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func test_drow_bandit():
	var c := srd.make_npc("bandit", "elf", "drow")
	assert_not_null(c)
	assert_eq(c.name, "Drow Bandit")
	assert_eq(int(c.senses.get("darkvision", 0)), 120, "Drow lineage: Darkvision 120 ft")
	var plain := srd.make_monster("bandit")
	assert_eq(c.armor_class, plain.armor_class, "numbers as written: AC")
	assert_eq(c.stats.max_hp, plain.stats.max_hp, "numbers as written: HP")
	assert_eq(c.weapon.weapon_name, plain.weapon.weapon_name)

func test_every_npc_role_and_species():
	var roles := ["bandit", "bandit-captain", "guard", "guard-captain", "knight", "mage", "priest", "priest-acolyte",
		"noble", "commoner", "scout", "spy", "tough", "tough-boss", "warrior-infantry", "warrior-veteran", "berserker",
		"cultist", "cultist-fanatic", "assassin", "archmage", "druid", "gladiator", "pirate", "pirate-captain"]
	for r in roles:
		for sp in srd.pack.slugs("species"):
			var c := srd.make_npc(r, sp)
			assert_not_null(c, "%s %s" % [sp, r])

func test_dwarf_guard_resists_poison_and_sees():
	var c := srd.make_npc("guard", "dwarf")
	assert_eq(c.name, "Dwarf Guard")
	assert_true(c.stats.has_resistance(SRD.DamageType.POISON), "Dwarven Resilience")
	assert_eq(int(c.senses.get("darkvision", 0)), 120)

func test_small_species_and_speed():
	assert_eq(srd.make_npc("scout", "halfling").size, "small")
	assert_eq(srd.make_npc("scout", "human").size, "medium")
	assert_eq(srd.make_npc("knight", "goliath").stats.speed, 35)
	assert_eq(srd.make_npc("scout", "elf", "wood-elf").stats.speed, 35)
	assert_eq(srd.make_npc("scout", "elf", "wood-elf").name, "Wood Elf Scout")

func test_lineage_resistances():
	assert_true(srd.make_npc("cultist", "tiefling", "infernal").stats.has_resistance(SRD.DamageType.FIRE))
	assert_true(srd.make_npc("knight", "dragonborn", "silver").stats.has_resistance(SRD.DamageType.COLD))
	assert_false(srd.make_npc("knight", "human").stats.has_resistance(SRD.DamageType.FIRE))

func test_unknown_inputs():
	assert_null(srd.make_npc("not-a-role", "human"))
	assert_null(srd.make_npc("bandit", "not-a-species"))
	assert_push_error_count(2)
	assert_eq(srd.make_npc("bandit", "").name, "Bandit", "no species: the plain stat block")

func test_monster_senses_from_stat_block():
	assert_eq(int(srd.make_monster("goblin-warrior").senses.get("darkvision", 0)), 60)
