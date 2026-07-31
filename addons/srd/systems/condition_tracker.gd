class_name ConditionTracker
extends RefCounted

# Bit mask — 1 bit per SRD.Condition value (15 values fit in an int)
var _mask: int = 0
var exhaustion_level: int = 0
# Timed conditions: condition_int → rounds_remaining (absent = permanent)
var _timed: Dictionary = {}

func add(condition: SRD.Condition) -> void:
	_mask |= (1 << int(condition))
	# Conditions that imply incapacitated
	if condition in [SRD.Condition.PARALYZED, SRD.Condition.PETRIFIED,
			SRD.Condition.STUNNED, SRD.Condition.UNCONSCIOUS]:
		_mask |= (1 << int(SRD.Condition.INCAPACITATED))

func remove(condition: SRD.Condition) -> void:
	_mask &= ~(1 << int(condition))
	# Re-evaluate incapacitated when removing a source
	if not _any_incapacitating():
		_mask &= ~(1 << int(SRD.Condition.INCAPACITATED))

func has(condition: SRD.Condition) -> bool:
	return (_mask >> int(condition)) & 1 == 1

## Add a condition that expires after a set number of rounds.
## tick_round() must be called at the end of each round to advance timers.
func add_timed(condition: SRD.Condition, rounds: int) -> void:
	add(condition)
	_timed[int(condition)] = rounds

## How many rounds remain for a timed condition. Returns -1 if permanent or absent.
func rounds_remaining(condition: SRD.Condition) -> int:
	return _timed.get(int(condition), -1)

## Call at the end of each round. Decrements all timed conditions and removes
## any that have expired. Returns an Array of conditions that expired this tick.
func tick_round() -> Array:
	var expired: Array = []
	for key: int in _timed.keys():
		_timed[key] -= 1
		if _timed[key] <= 0:
			expired.append(key as SRD.Condition)
	for cond: SRD.Condition in expired:
		_timed.erase(int(cond))
		remove(cond)
	return expired

func clear_all() -> void:
	_mask = 0
	exhaustion_level = 0
	_timed.clear()

func add_exhaustion() -> void:
	exhaustion_level = mini(exhaustion_level + 1, 6)
	if exhaustion_level >= 6:
		add(SRD.Condition.DEAD)

func remove_exhaustion(levels: int = 1) -> void:
	exhaustion_level = maxi(0, exhaustion_level - levels)

# --- Mechanical query methods ---

## Attackers have advantage against this target.
func grants_advantage_to_attackers() -> bool:
	return has(SRD.Condition.PARALYZED) or has(SRD.Condition.PETRIFIED) \
		or has(SRD.Condition.PRONE) or has(SRD.Condition.RESTRAINED) \
		or has(SRD.Condition.STUNNED) or has(SRD.Condition.UNCONSCIOUS)

## Target has disadvantage on their own attack rolls.
func has_attack_disadvantage() -> bool:
	return has(SRD.Condition.BLINDED) or has(SRD.Condition.FRIGHTENED) \
		or has(SRD.Condition.POISONED) or has(SRD.Condition.PRONE) \
		or has(SRD.Condition.RESTRAINED)

## Target has advantage on their own attack rolls.
func has_attack_advantage() -> bool:
	return has(SRD.Condition.INVISIBLE)

## Target automatically fails STR and DEX saving throws.
func auto_fails_str_dex_saves() -> bool:
	return has(SRD.Condition.PARALYZED) or has(SRD.Condition.UNCONSCIOUS)

## Target can take no actions.
func is_incapacitated() -> bool:
	return has(SRD.Condition.INCAPACITATED)

# --- Private ---

func _any_incapacitating() -> bool:
	return has(SRD.Condition.PARALYZED) or has(SRD.Condition.PETRIFIED) \
		or has(SRD.Condition.STUNNED) or has(SRD.Condition.UNCONSCIOUS)
