## Builds the addon's runtime resources (ClassData, WeaponData, ArmorData, AbilityData,
## monster Combatants) from rows extracted from the SRD 5.2.1 PDF (tools/extract_srd.py).
##
##   var srd := SRDContent.new()          # loads res://addons/srd/data/srd-5.2.1
##   var wizard := srd.make_class("wizard")
##   var goblin := srd.make_monster("goblin-warrior", 1)
##   var fireball := srd.make_spell("fireball", SRD.Ability.INTELLIGENCE)
class_name SRDContent
extends RefCounted

## Tag on AbilityData whose spell has effects AbilityData can't express yet (several
## damage parts, or a rider its text describes that extraction didn't capture). The dice
## it does carry are correct.
const TAG_PARTIAL := "partial"
## Tag on AbilityData for spells with no damage, healing, or effect detected: utility
## spells, or mechanics the extractor's heuristics miss. They need hand-authored effects.
const TAG_NO_MECHANICS := "no_mechanics"

var pack: SRDContentPack

func _init(content_pack: SRDContentPack = null) -> void:
	pack = content_pack if content_pack != null else SRDContentPack.load_default()

# ── Classes ───────────────────────────────────────────────────────────────────

func make_class(slug: String) -> ClassData:
	var row := _require("class", slug)
	if row.is_empty():
		return null
	var d: Dictionary = row.data
	var c := ClassData.new()
	c.class_name_str = row.name
	c.hit_die = int(d.get("hit_die", 8))
	c.save_proficiencies.assign(_abilities(d.get("saves", [])))
	for a in SRD.ABILITY_NAMES:
		if a in str(d.get("primary_ability", "")):
			c.primary_abilities.append(SRD.ABILITY_NAMES.find(a))
	var skills: Dictionary = d.get("skill_choices", {})
	c.skill_choices_count = int(skills.get("count", 2))
	for s in skills.get("options", []):
		if s == "any":
			for i in SRD.Skill.size():
				c.skill_options.append(i)
		elif skill_from(s) >= 0:
			c.skill_options.append(skill_from(s))
	var armor := str(d.get("armor_training", ""))
	for kind in ["Light", "Medium", "Heavy"]:
		if kind in armor:
			c.armor_proficiencies.append(kind.to_lower())
	if "Shield" in armor:
		c.armor_proficiencies.append("shield")
	c.weapon_proficiencies.assign(_weapon_proficiency_keys(str(d.get("weapon_proficiencies", ""))))
	var casting: Variant = d.get("spellcasting")
	c.slot_progression = _progression(casting.get("progression", "") if casting is Dictionary else "")
	for r in d.get("table", []):
		if r.has("slot_1"):
			var counts := []
			for i in range(1, 10):
				counts.append(int(r.get("slot_%d" % i, 0)))
			c.slot_table.append(counts)
	return c

## SRD.Ability the class casts with, or -1 for non-casters.
func spellcasting_ability(class_slug: String) -> int:
	var casting: Variant = _require("class", class_slug).get("data", {}).get("spellcasting")
	return ability_from(casting.get("ability", "")) if casting is Dictionary else -1

## "Simple and Martial weapons" -> ["simple", "martial"]; restricted martial access becomes
## "martial-light" (Monk) or "martial-finesse-or-light" (Rogue).
static func _weapon_proficiency_keys(text: String) -> Array:
	var out := []
	if "Simple" in text:
		out.append("simple")
	if "Martial weapons that have the Finesse or Light" in text:
		out.append("martial-finesse-or-light")
	elif "Martial weapons that have the Light" in text:
		out.append("martial-light")
	elif "Martial" in text:
		out.append("martial")
	return out

