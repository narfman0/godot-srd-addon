## Timed effects on one combatant: spell buffs (Bless, Shield, Shield of Faith), riders
## (Ray of Frost, Guiding Bolt, Shocking Grasp), and weapon masteries (Sap, Slow, Vex).
##
## Each effect is a Dictionary:
##   id        String  what created it ("bless", "mastery-sap"); re-applying an id replaces it
##   type      String  ac_bonus | bonus_die | speed_penalty | no_opportunity_attacks |
##                     advantage_to_attackers | disadvantage_on_attack | advantage_vs |
##                     next_attack_advantage | immune_to_spell | condition | <custom>
##   source    String  name of the creature that created it
##   expires   String  "start_of_turn" | "end_of_turn" | "" (until removed)
##   of        String  whose turn boundary counts (a combatant name)
##   turns     int     how many of those boundaries pass before it ends (default 1)
##   uses      int     consumed by use (advantage riders); -1 = unlimited
##   concentration  String  caster name when it ends with that caster's Concentration
##   ends_on_damage bool    removed when the bearer takes damage (Sleep)
## plus type-specific keys (amount, die, applies, target, condition, spell).
##
## The combat loop calls turn_started(name) / turn_ended(name) on every combatant's
## ActiveEffects (or SRDEffects.turn_started(all, who)) so effects measured on another
## creature's turns expire on time.
class_name ActiveEffects
extends RefCounted

## Emitted when an effect is removed for any reason (expired, consumed, concentration, damage).
signal effect_removed(effect: Dictionary)

var _effects: Array[Dictionary] = []
## Back-reference so condition effects can add/remove ConditionTracker entries.
var conditions: ConditionTracker

func _init(condition_tracker: ConditionTracker = null) -> void:
	conditions = condition_tracker

func add(effect: Dictionary) -> Dictionary:
	var e := effect.duplicate(true)
	e["turns"] = int(e.get("turns", 1))
	e["uses"] = int(e.get("uses", -1))
	remove_id(str(e.get("id", "")), str(e.get("type", "")))
	_effects.append(e)
	if e.get("type") == "condition" and conditions != null:
		conditions.add(SRDEffects.condition_from(str(e.condition)))
	return e

func all() -> Array[Dictionary]:
	return _effects

func has_type(type: String) -> bool:
	return _effects.any(func(e): return e.type == type)

func has_id(id: String) -> bool:
	return _effects.any(func(e): return e.get("id", "") == id)

func of_type(type: String) -> Array:
	return _effects.filter(func(e): return e.type == type)

## Remove effects with this id (and type, if given).
func remove_id(id: String, type: String = "") -> void:
	if id == "":
		return
	for e in _effects.duplicate():
		if e.get("id", "") == id and (type == "" or e.type == type):
			_remove(e)

func clear() -> void:
	for e in _effects.duplicate():
		_remove(e)

# ── Queries ──────────────────────────────────────────────────────────────────

## Total AC bonus: distinct sources stack, the same id never twice (add() replaces).
func ac_bonus() -> int:
	var total := 0
	for e in of_type("ac_bonus"):
		total += int(e.amount)
	return total

## Die sizes added to a roll of this kind ("attack", "save", "check"), e.g. [4] for Bless.
func bonus_dice(kind: String) -> Array[int]:
	var out: Array[int] = []
	for e in of_type("bonus_die"):
		if kind in e.get("applies", []):
			out.append(SRDContent.parse_dice(str(e.die)).sides)
	return out

## Roll every bonus die that applies to a roll of this kind.
func roll_bonus(kind: String) -> int:
	var total := 0
	for sides in bonus_dice(kind):
		total += Dice.roll(sides)
	return total

## Speed reduction: different sources stack; Slow mastery caps itself at 10 by sharing an id.
func speed_penalty() -> int:
	var total := 0
	for e in of_type("speed_penalty"):
		total += int(e.amount)
	return total

func can_make_opportunity_attacks() -> bool:
	return not has_type("no_opportunity_attacks")

func is_immune_to_spell(spell_id: String) -> bool:
	return _effects.any(func(e): return e.type == "immune_to_spell" and e.get("spell", "") == spell_id)

## Use up a one-shot rider of this type, optionally matching a target name (Vex). True if one was spent.
func consume(type: String, target_name: String = "") -> bool:
	for e in _effects:
		if e.type != type:
			continue
		if target_name != "" and e.has("target") and e.target != target_name:
			continue
		if int(e.uses) > 0:
			e.uses = int(e.uses) - 1
			if e.uses == 0:
				_remove(e)
		return true
	return false

## True without spending it.
func has_rider(type: String, target_name: String = "") -> bool:
	return _effects.any(func(e): return e.type == type \
		and (target_name == "" or not e.has("target") or e.target == target_name))

# ── Expiry ───────────────────────────────────────────────────────────────────

func turn_started(who: String) -> Array:
	return _tick("start_of_turn", who)

func turn_ended(who: String) -> Array:
	return _tick("end_of_turn", who)

## The bearer took damage: end effects that break on damage (Sleep).
func took_damage() -> Array:
	var gone := _effects.filter(func(e): return e.get("ends_on_damage", false))
	for e in gone:
		_remove(e)
	return gone

## A caster's Concentration ended: remove everything it was sustaining.
func end_concentration(caster_name: String) -> Array:
	var gone := _effects.filter(func(e): return e.get("concentration", "") == caster_name)
	for e in gone:
		_remove(e)
	return gone

func _tick(boundary: String, who: String) -> Array:
	var expired := []
	for e in _effects.duplicate():
		if e.get("expires", "") == boundary and e.get("of", "") == who:
			e.turns = int(e.turns) - 1
			if e.turns <= 0:
				expired.append(e)
				_remove(e)
	return expired

func _remove(e: Dictionary) -> void:
	var i := _effects.find(e)
	if i < 0:
		return
	_effects.remove_at(i)
	if e.get("type") == "condition" and conditions != null:
		var cond := SRDEffects.condition_from(str(e.condition))
		# Keep the condition if another effect still imposes it
		if not _effects.any(func(o): return o.type == "condition" and o.condition == e.condition):
			conditions.remove(cond)
	effect_removed.emit(e)
