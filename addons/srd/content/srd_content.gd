## Builds the addon's runtime resources (ClassData, WeaponData, ArmorData, AbilityData,
## monster Combatants) from SRD 5.2.1 content-pack rows.
##
##   var srd := SRDContent.new()          # loads res://addons/srd/data/srd-5.2
##   var wizard := srd.make_class("wizard")
##   var goblin := srd.make_monster("goblin", 1)
##   var fireball := srd.make_spell("fireball", SRD.Ability.INTELLIGENCE)
class_name SRDContent
extends RefCounted

## Tag on AbilityData whose pack row has effects AbilityData can't express yet
## (multi-part damage, flat bonuses, darts, riders). The dice it does carry are correct.
const TAG_PARTIAL := "partial"

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
	c.hit_die = int(d.get("hitDie", 8))
	c.save_proficiencies.assign(_abilities(d.get("saves", [])))
	c.primary_abilities.assign(_abilities(d.get("primaryAbility", [])))
	var skills: Dictionary = d.get("skillChoices", {})
	c.skill_choices_count = int(skills.get("pick", 2))
	for s in skills.get("from", []):
		var skill := skill_from(s)
		if skill >= 0:
			c.skill_options.append(skill)
	c.armor_proficiencies.assign(d.get("armorProficiencies", []))
	c.weapon_proficiencies.assign(d.get("weaponProficiencies", []))
	var casting: Variant = d.get("spellcasting")
	c.slot_progression = _progression((casting as Dictionary).get("progression", "") if casting is Dictionary else "")
	return c

## SRD.Ability the class casts with, or -1 for non-casters.
func spellcasting_ability(class_slug: String) -> int:
	var casting: Variant = _require("class", class_slug).get("data", {}).get("spellcasting")
	return ability_from(casting.get("ability", "")) if casting is Dictionary else -1

## Class features gained at exactly this level (rows from the "feature" kind).
func class_features_at(class_slug: String, level: int) -> Array:
	var out := []
	for f in _require("class", class_slug).get("data", {}).get("features", []):
		if int(f.level) == level and pack.has_row("feature", f.slug):
			out.append(pack.get_row("feature", f.slug))
	return out

# ── Equipment ─────────────────────────────────────────────────────────────────

func make_weapon(slug: String) -> WeaponData:
	var row := _require("item", slug)
	if row.is_empty():
		return null
	var d: Dictionary = row.data
	var w := WeaponData.new()
	w.weapon_name = row.name
	w.weapon_type = SRD.WeaponType.MARTIAL if str(d.get("weaponType", "")).begins_with("martial") \
		else SRD.WeaponType.SIMPLE
	w.properties = _weapon_properties(d.get("properties", []))
	var attack: Dictionary = _first_activity(d, "attack").get("attack", {})
	var dmg: Array = attack.get("damage", [])
	if not dmg.is_empty():
		var dice := parse_dice(dmg[0].dice)
		w.die_count = dice.count; w.die_sides = dice.sides
		w.damage_type = damage_type_from(dmg[0].type)
	var versatile: Variant = d.get("versatileDamage")
	if versatile is Dictionary or versatile is String:
		var vd := parse_dice(versatile.dice if versatile is Dictionary else versatile)
		w.versatile_die_count = vd.count; w.versatile_die_sides = vd.sides
	# Thrown melee weapons (thrownRange) keep melee reach so they still attack with STR
	var rng: Variant = d.get("range")
	if rng is Dictionary:
		w.range_normal = int(rng.get("normal", 5)); w.range_long = int(rng.get("long", w.range_normal))
	return w

func make_armor(slug: String) -> ArmorData:
	var row := _require("item", slug)
	if row.is_empty():
		return null
	var d: Dictionary = row.data
	var a := ArmorData.new()
	a.armor_name = row.name
	a.armor_type = _armor_type(d.get("armorType", "light"))
	var formula: Dictionary = d.get("armorClassFormula", {})
	a.base_ac = int(formula.get("base", 2 if a.armor_type == SRD.ArmorType.SHIELD else 10))
	if formula.get("ability") == null:
		a.max_dex_bonus = 0
	else:
		a.max_dex_bonus = int(formula.get("abilityCap", -1))
	a.strength_requirement = int(d.get("strRequired", 0))
	a.stealth_disadvantage = bool(d.get("stealthDisadvantage", false))
	return a

# ── Spells ────────────────────────────────────────────────────────────────────

## True when the pack row carries mechanics (an activity) rather than just a stub.
func spell_has_mechanics(slug: String) -> bool:
	var acts: Variant = _require("spell", slug).get("data", {}).get("activities")
	return acts is Array and not acts.is_empty()

