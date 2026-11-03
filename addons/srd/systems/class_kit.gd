## A character's class kit under SRD 5.2.1: class/subclass features held, limited-use
## resources, weapon masteries, and the feature logic for what's mechanically implemented.
## SRDContent.make_character() builds one and attaches it as Combatant.kit.
##
##   var ilse := srd.make_character("Ilse", "fighter", 3, scores, "longsword", "chain-mail", true)
##   ilse.kit.second_wind(ilse)          # Bonus Action, 1d10 + level, 2 uses (short rest: +1)
##   ilse.kit.action_surge(ilse)         # one extra action this turn
##   ilse.kit.feature_names()            # every feature held at this level, in level order
##
## Features listed in IMPLEMENTED have rules here, in AttackResolver, or in SpellResolver;
## everything else is carried as text (feature_rows()) for the UI.
class_name ClassKit
extends RefCounted

## Feature keys (the part of the feature slug after "<class>-" or "<class>-<subclass>-")
## whose rules the engine applies. The rest are text-only for now.
const IMPLEMENTED := {
	# Shared
	"weapon-mastery": true, "extra-attack": true, "two-extra-attacks": true,
	"three-extra-attacks": true, "spellcasting": true, "ability-score-improvement": false,
	# Fighter
	"fighting-style": true, "second-wind": true, "action-surge": true, "tactical-shift": true, "indomitable": true, "studied-attacks": true,
	"improved-critical": true, "superior-critical": true, "remarkable-athlete": true,
	"additional-fighting-style": true,
	# Rogue
	"sneak-attack": true, "cunning-action": true, "steady-aim": true, "uncanny-dodge": true,
	"evasion": true, "reliable-talent": true, "expertise": true, "cunning-strike": true,
	"improved-cunning-strike": true, "slippery-mind": true,
	# Cleric
	"divine-order": true, "channel-divinity": true, "disciple-of-life": true,
	"preserve-life": true, "life-domain-spells": true, "blessed-healer": true,
	"supreme-healing": true, "blessed-strikes": true, "improved-blessed-strikes": true,
	"sear-undead": true,
	# Wizard
	"arcane-recovery": true, "potent-cantrip": true, "empowered-evocation": true,
	"sculpt-spells": true,
	# Paladin
	"lay-on-hands": true, "paladins-smite": true, "aura-of-protection": true,
	"aura-of-courage": true, "radiant-strikes": true, "sacred-weapon": true,
	"oath-of-devotion-spells": true, "aura-of-devotion": true,
	# Monk
	"martial-arts": true, "unarmored-defense": true, "monks-focus": true,
	"unarmored-movement": true, "uncanny-metabolism": true, "deflect-attacks": true,
	"stunning-strike": true, "empowered-strikes": true, "heightened-focus": true,
	"disciplined-survivor": true, "perfect-focus": true,
	"deflect-energy": true, "open-hand-technique": true, "wholeness-of-body": true,
	# Ranger
	"favored-enemy": true, "roving": true, "relentless-hunter": true,
	"precise-hunter": true, "hunters-prey": true, "defensive-tactics": true,
	# Bard
	"bardic-inspiration": true, "font-of-inspiration": true, "magical-secrets": true,
	"cutting-words": true, "magical-discoveries": true, "jack-of-all-trades": true,
	# Druid
	"primal-order": true, "elemental-fury": true, "improved-elemental-fury": true,
	"wild-resurgence": true, "lands-aid": true, "natural-recovery": true, "natures-ward": true,
	"circle-of-the-land-spells": true,
	# Sorcerer
	"innate-sorcery": true, "metamagic": true,
	"sorcerous-restoration": true, "draconic-resilience": true,
	"draconic-spells": true, "elemental-affinity": true,
	# Warlock
	"eldritch-invocations": true, "pact-magic": true, "magical-cunning": true,
	"mystic-arcanum": true, "dark-ones-blessing": true, "fiend-spells": true,
	"fiendish-resilience": true,
}

