## Combat follow-up rules (SRD 5.2.1): spell crits, automatic crits within 5 ft., cover,
## monster Bonus Actions and Reactions, Unarmed Strike Shove, Undead Fortitude's save,
## Spiritual Weapon, Pact Magic slots, and Surprise.
extends GutTest

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func after_each():
	AttackResolver.within_5ft = Callable()

func _dummy(n: String = "Dummy", hp: int = 100, ac: int = 10) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = n
	s.max_hp = hp
	s.reset()
	var eq := EquipmentSlots.new()
	eq.natural_ac = ac
	return Combatant.new(s, null, eq)

func _fighter() -> Combatant:
	return srd.make_character("Ilse", "fighter", 3, [16, 12, 14, 8, 12, 10], "longsword", "chain-mail", true)

func _cleric(level := 3) -> Combatant:
	return srd.make_character("Maud", "cleric", level, [14, 10, 14, 10, 16, 12], "mace", "chain-shirt", true)

## The betrayer-style stat block, as text only: the parse must find everything.
func _infiltrator_row() -> Dictionary:
	return {"name": "Infiltrator", "data": {
		"size": "medium", "type": "humanoid", "ac": 15, "hp": 39, "hp_dice": "6d8+12",
		"initiative": 4, "speed": {"walk": 35},
		"abilities": {"str": {"score": 10, "mod": 0, "save": 0}, "dex": {"score": 18, "mod": 4, "save": 6},
			"con": {"score": 14, "mod": 2, "save": 2}, "int": {"score": 13, "mod": 1, "save": 1},
			"wis": {"score": 12, "mod": 1, "save": 1}, "cha": {"score": 16, "mod": 3, "save": 3}},
		"actions": [{"name": "Dagger", "text": "Melee or Ranged Attack Roll: +6, reach 5 ft. or range 20/60 ft. Hit: 6 (1d4 + 4) Piercing damage. Once per turn, if the infiltrator had Advantage on the roll, the target takes an extra 7 (2d6) Necrotic damage.",
			"attack": {"kind": "melee_or_ranged", "bonus": 6, "reach": 5, "range": [20, 60],
				"damage": [{"avg": 6, "dice": "1d4+4", "type": "piercing"}]}}],
		"bonus_actions": [
			{"name": "Shadow Step", "text": "While in Dim Light or Darkness, the infiltrator teleports up to 30 feet to an unoccupied space it can see that is also in Dim Light or Darkness. It then has Advantage on the next attack roll it makes before the end of the turn."},
			{"name": "Slip Away", "text": "The infiltrator takes the Disengage or Hide action."}],
		"reactions": [{"name": "Vanishing Exit", "usage": "1/Day", "text": "Trigger: The infiltrator takes damage and is Bloodied. Response: It teleports up to 60 feet to an unoccupied space it can see and has the Invisible condition until the start of its next turn or until it makes an attack roll."}]}}

func _infiltrator() -> Combatant:
	var pack := SRDContentPack.new()
	var row := _infiltrator_row()
	row["kind"] = "monster"
	row["slug"] = "test-infiltrator"
	pack.add_rows([row])
	return SRDContent.new(pack).make_monster("test-infiltrator")

# ── Spell crits ───────────────────────────────────────────────────────────────

class CritSpy extends SpellResolver:
	var crits: Array = []
	func apply_damage(target: Combatant, amount: int, damage_type: SRD.DamageType, is_crit: bool = false) -> int:
		crits.append(is_crit)
		return super.apply_damage(target, amount, damage_type, is_crit)

func test_spell_attack_crit_doubles_dice_and_reaches_apply_damage():
	var spy := CritSpy.new()
	var fire := srd.make_spell("fire-bolt", SRD.Ability.INTELLIGENCE)
	var wiz := srd.make_character("Teo", "wizard", 3, [8, 14, 14, 16, 12, 10])
	var ev: Array = spy.cast(wiz, fire, [_dummy()], 0, null, {"d20": 20, "average": true})
	assert_true(ev[0].crit)
	assert_eq(ev[0].damage_rolled, 2 * 5, "two d10s on a crit (average 5 each)")
	assert_eq(spy.crits, [true], "apply_damage is told about the Critical Hit")