## Build a player character: level-1 max HP from the hit die, average HP per level after,
## class save proficiencies, spell slots from the class table, gear, and a ClassKit with the
## features, resources, and Weapon Mastery choices for the level. scores are STR..CHA in
## order; skills are skill slugs ("arcana", "sleight-of-hand") the player picked.
##
## subclass: subclass slug; empty picks the class's SRD subclass from level 3.
## options: fighting_style ("defense" | "archery" | "great-weapon-fighting" |
##   "two-weapon-fighting"; Fighter default "defense"), divine_order ("protector" |
##   "thaumaturge"; default "protector"), blessed_strikes ("divine-strike" |
##   "potent-spellcasting"), weapon_masteries (weapon slugs; default the wielded weapon),
##   expertise (skill slugs; Rogue default Stealth and Sleight of Hand when proficient).
func make_character(char_name: String, class_slug: String, level: int, scores: Array,
		weapon_slug: String = "", armor_slug: String = "", shield: bool = false,
		skills: Array = [], subclass: String = "", options: Dictionary = {}) -> Combatant:
	var class_data := make_class(class_slug)
	if class_data == null:
		return null
	level = clampi(level, 1, 20)
	var s := CharacterStats.new()
	s.character_name = char_name
	for i in mini(scores.size(), 6):
		s.set_ability(i as SRD.Ability, int(scores[i]))
	s.hit_die = class_data.hit_die
	s.max_hp = class_data.starting_hp(s.ability_modifier(SRD.Ability.CONSTITUTION))
	SRDLevelUp.apply_class_proficiencies(s, class_data)
	for skill_slug in skills:
		var skill := skill_from(skill_slug)
		if skill >= 0:
			s.set_skill_proficiency(skill as SRD.Skill, true)
	var slots := class_data.make_slots(1)
	for _l in range(1, level):
		SRDLevelUp.level_up(s, class_data, slots)
	s.reset()

	var kit := make_kit(class_slug, level, subclass, options)
	# Divine Order: Protector adds Martial weapons and Heavy armor training
	if kit.has_feature("divine-order") and kit.options.get("divine_order") == "protector":
		if not "martial" in class_data.weapon_proficiencies:
			class_data.weapon_proficiencies.append("martial")
		if not "heavy" in class_data.armor_proficiencies:
			class_data.armor_proficiencies.append("heavy")
	if kit.has_feature("expertise"):
		var picks: Array = options.get("expertise", [])
		if picks.is_empty():
			for k in ["stealth", "sleight-of-hand"] + skills:
				if picks.size() < 2 and k in skills and not k in picks:
					picks.append(k)
		for k in picks:
			if skill_from(k) >= 0 and s.is_skill_proficient(skill_from(k) as SRD.Skill):
				s.set_skill_proficiency(skill_from(k) as SRD.Skill, true, true)

	var eq := EquipmentSlots.new()
	if armor_slug != "":
		eq.equip_armor(make_armor(armor_slug))
	if shield:
		eq.equip_shield(make_armor("shield"))
	var weapon := make_weapon(weapon_slug) if weapon_slug != "" else null
	var c := Combatant.new(s, weapon, eq)
	c.energy_slots = slots
	c.is_proficient_with_weapon = weapon == null or is_weapon_proficient(class_data, weapon)
	var masteries: Array = options.get("weapon_masteries", [])
	if masteries.is_empty() and weapon_slug != "":
		masteries = [weapon_slug]
	for m in masteries.slice(0, weapon_mastery_count(class_slug, level)):
		kit.weapon_masteries.append(str(m))
	c.kit = kit
	return c

## The ClassKit for a class at a level: features (class + subclass), the class table row,
## build options with SRD-recommended defaults, and limited-use resources.
func make_kit(class_slug: String, level: int, subclass: String = "", options: Dictionary = {}) -> ClassKit:
	var kit := ClassKit.new()
	kit.class_slug = class_slug
	kit.level = clampi(level, 1, 20)
	if subclass == "" and kit.level >= 3:
		var subs := subclass_slugs(class_slug)
		subclass = subs[0] if not subs.is_empty() else ""
	kit.subclass_slug = subclass if kit.level >= 3 else ""
	kit.features = features_at(class_slug, kit.level, kit.subclass_slug)
	kit.table_row = class_table_row(class_slug, kit.level)
	kit.casting_ability = spellcasting_ability(class_slug)
	kit.options = options.duplicate()
	if class_slug == "fighter":
		kit.options.merge({"fighting_style": "defense"})  # "Defense is recommended"
	if class_slug == "cleric":
		kit.options.merge({"divine_order": "protector", "blessed_strikes": "potent-spellcasting"})
	var t := kit.table_row
	match class_slug:
		"fighter":
			kit.add_resource("second_wind", int(t.get("second_wind", 0)), "one")
			kit.add_resource("action_surge", 2 if kit.level >= 17 else (1 if kit.level >= 2 else 0), "all")
			kit.add_resource("indomitable", 3 if kit.level >= 17 else (2 if kit.level >= 13 else (1 if kit.level >= 9 else 0)))
		"cleric", "paladin":
			kit.add_resource("channel_divinity", int(t.get("channel_divinity", 0)), "one")
		"wizard":
			kit.add_resource("arcane_recovery", 1)
		"barbarian":
			kit.add_resource("rage", int(t.get("rages", 0)), "one")
		"monk":
			kit.add_resource("focus_points", int(t.get("focus_points", 0)), "all")
		"sorcerer":
			kit.add_resource("sorcery_points", int(t.get("sorcery_points", 0)))
		"druid":
			kit.add_resource("wild_shape", int(t.get("wild_shape", 0)), "one")
	if class_slug == "paladin":
		kit.add_resource("lay_on_hands", 5 * kit.level)
	return kit

