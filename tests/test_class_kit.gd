## SRD 5.2.1 class features for the four primary classes (levels 1-3, plus the 17 kit).
extends GutTest

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func _fighter(level: int = 3, opts := {}) -> Combatant:
	return srd.make_character("Ilse", "fighter", level, [16, 12, 14, 8, 12, 10], "longsword",
		"chain-mail", true, ["athletics", "perception"], "", opts)

func _rogue(level: int = 3) -> Combatant:
	return srd.make_character("Corvin", "rogue", level, [8, 16, 14, 12, 12, 10], "rapier",
		"leather-armor", false, ["stealth", "sleight-of-hand", "investigation", "deception"])

func _cleric(level: int = 3, opts := {}) -> Combatant:
	return srd.make_character("Maud", "cleric", level, [14, 10, 14, 10, 16, 12], "mace",
		"chain-shirt", true, ["medicine", "religion"], "", opts)

func _wizard(level: int = 3) -> Combatant:
	return srd.make_character("Teodor", "wizard", level, [8, 14, 14, 16, 12, 10], "quarterstaff",
		"", false, ["arcana", "history"])

func _dummy(n: String = "Dummy", hp: int = 100, ac: int = 10) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = n
	s.max_hp = hp
	s.reset()
	var eq := EquipmentSlots.new()
	eq.natural_ac = ac
	return Combatant.new(s, null, eq)

# ── Kits ─────────────────────────────────────────────────────────────────────

func test_level_3_kits_pick_the_srd_subclass():
	assert_eq(_fighter().kit.subclass_slug, "champion")
	assert_eq(_rogue().kit.subclass_slug, "thief")
	assert_eq(_cleric().kit.subclass_slug, "life-domain")
	assert_eq(_wizard().kit.subclass_slug, "evoker")
	assert_eq(_fighter(2).kit.subclass_slug, "", "subclasses start at level 3")

func test_fighter_level_3_feature_list():
	assert_eq(_fighter().kit.feature_names(), ["Fighting Style", "Second Wind", "Weapon Mastery",
		"Action Surge", "Tactical Mind", "Fighter Subclass", "Improved Critical", "Remarkable Athlete"])

func test_feature_report_marks_implemented():
	var report := _fighter().kit.feature_report()
	var by_name := {}
	for f in report:
		by_name[f.name] = f.implemented
	assert_true(by_name["Second Wind"])
	assert_true(by_name["Improved Critical"])
	assert_false(by_name["Fighter Subclass"])

# ── Fighter ──────────────────────────────────────────────────────────────────

func test_second_wind_two_uses_one_back_on_short_rest():
	var f := _fighter()
	f.stats.current_hp = 5
	var ev := f.kit.second_wind(f, 6)
	assert_true(ev.used)
	assert_eq(ev.healed, 6 + 3)
	assert_eq(f.kit.uses_left("second_wind"), 1)
	assert_false(f.kit.second_wind(f, 6).used, "it costs the Bonus Action")
	f.action_economy.reset_turn()
	assert_true(f.kit.second_wind(f, 1).used)
	assert_eq(f.kit.uses_left("second_wind"), 0)
	f.kit.short_rest()
	assert_eq(f.kit.uses_left("second_wind"), 1, "a Short Rest restores one use")
	f.kit.long_rest()
	assert_eq(f.kit.uses_left("second_wind"), 2)

func test_second_wind_uses_scale_with_level():
	assert_eq(_fighter(4).kit.uses_left("second_wind"), 3)
	assert_eq(_fighter(10).kit.uses_left("second_wind"), 4)

func test_tactical_shift_at_5():
	var f := _fighter(5)
	assert_eq(f.kit.second_wind(f, 5).free_move_feet, 15)

func test_tactical_mind_only_spends_on_success():
	var f := _fighter()
	var miss := f.kit.tactical_mind(5, 20, 4)
	assert_false(miss.success)
	assert_eq(f.kit.uses_left("second_wind"), 2, "still failed: use not spent")
	var made := f.kit.tactical_mind(12, 15, 4)
	assert_true(made.success)
	assert_eq(made.total, 16)
	assert_eq(f.kit.uses_left("second_wind"), 1)

