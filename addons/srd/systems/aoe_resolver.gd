## Grid-agnostic AoE target resolution. The game layer provides the
## positional callback; this class handles shape metadata and filtering.
##
## Usage:
##   var resolver := AoEResolver.new()
##   resolver.targets_in_shape = func(shape, ability, all): return [c1, c2]
##   var targets := resolver.resolve(caster, ability, all_combatants)
class_name AoEResolver
extends RefCounted

## Game layer implements this. Called with (shape: AoEShape, ability: AbilityData,
## all_combatants: Array[Combatant]) → Array[Combatant] inside the area.
## Override per-resolver OR set as a Callable for a one-off.
var targets_in_shape: Callable

## Resolve targets for an ability cast by caster.
## Returns an empty array for non-AoE (area_size == 0) abilities.
func resolve(caster: Combatant, ability: AbilityData,
		all_combatants: Array) -> Array:
	if ability.area_size <= 0:
		return []
	var shape := _shape_for(ability)
	if targets_in_shape.is_valid():
		var raw: Array = targets_in_shape.call(shape, ability, all_combatants)
		return raw.filter(func(c): return _include(caster, c, ability))
	return []

## Override to change which combatants in the area are valid targets.
## Default: exclude the caster; include everyone else (ally damage is legal in SRD).
func _include(_caster: Combatant, candidate: Combatant,
		_ability: AbilityData) -> bool:
	return candidate.is_active

## Override to build a custom AoEShape from ability data.
func _shape_for(ability: AbilityData) -> AoEShape:
	var s := AoEShape.new()
	s.shape = ability.area_shape
	s.primary_size = ability.area_size
	return s
