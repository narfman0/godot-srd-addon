class_name SRDExperience
extends RefCounted

# XP required to reach each level (index 0 = level 1 threshold)
const XP_THRESHOLDS: Array[int] = [
	0,       # level 1
	300,     # level 2
	900,     # level 3
	2700,    # level 4
	6500,    # level 5
	14000,   # level 6
	23000,   # level 7
	34000,   # level 8
	48000,   # level 9
	64000,   # level 10
	85000,   # level 11
	100000,  # level 12
	120000,  # level 13
	140000,  # level 14
	165000,  # level 15
	195000,  # level 16
	225000,  # level 17
	265000,  # level 18
	305000,  # level 19
	355000,  # level 20
]

static func xp_for_level(level: int) -> int:
	return XP_THRESHOLDS[clampi(level, 1, 20) - 1]

static func level_for_xp(xp: int) -> int:
	for i in range(19, -1, -1):
		if xp >= XP_THRESHOLDS[i]:
			return i + 1
	return 1

## Add XP to a character. Returns true if they levelled up.
static func add_xp(char: CharacterStats, amount: int) -> bool:
	var old_level := level_for_xp(char.xp)
	char.xp += amount
	var new_level := level_for_xp(char.xp)
	return new_level > old_level