func test_action_surge_once_per_turn_two_uses_at_17():
	var f := _fighter(2)
	f.action_economy.use_action()
	assert_true(f.kit.action_surge(f))
	assert_true(f.action_economy.has_action)
	assert_true(f.turn_flags.no_magic_action)
	assert_false(f.kit.action_surge(f))
	var high := _fighter(17)
	assert_eq(high.kit.uses_left("action_surge"), 2)
	assert_true(high.kit.action_surge(high))
	assert_false(high.kit.action_surge(high), "only once on a turn")
	SRDEffects.turn_started([high], high)
	assert_true(high.kit.action_surge(high))

func test_fighting_styles():
	var archer := srd.make_character("A", "fighter", 1, [10, 16, 14, 8, 12, 10], "longbow",
		"leather-armor", false, [], "", {"fighting_style": "archery"})
	var ev := AttackResolver.weapon_attack(archer, _dummy(), {"d20": 10})
	assert_eq(ev.attack_bonus, 3 + 2 + 2)
	var gwf := srd.make_character("G", "fighter", 1, [16, 10, 14, 8, 12, 10], "greatsword",
		"chain-mail", false, [], "", {"fighting_style": "great-weapon-fighting"})
	for i in 30:
		var d := _dummy()
		var hit := AttackResolver.weapon_attack(gwf, d, {"d20": 15})
		assert_gte(hit.damage, 6 + 3, "each d6 counts as at least 3")

func test_champion_crits_on_19():
	var f := _fighter()
	var ev := AttackResolver.weapon_attack(f, _dummy("Dummy", 100, 30), {"d20": 19, "average": true})
	assert_true(ev.crit)
	assert_true(ev.hit)
	assert_eq(ev.free_move_feet, 15, "Remarkable Athlete")
	assert_eq(_fighter(15).kit.crit_threshold(), 18)

func test_extra_attacks():
	assert_eq(_fighter(4).kit.attacks_per_action(), 1)
	assert_eq(_fighter(5).kit.attacks_per_action(), 2)
	assert_eq(_fighter(17).kit.attacks_per_action(), 3)
	assert_eq(_rogue(17).kit.attacks_per_action(), 1)

func test_indomitable():
	var f := _fighter(9)
	var ev := f.kit.indomitable(f, SRD.Ability.WISDOM, 20, 10)
	assert_eq(ev.total, 10 + 1 + 9)
	assert_true(ev.saved)
	assert_false(f.kit.indomitable(f, SRD.Ability.WISDOM, 20, 10).used)

# ── Rogue ────────────────────────────────────────────────────────────────────

func test_sneak_attack_with_advantage():
	var r := _rogue()
	var ev := AttackResolver.weapon_attack(r, _dummy(), {"d20": 15, "d20_2": 2, "advantage": true, "average": true})
	assert_eq(ev.sneak_attack, 2 * 3, "2d6 at level 3")
	assert_eq(ev.damage, 4 + 3 + 6)

func test_sneak_attack_needs_adjacent_ally_or_advantage():
	var r := _rogue()
	var ev := AttackResolver.weapon_attack(r, _dummy(), {"d20": 15, "average": true})
	assert_false(ev.has("sneak_attack"))
	ev = AttackResolver.weapon_attack(r, _dummy(), {"d20": 15, "average": true, "ally_adjacent": true})
	assert_true(ev.has("sneak_attack"))

func test_sneak_attack_ally_query_from_game():
	var r := _rogue()
	AttackResolver.ally_adjacent = func(_a, t): return t.name == "Flanked"
	var ev := AttackResolver.weapon_attack(r, _dummy("Flanked"), {"d20": 15, "average": true})
	AttackResolver.ally_adjacent = Callable()
	assert_true(ev.has("sneak_attack"))

func test_sneak_attack_once_per_turn_and_not_with_disadvantage():
	var r := _rogue()
	AttackResolver.weapon_attack(r, _dummy(), {"d20": 15, "average": true, "ally_adjacent": true})
	var ev := AttackResolver.weapon_attack(r, _dummy(), {"d20": 15, "average": true, "ally_adjacent": true})
	assert_false(ev.has("sneak_attack"), "once per turn")
	SRDEffects.turn_started([r], r)
	ev = AttackResolver.weapon_attack(r, _dummy("Fresh"), {"d20": 15, "d20_2": 15, "average": true,
		"ally_adjacent": true, "disadvantage": true})  # (Vex only grants Advantage vs "Dummy")
	assert_false(ev.has("sneak_attack"), "Disadvantage blocks the ally route")

