## Weapon attacks under SRD 5.2.1: Advantage/Disadvantage from conditions and riders,
## Bless-style bonus dice, critical range, Fighting Styles, Sneak Attack, Divine Strike,
## Weapon Mastery properties, and Studied Attacks.
##
##   var ev := AttackResolver.weapon_attack(rogue, goblin, {"ally_adjacent": true})
##   if ev.get("cleave_available"): AttackResolver.weapon_attack(fighter, other, {"cleave": true})
##   if ev.has("push_feet"): move the target ev.push_feet straight away (the game owns space)
##
## Positional facts the engine can't know come from the game: pass them in opts, or set
## AttackResolver.ally_adjacent once so Sneak Attack can ask.
##
## opts (all optional):
##   d20, d20_2          fixed rolls (the second is used with Advantage/Disadvantage)
##   advantage, disadvantage   extra sources the game knows (hidden, Help, cover rules...)
##   ally_adjacent       an ally of the attacker without Incapacitated is within 5 ft. of the target
##   two_handed          wield a Versatile weapon in two hands
##   mastery             false to skip the weapon's mastery property
##   mastery_override    "push" | "sap" | "slow" (Tactical Master)
##   sneak_attack        false to hold Sneak Attack for a later hit this turn
##   cleave              this is Cleave's extra attack (no ability modifier unless negative)
##   light_extra         this is the Light property's extra attack (same rule; Two-Weapon Fighting adds it)
##   save_d20            fixed d20 for the target's save (Topple)
##   average             roll average damage (deterministic tests)
##   within_5ft          the attacker is within 5 ft. of the target (Prone, and automatic
##                       Critical Hits on Paralyzed / Unconscious targets); else asks
##                       AttackResolver.within_5ft, else assumes melee = within 5 ft.
##   cover               SRD.Cover the target has against this attack (+2 / +5 AC)
class_name AttackResolver
extends RefCounted

## func(attacker: Combatant, target: Combatant) -> bool. The game answers whether an ally of
## the attacker who isn't Incapacitated is within 5 feet of the target (Sneak Attack).
## Leave empty (invalid) for "no ally".
static var ally_adjacent: Callable
## func(attacker: Combatant, target: Combatant) -> bool: is the attacker within 5 feet of
## the target? Leave invalid to treat melee attacks as within 5 ft. and ranged as not.
static var within_5ft: Callable

const _PUSHABLE := ["tiny", "small", "medium", "large"]

