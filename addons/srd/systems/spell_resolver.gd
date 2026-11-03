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
## SRD 5.2.1 spells from SRDContent.make_spell() resolve fully here: attack and save
## spells with riders (Ray of Frost, Shocking Grasp, Guiding Bolt, Thunderwave's push,
## Sleep), darts and rays (Magic Missile, Scorching Ray), healing (Cure Wounds, Healing
## Word), buffs (Bless, Shield, Shield of Faith, Guidance), and self effects (Misty Step).
## Damage for one cast is rolled once and shared by every target, per the 2024 rules.
##
## opts (optional): d20, d20_2 (fixed attack rolls), save_d20 (fixed saves), average
## (average dice), advantage/disadvantage, sculpted (names Sculpt Spells protects),
## within_5ft (bool, or {target name: bool}: automatic crits on Paralyzed / Unconscious
## targets, Prone), cover (SRD.Cover, or {target name: SRD.Cover}: +2 / +5 to AC against
## spell attacks and to Dexterity saves).
##
## Summons (Spiritual Weapon): casting appends a {type: "summon", summon: SpellSummon}
## event; the game places summon.position and later calls summon_strike().
class_name SpellResolver
extends RefCounted

var _cast_damage: int = -1  # shared damage roll for the current cast
var _in_cast := false
var _empowered := false  # Empowered Evocation already applied this cast

## Cast an ability against an array of resolved targets.
## Caller is responsible for slot consumption and AoE target resolution.
## Projectile spells assign darts/rays to targets in order, cycling: [a] puts every dart
## on a; [a, a, b] puts two on a and one on b.
## Returns Array of event Dicts (one per target, or per projectile).
func cast(caster: Combatant, ability: AbilityData, targets: Array,
		cast_at_level: int = -1,
		concentration: ConcentrationTracker = null, opts: Dictionary = {}) -> Array:
	var events: Array = []

	if not before_cast(caster, ability, targets):
		return events

	if ability.concentration and concentration != null:
		concentration.begin(caster.stats, ability)

	var level := cast_at_level if cast_at_level >= ability.slot_level else ability.slot_level
	_cast_damage = -1
	_in_cast = true
	_empowered = false
	if not ability.summon.is_empty():
		opts = opts.duplicate()
		opts["within_5ft"] = true  # the force attacks a creature within 5 feet of itself
	var limit := ability.target_limit(level)
	if limit > 0 and targets.size() > limit:
		targets = targets.slice(0, limit)

	if ability.projectiles > 0:
		events = _resolve_projectiles(caster, ability, targets, level, opts)
	else:
		for target: Combatant in targets:
			var ev := {}
			if ability.is_healing() and not ability.has_damage():
				ev = _resolve_heal(caster, ability, target, level, opts)
			elif ability.uses_save:
				ev = _resolve_save_spell(caster, ability, target, level, int(opts.get("save_d20", -1)), opts)
			elif not ability.has_damage():
				ev = _resolve_buff(caster, ability, target, level)
			else:
				ev = _resolve_attack_spell(caster, ability, target, level, int(opts.get("d20", -1)), opts)
				if not ability.summon.is_empty():
					ev["by_summon"] = true
			events.append(ev)
			if concentration != null and ability.concentration:
				concentration.track(target)

	if not ability.summon.is_empty():
		var sm := SpellSummon.create(caster, ability, level)
		if concentration != null and ability.concentration:
			concentration.track_summon(sm)
		events.append({"type": "summon", "ability": ability.ability_name, "summon": sm})

	var self_ev := _apply_self_effects(caster, ability, level)
	if not self_ev.is_empty():
		events.append(self_ev)
	if ability.is_healing() and caster.kit != null and level > 0:
		var others := targets.any(func(t): return t != caster)
		var regained := caster.kit.blessed_healer(caster, level, others)
		if regained > 0:
			events.append({"type": "blessed_healer", "target": caster.name, "healed": regained})

	_in_cast = false
	_cast_damage = -1
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

## Roll spell damage dice. Override for meta-magic (Empowered, Maximise, etc.).
func roll_damage(ability: AbilityData, caster_level: int,
		cast_at_level: int) -> int:
	return ability.roll_damage(caster_level, cast_at_level)

