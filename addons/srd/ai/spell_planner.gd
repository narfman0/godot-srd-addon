## Which spell or feature is worth spending this turn. The game measures space and odds and
## hands in candidates; this weighs them against the plain attack and what the fight needs.
##
##   candidate: {id, value (expected damage-equivalent), slot (0 = free), kind}
##   situation: {baseline (the plain attack's value), rounds_left (how long the fight would
##               last on baseline damage), resources (fraction of the caster's slots left)}
##
## Thrift: a slot of level L costs L * level_cost damage-equivalents; a short fight makes
## slots dear, a long one makes them cheap, so low-threat fights run on cantrips and deadly
## ones burn the top slots from the first round.
class_name SpellPlanner
extends RefCounted

const LEVEL_COST := 5.0

static func thrift(rounds_left: float) -> float:
	if rounds_left >= 4.0:
		return 0.25
	if rounds_left >= 2.5:
		return 0.6
	if rounds_left >= 1.5:
		return 1.0
	return 2.0

## Net worth of a candidate after what its slot costs.
static func net(cand: Dictionary, situation: Dictionary) -> float:
	var t := thrift(float(situation.get("rounds_left", 3.0)))
	var cost := float(cand.get("slot", 0)) * LEVEL_COST * t
	if cand.get("slot", 0) > 0 and float(situation.get("resources", 1.0)) < 0.25:
		cost *= 1.5  # running low: hold what's left for when it matters
	return float(cand.get("value", 0.0)) - cost

## The best candidate that beats the plain attack by a margin, or {}.
static func pick(cands: Array, situation: Dictionary) -> Dictionary:
	var best := {}
	var best_net: float = float(situation.get("baseline", 0.0)) * 1.1
	for cand: Dictionary in cands:
		var v := net(cand, situation)
		if v > best_net:
			best_net = v
			best = cand
	return best

## Expected value of a save-or-suffer spell: fail chance x damage, half on success when it
## halves, plus a control value for the rounds it would take the target out.
static func save_value(fail: float, damage: float, halves: bool, control: float = 0.0) -> float:
	return fail * (damage + control) + (1.0 - fail) * (damage * 0.5 if halves else 0.0)
