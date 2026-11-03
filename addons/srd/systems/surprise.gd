## Who is surprised when combat starts. SRD 5.2.1: a surprised combatant has Disadvantage
## on its Initiative roll (CombatOrder.roll(c, tracker.is_surprised(c))) and nothing more.
## apply_to_turn() is the older (2014) "loses its first turn" rule, kept for Wayfarer.
class_name SurpriseTracker
extends RefCounted

## Set of combatants that are surprised in the first round.
var _surprised: Array = []  # Array[Combatant]
var _first_round_done: bool = false

func add_surprised(combatant: Combatant) -> void:
	if not _surprised.has(combatant):
		_surprised.append(combatant)

func is_surprised(combatant: Combatant) -> bool:
	return not _first_round_done and _surprised.has(combatant)

## Call at the end of the first full round to lift surprise.
func end_surprise_round() -> void:
	_first_round_done = true
	_surprised.clear()

## A surprised combatant cannot move, take actions, or use reactions their first turn.
func apply_to_turn(combatant: Combatant) -> void:
	if is_surprised(combatant):
		combatant.action_economy.apply_incapacitated()  # blocks action + bonus
		combatant.action_economy._movement_remaining = 0
		combatant.action_economy._has_reaction = false

func surprised_count() -> int:
	return _surprised.size()
