class_name Dice
extends RefCounted

static func roll(sides: int) -> int:
	return randi_range(1, sides)

static func roll_d4() -> int: return roll(4)
static func roll_d6() -> int: return roll(6)
static func roll_d8() -> int: return roll(8)
static func roll_d10() -> int: return roll(10)
static func roll_d12() -> int: return roll(12)
static func roll_d20() -> int: return roll(20)
static func roll_d100() -> int: return roll(100)

static func roll_with_advantage(sides: int) -> int:
	return max(roll(sides), roll(sides))

static func roll_with_disadvantage(sides: int) -> int:
	return min(roll(sides), roll(sides))

static func roll_nd(count: int, sides: int) -> int:
	var total := 0
	for i in count:
		total += roll(sides)
	return total