func test_spell_crit_denies_undead_fortitude():
	var z := srd.make_monster("zombie")
	z.stats.current_hp = 3
	var fire := srd.make_spell("fire-bolt", SRD.Ability.INTELLIGENCE)
	var wiz := srd.make_character("Teo", "wizard", 3, [8, 14, 14, 16, 12, 10])
	var ev: Array = SpellResolver.new().cast(wiz, fire, [z], 0, null, {"d20": 20, "average": true})
	assert_eq(ev[0].undead_fortitude, {"blocked": "critical"})
	assert_true(z.is_dead)

# ── Automatic crits within 5 ft. ──────────────────────────────────────────────

func test_hit_within_5ft_of_unconscious_is_a_crit():
	var f := _fighter()
	var t := _dummy()
	t.conditions.add(SRD.Condition.UNCONSCIOUS)
	var ev := AttackResolver.weapon_attack(f, t, {"d20": 10, "d20_2": 10, "within_5ft": true, "average": true})
	assert_true(ev.hit and ev.crit and ev.get("auto_crit", false))
	var far := AttackResolver.weapon_attack(f, _unconscious(), {"d20": 10, "d20_2": 10, "within_5ft": false})
	assert_true(far.hit)
	assert_false(far.crit, "from beyond 5 ft. it's only a hit")

func _unconscious() -> Combatant:
	var t := _dummy()
	t.conditions.add(SRD.Condition.UNCONSCIOUS)
	return t

func test_paralyzed_auto_crit_via_game_callable():
	var f := _fighter()
	var t := _dummy()
	t.conditions.add(SRD.Condition.PARALYZED)
	AttackResolver.within_5ft = func(_a, _b): return true
	var ev := AttackResolver.weapon_attack(f, t, {"d20": 8, "d20_2": 8})
	assert_true(ev.crit)
	assert_true(ev.advantage, "Paralyzed grants Advantage")

func test_melee_spell_attack_auto_crits_on_unconscious():
	var sg := srd.make_spell("shocking-grasp", SRD.Ability.INTELLIGENCE)
	var wiz := srd.make_character("Teo", "wizard", 3, [8, 14, 14, 16, 12, 10])
	var ev: Array = SpellResolver.new().cast(wiz, sg, [_unconscious()], 0, null,
		{"d20": 12, "d20_2": 12, "within_5ft": true, "average": true})
	assert_true(ev[0].crit and ev[0].get("auto_crit", false))

func test_prone_and_invisible_modes():
	var f := _fighter()
	var t := _dummy()
	t.conditions.add(SRD.Condition.PRONE)
	assert_eq(AttackResolver.roll_mode(f, t, false, {"within_5ft": true}), 1)
	assert_eq(AttackResolver.roll_mode(f, t, false, {"within_5ft": false}), -1, "reach weapon from 10 ft.")
	var inv := _dummy()
	inv.conditions.add(SRD.Condition.INVISIBLE)
	assert_eq(AttackResolver.roll_mode(f, inv, false, {}), -1, "attacks against the Invisible have Disadvantage")

# ── Cover ─────────────────────────────────────────────────────────────────────

func test_cover_adds_to_ac_against_attacks():
	var f := _fighter()  # +5 with a longsword
	var ev := AttackResolver.weapon_attack(f, _dummy("T", 100, 14), {"d20": 10, "cover": SRD.Cover.HALF})
	assert_eq(ev.target_ac, 16)
	assert_false(ev.hit, "15 misses AC 14 behind Half Cover")
	ev = AttackResolver.weapon_attack(f, _dummy("T", 100, 10), {"d20": 9, "cover": SRD.Cover.THREE_QUARTERS})
	assert_eq(ev.target_ac, 15)
	assert_false(ev.hit)

