class_name SRDActionTypes
extends RefCounted

enum Action {
	ATTACK,
	CAST_ABILITY,
	DASH,
	DISENGAGE,
	DODGE,
	HELP,
	HIDE,
	READY,
	SEARCH,
	USE_OBJECT,
}

## State applied to a combatant for effects that last until start of next turn.
class TurnEffects:
	var dodging: bool = false        # attacks vs this creature have disadvantage
	var disengaging: bool = false    # doesn't trigger opportunity attacks
	var hidden: bool = false         # attacks from this creature have advantage
	var helped_ally: Combatant = null
	var helped_check_type: String = ""  # "attack" or "skill"

	func reset() -> void:
		dodging = false
		disengaging = false
		hidden = false
		helped_ally = null
		helped_check_type = ""

## Execute a Dodge action — marks the actor dodging until their next turn.
static func dodge(actor: Combatant, effects: TurnEffects) -> void:
	assert(actor.action_economy.use_action(), "Dodge requires an Action")
	effects.dodging = true

## Execute a Dash action — add actor's speed to remaining movement.
static func dash(actor: Combatant) -> void:
	assert(actor.action_economy.use_action(), "Dash requires an Action")
	actor.action_economy._movement_remaining += actor.stats.speed

## Execute a Disengage action — no opportunity attacks this turn.
static func disengage(actor: Combatant, effects: TurnEffects) -> void:
	assert(actor.action_economy.use_action(), "Disengage requires an Action")
	effects.disengaging = true

## Execute a Help action — grant advantage to an ally's next attack or check.
static func help(actor: Combatant, ally: Combatant,
		check_type: String, effects: TurnEffects) -> void:
	assert(actor.action_economy.use_action(), "Help requires an Action")
	effects.helped_ally = ally
	effects.helped_check_type = check_type

## Execute a Hide action — return the Stealth roll result.
## Caller decides if the roll beats any observer's passive Perception.
static func hide(actor: Combatant, effects: TurnEffects,
		fixed_d20: int = -1) -> int:
	assert(actor.action_economy.use_action(), "Hide requires an Action")
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var bonus := SRDSkills.skill_bonus(actor.stats, SRD.Skill.STEALTH)
	var total := d20 + bonus
	# Hidden only if stealth roll > 0 (caller compares to observer passive perception)
	effects.hidden = total > 0
	return total

## Check if an ally is receiving the Help advantage on their next attack.
static func has_attack_help(ally: Combatant, effects: TurnEffects) -> bool:
	return effects.helped_ally == ally and effects.helped_check_type == "attack"