## Apply damage to a target. Override for reactions, immunities, etc. is_crit: the
## damage is from a Critical Hit (Undead Fortitude can't save against it).
func apply_damage(target: Combatant, amount: int,
		damage_type: SRD.DamageType, is_crit: bool = false) -> int:
	return target.take_damage(amount, damage_type, is_crit)

## A summoned force's later attack (Spiritual Weapon: "As a Bonus Action on your later
## turns, you can move the force up to 20 feet and repeat the attack against a creature
## within 5 feet of it"). The game moves summon.position and spends the Bonus Action.
func summon_strike(summon: SpellSummon, target: Combatant, opts: Dictionary = {}) -> Dictionary:
	if not summon.active:
		return {"type": "spell_attack", "ability": summon.ability.ability_name, "target": target.name,
			"hit": false, "skipped": "summon gone"}
	var o := opts.duplicate()
	o["within_5ft"] = true  # it attacks a creature within 5 feet of itself
	_cast_damage = -1
	var ev := _resolve_attack_spell(summon.caster, summon.ability, target, summon.level, int(o.get("d20", -1)), o)
	ev["by_summon"] = true
	after_cast(summon.caster, summon.ability, [ev])
	return ev

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
		fixed_d20: int = -1, opts: Dictionary = {}) -> Dictionary:
	var dc := ability.spell_save_dc(caster.stats) + caster.effects.total("spell_dc_bonus")
	var saved := false
	var auto := ""
	if ability.immune_if.any(func(c): return c in target.condition_immunities):
		saved = true; auto = "immune"
	elif target.name in opts.get("sculpted", []):
		saved = true; auto = "sculpted"
	elif target.conditions.auto_fails_str_dex_saves() and \
			ability.save_ability in [SRD.Ability.STRENGTH, SRD.Ability.DEXTERITY]:
		saved = false; auto = "auto_fail"
	else:
		# Bless and similar dice add to the save: fold them into the DC the hook sees
		# Cover adds +2 / +5 to Dexterity saves against an effect from the other side
		var cover_bonus := 0
		if ability.save_ability == SRD.Ability.DEXTERITY:
			cover_bonus = SRDRules.cover_ac_bonus(int(_per_target(opts, "cover", target, SRD.Cover.NONE)))
		saved = resolve_save(target.stats, dc - target.effects.roll_bonus("save") - cover_bonus,
			ability.save_ability, fixed_d20)
	var dmg := 0
	var dealt := 0
	if ability.has_damage():
		var raw_dmg := _shared_damage(caster, ability, cast_at_level, opts)
		dmg = _apply_save_effect(raw_dmg, saved, ability.save_effect)
		if auto == "sculpted" and ability.save_effect == SRD.SaveEffect.HALF:
			dmg = 0  # Sculpt Spells: no damage where a save would halve it
		elif _has_evasion(target, ability):
			dmg = 0 if saved else raw_dmg / 2
		elif saved and ability.slot_level == 0 and _kit_has(caster, "potent-cantrip"):
			dmg = raw_dmg / 2  # Potent Cantrip: half damage on a successful save
		if dmg > 0:
			dealt = apply_damage(target, dmg, ability.damage_type)
	var uf := target.last_undead_fortitude if dmg > 0 else {}
	var ev := {
		"type": "spell_save",
		"ability": ability.ability_name,
		"target": target.name,
		"dc": dc,
		"saved": saved,
		"damage_rolled": dmg,
		"damage_dealt": dealt,
		"target_hp_after": target.stats.current_hp,
	}
	if auto != "":
		ev["auto"] = auto
	if not uf.is_empty():
		ev["undead_fortitude"] = uf
	if not saved:
		_apply_effects(caster, ability, target, "fail", ev, dc)
	return ev