## Hotbar features a game can offer: ClassKit.feature_actions() lists the ones held now,
## can_use() says if one is usable, use_feature() runs it. cost: "action" | "bonus" | "free";
## target: "none" | "ally" | "enemy" | "area"; a resource and amount are spent on use.
const FEATURE_ACTIONS := {
	"steady_aim": {"needs": "steady-aim", "label": "Steady Aim", "glyph": "SA", "cost": "bonus",
		"target": "none", "tip": "If you haven't moved: Advantage on your next attack; Speed 0 this turn."},
	"preserve_life": {"needs": "preserve-life", "label": "Preserve Life", "glyph": "PL", "cost": "action",
		"target": "none", "range": 30, "resource": "channel_divinity",
		"tip": "Channel Divinity: split 5 x Cleric level HP among Bloodied allies within 30 ft, up to half their maximum."},
	"lay_on_hands": {"needs": "lay-on-hands", "label": "Lay On Hands", "glyph": "LOH", "cost": "bonus",
		"target": "ally", "range": 5, "resource": "lay_on_hands",
		"tip": "Touch: restore HP from your pool (5 x Paladin level per Long Rest)."},
	"sacred_weapon": {"needs": "sacred-weapon", "label": "Sacred Weapon", "glyph": "SW", "cost": "free",
		"target": "none", "resource": "channel_divinity",
		"tip": "Channel Divinity: add your CHA modifier to attack rolls with this weapon, and its hits may deal Radiant."},
	"flurry_of_blows": {"needs": "monks-focus", "label": "Flurry of Blows", "glyph": "FoB", "cost": "bonus",
		"target": "enemy", "range": 5, "resource": "focus_points",
		"tip": "1 Focus Point: two Unarmed Strikes (three at Monk 10)."},
	"bonus_unarmed": {"needs": "martial-arts", "label": "Unarmed Strike", "glyph": "US", "cost": "bonus",
		"target": "enemy", "range": 5, "tip": "Martial Arts: one Unarmed Strike as a Bonus Action."},
	"patient_defense": {"needs": "monks-focus", "label": "Patient Defense", "glyph": "PD", "cost": "bonus",
		"target": "none", "tip": "Disengage free; 1 Focus Point also Dodges."},
	"step_of_the_wind": {"needs": "monks-focus", "label": "Step of the Wind", "glyph": "SoW", "cost": "bonus",
		"target": "none", "tip": "Dash free; 1 Focus Point also Disengages and doubles your jump."},
	"wholeness_of_body": {"needs": "wholeness-of-body", "label": "Wholeness of Body", "glyph": "WoB", "cost": "bonus",
		"target": "none", "resource": "wholeness_of_body", "tip": "Regain Martial Arts die + WIS modifier HP."},
	"bardic_inspiration": {"needs": "bardic-inspiration", "label": "Bardic Inspiration", "glyph": "BI", "cost": "bonus",
		"target": "ally", "range": 60, "resource": "bardic_inspiration",
		"tip": "An ally gains your Bardic die: it adds to their next attack roll or save."},
	"innate_sorcery": {"needs": "innate-sorcery", "label": "Innate Sorcery", "glyph": "IS", "cost": "bonus",
		"target": "none", "resource": "innate_sorcery",
		"tip": "1 minute: +1 to your spell save DC, Advantage on your spell attacks."},
	"cs_poison": {"needs": "cunning-strike", "label": "Cunning: Poison", "glyph": "CSP", "cost": "free", "target": "none",
		"tip": "Your next Sneak Attack forgoes 1d6: CON save or Poisoned."},
	"cs_trip": {"needs": "cunning-strike", "label": "Cunning: Trip", "glyph": "CST", "cost": "free", "target": "none",
		"tip": "Your next Sneak Attack forgoes 1d6: DEX save or Prone (Large or smaller)."},
	"cs_withdraw": {"needs": "cunning-strike", "label": "Cunning: Withdraw", "glyph": "CSW", "cost": "free", "target": "none",
		"tip": "Your next Sneak Attack forgoes 1d6: move half your Speed without provoking."},
	"mm_quickened": {"needs": "metamagic", "label": "Quickened Spell", "glyph": "QS", "cost": "free", "target": "none",
		"metamagic": "quickened", "points": 2, "tip": "2 Sorcery Points: your next Action spell costs a Bonus Action."},
	"mm_empowered": {"needs": "metamagic", "label": "Empowered Spell", "glyph": "ES", "cost": "free", "target": "none",
		"metamagic": "empowered", "points": 1, "tip": "1 Sorcery Point: reroll your lowest damage dice (up to your CHA modifier) on your next spell."},
	"mm_careful": {"needs": "metamagic", "label": "Careful Spell", "glyph": "CaS", "cost": "free", "target": "none",
		"metamagic": "careful", "points": 1, "tip": "1 Sorcery Point: allies in your next save spell auto-succeed and take no damage."},
	"mm_distant": {"needs": "metamagic", "label": "Distant Spell", "glyph": "DS", "cost": "free", "target": "none",
		"metamagic": "distant", "points": 1, "tip": "1 Sorcery Point: double the range of your next spell."},
}


var class_slug := ""
var subclass_slug := ""
var level := 1
## Feature rows held at this level (class + subclass), in level order.
var features: Array = []
## The class table row for this level ({proficiency_bonus, features, sneak_attack, ...}).
var table_row: Dictionary = {}
## Build choices: fighting_style, divine_order, blessed_strikes ("divine-strike" | "potent-spellcasting").
var options: Dictionary = {}
## Weapon slugs whose mastery property this character can use.
var weapon_masteries: Array[String] = []
## Limited uses: name -> {max, current, short: "all" | "one" | "none"}
var resources: Dictionary = {}
## The Unarmed Strike a Monk swings for Flurry of Blows and the Martial Arts Bonus Action.
var unarmed: WeaponData = null
## Feats held (slugs): Alert, Savage Attacker, Skilled, Grappler, Ability Score Improvement.
var feats: Array = []

# ── Building ─────────────────────────────────────────────────────────────────

func has_feature(key: String) -> bool:
	for f in features:
		if f.slug.ends_with("-" + key):
			return true
	return false

func feature_names() -> Array:
	return features.map(func(f): return f.name)

## Every held feature and whether the engine applies its rules: [{slug, name, level, implemented}].
func feature_report() -> Array:
	return features.map(func(f): return {"slug": f.slug, "name": f.name,
		"level": int(f.data.level), "implemented": is_implemented(f)})

func is_implemented(f: Dictionary) -> bool:
	var key := str(f.slug)
	var prefix := class_slug + "-" + (subclass_slug + "-" if f.data.get("subclass", "") != "" else "")
	return IMPLEMENTED.get(key.trim_prefix(prefix), false)

