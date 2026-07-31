class_name ClassData
extends Resource

@export var class_name_str: String = ""
@export var hit_die: int = 8
@export var slot_progression: SRD.SlotProgression = SRD.SlotProgression.NONE
@export var skill_choices_count: int = 2

# 2-element arrays of SRD.Ability values
var save_proficiencies: Array[int] = []
# SRD.WeaponType or specific weapon/armor category strings
var armor_proficiencies: Array[String] = []
var weapon_proficiencies: Array[String] = []

## Build EnergySlots for a character of this class at the given level.
func make_slots(level: int) -> EnergySlots:
	match slot_progression:
		SRD.SlotProgression.FULL:
			return EnergySlots.make_full_caster(level)
		SRD.SlotProgression.HALF:
			return EnergySlots.make_half_caster(level)
		SRD.SlotProgression.THIRD:
			return EnergySlots.make_third_caster(level)
	return EnergySlots.new()  # NONE — no slots

# --- Built-in Space SRD archetypes ---

static func make_soldier() -> ClassData:
	var c := ClassData.new()
	c.class_name_str = "Soldier"
	c.hit_die = 10
	c.slot_progression = SRD.SlotProgression.NONE
	c.skill_choices_count = 2
	c.save_proficiencies = [int(SRD.Ability.STRENGTH), int(SRD.Ability.CONSTITUTION)]
	c.armor_proficiencies = ["light", "medium", "heavy", "shield"]
	c.weapon_proficiencies = ["simple", "martial"]
	return c

static func make_ghost() -> ClassData:
	var c := ClassData.new()
	c.class_name_str = "Ghost"
	c.hit_die = 8
	c.slot_progression = SRD.SlotProgression.NONE  # base Ghost; subclass adds magic
	c.skill_choices_count = 4
	c.save_proficiencies = [int(SRD.Ability.DEXTERITY), int(SRD.Ability.INTELLIGENCE)]
	c.armor_proficiencies = ["light"]
	c.weapon_proficiencies = ["simple", "hand crossbow", "longsword", "rapier", "shortsword"]
	return c

static func make_psion() -> ClassData:
	var c := ClassData.new()
	c.class_name_str = "Psion"
	c.hit_die = 6
	c.slot_progression = SRD.SlotProgression.FULL
	c.skill_choices_count = 2
	c.save_proficiencies = [int(SRD.Ability.INTELLIGENCE), int(SRD.Ability.WISDOM)]
	c.armor_proficiencies = []
	c.weapon_proficiencies = ["simple"]
	return c

static func make_warden() -> ClassData:
	var c := ClassData.new()
	c.class_name_str = "Warden"
	c.hit_die = 8
	c.slot_progression = SRD.SlotProgression.FULL
	c.skill_choices_count = 2
	c.save_proficiencies = [int(SRD.Ability.WISDOM), int(SRD.Ability.CHARISMA)]
	c.armor_proficiencies = ["light", "medium", "shield"]
	c.weapon_proficiencies = ["simple", "martial"]
	return c
