extends GutTest

func _make_combatant() -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Test"
	s.level = 1; s.hit_die = 8
	s.strength = 10; s.dexterity = 10; s.constitution = 10
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = 8; s.speed = 30; s.reset()
	return Combatant.new(s)

func test_dodge_marks_dodging_and_consumes_action():
	var c := _make_combatant()
	var fx := SRDActionTypes.TurnEffects.new()
	SRDActionTypes.dodge(c, fx)
	assert_true(fx.dodging)
	assert_false(c.action_economy.has_action)

func test_dash_adds_speed_to_movement():
	var c := _make_combatant()
	SRDActionTypes.dash(c)
	assert_eq(c.action_economy.movement_remaining, 60)  # 30 base + 30 dash

func test_disengage_marks_disengaging():
	var c := _make_combatant()
	var fx := SRDActionTypes.TurnEffects.new()
	SRDActionTypes.disengage(c, fx)
	assert_true(fx.disengaging)
	assert_false(c.action_economy.has_action)

func test_help_records_ally_and_check_type():
	var c := _make_combatant()
	var ally := _make_combatant()
	ally.stats.character_name = "Ally"
	var fx := SRDActionTypes.TurnEffects.new()
	SRDActionTypes.help(c, ally, "attack", fx)
	assert_true(SRDActionTypes.has_attack_help(ally, fx))

func test_help_does_not_grant_to_wrong_ally():
	var c := _make_combatant()
	var ally := _make_combatant()
	var other := _make_combatant()
	var fx := SRDActionTypes.TurnEffects.new()
	SRDActionTypes.help(c, ally, "attack", fx)
	assert_false(SRDActionTypes.has_attack_help(other, fx))

func test_hide_returns_stealth_roll_and_marks_hidden():
	var c := _make_combatant()
	var fx := SRDActionTypes.TurnEffects.new()
	var result := SRDActionTypes.hide(c, fx, 15)  # fixed d20=15
	assert_eq(result, 15)  # 15 + 0 mod (no proficiency, 10 DEX)
	assert_true(fx.hidden)

func test_hide_not_hidden_on_zero():
	var c := _make_combatant()
	c.stats.dexterity = 1  # large negative mod
	var fx := SRDActionTypes.TurnEffects.new()
	# roll 1 + (-5 DEX mod) = -4, hidden = false
	SRDActionTypes.hide(c, fx, 1)
	assert_false(fx.hidden)

func test_turn_effects_reset_clears_all():
	var c := _make_combatant()
	var fx := SRDActionTypes.TurnEffects.new()
	fx.dodging = true
	fx.disengaging = true
	fx.hidden = true
	fx.helped_ally = c
	fx.helped_check_type = "attack"
	fx.reset()
	assert_false(fx.dodging)
	assert_false(fx.disengaging)
	assert_false(fx.hidden)
	assert_null(fx.helped_ally)
	assert_eq(fx.helped_check_type, "")