func add_resource(res_name: String, max_uses: int, short_rest: String = "none") -> void:
	if max_uses > 0:
		resources[res_name] = {"max": max_uses, "current": max_uses, "short": short_rest}

func uses_left(res_name: String) -> int:
	return int(resources.get(res_name, {}).get("current", 0))

func spend(res_name: String, amount: int = 1) -> bool:
	if uses_left(res_name) < amount:
		return false
	resources[res_name].current -= amount
	return true

## SRD 5.2.1: Second Wind and Channel Divinity regain one use on a Short Rest; Action
## Surge regains all; the rest wait for a Long Rest.
func short_rest() -> void:
	for r in resources.values():
		match r.short:
			"all": r.current = r.max
			"one": r.current = mini(r.max, r.current + 1)

func long_rest() -> void:
	for r in resources.values():
		r.current = r.max
	restored_this_day = false

## Sorcerous Restoration: spent until the next Long Rest.
var restored_this_day := false

## Rest-time features: a Short Rest recovers these. Returns log lines.
## SRD: Arcane Recovery, Natural Recovery (highest slots first, total levels up to half the
## class level, none of level 6+), Sorcerous Restoration, Magical Cunning are the character's
## choice at the table; here a helper picks the largest slots missing.
func rest_recoveries(c: Combatant) -> Array:
	var out := []
	var budget := ceili(level / 2.0)
	for feat: String in ["arcane-recovery", "natural-recovery"]:
		var res := feat.replace("-", "_")
		if has_feature(feat) and uses_left(res) > 0 and c.energy_slots != null:
			var picks := _missing_slots(c, budget, 5)
			if not picks.is_empty():
				spend(res)
				for sl in picks:
					c.energy_slots.recover_slot(int(sl), 1)
				out.append("%s recovers level %s slots." % [feat.capitalize().replace("-", " "),
					", ".join(picks.map(func(p): return str(p)))])
	if has_feature("sorcerous-restoration") and not restored_this_day and resources.has("sorcery_points"):
		var r: Dictionary = resources.sorcery_points
		var got := mini(level / 2, int(r.max) - int(r.current))
		if got > 0:
			r.current += got
			restored_this_day = true
			out.append("Sorcerous Restoration: %d Sorcery Points." % got)
	if has_feature("magical-cunning") and uses_left("magical_cunning") > 0 and c.energy_slots != null:
		var slots := c.energy_slots
		for i in 9:
			var missing := slots.slots_max[i] - slots.slots_remaining[i]
			if missing > 0:
				slots.recover_slot(i + 1, ceili(slots.slots_max[i] / 2.0))
				spend("magical_cunning")
				out.append("Magical Cunning recovers Pact slots.")
				break
	return out

## Greedy: the highest missing slot levels whose total stays within the budget.
func _missing_slots(c: Combatant, budget: int, max_level: int) -> Array:
	var picks := []
	var left := {}
	for sl in range(max_level, 0, -1):
		left[sl] = c.energy_slots.slots_max[sl - 1] - c.energy_slots.slots_remaining[sl - 1]
	for sl in range(max_level, 0, -1):
		while int(left[sl]) > 0 and budget >= sl:
			picks.append(sl)
			left[sl] -= 1
			budget -= sl
	return picks

# ── Passive features ─────────────────────────────────────────────────────────

## Fold always-on class features into a freshly built character: AC, Speed, HP, saves,
## resources sized by an ability score, defenses. Called once by SRDContent.make_character.
func finish(c: Combatant) -> void:
	var s := c.stats
	var eq := c.equipment
	match class_slug:
		"monk":
			if has_feature("unarmored-defense"):
				eq.unarmored_ability = SRD.Ability.WISDOM
				eq.unarmored_no_shield = true
			s.speed += int(str(table_row.get("unarmored_movement", "0")).trim_prefix("+").to_int())
			add_resource("wholeness_of_body", maxi(1, s.ability_modifier(SRD.Ability.WISDOM)) if has_feature("wholeness-of-body") else 0)
			add_resource("uncanny_metabolism", 1 if has_feature("uncanny-metabolism") else 0)
			if has_feature("disciplined-survivor"):
				for a in SRD.Ability.values():
					s.set_save_proficiency(a as SRD.Ability, true)
		"bard":
			add_resource("bardic_inspiration", maxi(1, s.ability_modifier(SRD.Ability.CHARISMA)),
				"all" if has_feature("font-of-inspiration") else "none")
		"ranger":
			add_resource("favored_enemy", int(table_row.get("favored_enemy", 0)))
			if has_feature("roving"):
				s.speed += 10
		"sorcerer":
			add_resource("innate_sorcery", 2)
			if has_feature("draconic-resilience"):
				s.max_hp += level
				s.current_hp = s.max_hp
				eq.unarmored_ability = SRD.Ability.CHARISMA
			if has_feature("elemental-affinity"):
				s.set_resistance(SRDContent.damage_type_from(str(options.get("elemental_affinity", "fire"))), true)
		"warlock":
			add_resource("magical_cunning", 1 if has_feature("magical-cunning") else 0)
			if has_feature("fiendish-resilience"):
				s.set_resistance(SRDContent.damage_type_from(str(options.get("fiendish_resilience", "fire"))), true)
			if invocation("eldritch-mind"):
				c.concentration_advantage = true
		"rogue":
			if has_feature("slippery-mind"):
				s.set_save_proficiency(SRD.Ability.WISDOM, true)
				s.set_save_proficiency(SRD.Ability.CHARISMA, true)
		"paladin":
			if has_feature("aura-of-courage") and not "frightened" in c.condition_immunities:
				c.condition_immunities.append("frightened")
			if has_feature("aura-of-devotion") and not "charmed" in c.condition_immunities:
				c.condition_immunities.append("charmed")
		"druid":
			if has_feature("natures-ward"):
				s.set_immunity(SRD.DamageType.POISON, true)
				s.set_resistance(SRDContent.damage_type_from(str(options.get("natures_ward", "fire"))), true)
				if not "poisoned" in c.condition_immunities:
					c.condition_immunities.append("poisoned")
			if has_feature("natural-recovery"):
				add_resource("natural_recovery", 1)
		"fighter":
			if has_feature("remarkable-athlete"):
				c.initiative_advantage = true
	if has_feature("jack-of-all-trades"):
		s.half_proficiency_unskilled = true
	if "alert" in feats:
		c.initiative_extra += s.proficiency_bonus()
	adapt_weapon(c)

