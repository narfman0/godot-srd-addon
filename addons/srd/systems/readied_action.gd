class_name ReadiedAction
extends RefCounted

var trigger_description: String = ""
var action_type: SRDActionTypes.Action = SRDActionTypes.Action.ATTACK
var target: Object = null   # Combatant or null
var _callback: Callable     # func(actor, target) called when triggered

func _init() -> void:
	_callback = Callable()

## Declare a readied action. actor must spend their Action; reaction reserved for trigger.
## Returns false if actor has no action available.
static func declare(actor: Combatant, action: SRDActionTypes.Action,
		trigger: String, callback: Callable) -> ReadiedAction:
	if not actor.action_economy.use_action():
		return null
	var r := ReadiedAction.new()
	r.action_type = action
	r.trigger_description = trigger
	r._callback = callback
	return r

## Attempt to fire the readied action. Uses the actor's reaction.
## Returns true if triggered, false if no reaction available.
func trigger(actor: Combatant) -> bool:
	if not actor.action_economy.use_reaction():
		return false
	if _callback.is_valid():
		_callback.call(actor, target)
	return true

## A readied Dodge that hasn't been triggered — lose the dodge benefit on your next turn.
## Per SRD: concentration ends if you hold a ready and don't use it.
static func on_round_end_without_trigger(actor: Combatant,
		concentration: ConcentrationTracker = null) -> void:
	if concentration != null and concentration.is_concentrating:
		concentration.end()
