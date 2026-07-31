## SRD ability score generation: standard array, point buy, and rolled stats.
class_name SRDAbilityScores
extends RefCounted

const STANDARD_ARRAY: Array[int] = [15, 14, 13, 12, 10, 8]

const POINT_BUY_BUDGET := 27
const POINT_BUY_MIN := 8
const POINT_BUY_MAX := 15
## Cumulative cost to buy a score up from 8.
const POINT_BUY_COST := {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9}

## Cost of a single score under point buy, or -1 if out of range.
static func point_buy_cost(score: int) -> int:
	return POINT_BUY_COST.get(score, -1)

## Total point-buy cost of six scores, or -1 if any score is out of range.
static func point_buy_total(scores: Array) -> int:
	var total := 0
	for s in scores:
		var cost := point_buy_cost(s)
		if cost < 0:
			return -1
		total += cost
	return total

## True if six scores form a legal point-buy spend (within budget).
static func point_buy_valid(scores: Array) -> bool:
	var total := point_buy_total(scores)
	return total >= 0 and total <= POINT_BUY_BUDGET

## Roll one ability score: 4d6, drop the lowest die.
static func roll_score() -> int:
	var dice: Array[int] = []
	for i in 4:
		dice.append(Dice.roll(6))
	dice.sort()
	return dice[1] + dice[2] + dice[3]

## Roll a full array of six scores, sorted descending.
static func roll_array() -> Array[int]:
	var scores: Array[int] = []
	for i in 6:
		scores.append(roll_score())
	scores.sort()
	scores.reverse()
	return scores
