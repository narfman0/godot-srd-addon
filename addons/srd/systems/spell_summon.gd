## A force a spell creates and the caster keeps directing (Spiritual Weapon, SRD 5.2.1):
## it appears within the spell's range, attacks a creature within 5 ft. of itself, and on
## the caster's later turns moves up to move_feet and attacks again as a Bonus Action.
## It lasts the spell's duration and ends early with the caster's Concentration.
##
## The engine owns the attack (SpellResolver.summon_strike) and the lifetime; the game owns
## where it is (position) and how it looks.
class_name SpellSummon
extends RefCounted

signal dismissed(summon: SpellSummon)

var caster: Combatant
## The spell, fixed at the slot level it was cast with (upcast dice stay).
var ability: AbilityData
var level: int = 0
## Later turns: how far it moves before attacking, and its reach once there.
var move_feet: int = 20
var reach_feet: int = 5
## "bonus_action": what its later attacks cost the caster.
var repeat_as: String = "bonus_action"
var rounds_left: int = 10
var active: bool = true
## Game space (unused by the engine).
var position: Vector3 = Vector3.ZERO
var concentration = null  ## ConcentrationTracker that sustains it

static func create(c: Combatant, ab: AbilityData, cast_level: int) -> SpellSummon:
	var s := SpellSummon.new()
	s.caster = c
	s.ability = ab
	s.level = maxi(cast_level, ab.slot_level)
	s.move_feet = int(ab.summon.get("move_feet", 20))
	s.repeat_as = str(ab.summon.get("repeat_as", "bonus_action"))
	s.rounds_left = int(ab.summon.get("rounds", maxi(1, ab.duration_rounds)))
	return s

var name: String:
	get: return ability.ability_name if ability else "Summon"

## Can it reach a creature this far away (feet, from the force) on a later turn?
func can_reach(distance_ft: float) -> bool:
	return active and distance_ft <= move_feet + reach_feet

## The caster's turn started: count down the duration. Returns true if it just ended.
func turn_started() -> bool:
	if not active:
		return false
	rounds_left -= 1
	if rounds_left > 0:
		return false
	if concentration != null and concentration.is_concentrating:
		concentration.end()  # the spell's duration is up
	else:
		dismiss()
	return true

func dismiss() -> void:
	if not active:
		return
	active = false
	dismissed.emit(self)