func test_sneak_attack_needs_finesse_or_ranged():
	var r := srd.make_character("C", "rogue", 3, [14, 16, 14, 12, 12, 10], "club")
	var ev := AttackResolver.weapon_attack(r, _dummy(), {"d20": 15, "advantage": true, "d20_2": 15, "average": true})
	assert_false(ev.has("sneak_attack"))

func test_cunning_action():
	var r := _rogue(2)
	assert_true(r.kit.cunning_action(r, "disengage"))
	assert_true(r.turn_flags.disengaged)
	assert_false(r.kit.cunning_action(r, "dash"), "one Bonus Action per turn")
	SRDEffects.turn_started([r], r)
	assert_true(r.kit.cunning_action(r, "dash"))
	assert_eq(r.action_economy.movement_remaining, 60)

func test_steady_aim():
	var r := _rogue()
	r.action_economy.spend_movement(5)
	assert_false(r.kit.steady_aim(r), "not after moving")
	SRDEffects.turn_started([r], r)
	assert_true(r.kit.steady_aim(r))
	assert_eq(r.action_economy.movement_remaining, 0)
	var ev := AttackResolver.weapon_attack(r, _dummy(), {"d20": 3, "d20_2": 16, "average": true})
	assert_true(ev.advantage)
	assert_true(ev.has("sneak_attack"), "Advantage enables Sneak Attack")

func test_rogue_expertise_defaults():
	var r := _rogue()
	assert_true(r.stats.has_skill_expertise(SRD.Skill.STEALTH))
	assert_true(r.stats.has_skill_expertise(SRD.Skill.SLEIGHT_OF_HAND))
	assert_false(r.stats.has_skill_expertise(SRD.Skill.DECEPTION))

func test_uncanny_dodge_and_evasion_at_higher_levels():
	var r := _rogue(7)
	assert_eq(r.kit.uncanny_dodge(r, 15), 7)
	var caster := _wizard(5)
	var ab := srd.make_spell("burning-hands", SRD.Ability.INTELLIGENCE)
	var ev := SpellResolver.new().cast(caster, ab, [r], -1, null, {"save_d20": 20, "average": true})
	assert_eq(ev[0].damage_dealt, 0, "Evasion: no damage on a success")
	ev = SpellResolver.new().cast(caster, ab, [r], -1, null, {"save_d20": 1, "average": true})
	assert_eq(ev[0].damage_dealt, 9 / 2, "half on a failure")

# ── Cleric ───────────────────────────────────────────────────────────────────

func test_divine_order_protector_default():
	var c := _cleric()
	assert_eq(c.kit.options.divine_order, "protector")
	var heavy := srd.make_character("M", "cleric", 1, [14, 10, 14, 10, 16, 12], "longsword", "plate-armor")
	assert_true(heavy.is_proficient_with_weapon, "Protector: Martial weapons")

func test_channel_divinity_uses():
	assert_eq(_cleric(1).kit.uses_left("channel_divinity"), 0)
	assert_eq(_cleric(2).kit.uses_left("channel_divinity"), 2)
	assert_eq(_cleric(6).kit.uses_left("channel_divinity"), 3)
	assert_eq(_cleric(18).kit.uses_left("channel_divinity"), 4)

func test_divine_spark_heal_and_harm():
	var c := _cleric()
	var ally := _dummy("Ally", 30)
	ally.stats.current_hp = 10
	var ev := c.kit.divine_spark(c, ally, true)
	assert_true(ev.used)
	assert_between(ev.healed, 1 + 3, 8 + 3)
	SRDEffects.turn_started([c], c)
	var foe := _dummy("Foe", 50)
	ev = c.kit.divine_spark(c, foe, false, SRD.DamageType.RADIANT, 1)
	assert_false(ev.saved)
	assert_eq(ev.dc, 8 + 2 + 3)
	assert_between(ev.damage_dealt, 4, 11)
	assert_eq(c.kit.uses_left("channel_divinity"), 0)
	assert_eq(_cleric(7).kit.divine_spark_dice(), 2)

