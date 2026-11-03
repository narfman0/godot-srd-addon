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
	"fighting-style": true, "second-wind": true, "action-surge": true, "tactical-mind": true,
	"tactical-shift": true, "indomitable": true, "studied-attacks": true, "tactical-master": true,
	"improved-critical": true, "superior-critical": true, "remarkable-athlete": true,
	# Rogue
	"sneak-attack": true, "cunning-action": true, "steady-aim": true, "uncanny-dodge": true,
	"evasion": true, "reliable-talent": true, "expertise": true,
	# Cleric
	"divine-order": true, "channel-divinity": true, "disciple-of-life": true,
	"preserve-life": true, "life-domain-spells": true, "blessed-healer": true,
	"supreme-healing": true, "blessed-strikes": true, "improved-blessed-strikes": true,
	"sear-undead": true,
	# Wizard
	"arcane-recovery": true, "potent-cantrip": true, "empowered-evocation": true,
	"sculpt-spells": true, "overchannel": true,
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
