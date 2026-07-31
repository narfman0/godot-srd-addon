class_name ClassData
extends Resource

@export var class_name_str: String = ""
@export var description: String = ""
@export var hit_die: int = 8
@export var slot_progression: SRD.SlotProgression = SRD.SlotProgression.NONE
@export var skill_choices_count: int = 2

# 2-element arrays of SRD.Ability values
var save_proficiencies: Array[int] = []
# SRD.Skill values this class may choose proficiencies from
var skill_options: Array[int] = []
# SRD.Ability values the class leans on — used for UI hints / recommended builds
var primary_abilities: Array[int] = []
# SRD.WeaponType or specific weapon/armor category strings
var armor_proficiencies: Array[String] = []
var weapon_proficiencies: Array[String] = []

## Level-1 hit points: full hit die + CON modifier (minimum 1).
func starting_hp(con_modifier: int) -> int:
	return maxi(1, hit_die + con_modifier)

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
	c.description = "Frontline martial fighter. Heavy armor, all weapons, and the toughest hit die."
	c.hit_die = 10
	c.slot_progression = SRD.SlotProgression.NONE
	c.skill_choices_count = 2
	c.save_proficiencies = [int(SRD.Ability.STRENGTH), int(SRD.Ability.CONSTITUTION)]
	c.primary_abilities = [int(SRD.Ability.STRENGTH), int(SRD.Ability.CONSTITUTION)]
	c.skill_options = [
		int(SRD.Skill.ACROBATICS), int(SRD.Skill.ATHLETICS), int(SRD.Skill.HISTORY),
		int(SRD.Skill.INSIGHT), int(SRD.Skill.INTIMIDATION), int(SRD.Skill.PERCEPTION),
		int(SRD.Skill.SURVIVAL),
	]
	c.armor_proficiencies = ["light", "medium", "heavy", "shield"]
	c.weapon_proficiencies = ["simple", "martial"]
	return c

static func make_ghost() -> ClassData:
	var c := ClassData.new()
	c.class_name_str = "Ghost"
	c.description = "Skirmisher and infiltrator. Light armor, finesse weapons, and the widest skill range."
	c.hit_die = 8
	c.slot_progression = SRD.SlotProgression.NONE  # base Ghost; subclass adds magic
	c.skill_choices_count = 4
	c.save_proficiencies = [int(SRD.Ability.DEXTERITY), int(SRD.Ability.INTELLIGENCE)]
	c.primary_abilities = [int(SRD.Ability.DEXTERITY), int(SRD.Ability.INTELLIGENCE)]
	c.skill_options = [
		int(SRD.Skill.ACROBATICS), int(SRD.Skill.ATHLETICS), int(SRD.Skill.DECEPTION),
		int(SRD.Skill.INSIGHT), int(SRD.Skill.INTIMIDATION), int(SRD.Skill.INVESTIGATION),
		int(SRD.Skill.PERCEPTION), int(SRD.Skill.PERFORMANCE), int(SRD.Skill.PERSUASION),
		int(SRD.Skill.SLEIGHT_OF_HAND), int(SRD.Skill.STEALTH),
	]
	c.armor_proficiencies = ["light"]
	c.weapon_proficiencies = ["simple", "hand crossbow", "longsword", "rapier", "shortsword"]
	return c

static func make_psion() -> ClassData:
	var c := ClassData.new()
	c.class_name_str = "Psion"
	c.description = "Full caster shaping raw psychic energy. Fragile, but commands the deepest slot pool."
	c.hit_die = 6
	c.slot_progression = SRD.SlotProgression.FULL
	c.skill_choices_count = 2
	c.save_proficiencies = [int(SRD.Ability.INTELLIGENCE), int(SRD.Ability.WISDOM)]
	c.primary_abilities = [int(SRD.Ability.INTELLIGENCE), int(SRD.Ability.CONSTITUTION)]
	c.skill_options = [
		int(SRD.Skill.ARCANA), int(SRD.Skill.HISTORY), int(SRD.Skill.INSIGHT),
		int(SRD.Skill.INVESTIGATION), int(SRD.Skill.MEDICINE), int(SRD.Skill.RELIGION),
	]
	c.armor_proficiencies = []
	c.weapon_proficiencies = ["simple"]
	return c

static func make_warden() -> ClassData:
	var c := ClassData.new()
	c.class_name_str = "Warden"
	c.description = "Armored full caster channeling the Veil. Balances weapons, medium armor, and magic."
	c.hit_die = 8
	c.slot_progression = SRD.SlotProgression.FULL
	c.skill_choices_count = 2
	c.save_proficiencies = [int(SRD.Ability.WISDOM), int(SRD.Ability.CHARISMA)]
	c.primary_abilities = [int(SRD.Ability.WISDOM), int(SRD.Ability.CHARISMA)]
	c.skill_options = [
		int(SRD.Skill.HISTORY), int(SRD.Skill.INSIGHT), int(SRD.Skill.MEDICINE),
		int(SRD.Skill.PERSUASION), int(SRD.Skill.RELIGION),
	]
	c.armor_proficiencies = ["light", "medium", "shield"]
	c.weapon_proficiencies = ["simple", "martial"]
	return c
