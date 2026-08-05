extends Resource

@export var species_name: String = ""
@export var speed: int = 30
@export var asi: Dictionary = {}     # {int: int} SRD.Ability int → bonus
@export var darkvision: int = 0      # feet; 0 = none
@export var traits: Array = []       # Array[String]

func apply_to_stats(stats) -> void:
	for ab in asi:
		var cur: int = stats.get_ability(ab)
		stats.set_ability(ab, cur + asi[ab])
	if speed != 30:
		stats.speed = speed

# ── Dwarf ────────────────────────────────────────────────────────────────────

static func make_hill_dwarf():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Hill Dwarf"
	s.speed = 25
	s.asi = {2: 2, 4: 1}  # CON+2, WIS+1
	s.traits = ["Dwarven Resilience", "Dwarven Combat Training", "Dwarven Toughness"]
	return s

static func make_mountain_dwarf():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Mountain Dwarf"
	s.speed = 25
	s.asi = {2: 2, 0: 2}  # CON+2, STR+2
	s.traits = ["Dwarven Resilience", "Dwarven Combat Training", "Dwarven Armor Training"]
	return s

# ── Elf ──────────────────────────────────────────────────────────────────────

static func make_high_elf():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "High Elf"
	s.asi = {1: 2, 3: 1}  # DEX+2, INT+1
	s.darkvision = 60
	s.traits = ["Fey Ancestry", "Trance", "Cantrip", "Extra Language"]
	return s

static func make_wood_elf():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Wood Elf"
	s.speed = 35
	s.asi = {1: 2, 4: 1}  # DEX+2, WIS+1
	s.darkvision = 60
	s.traits = ["Fey Ancestry", "Trance", "Mask of the Wild"]
	return s

static func make_dark_elf():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Dark Elf (Drow)"
	s.asi = {1: 2, 5: 1}  # DEX+2, CHA+1
	s.darkvision = 120
	s.traits = ["Fey Ancestry", "Trance", "Superior Darkvision", "Sunlight Sensitivity", "Drow Magic"]
	return s

# ── Halfling ─────────────────────────────────────────────────────────────────

static func make_lightfoot_halfling():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Lightfoot Halfling"
	s.speed = 25
	s.asi = {1: 2, 5: 1}  # DEX+2, CHA+1
	s.traits = ["Lucky", "Brave", "Halfling Nimbleness", "Naturally Stealthy"]
	return s

static func make_stout_halfling():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Stout Halfling"
	s.speed = 25
	s.asi = {1: 2, 2: 1}  # DEX+2, CON+1
	s.traits = ["Lucky", "Brave", "Halfling Nimbleness", "Stout Resilience"]
	return s

# ── Human ────────────────────────────────────────────────────────────────────

static func make_human():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Human"
	s.asi = {0: 1, 1: 1, 2: 1, 3: 1, 4: 1, 5: 1}
	s.traits = ["Extra Language"]
	return s

# ── Dragonborn ───────────────────────────────────────────────────────────────

static func make_dragonborn():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Dragonborn"
	s.asi = {0: 2, 5: 1}  # STR+2, CHA+1
	s.traits = ["Draconic Ancestry", "Breath Weapon", "Damage Resistance"]
	return s

# ── Gnome ────────────────────────────────────────────────────────────────────

static func make_forest_gnome():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Forest Gnome"
	s.speed = 25
	s.asi = {3: 2, 1: 1}  # INT+2, DEX+1
	s.darkvision = 60
	s.traits = ["Gnome Cunning", "Natural Illusionist", "Speak with Small Beasts"]
	return s

static func make_rock_gnome():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Rock Gnome"
	s.speed = 25
	s.asi = {3: 2, 2: 1}  # INT+2, CON+1
	s.darkvision = 60
	s.traits = ["Gnome Cunning", "Artificer's Lore", "Tinker"]
	return s

# ── Half-Elf ─────────────────────────────────────────────────────────────────

static func make_half_elf():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Half-Elf"
	s.asi = {5: 2, 3: 1, 4: 1}  # CHA+2, INT+1, WIS+1 (representative defaults)
	s.darkvision = 60
	s.traits = ["Fey Ancestry", "Skill Versatility"]
	return s

# ── Half-Orc ─────────────────────────────────────────────────────────────────

static func make_half_orc():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Half-Orc"
	s.asi = {0: 2, 2: 1}  # STR+2, CON+1
	s.darkvision = 60
	s.traits = ["Menacing", "Relentless Endurance", "Savage Attacks"]
	return s

# ── Tiefling ─────────────────────────────────────────────────────────────────

static func make_tiefling():
	var s = load("res://addons/srd/resources/species_data.gd").new()
	s.species_name = "Tiefling"
	s.asi = {3: 1, 5: 2}  # INT+1, CHA+2
	s.darkvision = 60
	s.traits = ["Hellish Resistance", "Infernal Legacy"]
	return s

# ── All ──────────────────────────────────────────────────────────────────────

static func all_species() -> Array:
	return [
		make_hill_dwarf(), make_mountain_dwarf(),
		make_high_elf(), make_wood_elf(), make_dark_elf(),
		make_lightfoot_halfling(), make_stout_halfling(),
		make_human(),
		make_dragonborn(),
		make_forest_gnome(), make_rock_gnome(),
		make_half_elf(),
		make_half_orc(),
		make_tiefling(),
	]