func test_cover_adds_to_dex_saves_and_spell_attacks():
	var wiz := srd.make_character("Teo", "wizard", 3, [8, 14, 14, 16, 12, 10])
	var bh := srd.make_spell("burning-hands", SRD.Ability.INTELLIGENCE)  # DC 13 DEX
	var t := _dummy("T")
	var ev: Array = SpellResolver.new().cast(wiz, bh, [t], 1, null, {"save_d20": 11, "cover": {"T": SRD.Cover.HALF}})
	assert_true(ev[0].saved, "11 + 2 (Half Cover) meets DC 13")
	var bare: Array = SpellResolver.new().cast(wiz, bh, [_dummy("T")], 1, null, {"save_d20": 11})
	assert_false(bare[0].saved)
	var fb := srd.make_spell("fire-bolt", SRD.Ability.INTELLIGENCE)  # +5
	var ev2: Array = SpellResolver.new().cast(wiz, fb, [_dummy("U", 100, 12)], 0, null, {"d20": 8, "cover": SRD.Cover.HALF})
	assert_eq(ev2[0].target_ac, 14)
	assert_false(ev2[0].hit)

# ── Monster Bonus Actions and Reactions ──────────────────────────────────────

func test_parses_srd_bonus_actions_and_reactions():
	var gob := srd.make_monster("goblin-warrior")
	assert_eq(gob.bonus_actions[0].kind, "simple")
	assert_eq(gob.bonus_actions[0].options, ["disengage", "hide"])
	var golem := srd.make_monster("clay-golem")
	assert_true(golem.bonus_actions[0].all, "Hasten takes Dash and Disengage")
	var dog := srd.make_monster("blink-dog")
	assert_eq([dog.bonus_actions[0].kind, dog.bonus_actions[0].feet], ["teleport", 40])
	var cap := srd.make_monster("bandit-captain")
	var parry: Dictionary = cap.reactions[0]
	assert_eq([parry.kind, parry.amount, parry.trigger], ["ac_bonus", 2, "hit_by_melee_attack"])

func test_parses_infiltrator_from_text():
	var c := _infiltrator()
	var step: Dictionary = c.bonus_actions[0]
	assert_eq([step.kind, step.feet, step.requires, step.rider],
		["teleport", 30, "dim_light_or_darkness", "next_attack_advantage"])
	var exit: Dictionary = c.reactions[0]
	assert_eq([exit.kind, exit.feet, exit.trigger, exit.bloodied, exit.condition, exit.until_attack],
		["teleport", 60, "took_damage", true, "invisible", true])
	assert_eq(exit.usage, {"per_day": 1})
	assert_eq(c.hit_riders[0].dice, "2d6")
	assert_eq(c.initiative_bonus, 4, "stat block Initiative")

func test_nimble_escape_disengages_with_the_bonus_action():
	var gob := srd.make_monster("goblin-warrior")
	var ev := MonsterActions.use(gob, gob.bonus_actions[0], {"option": "disengage"})
	assert_true(ev.used)
	assert_true(gob.turn_flags.get("disengaged", false))
	assert_false(gob.action_economy.has_bonus_action)
	assert_false(MonsterActions.available(gob, gob.bonus_actions[0]), "one Bonus Action per turn")

func test_shadow_step_grants_advantage_on_next_attack_and_rider_damage():
	var c := _infiltrator()
	var ev := MonsterActions.use(c, c.bonus_actions[0])
	assert_eq(ev.teleport_feet, 30)
	var t := _dummy("T", 100, 10)
	var atk := AttackResolver.weapon_attack(c, t, {"d20": 3, "d20_2": 15, "average": true})
	assert_true(atk.advantage)
	assert_eq(atk.rider_damage.amount, 6, "2d6 necrotic with Advantage (average 3 each)")
	var again := AttackResolver.weapon_attack(c, t, {"d20": 15, "advantage": true, "d20_2": 15, "average": true})
	assert_false(again.has("rider_damage"), "once per turn")