# ── Class features ────────────────────────────────────────────────────────────

## Feature rows a character of this class has at `level` (cumulative, level order), with
## the subclass's features from level 3. Each row: {slug, name, data: {class, subclass,
## level, levels, feature, text, entries?}}.
func features_at(class_slug: String, level: int, subclass: String = "") -> Array:
	var held := pack.rows("feature").filter(func(r): return r.data["class"] == class_slug \
		and int(r.data.level) <= level and (r.data.subclass == "" or r.data.subclass == subclass))
	# Level order, class before subclass, then the PDF's order (rows load in that order)
	var out := []
	for lvl in range(1, level + 1):
		for sub in [false, true]:
			for r in held:
				if int(r.data.level) == lvl and (r.data.subclass != "") == sub:
					out.append(r)
	return out

## Feature rows gained exactly at `level` (the class table's Class Features column, resolved).
func features_gained_at(class_slug: String, level: int, subclass: String = "") -> Array:
	return features_at(class_slug, level, subclass).filter(func(r): \
		return r.data.get("levels", [r.data.level]).any(func(l): return int(l) == level))

## The class table row for a level: {level, proficiency_bonus, features, <columns>}.
func class_table_row(class_slug: String, level: int) -> Dictionary:
	for r in pack.get_row("class", class_slug).get("data", {}).get("table", []):
		if int(r.level) == level:
			return r
	return {}

func subclass_slugs(class_slug: String) -> Array:
	var out := []
	for r in pack.rows("subclass"):
		if r.data["class"] == class_slug:
			out.append(r.slug)
	out.sort()
	return out

func subclass_row(slug: String) -> Dictionary:
	return pack.get_row("subclass", slug)

## Kinds of weapons whose mastery the class can use at a level: the table's Weapon Mastery
## column (Barbarian, Fighter), or the count in the Weapon Mastery feature text.
func weapon_mastery_count(class_slug: String, level: int) -> int:
	var t := class_table_row(class_slug, level)
	if t.has("weapon_mastery"):
		return int(t.weapon_mastery)
	var row := pack.get_row("feature", class_slug + "-weapon-mastery")
	if row.is_empty() or int(row.data.level) > level:
		return 0
	var words := {"one": 1, "two": 2, "three": 3, "four": 4}
	var m := RegEx.create_from_string("mastery properties of (\\w+) kinds").search(str(row.data.text))
	return int(words.get(m.get_string(1), 0)) if m else 0

## Spells a subclass always has prepared at a class level (Life Domain Spells...).
## For Circle of the Land, pass land: "arid" | "polar" | "temperate" | "tropical".
func subclass_spells(subclass: String, level: int, land: String = "") -> Array:
	var out := []
	for r in pack.rows("feature"):
		if r.data.subclass != subclass or not r.data.has("prepared_spells"):
			continue
		var table: Dictionary = r.data.prepared_spells
		if land != "":
			table = table.get(land, {})
		for lvl in table:
			if int(lvl) <= level and table[lvl] is Array:
				out.append_array(table[lvl])
	return out

## Weapon property and mastery rules text ({mastery: bool, text}).
func weapon_property(slug: String) -> Dictionary:
	return pack.get_row("weapon_property", slug)

## Class weapon proficiency, including the SRD's restricted martial categories (Monk, Rogue).
static func is_weapon_proficient(class_data: ClassData, weapon: WeaponData) -> bool:
	var profs := class_data.weapon_proficiencies
	if weapon.weapon_type == SRD.WeaponType.SIMPLE:
		return "simple" in profs
	if "martial" in profs:
		return true
	var light := weapon.has_property(SRD.WeaponProperty.LIGHT)
	var finesse := weapon.has_property(SRD.WeaponProperty.FINESSE)
	if "martial-light" in profs:
		return light  # Monk: "Martial weapons that have the Light property"
	if "martial-finesse-or-light" in profs:
		return light or finesse
	return false

