class_name DeathSaveTracker
extends RefCounted

var successes: int = 0
var failures: int = 0
var is_stable: bool = false
var is_dead: bool = false

## Roll a death saving throw. Returns the d20 result.
## Pass in a pre-rolled value for deterministic tests.
func roll(d20_result: int = -1) -> int:
	assert(not is_stable and not is_dead, "Can't roll death saves when stable or dead")
	var roll_val := d20_result if d20_result >= 1 else Dice.roll_d20()

	if roll_val == 20:
		_on_natural_20()
	elif roll_val == 1:
		_add_failures(2)
	elif roll_val >= 10:
		_add_success()
	else:
		_add_failures(1)

	return roll_val

## Called when the unconscious character takes any damage at 0 HP.
func on_damage_taken(is_critical: bool = false) -> void:
	_add_failures(2 if is_critical else 1)

## Stabilise externally (healer's kit, Spare the Dying, etc.).
func stabilise() -> void:
	is_stable = true

## Revive the character (heal to ≥1 HP). Resets tracker.
func revive() -> void:
	successes = 0
	failures = 0
	is_stable = false
	is_dead = false

func is_resolved() -> bool:
	return is_stable or is_dead

# --- Private ---

func _add_success() -> void:
	successes += 1
	if successes >= 3:
		is_stable = true

func _add_failures(count: int) -> void:
	failures += count
	if failures >= 3:
		is_dead = true

func _on_natural_20() -> void:
	# Regain 1 HP — signal to caller to restore HP and clear tracker
	is_stable = true
	successes = 3  # sentinel so caller knows it was a nat 20 stabilise