## Monk weapons: Dexterous Attacks and the Martial Arts die. Called again on every weapon change.
func adapt_weapon(c: Combatant) -> void:
	if not has_feature("martial-arts"):
		return
	var die := SRDContent.parse_dice(str(table_row.get("martial_arts", "1d6")))
	unarmed = WeaponData.new()
	unarmed.weapon_name = "Unarmed Strike"
	unarmed.slug = "unarmed-strike"
	unarmed.weapon_type = SRD.WeaponType.SIMPLE
	unarmed.die_count = 1
	unarmed.die_sides = int(die.sides)
	unarmed.damage_type = SRD.DamageType.FORCE if has_feature("empowered-strikes") else SRD.DamageType.BLUDGEONING
	unarmed.properties = int(SRD.WeaponProperty.FINESSE)
	if c.weapon == null:
		c.weapon = unarmed
		c.is_proficient_with_weapon = true
		return
	if c.equipment.armor != null or c.equipment.shield != null or c.weapon.is_ranged():
		return
	var monk_weapon := c.weapon.weapon_type == SRD.WeaponType.SIMPLE \
		or c.weapon.has_property(SRD.WeaponProperty.LIGHT)
	if monk_weapon:
		c.weapon.properties |= int(SRD.WeaponProperty.FINESSE)
		c.weapon.die_sides = maxi(c.weapon.die_sides, int(die.sides))

func invocation(key: String) -> bool:
	return "warlock-" + key in options.get("invocations", []) or key in options.get("invocations", [])

# ── Hotbar features ──────────────────────────────────────────────────────────

## FEATURE_ACTIONS entries this kit holds now: [{id, label, glyph, cost, target, range, tip}].
func feature_actions() -> Array:
	var out := []
	for id: String in FEATURE_ACTIONS:
		var f: Dictionary = FEATURE_ACTIONS[id]
		if not has_feature(str(f.needs)):
			continue
		if f.has("metamagic") and not "sorcerer-%s-spell" % f.metamagic in options.get("metamagic", []):
			continue
		var row := f.duplicate()
		row["id"] = id
		out.append(row)
	return out

## [ok, reason]: is this feature usable now? (Action economy is the caller's job.)
func can_use(id: String, c: Combatant) -> Array:
	var f: Dictionary = FEATURE_ACTIONS.get(id, {})
	if f.is_empty():
		return [false, "Unknown feature"]
	if f.has("resource") and uses_left(str(f.resource)) <= 0:
		return [false, "No uses left"]
	match id:
		"steady_aim":
			if c.action_economy.has_moved:
				return [false, "You've already moved"]
		"sacred_weapon":
			if c.weapon == null or c.weapon.is_ranged():
				return [false, "Needs a melee weapon"]
			if c.effects.has_id("sacred-weapon"):
				return [false, "Already active"]
		"cs_poison", "cs_trip", "cs_withdraw":
			if c.turn_flags.get("cunning_strike", []).size() >= (2 if has_feature("improved-cunning-strike") else 1):
				return [false, "Already chosen this turn"]
		"innate_sorcery":
			if c.effects.has_id("innate-sorcery"):
				return [false, "Already active"]
	if f.has("metamagic"):
		if uses_left("sorcery_points") < int(f.get("points", 1)):
			return [false, "Not enough Sorcery Points"]
		if c.turn_flags.get("metamagic", "") != "":
			return [false, "Metamagic already set for this spell"]
	return [true, ""]

