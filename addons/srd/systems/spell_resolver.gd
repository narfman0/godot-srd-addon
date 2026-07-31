## Resolves spell/ability effects against one or more targets.
##
## Designed for subclassing — the game extends this class to override any step:
##
##   class MyResolver extends SpellResolver:
##       func roll_damage(ability, caster_level, cast_at_level) -> int:
##           var base := super.roll_damage(ability, caster_level, cast_at_level)
##           return base + my_bonus  # e.g. empowered spell
##
##       func after_cast(caster, ability, events) -> void:
##           vfx_system.play(ability.ability_name)
##
## All virtual methods are prefixed with nothing special — just override them.
class_name SpellResolver
extends RefCounted

## Cast an ability against an array of resolved targets.
## Caller is responsible for slot consumption and AoE target resolution.
## Returns Array of event Dicts (one per target); see _make_event() for keys.
func cast(caster: Combatant, ability: AbilityData, targets: Array,
		cast_at_level: int = -1,
		concentration: ConcentrationTracker = null) -> Array:
	var events: Array = []

	if not before_cast(caster, ability, targets):
		return events

	if ability.concentration and concentration != null:
		concentration.begin(caster.stats, ability)

	var level := cast_at_level if cast_at_level >= ability.slot_level else ability.slot_level

	for target: Combatant in targets:
		var ev := {}
		if ability.uses_save:
			ev = _resolve_save_spell(caster, ability, target, level)
		else:
			ev = _resolve_attack_spell(caster, ability, target, level)
		events.append(ev)

	after_cast(caster, ability, events)
	return events

# ── Virtual hooks — override in the game layer ──────────────────────────────

## Called before any effects are applied. Return false to cancel the cast.
func before_cast(_caster: Combatant, _ability: AbilityData,
		_targets: Array) -> bool:
	return true

## Roll the saving throw. Override to add situational bonuses/penalties.
func resolve_save(target: CharacterStats, dc: int,
		save_ability: SRD.Ability, fixed_d20: int = -1) -> bool:
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	return d20 + target.saving_throw_bonus(save_ability) >= dc

## Roll spell damage. Override for meta-magic (Empowered, Maximise, etc.).
func roll_damage(ability: AbilityData, caster_level: int,
		cast_at_level: int) -> int:
	return ability.roll_damage(caster_level, cast_at_level)

## Apply damage to a target. Override for reactions, immunities, etc.
func apply_damage(target: Combatant, amount: int,
		damage_type: SRD.DamageType) -> int:
	return DamageResolver.apply(target.stats, amount, damage_type)

## Apply a condition to a target. Override to trigger animations or log.
func apply_condition(target: Combatant, condition: SRD.Condition) -> void:
	target.conditions.add(condition)

## Called after all targets have been processed.
func after_cast(_caster: Combatant, _ability: AbilityData,
		_events: Array) -> void:
	pass

# ── Internal resolution ──────────────────────────────────────────────────────

func _resolve_save_spell(caster: Combatant, ability: AbilityData,
		target: Combatant, cast_at_level: int,
		fixed_d20: int = -1) -> Dictionary:
	var dc := ability.spell_save_dc(caster.stats)
	var saved := resolve_save(target.stats, dc, ability.save_ability, fixed_d20)
	var raw_dmg := roll_damage(ability, caster.stats.level, cast_at_level)
	var dmg := _apply_save_effect(raw_dmg, saved, ability.save_effect)
	var dealt := 0
	if dmg > 0:
		dealt = apply_damage(target, dmg, ability.damage_type)
	return {
		"type": "spell_save",
		"ability": ability.ability_name,
		"target": target.name,
		"dc": dc,
		"saved": saved,
		"damage_rolled": dmg,
		"damage_dealt": dealt,
		"target_hp_after": target.stats.current_hp,
	}

func _resolve_attack_spell(caster: Combatant, ability: AbilityData,
		target: Combatant, cast_at_level: int,
		fixed_d20: int = -1) -> Dictionary:
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var atk_bonus := ability.spell_attack_bonus(caster.stats)
	var crit := SRDRules.is_critical_hit(d20)
	var miss := SRDRules.is_critical_miss(d20)
	var hit := crit or (not miss and SRDRules.attack_hits(d20, atk_bonus, target.armor_class))
	var dmg := 0; var dealt := 0
	if hit:
		dmg = roll_damage(ability, caster.stats.level, cast_at_level)
		if crit:
			dmg += roll_damage(ability, caster.stats.level, cast_at_level)
		dealt = apply_damage(target, dmg, ability.damage_type)
	return {
		"type": "spell_attack",
		"ability": ability.ability_name,
		"target": target.name,
		"d20": d20, "hit": hit, "crit": crit,
		"damage_rolled": dmg,
		"damage_dealt": dealt,
		"target_hp_after": target.stats.current_hp,
	}

func _apply_save_effect(dmg: int, saved: bool,
		effect: SRD.SaveEffect) -> int:
	if not saved:
		return dmg
	match effect:
		SRD.SaveEffect.HALF: return dmg / 2
		SRD.SaveEffect.NONE: return 0
	return dmg
