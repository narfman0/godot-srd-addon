## Monster Bonus Actions and Reactions from SRD 5.2.1 stat blocks, parsed from their text
## (or authored in a game's pack) into features the engine can resolve and the AI can use.
##
## SRDContent.make_monster() fills Combatant.bonus_actions / Combatant.reactions with
## feature Dictionaries:
##   name     String  "Nimble Escape", "Shadow Step", "Parry", "Vanishing Exit"
##   slot     String  "bonus" | "reaction"
##   kind     String  simple | teleport | ac_bonus | other (text only, not mechanised)
##   options  Array   simple: the actions it grants ("dash", "disengage", "hide")
##   all      bool    simple: takes every option at once ("the Dash and Disengage actions")
##   feet     int     teleport distance
##   requires String  "dim_light_or_darkness" (the game answers it), "" for none
##   rider    String  "next_attack_advantage" (Shadow Step) applied after the teleport
##   trigger  String  reactions: "hit_by_attack" | "hit_by_melee_attack" | "took_damage"
##   bloodied bool    the trigger also needs the creature Bloodied (Vanishing Exit)
##   amount   int     ac_bonus: AC added against the triggering attack (Parry)
##   condition String condition gained after the response ("invisible")
##   until_attack bool that condition also ends when it makes an attack roll
##   usage    Dictionary {per_day: n} | {recharge: min d6} | {}
##   text     String  the stat block text
## Authored keys in the row (teleport_feet, condition, requires, usage, kind, trigger...)
## override what the text parse finds.
##
##   for f in c.bonus_actions: if MonsterActions.available(c, f): MonsterActions.use(c, f)
##   var r := MonsterActions.reaction_for(c, "took_damage")
##   if not r.is_empty(): var ev := MonsterActions.use(c, r)   # ev.teleport_feet -> game moves it
##
## Space is the game's: a teleport's event carries teleport_feet and the game picks the
## destination (unoccupied, in sight, meeting `requires`).
class_name MonsterActions
extends RefCounted

const _OPTION_WORDS := ["dash", "disengage", "hide", "dodge"]

# ── Parsing ───────────────────────────────────────────────────────────────────

static func parse_all(entries: Array, slot: String) -> Array:
	var out := []
	for e in entries:
		if e is Dictionary:
			out.append(parse(e, slot))
	return out

static func parse(entry: Dictionary, slot: String) -> Dictionary:
	var name := str(entry.get("name", ""))
	var text := str(entry.get("text", ""))
	var low := text.to_lower()
	var f := {"name": _clean_name(name), "slot": slot, "kind": "other", "text": text,
		"usage": _usage(name, str(entry.get("usage", "")))}
	if slot == "reaction":
		var trig := low.get_slice("response:", 0) if "response:" in low else low
		var resp := low.get_slice("response:", 1) if "response:" in low else low
		if "takes damage" in trig:
			f["trigger"] = "took_damage"
			f["bloodied"] = "bloodied" in trig
		elif "hit by a melee attack" in trig:
			f["trigger"] = "hit_by_melee_attack"
		elif "hit by an attack" in trig:
			f["trigger"] = "hit_by_attack"
		var ac := RegEx.create_from_string("adds (\\d+) to its ac").search(resp)
		if ac:
			f["kind"] = "ac_bonus"
			f["amount"] = int(ac.get_string(1))
		_parse_teleport(resp, f)
	else:
		var simple := RegEx.create_from_string("takes the ((?:dash|disengage|hide|dodge)(?:(?:,| or| and|, or|, and) (?:the )?(?:dash|disengage|hide|dodge))*) actions?").search(low)
		if simple and not "teleport" in low:
			f["kind"] = "simple"
			var opts := []
			for w in _OPTION_WORDS:
				if w in simple.get_string(1):
					opts.append(w)
			f["options"] = opts
			f["all"] = " and " in simple.get_string(1)
		_parse_teleport(low, f)
		if "dim light or darkness" in low.get_slice(",", 0):
			f["requires"] = "dim_light_or_darkness"
	# Authored keys win over the parse
	if entry.has("teleport_feet"):
		f["kind"] = "teleport"
		f["feet"] = int(entry.teleport_feet)
	for k in ["kind", "requires", "condition", "trigger", "rider", "amount", "options", "bloodied", "until_attack"]:
		if entry.has(k):
			f[k] = entry[k]
	if entry.get("usage", null) is Dictionary:
		f["usage"] = entry.usage
	return f