func make_spell(slug: String, casting_ability: SRD.Ability = SRD.Ability.INTELLIGENCE) -> AbilityData:
	var row := _require("spell", slug)
	if row.is_empty():
		return null
	var d: Dictionary = row.data
	var ab := AbilityData.new()
	ab.ability_name = row.name
	ab.description = str(d.get("description", ""))
	ab.slot_level = int(d.get("level", 0))
	ab.concentration = bool(d.get("concentration", false))
	ab.casting_ability = casting_ability
	ab.tags.assign(["spell", str(d.get("school", ""))])
	var rng: Variant = d.get("range")
	if rng is Dictionary:
		match str(rng.get("units", "")):
			"ft": ab.range_feet = int(rng.get("value", 30))
			"touch": ab.range_feet = -1
			"self": ab.range_feet = 0

	var act := _first_damaging_activity(d)
	if act.is_empty():
		ab.damage_die_count = 0
		if not spell_has_mechanics(slug):
			ab.tags.append("stub")
		return ab

	ab.uses_save = act.type == "save"
	if ab.uses_save:
		ab.save_ability = ability_from(act.save.get("ability", "dex")) as SRD.Ability
	var parts := _damage_parts(act)
	var dice := parse_dice(parts[0].dice)
	ab.damage_die_count = dice.count
	ab.damage_die_sides = dice.sides
	ab.damage_type = damage_type_from(parts[0].type)
	ab.save_effect = SRD.SaveEffect.HALF if parts[0].get("halfOnSave", false) else SRD.SaveEffect.NONE
	var scaling: Dictionary = act.get("damage", {}).get("scalesWithSlotLevel", {})
	if scaling.has("addDice"):
		ab.upcast_bonus_die_count = parse_dice(scaling.addDice).count
	if parts.size() > 1 or dice.bonus != 0 or scaling.has("addDarts") \
			or act.get("damage", {}).has("perDart"):
		ab.tags.append(TAG_PARTIAL)

	var target: Dictionary = act.get("target", {})
	if target.get("affects", "") == "area":
		ab.target_type = "area"
		ab.area_shape = _aoe_shape(str(target.get("shape", "sphere")))
		ab.area_size = int(target.get("radius", target.get("size", target.get("length", 0))))
	return ab

## Spell slugs available to a class, optionally limited to one spell level.
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
	var scores: Dictionary = d.get("abilityScores", {})
	for key in scores:
		var ab := ability_from(key)
		if ab >= 0:
			s.set_ability(ab as SRD.Ability, int(scores[key]))
	var hp: Dictionary = d.get("hp", {})
	var hp_dice := parse_dice(str(hp.get("formula", "1d8")))
	s.max_hp = int(hp.get("max", 1))
	s.hit_die = hp_dice.sides
	s.speed = int(d.get("speed", {}).get("walk", 30))
	s.reset()
	for entry in d.get("immunities", []):
		if str(entry).ends_with("-damage"):
			s.set_immunity(damage_type_from(str(entry).trim_suffix("-damage")), true)
	for entry in d.get("resistances", []):
		s.set_resistance(damage_type_from(str(entry).trim_suffix("-damage")), true)
	for entry in d.get("vulnerabilities", []):
		s.set_vulnerability(damage_type_from(str(entry).trim_suffix("-damage")), true)
	for key in d.get("saves", {}):
		var ab := ability_from(key)
		if ab >= 0:
			s.set_save_proficiency(ab as SRD.Ability, true)

	var eq := EquipmentSlots.new()
	eq.natural_ac = int(d.get("ac", 10))
	var c := Combatant.new(s, _monster_weapon(d.get("actions", [])), eq)
	c.dies_at_zero_hp = true
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

func _monster_weapon(actions: Array) -> WeaponData:
	for a in actions:
		if a.get("type", "") != "attack" or a.get("damage", []).is_empty():
			continue
		var w := WeaponData.new()
		w.weapon_name = a.name
		var dice := parse_dice(a.damage[0].dice)
		w.die_count = dice.count; w.die_sides = dice.sides
		w.damage_type = damage_type_from(a.damage[0].type)
		w.fixed_attack_bonus = int(a.get("attackBonus", 0))
		w.fixed_damage_bonus = dice.bonus
		if a.get("range", "melee") == "ranged":
			var bands: Dictionary = a.get("rangeBands", {})
			w.range_normal = int(bands.get("normal", 80))
			w.range_long = int(bands.get("long", w.range_normal))
		else:  # melee, or melee-or-thrown (fights in melee by default)
			w.range_normal = int(a.get("reach", 5)); w.range_long = w.range_normal
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

static func _first_activity(d: Dictionary, type: String) -> Dictionary:
	for a in d.get("activities", []):
		if a.get("type", "") == type:
			return a
	return {}

static func _first_damaging_activity(d: Dictionary) -> Dictionary:
	var acts: Variant = d.get("activities")
	if not acts is Array:
		return {}
	for a in acts:
		if a.get("type", "") in ["save", "attack", "damage"] and not _damage_parts(a).is_empty():
			return a
	return {}

## Damage parts live under activity.damage.parts (save/damage) or activity.attack.damage (attack).
static func _damage_parts(act: Dictionary) -> Array:
	var dmg: Variant = act.get("damage")
	if dmg is Dictionary and dmg.has("parts"):
		return dmg.parts
	return act.get("attack", {}).get("damage", [])