# ── Equipment ─────────────────────────────────────────────────────────────────

func make_weapon(slug: String) -> WeaponData:
	var row := _require("weapon", slug)
	if row.is_empty():
		return null
	var d: Dictionary = row.data
	var w := WeaponData.new()
	w.weapon_name = row.name
	w.slug = slug
	w.mastery = str(d.get("mastery", ""))
	w.weapon_type = SRD.WeaponType.MARTIAL if str(d.category).begins_with("martial") \
		else SRD.WeaponType.SIMPLE
	w.properties = _weapon_properties(d.get("properties", []))
	var dmg := parse_dice(str(d.get("damage", "")))
	w.die_count = dmg.count; w.die_sides = dmg.sides
	w.damage_type = damage_type_from(str(d.get("damage_type", "")))
	if d.has("versatile"):
		var vd := parse_dice(d.versatile)
		w.versatile_die_count = vd.count; w.versatile_die_sides = vd.sides
	# Thrown melee weapons keep melee reach so they still attack with STR
	if str(d.category).ends_with("ranged") and d.has("range"):
		w.range_normal = int(d.range[0]); w.range_long = int(d.range[1])
	return w

func make_armor(slug: String) -> ArmorData:
	var row := _require("armor", slug)
	if row.is_empty():
		return null
	var d: Dictionary = row.data
	var a := ArmorData.new()
	a.armor_name = row.name
	a.armor_type = _armor_type(str(d.get("type", "light")))
	a.base_ac = int(d.get("base_ac", d.get("ac_bonus", 10)))
	if not d.get("dex", false):
		a.max_dex_bonus = 0
	else:
		a.max_dex_bonus = int(d.get("dex_cap", -1))
	a.strength_requirement = int(d.get("strength", 0))
	a.stealth_disadvantage = bool(d.get("stealth_disadvantage", false))
	return a

# ── Spells ────────────────────────────────────────────────────────────────────

## True when extraction detected damage or healing for this spell.
func spell_has_mechanics(slug: String) -> bool:
	var mech: Dictionary = _require("spell", slug).get("data", {}).get("mechanics", {})
	return mech.has("damage") or mech.has("healing")

func make_spell(slug: String, casting_ability: SRD.Ability = SRD.Ability.INTELLIGENCE) -> AbilityData:
	var row := _require("spell", slug)
	if row.is_empty():
		return null
	var d: Dictionary = row.data
	var mech: Dictionary = d.get("mechanics", {})
	var ab := AbilityData.new()
	ab.ability_name = row.name
	ab.description = str(d.get("text", ""))
	ab.slot_level = int(d.get("level", 0))
	ab.concentration = bool(d.get("concentration", false))
	ab.casting_ability = casting_ability
	ab.tags.assign(["spell", str(d.get("school", ""))])
	var rng: Dictionary = d.get("range", {})
	if rng.has("feet"):
		ab.range_feet = int(rng.feet)
	elif rng.get("touch", false):
		ab.range_feet = -1
	elif rng.get("self", false):
		ab.range_feet = 0
	if mech.has("area"):
		ab.target_type = "area"
		ab.area_shape = _aoe_shape(str(mech.area.shape))
		ab.area_size = int(mech.area.size)

	ab.spell_id = slug
	for cls in d.get("classes", []):
		ab.tags.append(str(cls))
	var ct := str(d.get("casting_time", "Action"))
	ab.casting_time = ct.split(",")[0].strip_edges().to_lower().replace(" ", "_")
	ab.reaction_trigger = str(mech.get("reaction_trigger", ""))
	ab.effects = mech.get("effects", []).duplicate(true)
	ab.immune_if = mech.get("immune_if", []).duplicate()
	ab.summon = mech.get("summon", {}).duplicate()
	ab.projectiles = int(mech.get("projectiles", 0))
	ab.upcast_projectiles = int(mech.get("upcast_projectiles", 0))
	ab.auto_hit = bool(mech.get("auto_hit", false))
	ab.max_targets = int(mech.get("max_targets", 0))
	ab.upcast_targets = int(mech.get("upcast_targets", 0))
	ab.duration_rounds = _duration_rounds(str(d.get("duration", "")))
	if mech.has("save"):
		ab.save_ability = ability_from(mech.save) as SRD.Ability
	ab.uses_save = mech.has("save") and not mech.has("attack")

	if mech.has("healing"):
		var h := parse_dice(str(mech.healing))
		ab.heal_die_count = h.count
		ab.heal_die_sides = h.sides
		ab.heal_bonus = h.bonus
		ab.heal_add_modifier = bool(mech.get("healing_add_modifier", false))
		if mech.has("upcast_dice") and not mech.has("damage"):
			ab.upcast_heal_die_count = parse_dice(mech.upcast_dice).count

	if not mech.has("damage"):
		ab.damage_die_count = 0
		if not mech.has("healing") and ab.effects.is_empty():
			ab.tags.append(TAG_NO_MECHANICS)
		return ab
	var parts: Array = mech.damage
	var dice := parse_dice(parts[0].dice)
	ab.damage_die_count = dice.count
	ab.damage_die_sides = dice.sides
	ab.damage_bonus = dice.bonus
	ab.damage_add_modifier = bool(mech.get("damage_add_modifier", false))
	ab.damage_type = damage_type_from(parts[0].type)
	ab.save_effect = SRD.SaveEffect.HALF if mech.get("half_on_save", false) else SRD.SaveEffect.NONE
	if mech.has("upcast_dice"):
		ab.upcast_bonus_die_count = parse_dice(mech.upcast_dice).count
	if parts.size() > 1 or (ab.effects.is_empty() and RegEx.create_from_string(_RIDER_WORDS).search(ab.description) != null):
		ab.tags.append(TAG_PARTIAL)
	return ab

