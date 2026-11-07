extends GutTest
## Legendary Actions: parsed from the stat block, uses by round (more in a lair), what each option
## does and what it needs.

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func test_aboleth_legendary_actions():
	var c := srd.make_monster("aboleth")
	assert_eq(int(c.legendary.uses), 3)
	assert_eq(int(c.legendary.lair_uses), 4, "4 in its lair")
	var names := []
	for o in c.legendary.options:
		names.append(o.name)
	assert_eq(names, ["Lash", "Psychic Drain"])
	var lash: Dictionary = c.legendary.options[0]
	assert_eq([lash.kind, lash.action, lash.count], ["attack", "Tentacle", 1])
	var drain: Dictionary = c.legendary.options[1]
	assert_eq([drain.kind, drain.action, drain.heal, drain.requires], ["action", "Consume Memories", "1d10", "charmed_or_grappled"])

func test_no_legendary_actions():
	var c := srd.make_monster("bulette")
	assert_true(c.legendary.is_empty())
	assert_eq(MonsterActions.legendary_left(c), 0)

func test_uses_spent_and_regained():
	var c := srd.make_monster("aboleth")
	var lash: Dictionary = c.legendary.options[0]
	for i in 3:
		assert_true(MonsterActions.use_legendary(c, lash).used)
	assert_false(MonsterActions.legendary_available(c, lash), "three uses out of the lair")
	assert_true(MonsterActions.legendary_available(c, lash, true), "a fourth in its lair")
	assert_true(MonsterActions.use_legendary(c, lash, true).used)
	assert_eq(MonsterActions.legendary_left(c, true), 0)
	MonsterActions.start_turn(c)
	assert_eq(MonsterActions.legendary_left(c), 3, "all back at the start of its turn")

func test_psychic_drain_needs_a_thrall_and_heals():
	Dice.rng = RandomNumberGenerator.new()
	Dice.rng.seed = 5
	var c := srd.make_monster("aboleth")
	var drain: Dictionary = c.legendary.options[1]
	assert_false(MonsterActions.legendary_available(c, drain), "no one Charmed or Grappled")
	c.take_damage(40, SRD.DamageType.SLASHING)
	var hp := c.current_hp
	var ev := MonsterActions.use_legendary(c, drain, false, {"charmed_or_grappled": true})
	assert_true(ev.used)
	assert_between(int(ev.heal), 1, 10, "regains 1d10")
	assert_eq(c.current_hp, hp + int(ev.heal))
	Dice.rng = null

func test_incapacitated_takes_none():
	var c := srd.make_monster("aboleth")
	c.conditions.add(SRD.Condition.STUNNED)
	assert_false(MonsterActions.legendary_available(c, c.legendary.options[0]))

func test_dragon_options_parse():
	var c := srd.make_monster("adult-blue-dragon")
	assert_eq(int(c.legendary.uses), 3)
	var swipe := {}
	for o in c.legendary.options:
		if o.name == "Tail Swipe":
			swipe = o
	assert_eq([swipe.kind, swipe.action], ["attack", "Rend"])