## Run a feature. Returns {used, text, healed?, attacks?, ...}; the caller checks the action
## economy, applies space (attacks, movement) and logs `text`. target: Combatant or null.
func use_feature(id: String, c: Combatant, target: Combatant = null) -> Dictionary:
	var ok: Array = can_use(id, c)
	if not ok[0]:
		return {"used": false, "text": ok[1]}
	var f: Dictionary = FEATURE_ACTIONS[id]
	if f.has("resource"):
		spend(str(f.resource))
	match id:
		"steady_aim":
			c.effects.add({"id": "steady-aim", "type": "next_attack_advantage", "uses": 1,
				"source": c.name, "expires": "end_of_turn", "of": c.name})
			c.action_economy._movement_remaining = 0
			return {"used": true, "text": "takes [b]Steady Aim[/b]: Advantage on the next attack."}
		"lay_on_hands":
			# The resource's one point was spent above: this settles the rest of the amount
			var want := mini(target.stats.max_hp - target.current_hp, uses_left("lay_on_hands") + 1)
			resources.lay_on_hands.current = int(resources.lay_on_hands.current) + 1 - want
			return {"used": true, "heal": want, "text": "lays on hands: %d HP." % want}
		"sacred_weapon":
			var bonus := maxi(1, c.stats.ability_modifier(SRD.Ability.CHARISMA))
			c.effects.add({"id": "sacred-weapon", "type": "attack_bonus", "amount": bonus, "source": c.name,
				"expires": "start_of_turn", "of": c.name, "turns": 100})
			return {"used": true, "text": "imbues the weapon: [b]Sacred Weapon[/b] (+%d to hit)." % bonus}
		"flurry_of_blows":
			return {"used": true, "attacks": 3 if has_feature("heightened-focus") else 2,
				"flurry": true, "text": "unleashes a [b]Flurry of Blows[/b]."}
		"bonus_unarmed":
			return {"used": true, "attacks": 1, "text": "follows up with an Unarmed Strike."}
		"patient_defense":
			var focus := spend("focus_points")
			var thp := 0
			if focus and has_feature("heightened-focus"):
				thp = Dice.roll_nd(2, int(unarmed.die_sides if unarmed else 6))
				c.stats.add_temp_hp(thp)
			return {"used": true, "disengage": true, "dodge": focus, "temp_hp": thp,
				"text": "takes [b]Patient Defense[/b]%s." % (": Disengage and Dodge" if focus else ": Disengage")}
		"step_of_the_wind":
			var focus := spend("focus_points")
			c.action_economy._movement_remaining += c.speed
			return {"used": true, "disengage": focus, "text": "takes [b]Step of the Wind[/b]: Dash%s." % (" and Disengage" if focus else "")}
		"wholeness_of_body":
			var roll := Dice.roll(int(unarmed.die_sides if unarmed else 6))
			var amount := maxi(1, roll + c.stats.ability_modifier(SRD.Ability.WISDOM))
			return {"used": true, "self_heal": amount, "text": "draws on [b]Wholeness of Body[/b]."}
		"bardic_inspiration":
			var die := bardic_die()
			target.effects.add({"id": "bardic-inspiration", "type": "bonus_die", "die": "1d%d" % die,
				"applies": ["attack", "save"], "one_shot": true, "source": c.name,
				"expires": "start_of_turn", "of": c.name, "turns": 100})
			return {"used": true, "text": "inspires %s (d%d)." % [target.name, die]}
		"innate_sorcery":
			for type in ["spell_dc_bonus", "spell_attack_advantage"]:
				c.effects.add({"id": "innate-sorcery", "type": type, "amount": 1, "source": c.name,
					"expires": "start_of_turn", "of": c.name, "turns": 10})
			return {"used": true, "text": "unleashes [b]Innate Sorcery[/b]."}
		"cs_poison", "cs_trip", "cs_withdraw":
			var picks: Array = c.turn_flags.get("cunning_strike", [])
			picks.append(id.trim_prefix("cs_"))
			c.turn_flags["cunning_strike"] = picks
			return {"used": true, "text": "readies a Cunning Strike (%s)." % id.trim_prefix("cs_").capitalize()}
	if f.has("metamagic"):
		spend("sorcery_points", int(f.get("points", 1)))
		c.turn_flags["metamagic"] = str(f.metamagic)
		return {"used": true, "text": "shapes the next spell: [b]%s[/b]." % f.label}
	return {"used": true, "text": "uses %s." % f.label}

## The Bardic Inspiration die's size at this level.
func bardic_die() -> int:
	return int(str(table_row.get("bardic_die", "D6")).trim_prefix("D").trim_prefix("d"))

## Extra damage this hit deals from class features: [{name, dice, type}]. melee: the weapon
## is a melee weapon. wounded: the target was already missing HP before this hit.
func on_hit_extras(c: Combatant, melee: bool, wounded: bool, weapon_type: String) -> Array:
	var out := []
	if melee and has_feature("radiant-strikes"):
		out.append({"name": "Radiant Strikes", "dice": "1d8", "type": "radiant"})
	if has_feature("hunters-prey") and options.get("hunters_prey", "colossus-slayer") == "colossus-slayer" \
			and wounded and not c.turn_flags.get("colossus_slayer", false):
		c.turn_flags["colossus_slayer"] = true
		out.append({"name": "Colossus Slayer", "dice": "1d8", "type": weapon_type})
	if has_feature("elemental-fury") and options.get("elemental_fury", "potent-spellcasting") == "primal-strike" \
			and not c.turn_flags.get("primal_strike", false):
		c.turn_flags["primal_strike"] = true
		out.append({"name": "Primal Strike", "dice": "2d8" if has_feature("improved-elemental-fury") else "1d8",
			"type": str(options.get("primal_strike_type", "fire"))})
	return out

## Divine Smite (SRD 5.2.1 spell, on Paladin's Smite): radiant dice for a slot level.
static func divine_smite_dice(slot_level: int, undead_or_fiend: bool) -> int:
	return 1 + slot_level + (1 if undead_or_fiend else 0)

