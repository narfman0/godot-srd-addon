## Stat-block magic: a monster's "Spellcasting" action, and its actions that force a saving
## throw (Breath Weapons, a Pummel, a Hush), both as things a game can plan and resolve like
## spells. Additive beside MonsterActions (Bonus Actions, Reactions).
##
##   var book := MonsterSpells.parse(row.actions)
##   # {ability, dc, attack, at_will: [{slug, level}], daily: [{slug, level, per_day}], in_multiattack}
##   for s in MonsterSpells.available(c): ...
##   MonsterSpells.spend(c, s)
##   var ab := MonsterSpells.make_ability(srd, c, s)   # AbilityData with the block's DC
class_name MonsterSpells
extends RefCounted

static func parse(actions: Array) -> Dictionary:
	var out := {}
	for a in actions:
		if str(a.get("name", "")) == "Spellcasting":
			out = _parse_text(str(a.get("text", "")))
	if out.is_empty():
		return out
	for a in actions:
		if str(a.get("name", "")) == "Multiattack":
			out["in_multiattack"] = "Spellcasting" in str(a.get("text", ""))
	return out

static func _parse_text(text: String) -> Dictionary:
	var out := {"at_will": [], "daily": [], "ability": SRD.Ability.INTELLIGENCE, "dc": 0, "attack": -99,
		"in_multiattack": false}
	var ab := RegEx.create_from_string("using (\\w+) as the spellcasting ability").search(text)
	if ab:
		out.ability = SRDContent.ability_from(ab.get_string(1)) as SRD.Ability
	var dc := RegEx.create_from_string("spell save DC (\\d+)").search(text)
	if dc:
		out.dc = int(dc.get_string(1))
	var hit := RegEx.create_from_string("([+-]\\d+) to hit with spell attacks").search(text)
	if hit:
		out.attack = int(hit.get_string(1))
	var head := text.find("):")
	var body := text.substr(head + 2) if head >= 0 else text
	var re := RegEx.create_from_string("(At Will|\\d+/Day(?: Each)?):\\s*")
	var marks := re.search_all(body)
	for i in marks.size():
		var m: RegExMatch = marks[i]
		var end := marks[i + 1].get_start() if i + 1 < marks.size() else body.length()
		var per_day := 0 if m.get_string(1) == "At Will" else int(m.get_string(1).get_slice("/", 0))
		for raw in _split_outside_parens(body.substr(m.get_end(), end - m.get_end())):
			var s := _spell_entry(raw)
			if s.slug == "":
				continue
			if per_day == 0:
				out.at_will.append(s)
			else:
				s["per_day"] = per_day
				out.daily.append(s)
	return out

## Commas inside a note ("Shapechange (Beast form only, no Temporary Hit Points)") don't split.
static func _split_outside_parens(text: String) -> Array:
	var out := []
	var depth := 0
	var cur := ""
	for ch in text:
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
		if ch == "," and depth == 0:
			out.append(cur)
			cur = ""
		else:
			cur += ch
	out.append(cur)
	return out

## "Fireball (level 4 version)" -> {slug: "fireball", level: 4}.
static func _spell_entry(raw: String) -> Dictionary:
	var lvl := RegEx.create_from_string("level (\\d) version").search(raw)
	var name := raw.get_slice("(", 0).strip_edges().to_lower().replace("’", "").replace("'", "")
	return {"slug": name.replace(" ", "-").replace("/", "-"), "level": int(lvl.get_string(1)) if lvl else 0}

## Spells usable now: at-will ones and daily ones with casts left.
static func available(c: Combatant) -> Array:
	var book := c.monster_spells
	if book.is_empty():
		return []
	var out: Array = book.at_will.duplicate()
	for s: Dictionary in book.daily:
		if int(c.monster_uses.get("spell:" + s.slug, 0)) < int(s.per_day):
			out.append(s)
	return out

static func spend(c: Combatant, s: Dictionary) -> void:
	if s.has("per_day"):
		c.monster_uses["spell:" + s.slug] = int(c.monster_uses.get("spell:" + s.slug, 0)) + 1

## The spell as AbilityData with the stat block's numbers. null if the pack has no such spell.
static func make_ability(srd: SRDContent, c: Combatant, s: Dictionary) -> AbilityData:
	if not srd.pack.has_row("spell", str(s.slug)):
		return null
	var ab := srd.make_spell(str(s.slug), c.monster_spells.ability as SRD.Ability)
	ab.fixed_save_dc = int(c.monster_spells.dc)
	if int(c.monster_spells.attack) > -99:
		ab.fixed_attack_bonus = int(c.monster_spells.attack)
	return ab