static func weapon_attack(attacker: Combatant, target: Combatant, opts: Dictionary = {}) -> Dictionary:
	var w := attacker.weapon
	var kit := attacker.kit
	var ranged := w != null and w.is_ranged()
	var ev := {"type": "attack", "attacker": attacker.name, "target": target.name,
		"weapon": w.weapon_name if w else "Unarmed Strike"}

	var mode := roll_mode(attacker, target, ranged, opts, ev)
	var rolls := roll_d20s(mode, opts)
	var d20: int = rolls[-1] if rolls.size() == 1 else (rolls.max() if mode > 0 else rolls.min())

	# ── To hit ──
	var bonus := attacker.attack_modifier()
	if kit != null and kit.fighting_style() == "archery" and ranged:
		bonus += 2
	var bless := attacker.effects.roll_bonus("attack")
	attacker.effects.made_attack()
	var crit_on := kit.crit_threshold() if kit != null and w != null else 20
	var crit := d20 >= crit_on
	var cover := int(opts.get("cover", SRD.Cover.NONE))
	var ac := target.armor_class + SRDRules.cover_ac_bonus(cover)
	var hit := crit or (d20 != 1 and d20 + bonus + bless >= ac)
	if hit and not crit and target.conditions.crit_from_within_5ft() and is_within_5ft(attacker, target, ranged, opts):
		crit = true
		ev["auto_crit"] = true
	ev.merge({"d20": d20, "rolls": rolls, "advantage": mode > 0, "disadvantage": mode < 0,
		"attack_bonus": bonus, "bonus_dice": bless, "target_ac": ac, "cover": cover,
		"hit": hit, "crit": crit})

	var mastery := ""
	if kit != null and kit.can_use_mastery(w) and opts.get("mastery", true):
		mastery = w.mastery
		var ov := str(opts.get("mastery_override", ""))
		if ov in ["push", "sap", "slow"] and kit.has_feature("tactical-master"):
			mastery = ov
	if opts.get("cleave", false):
		attacker.turn_flags["cleave"] = true

	var dealt := 0
	if hit:
		var mod := _damage_mod(attacker, opts)
		var dmg := _weapon_dice(attacker, opts, crit) + mod
		# Sneak Attack: once per turn, Finesse or Ranged weapon, Advantage or an ally adjacent
		var sa_dice := kit.sneak_attack_dice() if kit != null else 0
		if sa_dice > 0 and opts.get("sneak_attack", true) and not attacker.turn_flags.get("sneak_attack", false) \
				and w != null and (w.has_property(SRD.WeaponProperty.FINESSE) or ranged):
			var ally: bool = opts.get("ally_adjacent", false) \
				or (ally_adjacent.is_valid() and bool(ally_adjacent.call(attacker, target)))
			if mode > 0 or (ally and mode >= 0):
				var sa := _roll(sa_dice * (2 if crit else 1), 6, opts)
				attacker.turn_flags["sneak_attack"] = true
				ev["sneak_attack"] = sa
				dmg += sa
		dmg = maxi(0, dmg)
		ev["damage"] = dmg
		dealt = target.take_damage(dmg, w.damage_type if w else SRD.DamageType.BLUDGEONING, crit)
		if not target.last_undead_fortitude.is_empty():
			ev["undead_fortitude"] = target.last_undead_fortitude
		# Monster riders: "Once per turn, if it had Advantage on the roll, an extra 2d6 Necrotic"
		for rider in attacker.hit_riders:
			var key := "rider-" + str(rider.name)
			if rider.get("condition", "") == "advantage" and mode <= 0:
				continue
			if int(rider.get("per_turn", 0)) > 0 and attacker.turn_flags.get(key, false):
				continue
			if not target.is_alive:
				break
			attacker.turn_flags[key] = true
			var rd := SRDContent.parse_dice(str(rider.dice))
			var extra: int = _roll(int(rd.count) * (2 if crit else 1), int(rd.sides), opts) + int(rd.bonus)
			var rtype := SRDContent.damage_type_from(str(rider.type))
			var rdealt := target.take_damage(extra, rtype, crit)
			ev["rider_damage"] = {"name": rider.name, "amount": extra, "dealt": rdealt,
				"type": str(rider.type).to_lower()}
			dealt += rdealt
		# Divine Strike (Cleric 7): once per turn, extra Radiant
		var ds := kit.divine_strike_dice() if kit != null and w != null else 0
		if ds > 0 and not attacker.turn_flags.get("divine_strike", false) and target.is_alive:
			attacker.turn_flags["divine_strike"] = true
			var extra := _roll(ds * (2 if crit else 1), 8, opts)
			ev["divine_strike"] = extra
			dealt += target.take_damage(extra, SRD.DamageType.RADIANT, crit)
		ev["damage_dealt"] = dealt
		if crit and kit != null and kit.has_feature("remarkable-athlete"):
			ev["free_move_feet"] = attacker.speed / 2
		_mastery_on_hit(mastery, attacker, target, dealt, opts, ev)
	else:
		ev["damage"] = 0
		ev["damage_dealt"] = 0
		if mastery == "graze":
			var gm := w.attack_ability_modifier(attacker.stats)
			if gm > 0:
				ev["mastery"] = "graze"
				ev["damage_dealt"] = target.take_damage(gm, w.damage_type)
		if kit != null and kit.has_feature("studied-attacks"):
			attacker.effects.add({"id": "studied-attacks", "type": "advantage_vs", "target": target.name,
				"uses": 1, "source": attacker.name, "expires": "end_of_turn", "of": attacker.name, "turns": 2})
	if mastery == "nick":
		ev["mastery"] = "nick"  # the Light extra attack can be part of the Attack action
	ev["target_hp_after"] = target.current_hp
	ev["target_alive"] = target.is_alive
	return ev

## Net Advantage (1), Disadvantage (-1), or a straight roll (0) for an attack roll, from
## opts, conditions, and one-shot riders (which this spends). Shared with spell attacks.
static func roll_mode(attacker: Combatant, target: Combatant, ranged: bool, opts: Dictionary,
		ev: Dictionary = {}) -> int:
	var adv: bool = opts.get("advantage", false)
	var dis: bool = opts.get("disadvantage", false)
	var prone := target.conditions.has(SRD.Condition.PRONE)
	if prone and not is_within_5ft(attacker, target, ranged, opts):
		dis = true  # Prone: attacks from beyond 5 ft. have Disadvantage
		if target.conditions.has(SRD.Condition.UNCONSCIOUS) or target.conditions.has(SRD.Condition.PARALYZED) \
				or target.conditions.has(SRD.Condition.STUNNED) or target.conditions.has(SRD.Condition.RESTRAINED) \
				or target.conditions.has(SRD.Condition.PETRIFIED) or target.conditions.has(SRD.Condition.BLINDED):
			adv = true
	elif target.conditions.grants_advantage_to_attackers():
		adv = true
	if target.conditions.imposes_disadvantage_on_attackers():
		dis = true
	if attacker.conditions.has_attack_advantage():
		adv = true
	if attacker.conditions.has_attack_disadvantage():
		dis = true
	# One-shot riders are spent by this roll whether or not they end up mattering
	if target.effects.consume("advantage_to_attackers"):
		adv = true
		ev["rider"] = "advantage_to_attackers"
	if attacker.effects.consume("advantage_vs", target.name):
		adv = true
	if attacker.effects.consume("next_attack_advantage"):
		adv = true
	if attacker.effects.consume("disadvantage_on_attack"):
		dis = true
	return 0 if adv == dis else (1 if adv else -1)

