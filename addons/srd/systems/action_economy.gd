class_name ActionEconomy
extends RefCounted

var _has_action: bool = true
var _has_bonus_action: bool = true
var _has_reaction: bool = true
var _movement_remaining: int = 30
var _speed: int = 30
## True once the creature has moved this turn (Steady Aim needs it false).
var has_moved: bool = false

func _init(speed: int = 30) -> void:
	_speed = speed
	_movement_remaining = speed

## Reset all resources for a new turn.
func reset_turn() -> void:
	_has_action = true
	_has_bonus_action = true
	_movement_remaining = _speed
	has_moved = false

## Reaction resets at the start of each character's turn in the round
## (tracked per-round; reset separately if needed).
func reset_reaction() -> void:
	_has_reaction = true

# --- Queries ---

var has_action: bool:
	get: return _has_action

var has_bonus_action: bool:
	get: return _has_bonus_action

var has_reaction: bool:
	get: return _has_reaction

var movement_remaining: int:
	get: return _movement_remaining

# --- Consumption ---

func use_action() -> bool:
	if not _has_action:
		return false
	_has_action = false
	return true

func use_bonus_action() -> bool:
	if not _has_bonus_action:
		return false
	_has_bonus_action = false
	return true

func use_reaction() -> bool:
	if not _has_reaction:
		return false
	_has_reaction = false
	return true

## Dash action: spend the action to gain extra movement equal to speed.
func dash() -> bool:
	if not use_action():
		return false
	_movement_remaining += _speed
	return true

## Returns false if there isn't enough movement left.
func spend_movement(feet: int) -> bool:
	if feet > _movement_remaining:
		return false
	_movement_remaining -= feet
	if feet > 0:
		has_moved = true
	return true

# --- Condition integration ---

## Apply incapacitated: lose action and bonus action immediately.
func apply_incapacitated() -> void:
	_has_action = false
	_has_bonus_action = false