## Deflect Attacks / Deflect Energy: how much damage the Reaction takes off (monk).
func deflect_amount(c: Combatant) -> int:
	return Dice.roll(10) + c.stats.ability_modifier(SRD.Ability.DEXTERITY) + level

## Stunning Strike's DC / any Focus save: 8 + WIS + PB.
func focus_dc(c: Combatant) -> int:
	return 8 + c.stats.proficiency_bonus() + c.stats.ability_modifier(SRD.Ability.WISDOM)

## Stunning Strike, on a hit. Costs 1 Focus Point, once per turn.
func stunning_strike(c: Combatant, target: Combatant, fixed_d20: int = -1) -> Dictionary:
	if not has_feature("stunning-strike") or c.turn_flags.get("stunning_strike", false) \
			or not spend("focus_points"):
		return {"used": false}
	c.turn_flags["stunning_strike"] = true
	var dc := focus_dc(c)
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var saved := d20 + target.stats.saving_throw_bonus(SRD.Ability.CONSTITUTION) + target.effects.roll_bonus("save") >= dc
	if saved:
		target.effects.add({"id": "stunning-strike-slow", "type": "speed_penalty", "amount": target.speed / 2,
			"source": c.name, "expires": "start_of_turn", "of": c.name})
		target.effects.add({"id": "stunning-strike-open", "type": "advantage_to_attackers", "uses": 1,
			"source": c.name, "expires": "start_of_turn", "of": c.name})
	elif not "stunned" in target.condition_immunities:
		target.effects.add({"id": "stunning-strike", "type": "condition", "condition": "stunned",
			"source": c.name, "expires": "start_of_turn", "of": c.name})
	return {"used": true, "dc": dc, "d20": d20, "saved": saved}

## Open Hand Technique, on a hit from Flurry of Blows: Topple (DEX save or Prone).
func open_hand_topple(c: Combatant, target: Combatant, fixed_d20: int = -1) -> Dictionary:
	var dc := focus_dc(c)
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var saved := d20 + target.stats.saving_throw_bonus(SRD.Ability.DEXTERITY) >= dc
	if not saved and not "prone" in target.condition_immunities:
		target.conditions.add(SRD.Condition.PRONE)
	return {"dc": dc, "saved": saved}

## Dark One's Blessing: Temporary HP on reducing an enemy to 0 HP.
func on_kill(c: Combatant) -> int:
	if not has_feature("dark-ones-blessing"):
		return 0
	var thp := maxi(1, c.stats.ability_modifier(SRD.Ability.CHARISMA) + level)
	c.stats.add_temp_hp(thp)
	return thp

## Uncanny Metabolism (Monk 2): on Initiative, regain all Focus Points once per Long Rest.
func initiative_rolled(c: Combatant) -> int:
	if has_feature("perfect-focus") and uses_left("focus_points") < 4:
		var r: Dictionary = resources.focus_points
		r.current = mini(int(r.max), 4)
	if uses_left("uncanny_metabolism") > 0 and uses_left("focus_points") == 0:
		spend("uncanny_metabolism")
		resources.focus_points.current = resources.focus_points.max
		c.stats.heal(Dice.roll(int(unarmed.die_sides if unarmed else 6)) + level)
		return 1
	if has_feature("wild-resurgence") and uses_left("wild_shape") == 0 and c.energy_slots != null:
		for i in 9:
			if c.energy_slots.slots_remaining[i] > 0:
				c.energy_slots.use_slot(i + 1)
				resources.wild_shape.current = 1
				return 1
	return 0

# ── Attacks ──────────────────────────────────────────────────────────────────

## Attacks per Attack action: Extra Attack (5), Two Extra Attacks (11), Three (20).
func attacks_per_action() -> int:
	if has_feature("three-extra-attacks"): return 4
	if has_feature("two-extra-attacks"): return 3
	if has_feature("extra-attack"): return 2
	return 1

## Lowest d20 that scores a Critical Hit with weapons (Champion: 19, then 18).
func crit_threshold() -> int:
	if has_feature("superior-critical"): return 18
	if has_feature("improved-critical"): return 19
	return 20

func can_use_mastery(weapon: WeaponData) -> bool:
	return weapon != null and weapon.mastery != "" and has_feature("weapon-mastery") \
		and (weapon.slug in weapon_masteries)

func fighting_style() -> String:
	return str(options.get("fighting_style", "")) if has_feature("fighting-style") else ""

## Champion's Additional Fighting Style adds a second one.
func has_style(style: String) -> bool:
	return fighting_style() == style or (has_feature("additional-fighting-style") \
		and str(options.get("fighting_style_2", "")) == style)

## Sneak Attack dice from the Rogue table ("2d6" at level 3).
func sneak_attack_dice() -> int:
	return SRDContent.parse_dice(str(table_row.get("sneak_attack", "0"))).count \
		if has_feature("sneak-attack") else 0

# ── Fighter ──────────────────────────────────────────────────────────────────

## Second Wind: Bonus Action, regain 1d10 + Fighter level. Returns HP regained, or -1 if
## no use or Bonus Action is left. Tactical Shift (5) adds a free half-Speed move: see
## the returned event's "free_move_feet".
func second_wind(c: Combatant, fixed_d10: int = -1) -> Dictionary:
	if not has_feature("second-wind") or uses_left("second_wind") <= 0 \
			or not c.action_economy.use_bonus_action():
		return {"used": false}
	spend("second_wind")
	var roll := fixed_d10 if fixed_d10 >= 1 else Dice.roll(10)
	var healed := c.stats.heal(roll + level)
	var ev := {"used": true, "type": "second_wind", "roll": roll, "healed": healed}
	if has_feature("tactical-shift"):
		ev["free_move_feet"] = c.speed / 2  # without provoking Opportunity Attacks
	return ev