static func _parse_teleport(low: String, f: Dictionary) -> void:
	var tp := RegEx.create_from_string("teleports(?: itself)?[^.]*?up to (\\d+) feet").search(low)
	if tp == null:
		return
	f["kind"] = "teleport"
	f["feet"] = int(tp.get_string(1))
	if "advantage on the next attack roll" in low:
		f["rider"] = "next_attack_advantage"
	var cond := RegEx.create_from_string("has the (\\w+) condition").search(low)
	if cond:
		f["condition"] = cond.get_string(1)
		f["until_attack"] = "until it makes an attack roll" in low

static func _clean_name(name: String) -> String:
	return name.get_slice(" (", 0).strip_edges()

static func _usage(name: String, usage: String) -> Dictionary:
	var src := (usage + " " + name).to_lower()
	var day := RegEx.create_from_string("(\\d+)/day").search(src)
	if day:
		return {"per_day": int(day.get_string(1))}
	var rech := RegEx.create_from_string("recharge ?(\\d)").search(src)
	if rech:
		return {"recharge": int(rech.get_string(1))}
	return {}

## The rider a monster's weapon action carries: "Once per turn, if the X had Advantage on
## the roll, the target takes an extra 7 (2d6) Necrotic damage." Authored as
## extra_damage: {dice, type, condition: "advantage", per_turn: 1}. Returns {} when absent.
static func parse_hit_rider(action: Dictionary) -> Dictionary:
	var ex: Variant = action.get("extra_damage")
	if ex is Dictionary and ex.has("dice"):
		return {"name": str(action.get("name", "")), "dice": str(ex.dice), "type": str(ex.get("type", "")),
			"condition": str(ex.get("condition", "")), "per_turn": int(ex.get("per_turn", 0))}
	var m := RegEx.create_from_string("(once per turn, )?if the \\w+ had advantage on the roll, the target takes an extra \\d+ \\((\\d+d\\d+)\\) (\\w+) damage") \
		.search(str(action.get("text", "")).to_lower())
	if m:
		return {"name": str(action.get("name", "")), "dice": m.get_string(2), "type": m.get_string(3),
			"condition": "advantage", "per_turn": 1 if m.get_string(1) != "" else 0}
	return {}

# ── Availability and use ──────────────────────────────────────────────────────

## Has a use left (per day / recharged) and the action-economy slot to spend.
static func available(c: Combatant, f: Dictionary) -> bool:
	if f.get("kind", "other") == "other" or c.conditions.is_incapacitated() or not c.is_alive:
		return false
	if f.slot == "bonus" and not c.action_economy.has_bonus_action:
		return false
	if f.slot == "reaction" and not c.action_economy.has_reaction:
		return false
	return uses_left(c, f) != 0

## -1 = unlimited.
static func uses_left(c: Combatant, f: Dictionary) -> int:
	var u: Dictionary = f.get("usage", {})
	var key := _key(f)
	if u.has("per_day"):
		return int(u.per_day) - int(c.monster_uses.get(key, 0))
	if u.has("recharge"):
		return 0 if c.monster_uses.get(key, 0) else 1
	return -1

## Start of the monster's turn: roll Recharge for spent features. Returns
## [{name, d20: d6 roll, recharged}] for the log.
static func start_turn(c: Combatant, fixed_d6: int = -1) -> Array:
	var out := []
	for f in c.bonus_actions + c.reactions:
		var u: Dictionary = f.get("usage", {})
		if u.has("recharge") and c.monster_uses.get(_key(f), 0):
			var r := fixed_d6 if fixed_d6 >= 1 else Dice.roll(6)
			var ok := r >= int(u.recharge)
			if ok:
				c.monster_uses.erase(_key(f))
			out.append({"name": f.name, "roll": r, "recharged": ok})
	return out

