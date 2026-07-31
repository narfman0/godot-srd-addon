class_name CombatAI
extends RefCounted

enum Profile {
	AGGRESSIVE,  ## close in, attack, off-hand if available
	DEFENSIVE,   ## hold ground, dodge when bloodied, attack in range
	SKIRMISHER,  ## attack then disengage, retreat when cornered
	SUPPORT,     ## help injured allies, hold back, use class features
}

static func plan_turn(ctx: AIContext, profile: Profile) -> TurnPlan:
	match profile:
		Profile.AGGRESSIVE: return _aggressive(ctx)
		Profile.DEFENSIVE:  return _defensive(ctx)
		Profile.SKIRMISHER: return _skirmisher(ctx)
		Profile.SUPPORT:    return _support(ctx)
	return TurnPlan.new()

# ── Profiles ──────────────────────────────────────────────────────────────────

static func _aggressive(ctx: AIContext) -> TurnPlan:
	var plan := TurnPlan.new()
	var foes := ctx.living_enemies()
	if foes.is_empty():
		return plan

	var in_melee := foes.filter(func(e): return ctx.melee_range(ctx.actor, e))
	if not in_melee.is_empty():
		plan.move_intent = TurnPlan.MoveIntent.HOLD
		plan.action = TurnPlan.ActionChoice.ATTACK
		plan.action_target = _weakest(in_melee)
	else:
		var reachable := foes.filter(func(e): return ctx.reachable(e))
		if not reachable.is_empty():
			plan.move_intent = TurnPlan.MoveIntent.CLOSE_TO_TARGET
			plan.move_target = _weakest(reachable)
			plan.action = TurnPlan.ActionChoice.ATTACK
			plan.action_target = plan.move_target
		else:
			plan.move_intent = TurnPlan.MoveIntent.CLOSE_TO_TARGET
			plan.move_target = _nearest(foes, ctx)
			plan.action = TurnPlan.ActionChoice.DASH

	plan.bonus_action = _bonus_action(ctx, plan.action_target)
	if plan.bonus_action == TurnPlan.BonusActionChoice.OFF_HAND_ATTACK:
		plan.bonus_target = plan.action_target
	return plan

static func _defensive(ctx: AIContext) -> TurnPlan:
	var plan := TurnPlan.new()
	plan.move_intent = TurnPlan.MoveIntent.HOLD
	var foes := ctx.living_enemies()
	if foes.is_empty():
		return plan

	if _hp_pct(ctx.actor) < 0.3:
		plan.action = TurnPlan.ActionChoice.DODGE
	else:
		var in_melee := foes.filter(func(e): return ctx.melee_range(ctx.actor, e))
		if not in_melee.is_empty():
			plan.action = TurnPlan.ActionChoice.ATTACK
			plan.action_target = _weakest(in_melee)
		else:
			plan.action = TurnPlan.ActionChoice.DODGE  # nothing in range; stay cautious

	plan.bonus_action = _bonus_action(ctx, plan.action_target)
	if plan.bonus_action == TurnPlan.BonusActionChoice.OFF_HAND_ATTACK:
		plan.bonus_target = plan.action_target
	return plan

static func _skirmisher(ctx: AIContext) -> TurnPlan:
	var plan := TurnPlan.new()
	var foes := ctx.living_enemies()
	if foes.is_empty():
		return plan

	var in_melee := foes.filter(func(e): return ctx.melee_range(ctx.actor, e))
	if not in_melee.is_empty():
		# Cornered — disengage and fall back
		plan.action = TurnPlan.ActionChoice.DISENGAGE
		plan.move_intent = TurnPlan.MoveIntent.RETREAT
		plan.move_target = _nearest(in_melee, ctx)
	else:
		var reachable := foes.filter(func(e): return ctx.reachable(e))
		if not reachable.is_empty():
			plan.move_intent = TurnPlan.MoveIntent.CLOSE_TO_TARGET
			plan.move_target = _weakest(reachable)
			plan.action = TurnPlan.ActionChoice.ATTACK
			plan.action_target = plan.move_target
		else:
			plan.move_intent = TurnPlan.MoveIntent.CLOSE_TO_TARGET
			plan.move_target = _nearest(foes, ctx)
			plan.action = TurnPlan.ActionChoice.DASH

	plan.bonus_action = _bonus_action(ctx, plan.action_target)
	if plan.bonus_action == TurnPlan.BonusActionChoice.OFF_HAND_ATTACK:
		plan.bonus_target = plan.action_target
	return plan

static func _support(ctx: AIContext) -> TurnPlan:
	var plan := TurnPlan.new()
	plan.move_intent = TurnPlan.MoveIntent.HOLD

	# Prioritise helping the most injured living ally
	var friends := ctx.living_allies()
	var injured := friends.filter(func(a): return _hp_pct(a) < 0.5)
	if not injured.is_empty():
		plan.action = TurnPlan.ActionChoice.HELP
		plan.action_target = _weakest(injured)
	else:
		# No injured allies — contribute an attack if possible
		var foes := ctx.living_enemies()
		var in_range := foes.filter(func(e): return ctx.melee_range(ctx.actor, e) or ctx.reachable(e))
		if not in_range.is_empty():
			plan.action = TurnPlan.ActionChoice.ATTACK
			plan.action_target = _weakest(in_range)

	plan.bonus_action = _bonus_action(ctx, null)
	return plan

# ── Bonus action selector ─────────────────────────────────────────────────────

static func _bonus_action(ctx: AIContext,
		atk_target: Combatant) -> TurnPlan.BonusActionChoice:
	var ft := ctx.feature_tracker
	# Heal self with Second Wind when below 40%
	if ft != null and not ft.second_wind_used and _hp_pct(ctx.actor) < 0.4:
		return TurnPlan.BonusActionChoice.SECOND_WIND
	# Channel Divinity if charges remain
	if ft != null and ft.channel_divinity_uses < ft.channel_divinity_max:
		return TurnPlan.BonusActionChoice.USE_CHANNEL_DIVINITY
	# Two-weapon fighting if we attacked something
	if atk_target != null and ctx.off_hand_weapon != null:
		if TwoWeaponFighting.can_use(ctx.actor.weapon, ctx.off_hand_weapon):
			return TurnPlan.BonusActionChoice.OFF_HAND_ATTACK
	return TurnPlan.BonusActionChoice.NONE

# ── Target helpers ────────────────────────────────────────────────────────────

static func _weakest(combatants: Array) -> Combatant:
	var best: Combatant = combatants[0]
	for c in combatants:
		if c.stats.current_hp < best.stats.current_hp:
			best = c
	return best

static func _nearest(combatants: Array, ctx: AIContext) -> Combatant:
	var best: Combatant = combatants[0]
	var best_dist := ctx.dist(best)
	for c in combatants.slice(1):
		var d := ctx.dist(c)
		if d < best_dist:
			best_dist = d
			best = c
	return best

static func _hp_pct(c: Combatant) -> float:
	if c.stats.max_hp == 0:
		return 0.0
	return float(c.stats.current_hp) / float(c.stats.max_hp)