## Words in a damaging spell's text that signal a rider; with no effect extracted, the
## spell is tagged partial (its damage works, its rider doesn't yet).
const _RIDER_WORDS := "has the \\w+ condition|Speed|pushed|Advantage|Disadvantage|Temporary Hit Points|can’t take"

static func _duration_rounds(duration: String) -> int:
	var m := RegEx.create_from_string("(\\d+) (round|minute|hour)").search(duration)
	if m == null:
		return 0
	return int(m.get_string(1)) * {"round": 1, "minute": 10, "hour": 600}[m.get_string(2)]

## Spell slugs on a class's spell list, optionally limited to one spell level.
func class_spell_slugs(class_slug: String, spell_level: int = -1) -> Array:
	var out := []
	for row in pack.rows("spell"):
		if class_slug in row.data.get("classes", []) \
				and (spell_level < 0 or int(row.data.level) == spell_level):
			out.append(row.slug)
	out.sort()
	return out

# ── Monsters ──────────────────────────────────────────────────────────────────

## Build a monster Combatant from its stat block. Uses the first attack action;
## id > 0 appends a number to the name ("Goblin 2").
func make_monster(slug: String, id: int = 0) -> Combatant:
	var row := _require("monster", slug)
	if row.is_empty():
		return null
	var d: Dictionary = row.data
	var s := CharacterStats.new()
	s.character_name = row.name + ("" if id == 0 else " %d" % id)
	s.level = 1
	var abilities: Dictionary = d.get("abilities", {})
	for key in abilities:
		var ab := ability_from(key)
		if ab < 0:
			continue
		s.set_ability(ab as SRD.Ability, int(abilities[key].score))
		# The stat block lists save totals; a save above the plain modifier means proficiency
		if int(abilities[key].save) > int(abilities[key].mod):
			s.set_save_proficiency(ab as SRD.Ability, true)
	s.max_hp = int(d.get("hp", 1))
	var hp_dice := parse_dice(str(d.get("hp_dice", "1d8")))
	s.hit_die = maxi(hp_dice.sides, 4)
	s.speed = int(d.get("speed", {}).get("walk", 30))
	s.reset()
	for t in d.get("damage_immunities", []):
		s.set_immunity(damage_type_from(t), true)
	for t in d.get("resistances", []):
		s.set_resistance(damage_type_from(t), true)
	for t in d.get("vulnerabilities", []):
		s.set_vulnerability(damage_type_from(t), true)

	var eq := EquipmentSlots.new()
	eq.natural_ac = int(d.get("ac", 10))
	var c := Combatant.new(s, _monster_weapon(d.get("actions", [])), eq)
	c.dies_at_zero_hp = true
	c.size = str(d.get("size", "medium")).split(" ")[0]
	for ci in d.get("condition_immunities", []):
		c.condition_immunities.append(str(ci))
	for t in d.get("traits", []):
		if t.get("name", "") == "Undead Fortitude":
			c.has_undead_fortitude = true
	return c

