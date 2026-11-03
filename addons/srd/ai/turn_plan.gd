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

## Monster Bonus Action (a MonsterActions feature) and when to take it:
## "before_move" (Shadow Step to the target, then attack with Advantage) or
## "after_action" (attack, then Nimble Escape's Disengage and fall back).
var monster_bonus: Dictionary = {}
var bonus_timing: String = ""
var bonus_option: String = ""      ## simple features: "disengage" | "dash" | "hide"
var bonus_purpose: String = ""     ## "engage" (teleport next to action_target) | "escape"
## Move away from move_target after the action instead of before it.
var retreat_after_action: bool = false