func _resolve_attack_spell(caster: Combatant, ability: AbilityData,
		target: Combatant, cast_at_level: int,
		fixed_d20: int = -1, opts: Dictionary = {}) -> Dictionary:
	var ev := {}
	var o := opts.duplicate()
	if caster.effects.has_type("spell_attack_advantage"):
		o["advantage"] = true  # Innate Sorcery
	if fixed_d20 >= 1:
		o["d20"] = fixed_d20
	var ranged := ability.is_ranged_attack()
	var near := _per_target(opts, "within_5ft", target, null)
	if near != null:
		o["within_5ft"] = bool(near)
	var mode := AttackResolver.roll_mode(caster, target, ranged, o, ev)
	var rolls := AttackResolver.roll_d20s(mode, o)
	var d20: int = rolls[0] if rolls.size() == 1 else (rolls.max() if mode > 0 else rolls.min())
	var atk_bonus := ability.spell_attack_bonus(caster.stats)
	var bless := caster.effects.roll_bonus("attack")
	caster.effects.made_attack()
	var cover := int(_per_target(opts, "cover", target, SRD.Cover.NONE))
	var ac := target.armor_class + SRDRules.cover_ac_bonus(cover)
	var crit := SRDRules.is_critical_hit(d20)
	var miss := SRDRules.is_critical_miss(d20)
	var hit := crit or (not miss and SRDRules.attack_hits(d20, atk_bonus + bless, ac))
	if hit and not crit and target.conditions.crit_from_within_5ft() \
			and AttackResolver.is_within_5ft(caster, target, ranged, o):
		crit = true
		ev["auto_crit"] = true
	var dmg := 0; var dealt := 0
	if ability.has_damage() and (hit or (ability.slot_level == 0 and _kit_has(caster, "potent-cantrip"))):
		dmg = _spell_dice(caster, ability, cast_at_level, opts)
		if crit:
			dmg += _spell_dice(caster, ability, cast_at_level, opts)  # crits roll the dice twice
		dmg = maxi(0, dmg + _flat_damage(caster, ability))
		if not hit:
			dmg /= 2  # Potent Cantrip: half damage on a miss, no other effect
		dealt = apply_damage(target, dmg, ability.damage_type, crit)
		if not target.last_undead_fortitude.is_empty():
			ev["undead_fortitude"] = target.last_undead_fortitude
	ev.merge({"target_ac": ac, "cover": cover, "attack_bonus": atk_bonus})
	ev.merge({
		"type": "spell_attack",
		"ability": ability.ability_name,
		"target": target.name,
		"d20": d20, "rolls": rolls, "hit": hit, "crit": crit,
		"advantage": mode > 0, "disadvantage": mode < 0, "bonus_dice": bless,
		"damage_rolled": dmg,
		"damage_dealt": dealt,
		"target_hp_after": target.stats.current_hp,
	})
	if hit:
		_apply_effects(caster, ability, target, "hit", ev)
	return ev

## opts[key] may be one value for every target or a {target name: value} map.
static func _per_target(opts: Dictionary, key: String, target: Combatant, default: Variant) -> Variant:
	if not opts.has(key):
		return default
	var v: Variant = opts[key]
	if v is Dictionary:
		return v.get(target.name, default)
	return v

## Darts (auto-hit, one damage roll each) and rays (one attack roll each).
func _resolve_projectiles(caster: Combatant, ability: AbilityData, targets: Array,
		level: int, opts: Dictionary) -> Array:
	var events := []
	if targets.is_empty():
		return events
	var n := ability.projectile_count(level)
	for i in n:
		var target: Combatant = targets[i % targets.size()]
		if ability.auto_hit:
			var dmg := 0
			var dealt := 0
			var blocked := target.effects.is_immune_to_spell(ability.spell_id)
			if not blocked:
				dmg = maxi(0, _roll_dice(ability.damage_die_count, ability.damage_die_sides, opts) \
					+ _flat_damage(caster, ability))
				dealt = apply_damage(target, dmg, ability.damage_type)
			var ev := {"type": "spell_projectile", "ability": ability.ability_name, "target": target.name,
				"index": i, "hit": not blocked, "damage_rolled": dmg, "damage_dealt": dealt,
				"target_hp_after": target.stats.current_hp}
			if blocked:
				ev["blocked"] = true
			events.append(ev)
		else:
			var ev := _resolve_attack_spell(caster, ability, target, level, int(opts.get("d20", -1)), opts)
			ev["type"] = "spell_projectile"
			ev["index"] = i
			events.append(ev)
	return events

