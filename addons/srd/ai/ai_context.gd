## Context passed to CombatAI.plan_turn(). The game layer populates the
## positional callbacks using its own scene data (nodes, NavigationServer, etc.).
class_name AIContext
extends RefCounted

var actor: Combatant
var allies: Array          ## Array[Combatant] — living allied combatants
var enemies: Array         ## Array[Combatant] — living enemy combatants

## Optional — only set for class-feature-aware combatants
var class_data: ClassData = null
var feature_tracker: ClassFeatureTracker = null
var off_hand_weapon: WeaponData = null  ## set if actor can two-weapon fight

## Positional queries — implemented by the game layer.
## All must be set before calling CombatAI.plan_turn().
var is_in_melee_range: Callable     ## func(a: Combatant, b: Combatant) -> bool
var can_reach_in_one_move: Callable ## func(actor: Combatant, target: Combatant) -> bool
var distance_feet: Callable         ## func(a: Combatant, b: Combatant) -> int
var cover_between: Callable         ## func(a: Combatant, b: Combatant) -> SRD.Cover
## Optional: func(c: Combatant, requirement: String) -> bool for monster features with a
## `requires` ("dim_light_or_darkness"). Unset: features with a requirement aren't used.
var requirement_met: Callable

## Convenience wrappers so AI code reads cleanly
func melee_range(a: Combatant, b: Combatant) -> bool:
	return is_in_melee_range.call(a, b)

func reachable(target: Combatant) -> bool:
	return can_reach_in_one_move.call(actor, target)

func dist(target: Combatant) -> int:
	return distance_feet.call(actor, target)

func cover(target: Combatant) -> SRD.Cover:
	return cover_between.call(actor, target)

func meets(requirement: String) -> bool:
	if requirement == "":
		return true
	return requirement_met.is_valid() and bool(requirement_met.call(actor, requirement))

func living_enemies() -> Array:
	return enemies.filter(func(c): return c.is_active)

func living_allies() -> Array:
	return allies.filter(func(c): return c.is_active)
