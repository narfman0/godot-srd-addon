## Level-ups under SRD 5.2.1: what a level grants, what must be chosen, and the build those
## choices add up to. Plain data throughout, so a game can save it as-is.
##
##   SRDProgression.summary(srd, "wizard", 5, "evoker", 2)  # what level 5 gives
##   SRDProgression.choices(srd, build, 5)                  # the choices level 5 asks for
##   build.choices["5"] = {"cantrips": [...], "spells": [...]}
##   var r := SRDProgression.resolve(srd, build, 5)         # scores, options, spells at level 5
##   srd.make_character(name, cls, 5, r.scores, weapon, armor, shield, skills, "", r.options)
##
## build: {class, scores: [STR..CHA], skills, spells?: seed list, choices: {"<level>": {<id>: [...]}}}
class_name SRDProgression
extends RefCounted

const ABILITIES := ["str", "dex", "con", "int", "wis", "cha"]
const SCORE_CAP := 20
const STYLES := ["archery", "defense", "great-weapon-fighting", "two-weapon-fighting"]
## Feats the engine can apply at an ASI level (others in the pack are Epic Boons, Fighting Styles).
const ASI_FEATS := ["ability-score-improvement", "alert", "savage-attacker", "skilled", "grappler"]
const DAMAGE_AFFINITY := ["acid", "cold", "fire", "lightning", "poison"]
const RESIST_ALL := ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic",
	"piercing", "poison", "psychic", "radiant", "slashing", "thunder"]

## Everything a level grants, for the level-up screen.
static func summary(srd: SRDContent, class_slug: String, level: int, subclass: String, con_mod: int) -> Dictionary:
	var cd := srd.make_class(class_slug)
	var row := srd.class_table_row(class_slug, level)
	var prev := srd.class_table_row(class_slug, level - 1)
	var feats := []
	for f in srd.features_gained_at(class_slug, level, subclass):
		feats.append({"slug": f.slug, "name": f.name, "text": str(f.data.get("text", ""))})
	var before := cd.make_slots(level - 1)
	var after := cd.make_slots(level)
	var slots := []
	for i in 9:
		if after.slots_max[i] > before.slots_max[i]:
			slots.append({"level": i + 1, "gain": after.slots_max[i] - before.slots_max[i]})
	var columns := {}
	for k in row:
		if k in ["level", "features", "proficiency_bonus"] or str(k).begins_with("slot_"):
			continue
		if row[k] != prev.get(k):
			columns[k] = row[k]
	return {"level": level, "hp_gain": maxi(1, cd.hit_die / 2 + 1 + con_mod),
		"proficiency_bonus": int(row.get("proficiency_bonus", 2)),
		"pb_up": int(row.get("proficiency_bonus", 2)) > int(prev.get("proficiency_bonus", 2)),
		"features": feats, "slots_gained": slots, "columns": columns}

## Highest spell level the class can cast at a character level (Warlock: Pact slots).
static func max_spell_level(srd: SRDContent, class_slug: String, level: int) -> int:
	var slots := srd.make_class(class_slug).make_slots(level)
	for i in range(8, -1, -1):
		if slots.slots_max[i] > 0:
			return i + 1
	return 0