func test_vanishing_exit_triggers_when_bloodied_once_per_day():
	var c := _infiltrator()
	c.take_damage(10, SRD.DamageType.SLASHING)
	assert_true(MonsterActions.reaction_for(c, "took_damage").is_empty(), "not Bloodied yet")
	c.take_damage(12, SRD.DamageType.SLASHING)
	var r := MonsterActions.reaction_for(c, "took_damage")
	assert_eq(r.name, "Vanishing Exit")
	var ev := MonsterActions.use(c, r)
	assert_eq([ev.teleport_feet, ev.condition], [60, "invisible"])
	assert_true(c.conditions.has(SRD.Condition.INVISIBLE))
	AttackResolver.weapon_attack(c, _dummy(), {"d20": 10})
	assert_false(c.conditions.has(SRD.Condition.INVISIBLE), "ends when it makes an attack roll")
	c.action_economy.reset_reaction()
	assert_true(MonsterActions.reaction_for(c, "took_damage").is_empty(), "1/Day spent")

func test_parry_only_when_it_turns_the_hit():
	var cap := srd.make_monster("bandit-captain")
	var ac := cap.armor_class
	assert_true(MonsterActions.reaction_for(cap, "hit_by_attack", {"melee": true, "total": ac + 5}).is_empty())
	assert_true(MonsterActions.reaction_for(cap, "hit_by_attack", {"melee": false, "total": ac}).is_empty(), "melee only")
	var r := MonsterActions.reaction_for(cap, "hit_by_attack", {"melee": true, "total": ac + 1})
	MonsterActions.use(cap, r)
	assert_eq(cap.armor_class, ac + 2)
	MonsterActions.attack_resolved(cap)
	assert_eq(cap.armor_class, ac)

func test_recharge_rolls():
	var c := _dummy()
	c.bonus_actions = [MonsterActions.parse({"name": "Leap (Recharge 5–6)", "text": "The creature takes the Dash action."}, "bonus")]
	MonsterActions.use(c, c.bonus_actions[0])
	c.action_economy.reset_turn()
	assert_false(MonsterActions.available(c, c.bonus_actions[0]))
	assert_false(MonsterActions.start_turn(c, 4)[0].recharged)
	assert_true(MonsterActions.start_turn(c, 5)[0].recharged)
	assert_true(MonsterActions.available(c, c.bonus_actions[0]))

func _ctx(actor: Combatant, foes: Array, melee: bool, dist: int, dim := true) -> AIContext:
	var ctx := AIContext.new()
	ctx.actor = actor
	ctx.enemies = foes
	ctx.allies = []
	ctx.is_in_melee_range = func(_a, _b): return melee
	ctx.can_reach_in_one_move = func(_a, _b): return false
	ctx.distance_feet = func(_a, _b): return dist
	ctx.requirement_met = func(_c, _r): return dim
	return ctx

func test_ai_shadow_steps_to_its_target():
	var c := _infiltrator()
	var plan := CombatAI.plan_turn(_ctx(c, [_dummy()], false, 25), CombatAI.Profile.SKIRMISHER)
	assert_eq(plan.monster_bonus.get("name"), "Shadow Step")
	assert_eq([plan.bonus_timing, plan.bonus_purpose, plan.action], ["before_move", "engage", TurnPlan.ActionChoice.ATTACK])
	var lit := CombatAI.plan_turn(_ctx(c, [_dummy()], false, 25, false), CombatAI.Profile.SKIRMISHER)
	assert_ne(lit.monster_bonus.get("name", ""), "Shadow Step", "needs Dim Light or Darkness")

