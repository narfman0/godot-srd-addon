extends Resource

@export var spell_name: String = ""
@export var spell_level: int = 0       # 0 = cantrip
@export var school: String = ""
@export var range_ft: int = 60
@export var description: String = ""
@export var damage_dice: int = 0       # die size; 0 = no damage roll
@export var damage_count: int = 1
@export var heal_dice: int = 0
@export var heal_count: int = 1
@export var save_ability: int = -1     # SRD.Ability int; -1 = attack roll or no save
@export var is_bonus_action: bool = false
@export var concentration: bool = false
@export var classes: Array = []        # Array[String] class keys

static func _make(name: String, level: int, school_str: String) -> Object:
	var s = load("res://addons/srd/resources/spell_data.gd").new()
	s.spell_name = name
	s.spell_level = level
	s.school = school_str
	return s

# ── Psion cantrips ────────────────────────────────────────────────────────────

static func make_fire_bolt():
	var s := _make("Fire Bolt", 0, "Evocation")
	s.range_ft = 120
	s.damage_dice = 10; s.damage_count = 1
	s.description = "1d10 fire damage. Ranged spell attack."
	s.classes = ["psion"]
	return s

static func make_toll_the_dead():
	var s := _make("Toll the Dead", 0, "Necromancy")
	s.range_ft = 60
	s.damage_dice = 8; s.damage_count = 1   # 1d12 if target is hurt — handled in resolver
	s.save_ability = 4   # WIS save
	s.description = "1d8 (1d12 if injured) necrotic damage. WIS save negates."
	s.classes = ["psion"]
	return s

static func make_mage_hand():
	var s := _make("Mage Hand", 0, "Conjuration")
	s.range_ft = 30
	s.description = "Conjure a spectral hand that can manipulate objects at range."
	s.classes = ["psion", "warden"]
	return s

# ── Warden cantrips ───────────────────────────────────────────────────────────

static func make_sacred_flame():
	var s := _make("Sacred Flame", 0, "Evocation")
	s.range_ft = 60
	s.damage_dice = 8; s.damage_count = 1
	s.save_ability = 1   # DEX save
	s.description = "1d8 radiant damage. DEX save negates. Cover provides no benefit."
	s.classes = ["warden"]
	return s

static func make_guidance():
	var s := _make("Guidance", 0, "Divination")
	s.range_ft = 30
	s.is_bonus_action = true
	s.description = "Touch: target adds 1d4 to one ability check before spell ends."
	s.classes = ["warden"]
	return s

# ── Psion level 1 spells ──────────────────────────────────────────────────────

static func make_magic_missile():
	var s := _make("Magic Missile", 1, "Evocation")
	s.range_ft = 120
	s.damage_dice = 4; s.damage_count = 3   # 3×(1d4+1) force, auto-hit
	s.description = "Three darts of magical force each deal 1d4+1 damage. Auto-hit."
	s.classes = ["psion"]
	return s

static func make_burning_hands():
	var s := _make("Burning Hands", 1, "Evocation")
	s.range_ft = 15
	s.damage_dice = 6; s.damage_count = 3
	s.save_ability = 1   # DEX save, half damage
	s.description = "3d6 fire damage in a 15-ft cone. DEX save halves."
	s.classes = ["psion"]
	return s

static func make_charm_person():
	var s := _make("Charm Person", 1, "Enchantment")
	s.range_ft = 30
	s.save_ability = 4   # WIS save
	s.description = "WIS save or target is charmed until end of your next long rest."
	s.classes = ["psion"]
	return s

# ── Warden level 1 spells ─────────────────────────────────────────────────────

static func make_cure_wounds():
	var s := _make("Cure Wounds", 1, "Evocation")
	s.range_ft = 5
	s.heal_dice = 8; s.heal_count = 1
	s.description = "Touch: restore 1d8 + WIS modifier HP."
	s.classes = ["warden"]
	return s

static func make_guiding_bolt():
	var s := _make("Guiding Bolt", 1, "Evocation")
	s.range_ft = 120
	s.damage_dice = 6; s.damage_count = 4
	s.description = "4d6 radiant damage. Next attack against target has advantage."
	s.classes = ["warden"]
	return s

static func make_bless():
	var s := _make("Bless", 1, "Enchantment")
	s.range_ft = 30
	s.is_bonus_action = true
	s.concentration = true
	s.description = "Up to 3 creatures add 1d4 to attack rolls and saving throws. Concentration."
	s.classes = ["warden"]
	return s

static func make_shield_of_faith():
	var s := _make("Shield of Faith", 1, "Abjuration")
	s.range_ft = 60
	s.is_bonus_action = true
	s.concentration = true
	s.description = "Target gains +2 AC for up to 10 minutes. Concentration."
	s.classes = ["warden"]
	return s

# ── Convenience lists ─────────────────────────────────────────────────────────

static func psion_cantrips() -> Array:
	return [make_fire_bolt(), make_toll_the_dead(), make_mage_hand()]

static func psion_l1_spells() -> Array:
	return [make_magic_missile(), make_burning_hands(), make_charm_person()]

static func warden_cantrips() -> Array:
	return [make_sacred_flame(), make_guidance(), make_mage_hand()]

static func warden_l1_spells() -> Array:
	return [make_cure_wounds(), make_guiding_bolt(), make_bless(), make_shield_of_faith()]