## Every option list a level asks for, given what the build already holds below that level.
## Each: {id, kind, label, count, options: [{id, name, text, modelled?}], text?}. kind "asi"
## answers are [feat, ...details]; other answers are `count` option ids.
static func choices(srd: SRDContent, build: Dictionary, level: int) -> Array:
	var cls := str(build["class"])
	var out := []
	var row := srd.class_table_row(cls, level)
	var prev := srd.class_table_row(cls, level - 1)
	var r := resolve(srd, build, level - 1)
	var subclass := str(r.options.get("subclass", _subclass(srd, cls)))
	var gained := srd.features_gained_at(cls, level, subclass).map(func(f): return str(f.slug))
	var has := func(key: String) -> bool:
		return gained.any(func(s): return s.ends_with("-" + key))
	if has.call("ability-score-improvement"):
		out.append({"id": "asi", "kind": "asi", "label": "Ability Score Improvement or Feat", "count": 1,
			"options": _asi_options(srd)})
	if has.call("additional-fighting-style"):
		out.append(_pick("fighting_style_2", "Additional Fighting Style", 1,
			STYLES.filter(func(s): return s != str(r.options.get("fighting_style", "defense"))).map(_style_option.bind(srd))))
	var mastery_gain := srd.weapon_mastery_count(cls, level) - srd.weapon_mastery_count(cls, level - 1)
	if mastery_gain > 0:
		var held: Array = r.options.get("weapon_masteries", [])
		var opts := []
		for slug in srd.pack.slugs("weapon"):
			if not slug in held and srd.pack.get_row("weapon", slug).data.get("mastery", "") != "":
				var w: Dictionary = srd.pack.get_row("weapon", slug)
				opts.append({"id": slug, "name": w.name, "text": "Mastery: %s" % str(w.data.mastery).capitalize()})
		out.append(_pick("weapon_mastery", "Weapon Mastery", mastery_gain, opts))
	if has.call("expertise") and level > 1:
		var known: Array = r.options.get("expertise", [])
		var skills: Array = build.get("skills", []).duplicate()
		skills.append_array(r.options.get("extra_skills", []))
		var opts := skills.filter(func(s): return not s in known) \
			.map(func(s): return {"id": s, "name": str(s).replace("-", " ").capitalize(), "text": "Double your Proficiency Bonus."})
		out.append(_pick("expertise", "Expertise", mini(2, opts.size()), opts))
	if row.has("cantrips") and int(row.cantrips) > int(prev.get("cantrips", 0)):
		out.append(_spell_choice(srd, "cantrips", "New Cantrips", int(row.cantrips) - int(prev.get("cantrips", 0)),
			_lists(cls, level, r), 0, 0, r.spells))
	if row.has("prepared_spells") and int(row.prepared_spells) > int(prev.get("prepared_spells", 0)):
		out.append(_spell_choice(srd, "spells", "New Prepared Spells", int(row.prepared_spells) - int(prev.get("prepared_spells", 0)),
			_lists(cls, level, r), 1, max_spell_level(srd, cls, level), r.spells))
	if has.call("magical-discoveries"):
		out.append(_spell_choice(srd, "discoveries", "Magical Discoveries", 2, ["cleric", "druid", "wizard"],
			0, max_spell_level(srd, cls, level), r.spells))
	if has.call("blessed-strikes"):
		out.append(_pick("blessed_strikes", "Blessed Strikes", 1, [
			{"id": "divine-strike", "name": "Divine Strike", "text": "Once per turn, a weapon hit deals an extra 1d8 Radiant or Necrotic damage."},
			{"id": "potent-spellcasting", "name": "Potent Spellcasting", "text": "Add your Wisdom modifier to your Cleric cantrips' damage."}]))
	if has.call("elemental-fury"):
		out.append(_pick("elemental_fury", "Elemental Fury", 1, [
			{"id": "potent-spellcasting", "name": "Potent Spellcasting", "text": "Add your Wisdom modifier to your Druid cantrips' damage."},
			{"id": "primal-strike", "name": "Primal Strike", "text": "Once per turn, a weapon hit deals an extra 1d8 elemental damage."}]))
	if has.call("defensive-tactics"):
		out.append(_pick("defensive_tactics", "Defensive Tactics", 1, [
			{"id": "escape-the-horde", "name": "Escape the Horde", "text": "Opportunity Attacks have Disadvantage against you."},
			{"id": "multiattack-defense", "name": "Multiattack Defense", "text": "A creature that hits you has Disadvantage on its other attacks against you this turn.", "modelled": false}]))
	if has.call("elemental-affinity"):
		out.append(_pick("elemental_affinity", "Elemental Affinity", 1, DAMAGE_AFFINITY.map(func(t):
			return {"id": t, "name": t.capitalize(), "text": "Resistance, and your Charisma modifier on one damage roll of a %s spell." % t})))
	if has.call("natures-ward"):
		out.append(_pick("natures_ward", "Nature's Ward", 1, ["cold", "fire", "lightning", "poison"].map(func(t):
			return {"id": t, "name": t.capitalize(), "text": "Resistance to %s damage." % t})))
	if has.call("fiendish-resilience"):
		out.append(_pick("fiendish_resilience", "Fiendish Resilience", 1, RESIST_ALL.filter(func(t): return t != "force").map(func(t):
			return {"id": t, "name": t.capitalize(), "text": "Resistance to %s damage until you change it on a rest." % t})))
	if row.has("eldritch_invocations") and int(row.eldritch_invocations) > int(prev.get("eldritch_invocations", 0)):
		out.append(_pick("invocations", "Eldritch Invocations", int(row.eldritch_invocations) - int(prev.get("eldritch_invocations", 0)),
			_invocations(srd, level, r)))
	if cls == "sorcerer" and level in [10, 17]:
		var held: Array = r.options.get("metamagic", [])
		var opts := []
		for o in srd.pack.rows("class_option"):
			if o.data["class"] == "sorcerer" and not o.slug in held:
				opts.append({"id": o.slug, "name": o.name, "text": "%d SP. %s" % [int(o.data.get("cost", 1)), str(o.data.text).left(160)],
					"modelled": str(o.slug).trim_prefix("sorcerer-").trim_suffix("-spell") in ["quickened", "empowered", "careful", "distant"]})
		out.append(_pick("metamagic", "Metamagic", 2, opts))
	if cls == "warlock" and level in [11, 13, 15, 17]:
		var sl: int = {11: 6, 13: 7, 15: 8, 17: 9}[level]
		out.append(_spell_choice(srd, "arcanum", "Mystic Arcanum (level %d)" % sl, 1, ["warlock"], sl, sl, r.spells))
	return out