func monster_xp(slug: String) -> int:
	return int(_require("monster", slug).get("data", {}).get("xp", 0))

## Challenge rating as a float ("1/4" -> 0.25).
func monster_cr(slug: String) -> float:
	var cr := str(_require("monster", slug).get("data", {}).get("cr", "0"))
	if "/" in cr:
		var p := cr.split("/")
		return float(p[0]) / float(p[1])
	return float(cr)

## First action with an attack roll becomes the monster's weapon.
func _monster_weapon(actions: Array) -> WeaponData:
	for a in actions:
		var atk: Variant = a.get("attack")
		if not atk is Dictionary or atk.get("damage", []).is_empty():
			continue
		var w := WeaponData.new()
		w.weapon_name = a.name
		var dice := parse_dice(atk.damage[0].dice)
		w.die_count = dice.count; w.die_sides = dice.sides
		w.damage_type = damage_type_from(atk.damage[0].type)
		w.fixed_attack_bonus = int(atk.bonus)
		w.fixed_damage_bonus = dice.bonus
		if atk.kind == "ranged" and atk.has("range"):
			w.range_normal = int(atk.range[0]); w.range_long = int(atk.range[1])
		else:  # melee, or melee_or_ranged (fights in melee by default)
			w.range_normal = int(atk.get("reach", 5)); w.range_long = w.range_normal
		return w
	return null

# ── Parsing helpers ───────────────────────────────────────────────────────────

const _ABILITY_KEYS := ["str", "dex", "con", "int", "wis", "cha"]

static func ability_from(key: String) -> int:
	return _ABILITY_KEYS.find(key.to_lower().left(3))

static func skill_from(key: String) -> int:
	var name := key.to_upper().replace("-", "_").replace(" ", "_")
	return SRD.Skill.get(name, -1)

static func damage_type_from(key: String) -> SRD.DamageType:
	return SRD.DamageType.get(key.to_upper(), SRD.DamageType.BLUDGEONING) as SRD.DamageType

## "2d6+3" -> {count: 2, sides: 6, bonus: 3}; a bare "5" -> {count: 0, sides: 0, bonus: 5}.
static func parse_dice(expr: String) -> Dictionary:
	var out := { "count": 0, "sides": 0, "bonus": 0 }
	var re := RegEx.create_from_string("^\\s*(\\d*)d(\\d+)\\s*(?:([+-])\\s*(\\d+))?\\s*$")
	var m := re.search(expr)
	if m == null:
		out.bonus = int(expr)
		return out
	out.count = int(m.get_string(1)) if m.get_string(1) != "" else 1
	out.sides = int(m.get_string(2))
	if m.get_string(4) != "":
		out.bonus = int(m.get_string(4)) * (-1 if m.get_string(3) == "-" else 1)
	return out

func _require(kind: String, slug: String) -> Dictionary:
	var row := pack.get_row(kind, slug)
	if row.is_empty():
		push_error("SRDContent: no %s '%s' in pack" % [kind, slug])
	return row

func _abilities(keys: Array) -> Array:
	var out := []
	for k in keys:
		var a := ability_from(k)
		if a >= 0:
			out.append(a)
	return out

static func _progression(key: String) -> SRD.SlotProgression:
	match key:
		"full": return SRD.SlotProgression.FULL
		"half": return SRD.SlotProgression.HALF
		"third": return SRD.SlotProgression.THIRD
		"pact": return SRD.SlotProgression.PACT
	return SRD.SlotProgression.NONE

static func _armor_type(key: String) -> SRD.ArmorType:
	return SRD.ArmorType.get(key.to_upper(), SRD.ArmorType.LIGHT) as SRD.ArmorType

static func _aoe_shape(key: String) -> SRD.AoEShape:
	match key:
		"cone": return SRD.AoEShape.CONE
		"line": return SRD.AoEShape.LINE
		"cube": return SRD.AoEShape.CUBE
		"cylinder": return SRD.AoEShape.CYLINDER
	return SRD.AoEShape.SPHERE  # sphere, radius, emanation

static func _weapon_properties(props: Array) -> int:
	var mask := 0
	for p in props:
		mask |= int(SRD.WeaponProperty.get(str(p).to_upper().replace("-", "_"), 0))
	return mask
