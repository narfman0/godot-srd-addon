extends GutTest

func _make_melee_combatant(hp: int = 20) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Watcher"
	s.level = 3; s.hit_die = 8
	s.strength = 14; s.dexterity = 10; s.constitution = 12
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = hp; s.speed = 30; s.reset()
	var sword := WeaponData.new()
	sword.weapon_name = "Shortsword"
	sword.die_count = 1; sword.die_sides = 6
	sword.damage_type = SRD.DamageType.PIERCING
	sword.range_normal = 5  # melee
	return Combatant.new(s, sword)

func _make_target(hp: int = 30) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Mover"
	s.level = 1; s.hit_die = 8
	s.strength = 10; s.dexterity = 10; s.constitution = 10
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = hp; s.speed = 30; s.reset()
	return Combatant.new(s)

func test_can_trigger_when_conditions_met():
	var watcher := _make_melee_combatant()
	assert_true(OpportunityAttack.can_trigger(watcher, false))

func test_cannot_trigger_when_mover_is_disengaging():
	var watcher := _make_melee_combatant()
	assert_false(OpportunityAttack.can_trigger(watcher, true))

func test_cannot_trigger_without_reaction():
	var watcher := _make_melee_combatant()
	watcher.action_economy.use_reaction()
	assert_false(OpportunityAttack.can_trigger(watcher, false))

func test_cannot_trigger_when_incapacitated():
	var watcher := _make_melee_combatant()
	watcher.conditions.add(SRD.Condition.INCAPACITATED)
	assert_false(OpportunityAttack.can_trigger(watcher, false))

func test_cannot_trigger_with_ranged_weapon():
	var s := CharacterStats.new()
	s.character_name = "Archer"; s.level = 1; s.max_hp = 10; s.speed = 30; s.reset()
	var bow := WeaponData.new()
	bow.die_count = 1; bow.die_sides = 8; bow.range_normal = 80  # ranged
	var archer := Combatant.new(s, bow)
	assert_false(OpportunityAttack.can_trigger(archer, false))

func test_trigger_consumes_reaction():
	var watcher := _make_melee_combatant()
	var mover := _make_target()
	assert_true(watcher.action_economy.has_reaction)
	OpportunityAttack.trigger(watcher, mover, 10)
	assert_false(watcher.action_economy.has_reaction)

func test_trigger_returns_event_dict():
	var watcher := _make_melee_combatant()
	var mover := _make_target()
	var ev := OpportunityAttack.trigger(watcher, mover, 15)
	assert_eq(ev["type"], "opportunity_attack")
	assert_true(ev.has("hit"))
	assert_true(ev.has("d20"))
	assert_eq(ev["d20"], 15)

func test_trigger_crit_deals_damage():
	var watcher := _make_melee_combatant()
	var mover := _make_target(30)
	var ev := OpportunityAttack.trigger(watcher, mover, 20)  # crit on 20
	assert_true(ev["hit"])
	assert_true(ev["crit"])
	assert_gt(ev["damage"], 0)
	assert_lt(mover.stats.current_hp, 30)

func test_trigger_unarmed_works():
	var s := CharacterStats.new()
	s.character_name = "Brawler"; s.level = 1; s.strength = 14
	s.max_hp = 10; s.speed = 30; s.reset()
	var brawler := Combatant.new(s, null)  # no weapon
	var mover := _make_target()
	var ev := OpportunityAttack.trigger(brawler, mover, 15)
	assert_eq(ev["type"], "opportunity_attack")
	assert_true(ev.has("hit"))
