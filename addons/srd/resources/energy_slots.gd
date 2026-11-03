class_name EnergySlots
extends Resource

# slots_max[i] and slots_remaining[i] for slot levels 1-9 (index 0 = level 1)
var slots_max: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var slots_remaining: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]

func _init() -> void:
	slots_max.resize(9)
	slots_remaining.resize(9)

## Use a slot at the given level (1-9). Returns false if no slot available.
func use_slot(level: int) -> bool:
	assert(level >= 1 and level <= 9, "Slot level must be 1-9")
	var idx := level - 1
	if slots_remaining[idx] <= 0:
		return false
	slots_remaining[idx] -= 1
	return true

## Recover a number of slots at the given level.
func recover_slot(level: int, count: int = 1) -> void:
	var idx := level - 1
	slots_remaining[idx] = mini(slots_remaining[idx] + count, slots_max[idx])

## Restore all slots to maximum (long rest).
func recover_all() -> void:
	for i in 9:
		slots_remaining[i] = slots_max[i]

func slots_remaining_at(level: int) -> int:
	return slots_remaining[level - 1]

func slots_max_at(level: int) -> int:
	return slots_max[level - 1]

func has_slot(level: int) -> bool:
	return slots_remaining[level - 1] > 0

# --- Predefined slot tables (5e SRD values) ---

## Full caster table (Wizard/Psion progression).
static func make_full_caster(char_level: int) -> EnergySlots:
	var s := EnergySlots.new()
	# [l1, l2, l3, l4, l5, l6, l7, l8, l9]
	const TABLE: Array[Array] = [
		[2,0,0,0,0,0,0,0,0],   # level 1
		[3,0,0,0,0,0,0,0,0],   # level 2
		[4,2,0,0,0,0,0,0,0],   # level 3
		[4,3,0,0,0,0,0,0,0],   # level 4
		[4,3,2,0,0,0,0,0,0],   # level 5
		[4,3,3,0,0,0,0,0,0],   # level 6
		[4,3,3,1,0,0,0,0,0],   # level 7
		[4,3,3,2,0,0,0,0,0],   # level 8
		[4,3,3,3,1,0,0,0,0],   # level 9
		[4,3,3,3,2,0,0,0,0],   # level 10
		[4,3,3,3,2,1,0,0,0],   # level 11
		[4,3,3,3,2,1,0,0,0],   # level 12
		[4,3,3,3,2,1,1,0,0],   # level 13
		[4,3,3,3,2,1,1,0,0],   # level 14
		[4,3,3,3,2,1,1,1,0],   # level 15
		[4,3,3,3,2,1,1,1,0],   # level 16
		[4,3,3,3,2,1,1,1,1],   # level 17
		[4,3,3,3,3,1,1,1,1],   # level 18
		[4,3,3,3,3,2,1,1,1],   # level 19
		[4,3,3,3,3,2,2,1,1],   # level 20
	]
	var row: Array = TABLE[clampi(char_level, 1, 20) - 1]
	for i in 9:
		s.slots_max[i] = row[i]
		s.slots_remaining[i] = row[i]
	return s

## Pact Magic (Warlock): every slot is the same level; all recover on a short rest.
static func make_pact_caster(char_level: int) -> EnergySlots:
	var s := EnergySlots.new()
	# [slot count, slot level] per character level
	const TABLE: Array[Array] = [
		[1,1], [2,1], [2,2], [2,2], [2,3], [2,3], [2,4], [2,4], [2,5], [2,5],
		[3,5], [3,5], [3,5], [3,5], [3,5], [3,5], [4,5], [4,5], [4,5], [4,5],
	]
	var row: Array = TABLE[clampi(char_level, 1, 20) - 1]
	s.slots_max[row[1] - 1] = row[0]
	s.slots_remaining[row[1] - 1] = row[0]
	return s

## Half caster table (Paladin/Warden — rounds down).
static func make_half_caster(char_level: int) -> EnergySlots:
	var s := EnergySlots.new()
	const TABLE: Array[Array] = [
		[0,0,0,0,0,0,0,0,0],   # level 1
		[2,0,0,0,0,0,0,0,0],   # level 2
		[3,0,0,0,0,0,0,0,0],   # level 3
		[3,0,0,0,0,0,0,0,0],   # level 4
		[4,2,0,0,0,0,0,0,0],   # level 5
		[4,2,0,0,0,0,0,0,0],   # level 6
		[4,3,0,0,0,0,0,0,0],   # level 7
		[4,3,0,0,0,0,0,0,0],   # level 8
		[4,3,2,0,0,0,0,0,0],   # level 9
		[4,3,2,0,0,0,0,0,0],   # level 10
		[4,3,3,0,0,0,0,0,0],   # level 11
		[4,3,3,0,0,0,0,0,0],   # level 12
		[4,3,3,1,0,0,0,0,0],   # level 13
		[4,3,3,1,0,0,0,0,0],   # level 14
		[4,3,3,2,0,0,0,0,0],   # level 15
		[4,3,3,2,0,0,0,0,0],   # level 16
		[4,3,3,3,1,0,0,0,0],   # level 17
		[4,3,3,3,1,0,0,0,0],   # level 18
		[4,3,3,3,2,0,0,0,0],   # level 19
		[4,3,3,3,2,0,0,0,0],   # level 20
	]
	var row: Array = TABLE[clampi(char_level, 1, 20) - 1]
	for i in 9:
		s.slots_max[i] = row[i]
		s.slots_remaining[i] = row[i]
	return s

## Third caster (Rogue/Ghost Arcane Trickster equivalent).
static func make_third_caster(char_level: int) -> EnergySlots:
	var s := EnergySlots.new()
	const TABLE: Array[Array] = [
		[0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0],
		[2,0,0,0,0,0,0,0,0],
		[3,0,0,0,0,0,0,0,0],
		[3,0,0,0,0,0,0,0,0],
		[3,0,0,0,0,0,0,0,0],
		[4,2,0,0,0,0,0,0,0],
		[4,2,0,0,0,0,0,0,0],
		[4,2,0,0,0,0,0,0,0],
		[4,3,0,0,0,0,0,0,0],
		[4,3,0,0,0,0,0,0,0],
		[4,3,0,0,0,0,0,0,0],
		[4,3,2,0,0,0,0,0,0],
		[4,3,2,0,0,0,0,0,0],
		[4,3,2,0,0,0,0,0,0],
		[4,3,3,0,0,0,0,0,0],
		[4,3,3,0,0,0,0,0,0],
		[4,3,3,0,0,0,0,0,0],
		[4,3,3,1,0,0,0,0,0],
		[4,3,3,1,0,0,0,0,0],
	]
	var row: Array = TABLE[clampi(char_level, 1, 20) - 1]
	for i in 9:
		s.slots_max[i] = row[i]
		s.slots_remaining[i] = row[i]
	return s