static func _subclass(srd: SRDContent, cls: String) -> String:
	var subs := srd.subclass_slugs(cls)
	return subs[0] if not subs.is_empty() else ""

static func _lists(cls: String, level: int, r: Dictionary) -> Array:
	# Magical Secrets (Bard 10): the Bard's picks may come from three more lists
	if cls == "bard" and level >= 10:
		return ["bard", "cleric", "druid", "wizard"]
	return [cls]

static func _pick(id: String, label: String, count: int, options: Array) -> Dictionary:
	return {"id": id, "kind": "pick", "label": label, "count": count, "options": options}

static func _style_option(style: String, srd: SRDContent) -> Dictionary:
	var row := srd.pack.get_row("feat", style)
	return {"id": style, "name": row.get("name", style), "text": str(row.get("data", {}).get("text", ""))}

static func _asi_options(srd: SRDContent) -> Array:
	var out := []
	for slug in ASI_FEATS:
		var row := srd.pack.get_row("feat", slug)
		if not row.is_empty():
			out.append({"id": slug, "name": row.name, "text": str(row.data.text).left(240)})
	return out

static func _invocations(srd: SRDContent, level: int, r: Dictionary) -> Array:
	var held: Array = r.options.get("invocations", [])
	var out := []
	for o in srd.pack.rows("class_option"):
		if o.data["class"] != "warlock" or o.slug in held:
			continue
		var pre := str(o.data.get("prerequisite", ""))
		var m := RegEx.create_from_string("Level (\\d+)\\+").search(pre)
		if m and int(m.get_string(1)) > level:
			continue
		if "Pact of the" in pre and not held.any(func(h): return str(h).begins_with("warlock-pact-of-the")):
			continue
		out.append({"id": o.slug, "name": o.name, "text": str(o.data.text).left(200),
			"modelled": str(o.slug) in ["warlock-agonizing-blast", "warlock-eldritch-mind"]})
	return out

static func _spell_choice(srd: SRDContent, id: String, label: String, count: int, lists: Array,
		lo: int, hi: int, known: Array) -> Dictionary:
	var opts := []
	var seen := {}
	for cls in lists:
		for lvl in range(lo, hi + 1):
			for slug in srd.class_spell_slugs(str(cls), lvl):
				if seen.has(slug) or slug in known:
					continue
				seen[slug] = true
				var row := srd.pack.get_row("spell", slug)
				opts.append({"id": slug, "name": row.name, "level": lvl, "text": str(row.data.get("text", "")).left(200),
					"modelled": srd.spell_has_mechanics(slug)})
	opts.sort_custom(func(a, b): return a.level > b.level if a.level != b.level else a.name < b.name)
	return {"id": id, "kind": "spell", "label": label, "count": count, "options": opts}