## First reaction whose trigger matches and that can be used now.
## ctx: hit_by_*: {melee: bool, total: int (attack total), crit: bool} — Parry is only taken
## when it turns the hit into a miss.
static func reaction_for(c: Combatant, trigger: String, ctx: Dictionary = {}) -> Dictionary:
	for f in c.reactions:
		if not available(c, f):
			continue
		var t := str(f.get("trigger", ""))
		match trigger:
			"took_damage":
				if t != "took_damage" or c.current_hp <= 0 or (f.get("bloodied", false) and not c.is_bloodied):
					continue
			"hit_by_attack":
				if not (t == "hit_by_attack" or (t == "hit_by_melee_attack" and ctx.get("melee", false))):
					continue
				if f.kind == "ac_bonus" and (ctx.get("crit", false) \
						or int(ctx.get("total", 0)) >= c.armor_class + int(f.get("amount", 0))):
					continue
			_:
				if t != trigger:
					continue
		return f
	return {}

## Spend the feature (action-economy slot and limited use) and apply what the engine owns.
## opts: option ("disengage" | "dash" | "hide") for simple features.
## Returns an event: {type: "monster_feature", name, kind, slot, ...} with
##   teleport_feet   the game moves the creature (and checks `requires`)
##   options         simple: the actions taken
##   ac_bonus        Parry: added until MonsterActions.attack_resolved(c)
##   condition       gained (Invisible)
static func use(c: Combatant, f: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var ev := {"type": "monster_feature", "name": f.name, "kind": f.kind, "slot": f.slot,
		"actor": c.name}
	if not available(c, f):
		ev["used"] = false
		return ev
	if f.slot == "bonus":
		c.action_economy.use_bonus_action()
	else:
		c.action_economy.use_reaction()
	var u: Dictionary = f.get("usage", {})
	if not u.is_empty():
		c.monster_uses[_key(f)] = int(c.monster_uses.get(_key(f), 0)) + 1
	ev["used"] = true
	match str(f.kind):
		"simple":
			var taken: Array = f.get("options", []) if f.get("all", false) \
				else [str(opts.get("option", f.get("options", ["disengage"])[0]))]
			for o in taken:
				match o:
					"disengage": c.turn_flags["disengaged"] = true
					"dash": c.action_economy._movement_remaining += c.speed
					"dodge": c.turn_flags["dodging"] = true
					"hide": c.turn_flags["hide_attempt"] = true  # the game rolls Stealth
			ev["options"] = taken
		"teleport":
			ev["teleport_feet"] = int(f.get("feet", 30))
			if f.get("rider", "") == "next_attack_advantage":
				c.effects.add({"id": "%s-advantage" % _key(f), "type": "next_attack_advantage", "uses": 1,
					"source": c.name, "expires": "end_of_turn", "of": c.name})
			if f.has("condition"):
				c.effects.add({"id": "%s-%s" % [_key(f), f.condition], "type": "condition",
					"condition": str(f.condition), "source": c.name, "expires": "start_of_turn",
					"of": c.name, "ends_on_attack": bool(f.get("until_attack", false))})
				ev["condition"] = str(f.condition)
		"ac_bonus":
			c.effects.add({"id": "reaction-" + _key(f), "type": "ac_bonus", "amount": int(f.amount),
				"source": c.name, "until_attack_resolved": true})
			ev["ac_bonus"] = int(f.amount)
	return ev

## The triggering attack is over: drop "against that attack" bonuses (Parry).
static func attack_resolved(c: Combatant) -> void:
	for e in c.effects.all().duplicate():
		if e.get("until_attack_resolved", false):
			c.effects.remove_id(str(e.id))

## Features the engine has no mechanics for (shown in the stat block only).
static func unmechanised(c: Combatant) -> Array:
	return (c.bonus_actions + c.reactions).filter(func(f): return f.kind == "other").map(func(f): return f.name)

static func _key(f: Dictionary) -> String:
	return str(f.get("name", "")).to_lower().replace(" ", "-")