func test_ai_skirmisher_attacks_then_slips_away():
	var c := _infiltrator()
	var plan := CombatAI.plan_turn(_ctx(c, [_dummy()], true, 5), CombatAI.Profile.SKIRMISHER)
	assert_eq(plan.action, TurnPlan.ActionChoice.ATTACK)
	assert_eq([plan.monster_bonus.name, plan.bonus_option, plan.bonus_timing], ["Slip Away", "disengage", "after_action"])
	assert_true(plan.retreat_after_action)

func test_ai_escape_prefers_teleport_then_bonus_disengage():
	var c := _infiltrator()
	var plan := CombatAI.plan_escape(_ctx(c, [_dummy()], true, 5))
	assert_eq([plan.monster_bonus.name, plan.bonus_purpose, plan.move_intent], ["Shadow Step", "escape", TurnPlan.MoveIntent.RETREAT])
	var lit := CombatAI.plan_escape(_ctx(c, [_dummy()], true, 5, false))
	assert_eq([lit.monster_bonus.name, lit.action], ["Slip Away", TurnPlan.ActionChoice.DASH])

# ── Unarmed Strike: Shove ─────────────────────────────────────────────────────

func test_shove_dc_and_targets_choice_of_save():
	var f := _fighter()  # STR 16 (+3), PB 2
	assert_eq(UnarmedStrike.save_dc(f), 13)
	var z := srd.make_monster("zombie")  # STR +1, DEX -2
	assert_eq(UnarmedStrike.save_ability(z), SRD.Ability.STRENGTH)
	var ev := UnarmedStrike.shove(f, z, true, {"save_d20": 5})
	assert_false(ev.saved)
	assert_true(ev.prone and z.conditions.has(SRD.Condition.PRONE))
	var push := UnarmedStrike.shove(f, srd.make_monster("zombie"), false, {"save_d20": 5})
	assert_eq(push.push_feet, 5)
	var ok := UnarmedStrike.shove(f, srd.make_monster("zombie"), false, {"save_d20": 15})
	assert_true(ok.saved and not ok.has("push_feet"))

func test_shove_size_limit_and_auto_fail():
	var f := _fighter()
	var big := _dummy()
	big.size = "huge"
	assert_eq(UnarmedStrike.shove(f, big, true).get("refused"), "size")
	var out := _unconscious()
	var ev := UnarmedStrike.shove(f, out, false, {"save_d20": 20})
	assert_true(ev.auto_fail and not ev.saved)
	assert_eq(UnarmedStrike.fail_chance(f, out), 1.0)

# ── Undead Fortitude ──────────────────────────────────────────────────────────

func test_undead_fortitude_save_is_exposed():
	var z := srd.make_monster("zombie")  # CON save +3
	z.stats.current_hp = 4
	z.take_damage(6, SRD.DamageType.SLASHING, false, 8)
	assert_eq(z.last_undead_fortitude, {"dc": 11, "d20": 8, "bonus": 3, "total": 11, "saved": true})
	assert_eq(z.current_hp, 1)
	z.take_damage(5, SRD.DamageType.RADIANT, false, 20)
	assert_eq(z.last_undead_fortitude, {"blocked": "radiant"})
	assert_true(z.is_dead)

func test_weapon_attack_reports_undead_fortitude():
	var z := srd.make_monster("zombie")
	z.stats.current_hp = 1
	var ev := AttackResolver.weapon_attack(_fighter(), z, {"d20": 15, "average": true})
	assert_true(ev.has("undead_fortitude"))

# ── Spiritual Weapon ─────────────────────────────────────────────────────────