## Is the attacker within 5 ft. of the target? opts.within_5ft, else the game's callable,
## else melee attacks are and ranged ones aren't.
static func is_within_5ft(attacker: Combatant, target: Combatant, ranged: bool, opts: Dictionary = {}) -> bool:
	if opts.has("within_5ft"):
		return bool(opts.within_5ft)
	if within_5ft.is_valid():
		return bool(within_5ft.call(attacker, target))
	return not ranged

## The d20s rolled for an attack: one, or two with Advantage/Disadvantage.
static func roll_d20s(mode: int, opts: Dictionary) -> Array:
	var rolls := [_d20(opts, "d20")]
	if mode != 0:
		rolls.append(_d20(opts, "d20_2"))
	return rolls

static func _mastery_on_hit(mastery: String, attacker: Combatant, target: Combatant, dealt: int,
		opts: Dictionary, ev: Dictionary) -> void:
	match mastery:
		"cleave":
			if not attacker.turn_flags.get("cleave", false):
				ev["cleave_available"] = true
		"push":
			if target.size in _PUSHABLE:
				ev["push_feet"] = 10
		"sap":
			target.effects.add({"id": "mastery-sap", "type": "disadvantage_on_attack", "uses": 1,
				"source": attacker.name, "expires": "start_of_turn", "of": attacker.name})
		"slow":
			if dealt <= 0:
				return
			# Same id: several Slow hits never exceed 10 feet
			target.effects.add({"id": "mastery-slow", "type": "speed_penalty", "amount": 10,
				"source": attacker.name, "expires": "start_of_turn", "of": attacker.name})
		"topple":
			var dc := 8 + attacker.weapon.attack_ability_modifier(attacker.stats) + attacker.stats.proficiency_bonus()
			var d20 := _d20(opts, "save_d20")
			var saved := d20 + target.stats.saving_throw_bonus(SRD.Ability.CONSTITUTION) \
				+ target.effects.roll_bonus("save") >= dc
			ev["topple"] = {"dc": dc, "d20": d20, "saved": saved}
			if not saved and not "prone" in target.condition_immunities:
				target.conditions.add(SRD.Condition.PRONE)
		"vex":
			if dealt <= 0:
				return
			attacker.effects.add({"id": "mastery-vex", "type": "advantage_vs", "target": target.name,
				"uses": 1, "source": attacker.name, "expires": "end_of_turn", "of": attacker.name, "turns": 2})
		_:
			return
	ev["mastery"] = mastery

## Ability modifier to damage. Cleave and Light extra attacks add it only when negative,
## unless Two-Weapon Fighting applies to the Light attack.
static func _damage_mod(attacker: Combatant, opts: Dictionary) -> int:
	if attacker.weapon == null:
		return 1 + attacker.stats.ability_modifier(SRD.Ability.STRENGTH)  # Unarmed Strike: 1 + Str
	var mod := attacker.weapon._damage_mod(attacker.stats)
	var twf: bool = attacker.kit != null and attacker.kit.fighting_style() == "two-weapon-fighting"
	if opts.get("cleave", false) or (opts.get("light_extra", false) and not twf):
		return mini(mod, 0)
	return mod

static func _weapon_dice(attacker: Combatant, opts: Dictionary, crit: bool) -> int:
	var w := attacker.weapon
	if w == null:
		return 0
	var count := w.die_count
	var sides := w.die_sides
	var two: bool = opts.get("two_handed", false)
	if two and w.versatile_die_count > 0:
		count = w.versatile_die_count; sides = w.versatile_die_sides
	if crit:
		count *= 2
	# Great Weapon Fighting: a 1 or 2 on a damage die of a Two-Handed or Versatile (in two hands) melee weapon counts as 3
	var gwf: bool = attacker.kit != null and attacker.kit.fighting_style() == "great-weapon-fighting" \
		and not w.is_ranged() and (w.has_property(SRD.WeaponProperty.TWO_HANDED) or two)
	if opts.get("average", false):
		return count * ((sides + 1) / 2)
	var total := 0
	for i in count:
		var r := Dice.roll(sides)
		total += maxi(r, 3) if gwf else r
	return total

static func _roll(count: int, sides: int, opts: Dictionary) -> int:
	return count * ((sides + 1) / 2) if opts.get("average", false) else Dice.roll_nd(count, sides)

static func _d20(opts: Dictionary, key: String) -> int:
	var v := int(opts.get(key, -1))
	return v if v >= 1 else Dice.roll_d20()
