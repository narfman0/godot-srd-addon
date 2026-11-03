## Worn gear's rules on a Combatant. A game keeps items as data; each item's `mods` is a plain
## Dictionary, and apply() resets the combatant to its bare values and folds in every mod.
##
## mods (all optional):
##   ac, attack, damage        flat bonuses (attack and damage are the wielded weapon's)
##   unarmored_ac              AC bonus only while wearing no armor and no shield (Bracers of Defense)
##   save                      bonus to every saving throw
##   spell_attack, spell_dc    bonus to spell attacks / save DC
##   speed                     feet added
##   initiative                bonus to Initiative
##   set_ability               {"str": 19}: the score becomes this unless already higher
##   ability                   {"con": 2}: added to the score
##   resist, immune            damage type names
##   condition_immune          condition names
##   extra_damage              {dice: "1d6", type: "fire"} on every weapon hit
##   crit_immune               Critical Hits against the wearer become normal hits (Adamantine)
##   heavy_stealth             armor without Stealth Disadvantage (Mithral)
##   strength_free             armor with no Strength requirement (Mithral)
class_name ItemEffects
extends RefCounted

const GEAR_RIDER := "gear"

## Reset to the unmodified Combatant, then apply each mods Dictionary in order.
static func apply(c: Combatant, mods_list: Array) -> void:
	if c.gear_base.is_empty():
		_capture(c)
	_restore(c)
	for m: Dictionary in mods_list:
		_apply_one(c, m)
	# A changed Constitution changes Hit Points retroactively
	var con_delta: int = c.stats.ability_modifier(SRD.Ability.CONSTITUTION) - int(c.gear_base.con_mod)
	var old_max: int = c.stats.max_hp
	c.stats.max_hp = int(c.gear_base.max_hp) + con_delta * c.stats.level
	if c.stats.current_hp > 0:
		c.stats.current_hp = clampi(c.stats.current_hp + c.stats.max_hp - old_max, 1, c.stats.max_hp)

static func _capture(c: Combatant) -> void:
	var s := c.stats
	c.gear_base = {
		"scores": [s.strength, s.dexterity, s.constitution, s.intelligence, s.wisdom, s.charisma],
		"max_hp": s.max_hp, "con_mod": s.ability_modifier(SRD.Ability.CONSTITUTION), "speed": s.speed,
		"resist": s.resistance_mask, "immune": s.immunity_mask,
		"conditions": c.condition_immunities.duplicate(), "riders": c.hit_riders.duplicate(),
		"attack": c.bonus_attack, "damage": c.bonus_damage, "ac": c.bonus_ac,
		"initiative": c.initiative_extra,
	}

static func _restore(c: Combatant) -> void:
	var b := c.gear_base
	var s := c.stats
	for i in 6:
		s.set_ability(i as SRD.Ability, int(b.scores[i]))
	s.speed = int(b.speed)
	s.resistance_mask = int(b.resist)
	s.immunity_mask = int(b.immune)
	s.save_bonus = 0
	s.spell_dc_bonus = 0
	s.spell_attack_mod = 0
	c.condition_immunities.assign(b.conditions)
	c.hit_riders = b.riders.duplicate()
	c.bonus_attack = int(b.attack)
	c.bonus_damage = int(b.damage)
	c.bonus_ac = int(b.ac)
	c.initiative_extra = int(b.initiative)
	c.crit_immune = false
	c.equipment.unarmored_bonus = 0
	c.equipment.ignore_armor_penalties = false

static func _apply_one(c: Combatant, m: Dictionary) -> void:
	var s := c.stats
	c.bonus_ac += int(m.get("ac", 0))
	c.bonus_attack += int(m.get("attack", 0))
	c.bonus_damage += int(m.get("damage", 0))
	c.equipment.unarmored_bonus += int(m.get("unarmored_ac", 0))
	s.save_bonus += int(m.get("save", 0))
	s.spell_attack_mod += int(m.get("spell_attack", 0))
	s.spell_dc_bonus += int(m.get("spell_dc", 0))
	s.speed += int(m.get("speed", 0))
	c.initiative_extra += int(m.get("initiative", 0))
	var setv: Dictionary = m.get("set_ability", {})
	for k in setv:
		var ab := SRDContent.ability_from(str(k)) as SRD.Ability
		s.set_ability(ab, maxi(s.get_ability(ab), int(setv[k])))
	var addv: Dictionary = m.get("ability", {})
	for k in addv:
		var ab := SRDContent.ability_from(str(k)) as SRD.Ability
		s.set_ability(ab, s.get_ability(ab) + int(addv[k]))
	for t in m.get("resist", []):
		s.set_resistance(SRDContent.damage_type_from(str(t)), true)
	for t in m.get("immune", []):
		s.set_immunity(SRDContent.damage_type_from(str(t)), true)
	for k in m.get("condition_immune", []):
		if not str(k) in c.condition_immunities:
			c.condition_immunities.append(str(k))
	if m.has("extra_damage"):
		var e: Dictionary = m.extra_damage
		c.hit_riders.append({"name": str(e.get("name", "Magic")), "dice": str(e.dice), "type": str(e.type)})
	if m.get("crit_immune", false):
		c.crit_immune = true
	if m.get("heavy_stealth", false) or m.get("strength_free", false):
		c.equipment.ignore_armor_penalties = true