func _resolve_heal(caster: Combatant, ability: AbilityData, target: Combatant,
		level: int, opts: Dictionary) -> Dictionary:
	var count := ability.heal_dice(level)
	var amount := 0
	if caster.kit != null and caster.kit.has_feature("supreme-healing"):
		amount = count * ability.heal_die_sides
	else:
		amount = _roll_dice(count, ability.heal_die_sides, opts)
	amount += ability.heal_bonus + ability.upcast_heal_flat * maxi(0, level - ability.slot_level)
	if ability.heal_add_modifier:
		amount += caster.stats.ability_modifier(ability.casting_ability)
	if caster.kit != null and ability.slot_level > 0:
		amount += caster.kit.healing_bonus(level)  # Disciple of Life
	var healed := heal(target, maxi(0, amount))
	var ev := {"type": "spell_heal", "ability": ability.ability_name, "target": target.name,
		"amount": amount, "healed": healed, "target_hp_after": target.stats.current_hp}
	_apply_effects(caster, ability, target, "apply", ev)
	return ev

## Restore HP; a creature at 0 HP (not dead) regains consciousness.
func heal(target: Combatant, amount: int) -> int:
	if target.is_dead or amount <= 0:
		return 0
	if target.stats.current_hp <= 0:
		target.stats.current_hp = 0
		target.death_saves.revive()
		target.conditions.remove(SRD.Condition.UNCONSCIOUS)
		var before := target.stats.current_hp
		target.stats.current_hp = mini(target.stats.max_hp, amount)
		return target.stats.current_hp - before
	return target.stats.heal(amount)

func _resolve_buff(caster: Combatant, ability: AbilityData, target: Combatant, _level: int) -> Dictionary:
	var ev := {"type": "spell_effect", "ability": ability.ability_name, "target": target.name}
	_apply_effects(caster, ability, target, "apply", ev)
	return ev

## Effects marked "self" land on the caster once per cast (Shield, Misty Step).
func _apply_self_effects(caster: Combatant, ability: AbilityData, _level: int) -> Dictionary:
	var applied := []
	var ev := {"type": "spell_self", "ability": ability.ability_name, "target": caster.name}
	for tmpl: Dictionary in ability.effects:
		if not tmpl.get("self", false):
			continue
		if tmpl.type == "teleport":
			ev["teleport_feet"] = int(tmpl.feet)  # the game moves the caster
			applied.append("teleport")
			continue
		var e := SRDEffects.instantiate(tmpl, _effect_id(ability, tmpl), caster, caster)
		e.erase("self")
		caster.effects.add(e)
		applied.append(tmpl.type)
	if applied.is_empty():
		return {}
	ev["effects"] = applied
	return ev

## Apply a spell's effect templates for one trigger ("hit", "fail", "apply") to a target.
func _apply_effects(caster: Combatant, ability: AbilityData, target: Combatant,
		trigger: String, ev: Dictionary, dc: int = -1) -> void:
	var applied := []
	for tmpl: Dictionary in ability.effects:
		if tmpl.get("on", "") != trigger or tmpl.get("self", false):
			continue
		match str(tmpl.type):
			"push":
				ev["push_feet"] = int(tmpl.feet)  # the game moves the target
				applied.append("push")
				continue
			"condition":
				if str(tmpl.condition) in target.condition_immunities:
					continue
			"temp_hp":  # False Life
				var td := SRDContent.parse_dice(str(tmpl.dice))
				target.stats.add_temp_hp(_roll_dice(int(td.count), int(td.sides), {}) + int(td.bonus))
				applied.append("temp_hp")
				continue
		var e := SRDEffects.instantiate(tmpl, _effect_id(ability, tmpl), caster, target)
		if ability.concentration:
			e["concentration"] = caster.name
		if e.has("repeat_save"):
			e["save_dc"] = dc if dc > 0 else ability.spell_save_dc(caster.stats)
			e["save_ability"] = SRD.ABILITY_ABBREV[int(ability.save_ability)].to_lower()
		target.effects.add(e)
		applied.append(tmpl.type)
	if not applied.is_empty():
		ev["effects"] = applied

