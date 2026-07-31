## Static helpers — the actual class feature logic.
class_name SRDClassFeatures
extends RefCounted

# ── Soldier / Fighter ────────────────────────────────────────────────────────

## Action Surge: gain one additional Action this turn. Once per short rest.
static func action_surge(ae: ActionEconomy, tracker: ClassFeatureTracker) -> bool:
	if tracker.action_surge_used or not ae.has_action == false:
		# Allow even if current action spent — that's the point
		if tracker.action_surge_used:
			return false
	tracker.action_surge_used = true
	ae._has_action = true  # restore action
	return true

## Second Wind: bonus action, regain 1d10 + level HP.
static func second_wind(char: CharacterStats, tracker: ClassFeatureTracker,
		fixed_d10: int = -1) -> int:
	if tracker.second_wind_used:
		return 0
	tracker.second_wind_used = true
	var roll := fixed_d10 if fixed_d10 >= 1 else Dice.roll(10)
	return char.heal(roll + char.level)

# ── Ghost / Rogue ────────────────────────────────────────────────────────────

## Sneak Attack dice count (d6s) at a given level.
static func sneak_attack_dice(level: int) -> int:
	return ceili(level / 2.0)

## Returns true if Sneak Attack can apply to this attack.
static func can_sneak_attack(weapon: WeaponData, has_advantage: bool,
		ally_adjacent_to_target: bool, has_disadvantage: bool) -> bool:
	if weapon == null:
		return false
	var is_finesse := weapon.has_property(SRD.WeaponProperty.FINESSE)
	var is_ranged  := weapon.range_normal > 5
	if not (is_finesse or is_ranged):
		return false
	if has_disadvantage:
		return false
	return has_advantage or ally_adjacent_to_target

## Roll Sneak Attack extra damage.
static func roll_sneak_attack(level: int, fixed_d6: int = -1) -> int:
	var count := sneak_attack_dice(level)
	if fixed_d6 >= 1:
		return fixed_d6 * count
	return Dice.roll_nd(count, 6)

# ── Psion / Wizard ────────────────────────────────────────────────────────────

## Total slot levels recoverable by Arcane Recovery (ceil(level/2), once per day).
static func arcane_recovery_slots(level: int) -> int:
	return ceili(level / 2.0)

## Attempt Arcane Recovery. recovery_choices: Array[int] of slot levels to restore.
## Sum must not exceed arcane_recovery_slots(level) and no slot level ≥ 6.
static func arcane_recovery(slots: EnergySlots, recovery_choices: Array,
		level: int, tracker: ClassFeatureTracker) -> bool:
	if tracker.arcane_recovery_used:
		return false
	var budget := arcane_recovery_slots(level)
	var total := 0
	for sl in recovery_choices:
		if sl >= 6:
			return false  # can't recover 6th level or higher
		total += sl
	if total > budget:
		return false
	tracker.arcane_recovery_used = true
	for sl in recovery_choices:
		slots.recover_slot(sl, 1)
	return true

# ── Warden / Cleric ──────────────────────────────────────────────────────────

## Channel Divinity uses per short rest by level.
static func channel_divinity_count(class_data: ClassData, level: int) -> int:
	if class_data.class_name_str != "Warden":
		return 0
	if level >= 18: return 3
	if level >= 6:  return 2
	return 1

static func use_channel_divinity(tracker: ClassFeatureTracker) -> bool:
	if tracker.channel_divinity_uses >= tracker.channel_divinity_max:
		return false
	tracker.channel_divinity_uses += 1
	return true