## The whole build at a level: {scores, options (for make_character), spells, feats}.
static func resolve(srd: SRDContent, build: Dictionary, level: int) -> Dictionary:
	var scores: Array = build.get("scores", [10, 10, 10, 10, 10, 10]).duplicate()
	var options: Dictionary = build.get("options", {}).duplicate(true)
	var spells: Array = build.get("spells", build.get("seed_spells", [])).duplicate()
	var feats: Array = []
	var picks: Dictionary = build.get("choices", {})
	var levels := picks.keys().map(func(k): return int(k))
	levels.sort()
	for lvl: int in levels:
		if lvl > level:
			continue
		var answers: Dictionary = picks[str(lvl)]
		for id: String in answers:
			var a: Array = answers[id]
			match id:
				"asi":
					_apply_asi(a, scores, feats, options)
				"fighting_style_2", "blessed_strikes", "elemental_fury", "defensive_tactics", \
						"elemental_affinity", "natures_ward", "fiendish_resilience":
					if not a.is_empty():
						options[id] = a[0]
				"weapon_mastery":
					_append(options, "weapon_masteries", a)
				"expertise":
					_append(options, "expertise", a)
				"invocations", "metamagic":
					_append(options, id, a)
				"cantrips", "spells", "discoveries":
					spells.append_array(a.filter(func(s): return not s in spells))
				"arcanum":
					spells.append_array(a.filter(func(s): return not s in spells))
					_append(options, "arcana", a)
	options["feats"] = feats
	return {"scores": scores, "options": options, "spells": spells, "feats": feats}

static func _append(options: Dictionary, key: String, values: Array) -> void:
	var cur: Array = options.get(key, [])
	for v in values:
		if not v in cur:
			cur.append(v)
	options[key] = cur

static func _apply_asi(a: Array, scores: Array, feats: Array, options: Dictionary) -> void:
	if a.is_empty():
		return
	var feat := str(a[0])
	feats.append(feat)
	match feat:
		"ability-score-improvement":
			for ab in a.slice(1):  # two names: +1 each, or the same one twice: +2
				_raise(scores, str(ab))
		"grappler":
			_raise(scores, str(a[1]) if a.size() > 1 else "str")
		"skilled":
			_append(options, "extra_skills", a.slice(1))

static func _raise(scores: Array, ability: String) -> void:
	var i := ABILITIES.find(ability)
	if i >= 0 and int(scores[i]) < SCORE_CAP:
		scores[i] = int(scores[i]) + 1

## Fill in a choice from a preference list. prefs: {asi: ["int", "con", ...], spells: [...],
## cantrips: [...], <id>: [...]}: the first available options win, then the list's order, with
## options the engine models first. Returns the answer Array.
static func auto_answer(choice: Dictionary, prefs: Dictionary, scores: Array) -> Array:
	if choice.kind == "asi":
		var order: Array = prefs.get("asi", ABILITIES)
		var out := ["ability-score-improvement"]
		var virtual := scores.duplicate()
		for _i in 2:
			for ab in order:
				var i := ABILITIES.find(str(ab))
				if i >= 0 and int(virtual[i]) < SCORE_CAP:
					virtual[i] = int(virtual[i]) + 1
					out.append(str(ab))
					break
		return out
	var want: Array = prefs.get(choice.id, [])
	var ids: Array = choice.options.map(func(o): return o.id)
	var out := []
	if choice.kind == "spell":  # the strongest listed spell this level opens up comes first
		var level_of := {}
		for o in choice.options:
			level_of[o.id] = int(o.level)
		want = want.duplicate()
		want.sort_custom(func(a, b): return int(level_of.get(a, -1)) > int(level_of.get(b, -1)))
	for p in want:
		if p in ids and not p in out and out.size() < int(choice.count):
			out.append(p)
	for o in choice.options:
		if out.size() < int(choice.count) and o.get("modelled", true) and not o.id in out:
			out.append(o.id)
	for o in choice.options:
		if out.size() < int(choice.count) and not o.id in out:
			out.append(o.id)
	return out
