extends GutTest

# ── Fixture helpers ───────────────────────────────────────────────────────────

func _make_combatant(name: String, hp: int = 20, max_hp: int = 20,
		speed: int = 30) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = name; s.level = 3
	s.strength = 14; s.dexterity = 14; s.constitution = 12
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.max_hp = max_hp; s.speed = speed; s.reset()
	s.current_hp = hp
	var sword := WeaponData.new()
	sword.die_count = 1; sword.die_sides = 6
	sword.damage_type = SRD.DamageType.SLASHING
	sword.range_normal = 5
	return Combatant.new(s, sword)

func _light_weapon() -> WeaponData:
	var w := WeaponData.new()
	w.die_count = 1; w.die_sides = 6
	w.damage_type = SRD.DamageType.SLASHING
	w.range_normal = 5
	w.properties = SRD.WeaponProperty.LIGHT | SRD.WeaponProperty.FINESSE
	return w

## Build an AIContext with simple lambda stubs.
## in_melee_ids: Array[String] of enemy names considered in melee with actor.
## reachable_ids: Array[String] of enemy names reachable in one move.
func _make_ctx(actor: Combatant, enemies: Array, allies: Array = [],
		in_melee_ids: Array = [], reachable_ids: Array = []) -> AIContext:
	var ctx := AIContext.new()
	ctx.actor = actor
	ctx.enemies = enemies
	ctx.allies = allies
	ctx.is_in_melee_range = func(a, b):
		if a == actor:
			return b.name in in_melee_ids
		return false
	ctx.can_reach_in_one_move = func(_a, b):
		return b.name in reachable_ids
	ctx.distance_feet = func(_a, b):
		# nearest = first enemy for simplicity
		return 5 if b == enemies[0] else 30
	ctx.cover_between = func(_a, _b):
		return SRD.Cover.NONE
	return ctx

# ── Aggressive ────────────────────────────────────────────────────────────────

func test_aggressive_attacks_weakest_enemy_in_melee():
	var actor := _make_combatant("Hero")
	var strong := _make_combatant("Strong", 18)
	var weak := _make_combatant("Weak", 5)
	var ctx := _make_ctx(actor, [strong, weak], [], ["Strong", "Weak"])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.AGGRESSIVE)
	assert_eq(plan.action, TurnPlan.ActionChoice.ATTACK)
	assert_eq(plan.action_target, weak)

func test_aggressive_moves_to_reach_enemy():
	var actor := _make_combatant("Hero")
	var enemy := _make_combatant("Enemy")
	# Enemy not in melee but reachable in one move
	var ctx := _make_ctx(actor, [enemy], [], [], ["Enemy"])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.AGGRESSIVE)
	assert_eq(plan.action, TurnPlan.ActionChoice.ATTACK)
	assert_eq(plan.move_intent, TurnPlan.MoveIntent.CLOSE_TO_TARGET)

func test_aggressive_dashes_when_enemy_out_of_reach():
	var actor := _make_combatant("Hero")
	var enemy := _make_combatant("Enemy")
	# Enemy neither in melee nor reachable
	var ctx := _make_ctx(actor, [enemy], [], [], [])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.AGGRESSIVE)
	assert_eq(plan.action, TurnPlan.ActionChoice.DASH)
	assert_eq(plan.move_intent, TurnPlan.MoveIntent.CLOSE_TO_TARGET)

func test_aggressive_uses_second_wind_when_bloodied():
	var actor := _make_combatant("Hero", 5, 20)  # 25% HP
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [], ["Enemy"])
	var ft := ClassFeatureTracker.new(ClassData.make_soldier())
	ctx.feature_tracker = ft
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.AGGRESSIVE)
	assert_eq(plan.bonus_action, TurnPlan.BonusActionChoice.SECOND_WIND)

func test_aggressive_uses_twf_when_off_hand_available():
	var actor := _make_combatant("Hero")
	actor.weapon = _light_weapon()
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [], ["Enemy"])
	ctx.off_hand_weapon = _light_weapon()
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.AGGRESSIVE)
	assert_eq(plan.bonus_action, TurnPlan.BonusActionChoice.OFF_HAND_ATTACK)
	assert_eq(plan.bonus_target, enemy)