## Tactical Mind: after failing an ability check, spend Second Wind to add 1d10; the use is
## only spent if the check then succeeds.
func tactical_mind(check_total: int, dc: int, fixed_d10: int = -1) -> Dictionary:
	if not has_feature("tactical-mind") or uses_left("second_wind") <= 0 or check_total >= dc:
		return {"used": false, "total": check_total, "success": check_total >= dc}
	var roll := fixed_d10 if fixed_d10 >= 1 else Dice.roll(10)
	var total := check_total + roll
	if total >= dc:
		spend("second_wind")
	return {"used": total >= dc, "roll": roll, "total": total, "success": total >= dc}

## Action Surge: one additional action this turn (not the Magic action). Two uses at 17,
## but only once per turn.
func action_surge(c: Combatant) -> bool:
	if not has_feature("action-surge") or c.turn_flags.get("action_surge", false) \
			or not spend("action_surge"):
		return false
	c.turn_flags["action_surge"] = true
	c.turn_flags["no_magic_action"] = true  # the surged action can't be the Magic action
	c.action_economy._has_action = true
	return true

## Indomitable: reroll a failed save with a bonus equal to Fighter level; must use the new roll.
func indomitable(c: Combatant, save_ability: SRD.Ability, dc: int, fixed_d20: int = -1) -> Dictionary:
	if not has_feature("indomitable") or not spend("indomitable"):
		return {"used": false}
	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var total := d20 + c.stats.saving_throw_bonus(save_ability) + level
	return {"used": true, "d20": d20, "total": total, "saved": total >= dc}

# ── Rogue ────────────────────────────────────────────────────────────────────

## Cunning Action: Dash, Disengage, or Hide as a Bonus Action.
func cunning_action(c: Combatant, action: String) -> bool:
	if not has_feature("cunning-action") or not action in ["dash", "disengage", "hide"] \
			or not c.action_economy.use_bonus_action():
		return false
	match action:
		"dash": c.action_economy._movement_remaining += c.speed
		"disengage": c.turn_flags["disengaged"] = true
		"hide": c.turn_flags["hiding"] = true  # the game rolls Dex (Stealth) vs DC 15
	return true

## Steady Aim: Bonus Action, only if you haven't moved this turn: Advantage on your next
## attack roll this turn, and your Speed is 0 until the end of the turn.
func steady_aim(c: Combatant) -> bool:
	if not has_feature("steady-aim") or c.action_economy.has_moved \
			or not c.action_economy.use_bonus_action():
		return false
	c.effects.add({"id": "steady-aim", "type": "next_attack_advantage", "uses": 1,
		"source": c.name, "expires": "end_of_turn", "of": c.name})
	c.action_economy._movement_remaining = 0
	return true

## Uncanny Dodge: Reaction when hit by an attacker you can see: halve the damage (round down).
func uncanny_dodge(c: Combatant, damage: int) -> int:
	if not has_feature("uncanny-dodge") or not c.action_economy.use_reaction():
		return damage
	return damage / 2

## Reliable Talent: a d20 of 9 or lower counts as 10 on checks using a proficiency.
func reliable_d20(d20: int, proficient: bool) -> int:
	return maxi(d20, 10) if has_feature("reliable-talent") and proficient else d20

# ── Cleric ───────────────────────────────────────────────────────────────────

## Divine Spark (Channel Divinity, Magic action): 1d8 + Wis mod (2d8 at 7, 3d8 at 13,
## 4d8 at 18), healing a creature or dealing Necrotic/Radiant damage (Con save for half).
func divine_spark_dice() -> int:
	if level >= 18: return 4
	if level >= 13: return 3
	if level >= 7: return 2
	return 1

func divine_spark(c: Combatant, target: Combatant, heal: bool,
		damage_type: SRD.DamageType = SRD.DamageType.RADIANT, fixed_save_d20: int = -1) -> Dictionary:
	if not has_feature("channel-divinity") or uses_left("channel_divinity") <= 0 \
			or not c.action_economy.use_action():
		return {"used": false}
	spend("channel_divinity")
	var wis := c.stats.ability_modifier(SRD.Ability.WISDOM)
	var amount := _roll_healing_dice(divine_spark_dice(), 8) + wis if heal \
		else Dice.roll_nd(divine_spark_dice(), 8) + wis
	if heal:
		return {"used": true, "type": "divine_spark", "healed": target.stats.heal(maxi(0, amount))}
	var dc := spell_save_dc(c)
	var d20 := fixed_save_d20 if fixed_save_d20 >= 1 else Dice.roll_d20()
	var saved := d20 + target.stats.saving_throw_bonus(SRD.Ability.CONSTITUTION) \
		+ target.effects.roll_bonus("save") >= dc
	var dmg := maxi(0, amount) / 2 if saved else maxi(0, amount)
	return {"used": true, "type": "divine_spark", "saved": saved, "dc": dc,
		"damage_dealt": target.take_damage(dmg, damage_type)}