## Actions that are a saving throw rather than an attack roll.
## [{name, ability, dc, dice, type, half, area_shape, area_size, range, recharge, condition}]
static func parse_save_actions(actions: Array) -> Array:
	var out := []
	for a in actions:
		if a.has("attack"):
			continue
		var text := str(a.get("text", ""))
		var m := RegEx.create_from_string("(Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma) Saving Throw:\\s*DC (\\d+)").search(text)
		if m == null:
			continue
		var f := {"name": str(a.get("name", "")).get_slice(" (", 0), "ability": SRDContent.ability_from(m.get_string(1)),
			"dc": int(m.get_string(2)), "dice": "", "type": "", "half": "half damage" in text.to_lower(),
			"area_shape": "", "area_size": 0, "range": 5, "recharge": _recharge(str(a.get("name", "")) + " " + str(a.get("usage", ""))),
			"condition": "", "uses": _limited(str(a.get("name", "")) + " " + str(a.get("usage", ""))), "key": str(a.get("name", ""))}
		f["needs_grapple"] = RegEx.create_from_string("(Grappled|Charmed|Restrained|Stunned|Paralyzed) by").search(text) != null
		var d := RegEx.create_from_string("\\((\\d+d\\d+(?:\\s*[+−-]\\s*\\d+)?)\\)\\s*(\\w+) damage").search(text)
		if d:
			f.dice = d.get_string(1).replace(" ", "").replace("−", "-")
			f.type = d.get_string(2).to_lower()
		var area := RegEx.create_from_string("(\\d+)-foot(?:-radius)?\\s+(Cone|Cube|Sphere|Emanation|Cylinder)").search(text)
		var line := RegEx.create_from_string("(\\d+)-foot-long,[^.]*Line").search(text)
		if area:
			f.area_size = int(area.get_string(1))
			f.area_shape = area.get_string(2).to_lower()
		elif line:
			f.area_size = int(line.get_string(1))
			f.area_shape = "line"
		var rng := RegEx.create_from_string("within (\\d+) feet").search(text)
		if rng:
			f.range = int(rng.get_string(1))
		var c := RegEx.create_from_string("Failure:[^.]*?(\\w+) condition").search(text)
		if c:
			f.condition = c.get_string(1).to_lower()
		if f.dice != "" or f.condition != "":
			out.append(f)
	return out

## "Fire Breath (Recharge 5–6)" -> 5; 0 = no recharge.
static func _recharge(name: String) -> int:
	var m := RegEx.create_from_string("Recharge (\\d)").search(name)
	return int(m.get_string(1)) if m else 0

## "Mournful Recital (1/Day)" -> 1; 0 = unlimited.
static func _limited(name: String) -> int:
	var m := RegEx.create_from_string("(\\d)/Day").search(name)
	return int(m.get_string(1)) if m else 0

## Can this save action be used now? Tracks 1/Day uses and Recharge in c.monster_uses.
static func save_action_ready(c: Combatant, f: Dictionary) -> bool:
	var key := "save:" + str(f.key)
	if int(f.uses) > 0:
		return int(c.monster_uses.get(key, 0)) < int(f.uses)
	if int(f.recharge) > 0:
		return int(c.monster_uses.get(key, 0)) == 0
	return true

static func spend_save_action(c: Combatant, f: Dictionary) -> void:
	var key := "save:" + str(f.key)
	if int(f.uses) > 0 or int(f.recharge) > 0:
		c.monster_uses[key] = int(c.monster_uses.get(key, 0)) + 1

## Start of the monster's turn: roll Recharge for spent save actions. Returns log lines' data.
static func recharge(c: Combatant) -> Array:
	var out := []
	for f: Dictionary in c.save_actions:
		var key := "save:" + str(f.key)
		if int(f.recharge) > 0 and int(c.monster_uses.get(key, 0)) > 0:
			var roll := Dice.roll(6)
			var ok: bool = roll >= int(f.recharge)
			if ok:
				c.monster_uses.erase(key)
			out.append({"name": f.name, "roll": roll, "recharged": ok})
	return out

## A save action as AbilityData, so SpellResolver and area geometry treat it as a spell.
static func save_ability(f: Dictionary) -> AbilityData:
	var ab := AbilityData.new()
	ab.ability_name = str(f.name)
	ab.spell_id = "action-" + str(f.key).to_lower().replace(" ", "-")
	ab.slot_level = 1  # no scaling; the game doesn't spend a slot for it
	ab.uses_save = true
	ab.save_ability = int(f.ability) as SRD.Ability
	ab.fixed_save_dc = int(f.dc)
	ab.save_effect = SRD.SaveEffect.HALF if f.half else SRD.SaveEffect.NONE
	ab.range_feet = int(f.range)
	var dice := SRDContent.parse_dice(str(f.dice)) if str(f.dice) != "" else {"count": 0, "sides": 0, "bonus": 0}
	ab.damage_die_count = int(dice.count)
	ab.damage_die_sides = int(dice.sides)
	ab.damage_bonus = int(dice.bonus)
	ab.damage_type = SRDContent.damage_type_from(str(f.type))
	if int(f.area_size) > 0:
		ab.target_type = "area"
		ab.area_size = int(f.area_size)
		ab.area_shape = SRDContent._aoe_shape(str(f.area_shape))
		ab.range_feet = 0 if str(f.area_shape) in ["cone", "line", "emanation"] else maxi(ab.range_feet, 60)
	if str(f.condition) != "":
		ab.effects = [{"on": "fail", "type": "condition", "condition": f.condition,
			"expires": "end_of_turn", "of": "target", "turns": 1, "repeat_save": {"repeat": true}}]
	return ab