func _effect_id(ability: AbilityData, tmpl: Dictionary) -> String:
	var base := ability.spell_id if ability.spell_id != "" else ability.ability_name.to_lower()
	return "%s-%s" % [base, tmpl.type]

## Flat damage on top of the dice: the spell's own bonus, the spellcasting modifier when the
## spell adds it, Potent Spellcasting (Cleric cantrips), and Empowered Evocation.
func _flat_damage(caster: Combatant, ability: AbilityData) -> int:
	var flat := ability.damage_bonus
	if ability.damage_add_modifier:
		flat += caster.stats.ability_modifier(ability.casting_ability)
	if caster.kit != null:
		if ability.slot_level == 0 and caster.kit.class_slug in ability.tags:
			flat += caster.kit.cantrip_damage_bonus(caster, ability)
		# Elemental Affinity: Charisma modifier to one damage roll of a spell of the type
		if caster.kit.has_feature("elemental-affinity") and not _empowered \
				and SRDContent.damage_type_from(str(caster.kit.options.get("elemental_affinity", "fire"))) == ability.damage_type:
			flat += caster.stats.ability_modifier(SRD.Ability.CHARISMA)
			_empowered = _in_cast
		# Empowered Evocation: Int modifier to one damage roll of the spell
		if caster.kit.has_feature("empowered-evocation") and "evocation" in ability.tags \
				and "wizard" in ability.tags and not _empowered:
			flat += caster.stats.ability_modifier(SRD.Ability.INTELLIGENCE)
			_empowered = _in_cast
	return flat

## One damage roll per cast, shared by every target of an area spell.
func _shared_damage(caster: Combatant, ability: AbilityData, level: int, opts: Dictionary) -> int:
	if _cast_damage < 0:
		_cast_damage = _spell_dice(caster, ability, level, opts)
		_cast_damage = maxi(0, _cast_damage + _flat_damage(caster, ability))
	var shared := _cast_damage
	if not _in_cast:
		_cast_damage = -1  # called directly (tests, game hooks): roll fresh every time
	return shared

## The spell's damage dice at this slot level (cantrips scale with caster level); average
## dice when opts.average, otherwise the roll_damage hook.
func _spell_dice(caster: Combatant, ability: AbilityData, level: int, opts: Dictionary) -> int:
	if opts.get("average", false):
		var n := ability.upcasted_damage_dice(level) if level > ability.slot_level and ability.slot_level > 0 \
			else ability.base_damage_dice(caster.stats.level)
		return n * ((ability.damage_die_sides + 1) / 2)
	if int(opts.get("empowered", 0)) > 0:
		return _empowered_dice(ability, caster, level, int(opts.empowered))
	return roll_damage(ability, caster.stats.level, level)

## Empowered Spell: reroll up to `rerolls` of the lowest dice and take the new numbers.
func _empowered_dice(ability: AbilityData, caster: Combatant, level: int, rerolls: int) -> int:
	var n := ability.upcasted_damage_dice(level) if level > ability.slot_level and ability.slot_level > 0 \
		else ability.base_damage_dice(caster.stats.level)
	var dice := []
	for i in n:
		dice.append(Dice.roll(ability.damage_die_sides))
	dice.sort()
	for i in mini(rerolls, dice.size()):
		dice[i] = Dice.roll(ability.damage_die_sides)
	return dice.reduce(func(a, b): return a + b, 0)

func _roll_dice(count: int, sides: int, opts: Dictionary) -> int:
	if opts.get("average", false):
		return count * ((sides + 1) / 2)
	return Dice.roll_nd(count, sides)

func _has_evasion(target: Combatant, ability: AbilityData) -> bool:
	return target.kit != null and target.kit.has_feature("evasion") \
		and ability.save_ability == SRD.Ability.DEXTERITY and ability.save_effect == SRD.SaveEffect.HALF \
		and not target.conditions.is_incapacitated()

func _kit_has(c: Combatant, key: String) -> bool:
	return c.kit != null and c.kit.has_feature(key)

func _apply_save_effect(dmg: int, saved: bool,
		effect: SRD.SaveEffect) -> int:
	if not saved:
		return dmg
	match effect:
		SRD.SaveEffect.HALF: return dmg / 2
		SRD.SaveEffect.NONE: return 0
	return dmg