# ── Defensive ─────────────────────────────────────────────────────────────────

func test_defensive_dodges_when_below_30pct_hp():
	var actor := _make_combatant("Hero", 5, 20)  # 25%
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [], ["Enemy"])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.DEFENSIVE)
	assert_eq(plan.action, TurnPlan.ActionChoice.DODGE)
	assert_eq(plan.move_intent, TurnPlan.MoveIntent.HOLD)

func test_defensive_attacks_enemy_in_melee_when_healthy():
	var actor := _make_combatant("Hero", 18, 20)  # 90%
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [], ["Enemy"])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.DEFENSIVE)
	assert_eq(plan.action, TurnPlan.ActionChoice.ATTACK)
	assert_eq(plan.move_intent, TurnPlan.MoveIntent.HOLD)

func test_defensive_holds_and_dodges_when_no_enemies_in_range():
	var actor := _make_combatant("Hero", 18, 20)
	var enemy := _make_combatant("Enemy")
	# enemy not in melee, not reachable
	var ctx := _make_ctx(actor, [enemy], [], [], [])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.DEFENSIVE)
	assert_eq(plan.action, TurnPlan.ActionChoice.DODGE)
	assert_eq(plan.move_intent, TurnPlan.MoveIntent.HOLD)

# ── Skirmisher ────────────────────────────────────────────────────────────────

func test_skirmisher_disengages_when_cornered():
	var actor := _make_combatant("Ghost")
	var enemy := _make_combatant("Enemy")
	# enemy is in melee — skirmisher must escape
	var ctx := _make_ctx(actor, [enemy], [], ["Enemy"])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.SKIRMISHER)
	assert_eq(plan.action, TurnPlan.ActionChoice.DISENGAGE)
	assert_eq(plan.move_intent, TurnPlan.MoveIntent.RETREAT)

func test_skirmisher_attacks_reachable_enemy():
	var actor := _make_combatant("Ghost")
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [], [], ["Enemy"])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.SKIRMISHER)
	assert_eq(plan.action, TurnPlan.ActionChoice.ATTACK)
	assert_eq(plan.move_intent, TurnPlan.MoveIntent.CLOSE_TO_TARGET)

func test_skirmisher_dashes_when_out_of_reach():
	var actor := _make_combatant("Ghost")
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [], [], [])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.SKIRMISHER)
	assert_eq(plan.action, TurnPlan.ActionChoice.DASH)

# ── Support ───────────────────────────────────────────────────────────────────

func test_support_helps_injured_ally():
	var actor := _make_combatant("Warden")
	var ally := _make_combatant("Ally", 4, 20)  # 20% HP — injured
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [ally])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.SUPPORT)
	assert_eq(plan.action, TurnPlan.ActionChoice.HELP)
	assert_eq(plan.action_target, ally)

func test_support_attacks_when_no_injured_allies():
	var actor := _make_combatant("Warden")
	var ally := _make_combatant("Ally", 20, 20)  # full HP
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [ally], ["Enemy"])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.SUPPORT)
	assert_eq(plan.action, TurnPlan.ActionChoice.ATTACK)

func test_support_uses_channel_divinity_as_bonus():
	var actor := _make_combatant("Warden", 20, 20)
	var ally := _make_combatant("Ally", 20, 20)
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [ally])
	var ft := ClassFeatureTracker.new(ClassData.make_warden())
	ctx.feature_tracker = ft
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.SUPPORT)
	assert_eq(plan.bonus_action, TurnPlan.BonusActionChoice.USE_CHANNEL_DIVINITY)

func test_support_holds_position():
	var actor := _make_combatant("Warden")
	var ally := _make_combatant("Ally", 4, 20)
	var enemy := _make_combatant("Enemy")
	var ctx := _make_ctx(actor, [enemy], [ally])
	var plan := CombatAI.plan_turn(ctx, CombatAI.Profile.SUPPORT)
	assert_eq(plan.move_intent, TurnPlan.MoveIntent.HOLD)
