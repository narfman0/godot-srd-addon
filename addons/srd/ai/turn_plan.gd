## The AI's decision for one combatant's turn. The game layer executes it.
class_name TurnPlan
extends RefCounted

enum MoveIntent {
	NONE,
	CLOSE_TO_TARGET,   ## move toward move_target
	MAINTAIN_RANGE,    ## stay at current distance
	RETREAT,           ## move away from move_target
	HOLD,              ## don't move
}

enum ActionChoice {
	NONE,
	ATTACK,
	DASH,
	DODGE,
	DISENGAGE,
	HELP,
}

enum BonusActionChoice {
	NONE,
	OFF_HAND_ATTACK,
	SECOND_WIND,
	USE_CHANNEL_DIVINITY,
}

var move_intent: MoveIntent = MoveIntent.NONE
var move_target: Combatant = null   ## who to move toward / away from

var action: ActionChoice = ActionChoice.NONE
var action_target: Combatant = null

var bonus_action: BonusActionChoice = BonusActionChoice.NONE
var bonus_target: Combatant = null
