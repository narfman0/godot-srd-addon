class_name ConcentrationTracker
extends RefCounted

var _active_ability: AbilityData = null
var _caster: CharacterStats = null
## Combatants carrying effects this concentration sustains; end() strips them.
var affected: Array = []

var is_concentrating: bool:
	get: return _active_ability != null

var active_ability: AbilityData:
	get: return _active_ability

## Begin concentrating on a new ability. Automatically ends the previous one.
func begin(caster: CharacterStats, ability: AbilityData) -> void:
	assert(ability.concentration, "AbilityData.concentration must be true")
	if is_concentrating:
		end()  # a new Concentration spell ends the previous one
	_caster = caster
	_active_ability = ability

## End concentration explicitly (moved out of range, took an action, etc.).
func end() -> void:
	if _caster != null:
		for c in affected:
			c.effects.end_concentration(_caster.character_name)
	affected.clear()
	_active_ability = null
	_caster = null

## Remember a combatant affected by the current spell (SpellResolver calls this).
func track(target) -> void:
	if not target in affected:
		affected.append(target)

## Called when the concentrating character takes damage.
## Rolls a CON saving throw: DC = max(10, floor(damage / 2)).
## Returns true if concentration is maintained, false if broken.
## Pass injected_d20 for deterministic tests.
func damage_concentration_check(damage_taken: int, injected_d20: int = -1) -> bool:
	if not is_concentrating:
		return true
	var dc := maxi(10, damage_taken / 2)
	var d20 := injected_d20 if injected_d20 >= 1 else Dice.roll_d20()
	var bonus := _caster.saving_throw_bonus(SRD.Ability.CONSTITUTION)
	var maintained := d20 + bonus >= dc
	if not maintained:
		end()
	return maintained