func test_spiritual_weapon_summon_lives_on_concentration():
	var c := _cleric()
	var ab := srd.make_spell("spiritual-weapon", SRD.Ability.WISDOM)
	assert_eq(ab.attack_kind, "melee")
	assert_true(ab.concentration, "2024: Concentration, up to 1 minute")
	var conc := ConcentrationTracker.new()
	var r := SpellResolver.new()
	var ev: Array = r.cast(c, ab, [_dummy()], 3, conc, {"d20": 15, "average": true})
	assert_eq(ev[0].damage_dealt, 2 * 4 + 3, "upcast to 3: 2d8 + WIS")
	var sm: SpellSummon = ev[1].summon
	assert_eq([sm.level, sm.move_feet, sm.reach_feet, sm.repeat_as], [3, 20, 5, "bonus_action"])
	assert_true(sm.can_reach(24) and not sm.can_reach(26))
	var again := r.summon_strike(sm, _dummy(), {"d20": 15, "average": true})
	assert_true(again.hit)
	assert_eq(again.damage_dealt, 11, "later attacks keep the cast level")
	conc.end()
	assert_false(sm.active, "ends with Concentration")
	assert_eq(r.summon_strike(sm, _dummy(), {"d20": 15}).get("skipped"), "summon gone")

func test_spiritual_weapon_attack_is_melee_and_duration_runs_out():
	var c := _cleric()
	var ab := srd.make_spell("spiritual-weapon", SRD.Ability.WISDOM)
	var t := _dummy()
	t.conditions.add(SRD.Condition.UNCONSCIOUS)
	var conc := ConcentrationTracker.new()
	var ev: Array = SpellResolver.new().cast(c, ab, [t], 2, conc, {"d20": 12, "d20_2": 12, "average": true})
	assert_true(ev[0].crit, "the force is within 5 ft. of what it attacks")
	var sm: SpellSummon = ev[1].summon
	for i in 9:
		assert_false(sm.turn_started())
	assert_true(sm.turn_started())
	assert_false(conc.is_concentrating)

# ── Pact Magic ────────────────────────────────────────────────────────────────

func test_warlock_level_3_has_two_second_level_slots_only():
	var w := srd.make_character("Teo", "warlock", 3, [8, 14, 14, 12, 10, 16], "dagger")
	assert_eq(Array(w.energy_slots.slots_max), [0, 2, 0, 0, 0, 0, 0, 0, 0])
	assert_eq(Array(w.energy_slots.slots_remaining), [0, 2, 0, 0, 0, 0, 0, 0, 0])
	assert_true(w.energy_slots.recovers_on_short_rest)
	var w17 := srd.make_character("Teo", "warlock", 17, [8, 14, 14, 12, 10, 16], "dagger")
	assert_eq(Array(w17.energy_slots.slots_max), [0, 0, 0, 0, 4, 0, 0, 0, 0])

func test_pact_slots_match_the_class_table_every_level():
	var cls := srd.make_class("warlock")
	for lvl in range(1, 21):
		var row := srd.class_table_row("warlock", lvl)
		var s := cls.make_slots(lvl)
		assert_eq(s.slots_max_at(int(row.slot_level)), int(row.spell_slots), "level %d" % lvl)
		var total := 0
		for i in 9:
			total += s.slots_max[i]
		assert_eq(total, int(row.spell_slots), "level %d: no other slots" % lvl)

# ── Surprise ──────────────────────────────────────────────────────────────────

func test_surprise_is_disadvantage_on_initiative():
	var f := _fighter()  # DEX 12 (+1)
	f.initiative_advantage = false  # the Champion's Remarkable Athlete would cancel it
	var r := CombatOrder.roll(f, true, [17, 4])
	assert_eq([r.d20, r.total, r.disadvantage], [4, 5, true])
	var n := CombatOrder.roll(f, false, [17, 4])
	assert_eq([n.d20, n.rolls.size()], [17, 1])
	var c := _infiltrator()
	c.conditions.add(SRD.Condition.INVISIBLE)
	var inv := CombatOrder.roll(c, true, [17, 4])
	assert_eq(inv.d20, 17, "Invisible's Advantage cancels Surprise's Disadvantage")
	assert_eq(inv.rolls.size(), 1)
