class_name TwoWeaponFighting
extends RefCounted

## Both weapons must be Light for standard two-weapon fighting.
static func can_use(main_hand: WeaponData, off_hand: WeaponData) -> bool:
	if main_hand == null or off_hand == null:
		return false
	return main_hand.has_property(SRD.WeaponProperty.LIGHT) \
		and off_hand.has_property(SRD.WeaponProperty.LIGHT)

## Roll off-hand damage. Without the Two-Weapon Fighting style, ability modifier
## is NOT added (unless negative — negative modifier always applies per SRD).
static func off_hand_damage(weapon: WeaponData, char: CharacterStats,
		has_fighting_style: bool = false, fixed_roll: int = -1) -> int:
	var dice := fixed_roll if fixed_roll >= 1 else Dice.roll_nd(weapon.die_count, weapon.die_sides)
	if has_fighting_style:
		return dice + weapon._damage_mod(char)
	else:
		var mod := weapon._damage_mod(char)
		return dice + mini(0, mod)  # add modifier only if negative

## Off-hand attack bonus (same as main hand but no modifier restriction on attack roll).
static func off_hand_attack_bonus(weapon: WeaponData, char: CharacterStats,
		proficient: bool) -> int:
	return weapon.attack_bonus(char, proficient)

## Attempt off-hand attack. Returns attack event dict (same format as BattleSimulator).
static func resolve_off_hand_attack(attacker: Combatant, target: Combatant,
		off_hand_weapon: WeaponData, proficient: bool,
		has_fighting_style: bool = false,
		fixed_d20: int = -1) -> Dictionary:
	if not attacker.action_economy.use_bonus_action():
		return { "hit": false, "reason": "no_bonus_action" }
	if not can_use(attacker.weapon, off_hand_weapon):
		return { "hit": false, "reason": "not_light_weapons" }

	var d20 := fixed_d20 if fixed_d20 >= 1 else Dice.roll_d20()
	var atk_bonus := off_hand_attack_bonus(off_hand_weapon, attacker.stats, proficient)
	var crit := SRDRules.is_critical_hit(d20)
	var miss := SRDRules.is_critical_miss(d20)
	var hit := false
	if crit: hit = true
	elif miss: hit = false
	else: hit = SRDRules.attack_hits(d20, atk_bonus, target.armor_class)

	if not hit:
		return { "type": "off_hand_attack", "hit": false, "crit": false, "d20": d20 }

	var dmg := off_hand_damage(off_hand_weapon, attacker.stats, has_fighting_style)
	if crit:
		dmg += Dice.roll_nd(off_hand_weapon.die_count, off_hand_weapon.die_sides)
	var dealt := DamageResolver.apply(target.stats, dmg, off_hand_weapon.damage_type)
	return {
		"type": "off_hand_attack", "hit": true, "crit": crit,
		"d20": d20, "damage": dmg, "damage_dealt": dealt,
		"target_hp_after": target.stats.current_hp,
	}
