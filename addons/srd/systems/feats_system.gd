## Static helpers for feat effects. Feats are stored as Array[FeatData] on the
## character; this class queries and applies them without mutating FeatData itself.
class_name FeatsSystem
extends RefCounted

# ── Application (call once at character creation / level-up) ─────────────────

## Apply a feat's permanent stat changes to a character.
## If feat.on_apply is set, delegates entirely to that callable.
static func apply_stat_mods(char: CharacterStats, feat: FeatData) -> void:
	if feat.on_apply.is_valid():
		feat.on_apply.call(char)
		return
	if feat.speed_bonus != 0:
		char.speed += feat.speed_bonus
	if feat.resilient_ability >= 0:
		var ab := feat.resilient_ability as SRD.Ability
		char.set_ability(ab, mini(20, char.get_ability(ab) + 1))
		char.set_save_proficiency(ab, true)

# ── Queries (call each time the value is needed) ──────────────────────────────

## Total initiative bonus from all feats (Alert: +5).
static func initiative_bonus(feats: Array) -> int:
	var total := 0
	for f: FeatData in feats:
		total += f.initiative_bonus
	return total

## True if any feat prevents this character from being surprised.
static func cannot_be_surprised(feats: Array) -> bool:
	for f: FeatData in feats:
		if f.cannot_be_surprised:
			return true
	return false

## True if any feat grants Mobile's no-OA-after-melee-attack benefit.
static func no_oa_after_melee(feats: Array) -> bool:
	for f: FeatData in feats:
		if f.has_mobile:
			return true
	return false

## True if any feat grants advantage on CON concentration saves (War Caster).
static func war_caster_concentration(feats: Array) -> bool:
	for f: FeatData in feats:
		if f.has_war_caster:
			return true
	return false

## True if any feat allows ignoring half and three-quarters cover (Sharpshooter).
static func ignores_ranged_cover(feats: Array) -> bool:
	for f: FeatData in feats:
		if f.has_sharpshooter:
			return true
	return false

## True if any feat grants Sentinel's opportunity-attack behaviour.
static func has_sentinel(feats: Array) -> bool:
	for f: FeatData in feats:
		if f.has_sentinel:
			return true
	return false

## True if the character has Great Weapon Master.
static func has_gwm(feats: Array) -> bool:
	for f: FeatData in feats:
		if f.has_gwm:
			return true
	return false

## Does this character have a feat with this exact name?
static func has_feat(feats: Array, feat_name: String) -> bool:
	for f: FeatData in feats:
		if f.feat_name == feat_name:
			return true
	return false

# ── Power-attack modifiers (Sharpshooter / GWM -5/+10 option) ────────────────

## Attack roll modifier when player activates the power-attack option.
static func power_attack_hit_bonus(active: bool) -> int:
	return -5 if active else 0

## Damage bonus when player activates the power-attack option.
static func power_attack_damage_bonus(active: bool) -> int:
	return 10 if active else 0


## Per-long-rest Lucky point tracker. Create one per character that has Lucky.
class LuckyTracker extends RefCounted:
	const MAX_POINTS: int = 3
	var points: int = MAX_POINTS

	## Spend a luck point to reroll. Returns false if none left.
	func spend() -> bool:
		if points <= 0:
			return false
		points -= 1
		return true

	func long_rest_reset() -> void:
		points = MAX_POINTS
