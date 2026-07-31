extends GutTest

func _make_combatant() -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Test"; s.level = 1
	s.strength = 10; s.dexterity = 10; s.constitution = 10
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 8; s.speed = 30; s.reset()
	return Combatant.new(s)

func test_declare_consumes_action():
	var actor := _make_combatant()
	var ra := ReadiedAction.declare(actor, SRDActionTypes.Action.ATTACK, "enemy moves", Callable())
	assert_not_null(ra)
	assert_false(actor.action_economy.has_action)

func test_declare_returns_null_without_action():
	var actor := _make_combatant()
	actor.action_economy.use_action()
	var ra := ReadiedAction.declare(actor, SRDActionTypes.Action.ATTACK, "trigger", Callable())
	assert_null(ra)

func test_declare_stores_trigger_description():
	var actor := _make_combatant()
	var ra := ReadiedAction.declare(actor, SRDActionTypes.Action.ATTACK, "enemy appears", Callable())
	assert_eq(ra.trigger_description, "enemy appears")

func test_trigger_uses_reaction():
	var actor := _make_combatant()
	var ra := ReadiedAction.declare(actor, SRDActionTypes.Action.ATTACK, "trigger", Callable())
	assert_true(actor.action_economy.has_reaction)
	ra.trigger(actor)
	assert_false(actor.action_economy.has_reaction)

func test_trigger_returns_true_with_reaction():
	var actor := _make_combatant()
	var ra := ReadiedAction.declare(actor, SRDActionTypes.Action.ATTACK, "trigger", Callable())
	assert_true(ra.trigger(actor))

func test_trigger_returns_false_without_reaction():
	var actor := _make_combatant()
	var ra := ReadiedAction.declare(actor, SRDActionTypes.Action.ATTACK, "trigger", Callable())
	actor.action_economy.use_reaction()
	assert_false(ra.trigger(actor))

func test_trigger_invokes_callback():
	var actor := _make_combatant()
	var called := false
	var cb := func(_a, _t): called = true
	var ra := ReadiedAction.declare(actor, SRDActionTypes.Action.ATTACK, "trigger", cb)
	ra.trigger(actor)
	assert_true(called)

func test_on_round_end_ends_concentration():
	var actor := _make_combatant()
	var conc := ConcentrationTracker.new()
	var ability := AbilityData.new()
	ability.concentration = true
	conc.begin(actor.stats, ability)
	assert_true(conc.is_concentrating)
	ReadiedAction.on_round_end_without_trigger(actor, conc)
	assert_false(conc.is_concentrating)

func test_on_round_end_no_concentration_is_safe():
	var actor := _make_combatant()
	ReadiedAction.on_round_end_without_trigger(actor, null)
	# should not crash
	assert_true(true)
