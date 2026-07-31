## Describes a single feat. Subclass or set on_apply for fully custom feats.
##
## Built-in factories cover the 8 SRD feats relevant to the Space SRD archetypes.
## For homebrew feats, either:
##   • Set on_apply: func(char: CharacterStats) -> void
##   • Subclass FeatData and override apply_stat_mods()
class_name FeatData
extends Resource

@export var feat_name: String = ""
@export var description: String = ""

## Permanent stat deltas — applied once via FeatsSystem.apply_stat_mods().
@export var initiative_bonus: int = 0
@export var speed_bonus: int = 0
## Resilient: +1 to ability + save proficiency. -1 = not Resilient.
@export var resilient_ability: int = -1

## Combat flags — checked at runtime by the relevant system or game layer.
@export var cannot_be_surprised: bool = false
@export var has_lucky: bool = false        ## 3 reroll points per long rest
@export var has_sentinel: bool = false     ## OA stops movement; react to ally-targeted attacks
@export var has_war_caster: bool = false   ## advantage on CON concentration saves; spell-as-OA
@export var has_sharpshooter: bool = false ## optional -5/+10; ignore half & 3/4 cover
@export var has_gwm: bool = false          ## optional -5/+10 heavy melee; bonus attack on kill/crit
@export var has_mobile: bool = false       ## no OA provoked after melee attack against a creature

## Fully custom feat: func(char: CharacterStats) -> void.
## When set, FeatsSystem.apply_stat_mods() delegates entirely to this callable.
var on_apply: Callable

# ── Built-in factories ────────────────────────────────────────────────────────

static func make_alert() -> FeatData:
	var f := FeatData.new()
	f.feat_name = "Alert"
	f.description = "+5 initiative; cannot be surprised; hidden attackers get no advantage vs you."
	f.initiative_bonus = 5
	f.cannot_be_surprised = true
	return f

static func make_lucky() -> FeatData:
	var f := FeatData.new()
	f.feat_name = "Lucky"
	f.description = "3 luck points per long rest; spend to reroll any d20."
	f.has_lucky = true
	return f

static func make_mobile() -> FeatData:
	var f := FeatData.new()
	f.feat_name = "Mobile"
	f.description = "+10 ft speed; Dash ignores difficult terrain; no OA after attacking a creature."
	f.speed_bonus = 10
	f.has_mobile = true
	return f

## ability: the SRD.Ability this character becomes proficient in for saves.
static func make_resilient(ability: SRD.Ability) -> FeatData:
	var f := FeatData.new()
	f.feat_name = "Resilient"
	f.description = "+1 to chosen ability; proficiency in that ability's saving throw."
	f.resilient_ability = int(ability)
	return f

static func make_sentinel() -> FeatData:
	var f := FeatData.new()
	f.feat_name = "Sentinel"
	f.description = "OA hits reduce target speed to 0; OA even through Disengage; react when ally attacked."
	f.has_sentinel = true
	return f

static func make_war_caster() -> FeatData:
	var f := FeatData.new()
	f.feat_name = "War Caster"
	f.description = "Advantage on CON concentration saves; can cast a spell as an opportunity attack."
	f.has_war_caster = true
	return f

static func make_sharpshooter() -> FeatData:
	var f := FeatData.new()
	f.feat_name = "Sharpshooter"
	f.description = "No long-range disadvantage; ignore half/3-4 cover; optional -5 atk / +10 dmg."
	f.has_sharpshooter = true
	return f

static func make_gwm() -> FeatData:
	var f := FeatData.new()
	f.feat_name = "Great Weapon Master"
	f.description = "Bonus melee attack on crit/kill; optional -5 atk / +10 dmg with heavy weapons."
	f.has_gwm = true
	return f
