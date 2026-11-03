## Helpers that drive ActiveEffects across a whole encounter.
##
##   # in the combat loop, for the creature whose turn it is:
##   SRDEffects.turn_started(all_combatants, actor)
##   ... actor's turn ...
##   var events := SRDEffects.turn_ended(all_combatants, actor)   # Sleep's repeat save, etc.
class_name SRDEffects
extends RefCounted

const _CONDITIONS := {
	"blinded": SRD.Condition.BLINDED, "charmed": SRD.Condition.CHARMED,
	"deafened": SRD.Condition.DEAFENED, "frightened": SRD.Condition.FRIGHTENED,
	"grappled": SRD.Condition.GRAPPLED, "incapacitated": SRD.Condition.INCAPACITATED,
	"invisible": SRD.Condition.INVISIBLE, "paralyzed": SRD.Condition.PARALYZED,
	"petrified": SRD.Condition.PETRIFIED, "poisoned": SRD.Condition.POISONED,
	"prone": SRD.Condition.PRONE, "restrained": SRD.Condition.RESTRAINED,
	"stunned": SRD.Condition.STUNNED, "unconscious": SRD.Condition.UNCONSCIOUS,
}

static func condition_from(key: String) -> SRD.Condition:
	return _CONDITIONS.get(key.to_lower(), SRD.Condition.INCAPACITATED)

## Start of `actor`'s turn: expire "until the start of X's next turn" effects everywhere,
## and refresh the actor's turn resources (action economy, once-per-turn features).
static func turn_started(all: Array, actor: Combatant) -> Array:
	var expired := []
	for c: Combatant in all:
		expired.append_array(c.effects.turn_started(actor.name))
	actor.action_economy.reset_turn()
	actor.action_economy._movement_remaining = actor.speed
	actor.action_economy.reset_reaction()
	actor.turn_flags.clear()
	return expired

## End of `actor`'s turn: expire effects and run repeat saves (Sleep). Returns events.
static func turn_ended(all: Array, actor: Combatant, fixed_d20: int = -1) -> Array:
	var events := []
	for c: Combatant in all:
		for e in c.effects.turn_ended(actor.name):
			if e.has("repeat_save") and c.is_alive:
				events.append(repeat_save(c, e, fixed_d20))
	return events

## Repeat a save an effect calls for when it ends; a failure applies its on_fail effect.
static func repeat_save(c: Combatant, e: Dictionary, fixed_d20: int = -1) -> Dictionary:
	var ability := SRDContent.ability_from(str(e.get("save_ability", "wis")))
	var dc := int(e.get("save_dc", 10))
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var total := d20 + c.stats.saving_throw_bonus(ability as SRD.Ability) + c.effects.roll_bonus("save")
	var saved := total >= dc
	if not saved:
		var follow: Dictionary = e.repeat_save.get("on_fail", {}).duplicate(true)
		follow["id"] = str(e.get("id", "")) + "-fail"
		follow["source"] = e.get("source", "")
		follow["of"] = e.get("caster_name", e.get("source", "")) if follow.get("of") == "caster" else c.name
		if e.has("concentration"):
			follow["concentration"] = e.concentration
		c.effects.add(follow)
	return {"type": "repeat_save", "target": c.name, "effect": e.get("id", ""),
		"d20": d20, "total": total, "dc": dc, "saved": saved}

## Concentration ended (broken, recast, or dropped): strip its effects from everyone.
static func end_concentration(all: Array, caster: Combatant) -> void:
	for c: Combatant in all:
		c.effects.end_concentration(caster.name)

## Resolve an effect template from data ({on, type, expires, of: "caster"|"target", ...})
## into a concrete effect for `bearer`.
static func instantiate(template: Dictionary, id: String, caster: Combatant, bearer: Combatant) -> Dictionary:
	var e := template.duplicate(true)
	e.erase("on")
	e["id"] = id
	e["source"] = caster.name
	e["caster_name"] = caster.name
	match str(e.get("of", "")):
		"caster": e["of"] = caster.name
		"target": e["of"] = bearer.name
	return e
