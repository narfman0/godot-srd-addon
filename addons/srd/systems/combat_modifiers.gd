class_name CombatModifiers
extends RefCounted

## Returns true if a ranged attack has disadvantage due to melee proximity.
## Per SRD: attacker or target within 5ft of a hostile → disadvantage.
static func ranged_into_melee_disadvantage(attacker_in_melee: bool,
		target_in_melee: bool = false) -> bool:
	return attacker_in_melee or target_in_melee

## Movement cost accounting for difficult terrain (costs 2× to enter).
## Pass the feet you want to move and whether the destination is difficult terrain.
static func movement_cost(feet: int, in_difficult_terrain: bool) -> int:
	return feet * 2 if in_difficult_terrain else feet

## Returns true if the attack roll has disadvantage from lighting.
## attacker_can_see = false when attacker is blinded or target is invisible.
## target_can_see   = false when target is blinded or attacker is invisible.
static func lighting_attack_disadvantage(attacker_can_see_target: bool) -> bool:
	return not attacker_can_see_target

static func lighting_attack_advantage(target_can_see_attacker: bool) -> bool:
	return not target_can_see_attacker

## Cover AC bonus.
static func cover_bonus(cover: SRD.Cover) -> int:
	return SRDRules.cover_ac_bonus(cover)