## Turn Undead (Channel Divinity, Magic action): each Undead within 30 ft. makes a Wis save
## or is Frightened and Incapacitated for 1 minute (ends early if it takes damage). Sear
## Undead (5) adds Wis-mod d8s of Radiant damage to those that fail.
func turn_undead(c: Combatant, undead: Array, fixed_save_d20: int = -1) -> Array:
	if not has_feature("channel-divinity") or uses_left("channel_divinity") <= 0 \
			or not c.action_economy.use_action():
		return []
	spend("channel_divinity")
	var dc := spell_save_dc(c)
	var events := []
	for t: Combatant in undead:
		var d20 := fixed_save_d20 if fixed_save_d20 >= 1 else Dice.roll_d20()
		var saved := d20 + t.stats.saving_throw_bonus(SRD.Ability.WISDOM) >= dc
		var ev := {"type": "turn_undead", "target": t.name, "saved": saved, "dc": dc}
		if not saved:
			for cond in ["frightened", "incapacitated"]:
				if not cond in t.condition_immunities:
					t.effects.add({"id": "turn-undead-" + cond, "type": "condition", "condition": cond,
						"source": c.name, "ends_on_damage": true, "expires": "start_of_turn",
						"of": c.name, "turns": 10})
			if has_feature("sear-undead"):
				var n := maxi(1, c.stats.ability_modifier(SRD.Ability.WISDOM))
				ev["damage_dealt"] = t.take_damage(Dice.roll_nd(n, 8), SRD.DamageType.RADIANT)
		events.append(ev)
	return events

## Preserve Life (Life 3, Channel Divinity, Magic action): split 5 x Cleric level HP among
## Bloodied creatures within 30 ft.; none can be raised above half its HP maximum.
## allocation: Array of [Combatant, hp] pairs. Returns HP actually restored per target.
func preserve_life(c: Combatant, allocation: Array) -> Dictionary:
	var pool := 5 * level
	var asked := 0
	for pair in allocation:
		asked += int(pair[1])
	if not has_feature("preserve-life") or asked > pool or uses_left("channel_divinity") <= 0 \
			or not c.action_economy.use_action():
		return {"used": false}
	spend("channel_divinity")
	var out := {"used": true}
	for pair in allocation:
		var t: Combatant = pair[0]
		var cap := maxi(0, t.stats.max_hp / 2 - t.current_hp)
		out[t.name] = t.stats.heal(mini(int(pair[1]), cap)) if t.is_bloodied else 0
	return out

## Extra healing a slot spell grants (Disciple of Life: 2 + slot level), and dice handling
## (Supreme Healing at 17: maximum on every healing die).
func healing_bonus(slot_level: int) -> int:
	return 2 + slot_level if slot_level > 0 and has_feature("disciple-of-life") else 0

func _roll_healing_dice(count: int, sides: int) -> int:
	return count * sides if has_feature("supreme-healing") else Dice.roll_nd(count, sides)

## Blessed Healer (Life 6): after healing others with a slot spell, regain 2 + slot level.
func blessed_healer(c: Combatant, slot_level: int, healed_others: bool) -> int:
	if not healed_others or slot_level <= 0 or not has_feature("blessed-healer"):
		return 0
	return c.stats.heal(2 + slot_level)

## Blessed Strikes (7): Divine Strike, once per turn +1d8 (2d8 at 14) on a weapon hit.
func divine_strike_dice() -> int:
	if not has_feature("blessed-strikes") or options.get("blessed_strikes", "") != "divine-strike":
		return 0
	return 2 if has_feature("improved-blessed-strikes") else 1

## Potent Spellcasting: add Wis mod to Cleric cantrip damage.
func cantrip_damage_bonus(c: Combatant, ability: AbilityData) -> int:
	var bonus := 0
	if class_slug == "cleric" and has_feature("blessed-strikes") \
			and options.get("blessed_strikes", "potent-spellcasting") == "potent-spellcasting":
		bonus += c.stats.ability_modifier(SRD.Ability.WISDOM)
	if class_slug == "druid" and has_feature("elemental-fury") \
			and options.get("elemental_fury", "potent-spellcasting") == "potent-spellcasting":
		bonus += c.stats.ability_modifier(SRD.Ability.WISDOM)
	if class_slug == "warlock" and invocation("agonizing-blast"):
		bonus += c.stats.ability_modifier(SRD.Ability.CHARISMA)
	return bonus

# ── Wizard ───────────────────────────────────────────────────────────────────

## Arcane Recovery: after a Short Rest, recover slots with a combined level up to half the
## Wizard level (round up), none level 6+. Once per Long Rest.
func arcane_recovery(c: Combatant, slot_levels: Array) -> bool:
	if not has_feature("arcane-recovery") or uses_left("arcane_recovery") <= 0:
		return false
	var total := 0
	for sl in slot_levels:
		if int(sl) >= 6 or int(sl) < 1:
			return false
		total += int(sl)
	if total > ceili(level / 2.0):
		return false
	spend("arcane_recovery")
	for sl in slot_levels:
		c.energy_slots.recover_slot(int(sl), 1)
	return true

# ── Spellcasting ─────────────────────────────────────────────────────────────

var casting_ability: int = -1

func spell_save_dc(c: Combatant) -> int:
	var ab := casting_ability if casting_ability >= 0 else SRD.Ability.WISDOM
	return 8 + c.stats.proficiency_bonus() + c.stats.ability_modifier(ab as SRD.Ability)
