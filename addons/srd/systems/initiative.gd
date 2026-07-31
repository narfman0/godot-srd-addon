class_name CombatOrder
extends RefCounted

# Each entry: { "char": CharacterStats, "roll": int, "total": int }
var _order: Array = []
var _current_index: int = 0
var round_number: int = 1

## Roll initiative for a list of CharacterStats and build sorted combat order.
func build(combatants: Array) -> void:
	_order.clear()
	_current_index = 0
	round_number = 1
	for char in combatants:
		var dex := char.get_ability(SRD.Ability.DEXTERITY)
		var mod := SRDRules.ability_modifier(dex)
		var roll := Dice.roll_d20()
		_order.append({ "char": char, "roll": roll, "total": roll + mod })

	# Sort descending by total; ties broken by DEX score, then by random coin flip
	_order.sort_custom(func(a, b):
		if a["total"] != b["total"]:
			return a["total"] > b["total"]
		var dex_a := a["char"].get_ability(SRD.Ability.DEXTERITY)
		var dex_b := b["char"].get_ability(SRD.Ability.DEXTERITY)
		if dex_a != dex_b:
			return dex_a > dex_b
		return randi() % 2 == 0
	)

## Inject a pre-built order (useful for deterministic tests).
func set_order(entries: Array) -> void:
	_order = entries
	_current_index = 0
	round_number = 1

func current() -> CharacterStats:
	if _order.is_empty():
		return null
	return _order[_current_index]["char"]

func current_entry() -> Dictionary:
	if _order.is_empty():
		return {}
	return _order[_current_index]

## Advance to the next combatant. Returns true when a new round begins.
func advance() -> bool:
	_current_index += 1
	if _current_index >= _order.size():
		_current_index = 0
		round_number += 1
		return true
	return false

func count() -> int:
	return _order.size()

func get_entry(index: int) -> Dictionary:
	return _order[index]

func initiative_total(char: CharacterStats) -> int:
	for entry in _order:
		if entry["char"] == char:
			return entry["total"]
	return 0
