## Item prices and SRD 5.2.1 magic item rows.
##
##   SRDItems.value_of("rare")                 # 4000
##   SRDItems.value_of("rare", true)           # 2000 (consumable: half)
##   SRDItems.cost_gp("5 SP")                  # 0.5
class_name SRDItems
extends RefCounted

## "Magic Item Rarities and Values" (SRD 5.2.1). Artifacts are priceless: 0 means "not for sale".
const RARITY_VALUE := {"common": 100, "uncommon": 400, "rare": 4000, "very rare": 40000,
	"legendary": 200000, "artifact": 0}
const RARITIES := ["common", "uncommon", "rare", "very rare", "legendary", "artifact"]

## Value in GP of a magic item: halved for a consumable (a Spell Scroll's price is its own rule).
static func value_of(rarity: String, consumable: bool = false) -> int:
	var v: int = RARITY_VALUE.get(rarity.to_lower(), 0)
	return v / 2 if consumable else v

## "15 GP" / "5 SP" / "1 CP" from the equipment tables, in GP.
static func cost_gp(text: String) -> float:
	var m := RegEx.create_from_string("([\\d,]+)\\s*(CP|SP|EP|GP|PP)").search(text)
	if m == null:
		return 0.0
	var n := float(m.get_string(1).replace(",", ""))
	match m.get_string(2):
		"CP": return n / 100.0
		"SP": return n / 10.0
		"EP": return n / 2.0
		"PP": return n * 10.0
	return n

## Does `class_slug` qualify for an item's attunement requirement? by: the row's attunement_by
## ("a Wizard", "a Cleric, Druid, or Warlock", "a Spellcaster"); "" = anyone.
static func can_attune(by: String, class_slug: String, is_spellcaster: bool) -> bool:
	if by == "":
		return true
	var low := by.to_lower()
	if "spellcaster" in low:
		return is_spellcaster
	for cls in ["barbarian", "bard", "cleric", "druid", "fighter", "monk", "paladin", "ranger",
			"rogue", "sorcerer", "warlock", "wizard"]:
		if cls in low:
			return class_slug in low
	return true  # creature-kind requirements ("a Dwarf") aren't modelled