func test_turn_undead():
	var c := _cleric()
	var z := srd.make_monster("zombie")
	var ev := c.kit.turn_undead(c, [z], 1)
	assert_false(ev[0].saved)
	assert_true(z.conditions.has(SRD.Condition.FRIGHTENED))
	assert_true(z.conditions.is_incapacitated())
	z.take_damage(1, SRD.DamageType.FIRE)
	assert_false(z.conditions.has(SRD.Condition.FRIGHTENED), "ends early on damage")

func test_disciple_of_life_adds_to_slot_healing():
	var c := _cleric()
	var ally := _dummy("Ally", 40)
	ally.stats.current_hp = 1
	var cure := srd.make_spell("cure-wounds", SRD.Ability.WISDOM)
	var ev := SpellResolver.new().cast(c, cure, [ally], 1, null, {"average": true})
	assert_eq(ev[0].amount, 2 * 4 + 3 + (2 + 1))  # 2d8 avg + Wis + Disciple of Life

func test_preserve_life():
	var c := _cleric()
	var a := _dummy("A", 40); a.stats.current_hp = 5
	var b := _dummy("B", 40); b.stats.current_hp = 30  # not Bloodied
	var ev := c.kit.preserve_life(c, [[a, 15], [b, 0]])
	assert_true(ev.used)
	assert_eq(ev["A"], 15, "pool is 5 x level = 15")
	assert_eq(a.current_hp, 20)
	SRDEffects.turn_started([c], c)
	a.stats.current_hp = 15
	ev = c.kit.preserve_life(c, [[a, 15]])
	assert_eq(ev["A"], 5, "can't raise above half HP max")

func test_life_domain_spells():
	var spells := srd.subclass_spells("life-domain", 3)
	assert_eq(spells, ["aid", "bless", "cure-wounds", "lesser-restoration"])
	assert_eq(srd.subclass_spells("life-domain", 5).size(), 6)

func test_supreme_healing_maxes_dice():
	var c := _cleric(17)
	var ally := _dummy("Ally", 100)
	ally.stats.current_hp = 1
	var ev := SpellResolver.new().cast(c, srd.make_spell("healing-word", SRD.Ability.WISDOM), [ally], 1)
	assert_eq(ev[0].amount, 8 + 3 + 3)  # 2d4 max + Wis + Disciple of Life (2 + 1)

# ── Wizard ───────────────────────────────────────────────────────────────────

func test_arcane_recovery():
	var w := _wizard(3)
	w.energy_slots.use_slot(1)
	w.energy_slots.use_slot(1)
	w.energy_slots.use_slot(2)
	assert_false(w.kit.arcane_recovery(w, [2, 1]), "budget is ceil(3 / 2) = 2")
	assert_true(w.kit.arcane_recovery(w, [2]))
	assert_eq(w.energy_slots.slots_remaining_at(2), 2)
	assert_false(w.kit.arcane_recovery(w, [1]), "once per Long Rest")
	w.kit.long_rest()
	assert_true(w.kit.arcane_recovery(w, [1]))
	var high := _wizard(17)
	assert_false(high.kit.arcane_recovery(high, [6]), "no level 6+ slots")

func test_potent_cantrip_half_on_miss():
	var w := _wizard(3)
	var bolt := srd.make_spell("fire-bolt", SRD.Ability.INTELLIGENCE)
	var t := _dummy("T", 50, 30)
	var ev := SpellResolver.new().cast(w, bolt, [t], -1, null, {"d20": 2, "average": true})
	assert_false(ev[0].hit)
	assert_eq(ev[0].damage_dealt, 5 / 2)
	var plain := srd.make_character("W", "wizard", 2, [8, 14, 14, 16, 12, 10])
	ev = SpellResolver.new().cast(plain, bolt, [_dummy("T", 50, 30)], -1, null, {"d20": 2, "average": true})
	assert_eq(ev[0].damage_dealt, 0, "no Potent Cantrip before Evoker 3")

func test_empowered_evocation_at_17():
	var w := _wizard(17)
	var ev := SpellResolver.new().cast(w, srd.make_spell("magic-missile", SRD.Ability.INTELLIGENCE),
		[_dummy()], 1, null, {"average": true})
	assert_eq(ev[0].damage_dealt, 2 + 1 + 3)
