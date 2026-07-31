extends GutTest

func _make_char(speed: int = 30) -> CharacterStats:
	var s := CharacterStats.new()
	s.strength = 10; s.dexterity = 14; s.constitution = 12
	s.intelligence = 10; s.wisdom = 10; s.charisma = 10
	s.level = 5; s.max_hp = 30; s.speed = speed; s.reset()
	return s

# ── Alert ─────────────────────────────────────────────────────────────────────

func test_alert_initiative_bonus():
	var feats := [FeatData.make_alert()]
	assert_eq(FeatsSystem.initiative_bonus(feats), 5)

func test_alert_cannot_be_surprised():
	var feats := [FeatData.make_alert()]
	assert_true(FeatsSystem.cannot_be_surprised(feats))

func test_no_feats_can_be_surprised():
	assert_false(FeatsSystem.cannot_be_surprised([]))

# ── Mobile ────────────────────────────────────────────────────────────────────

func test_mobile_increases_speed():
	var s := _make_char(30)
	FeatsSystem.apply_stat_mods(s, FeatData.make_mobile())
	assert_eq(s.speed, 40)

func test_mobile_no_oa_after_melee():
	var feats := [FeatData.make_mobile()]
	assert_true(FeatsSystem.no_oa_after_melee(feats))

# ── Resilient ─────────────────────────────────────────────────────────────────

func test_resilient_grants_save_proficiency():
	var s := _make_char()
	assert_false(s.is_save_proficient(SRD.Ability.CONSTITUTION))
	FeatsSystem.apply_stat_mods(s, FeatData.make_resilient(SRD.Ability.CONSTITUTION))
	assert_true(s.is_save_proficient(SRD.Ability.CONSTITUTION))

func test_resilient_increases_ability_by_1():
	var s := _make_char()
	s.constitution = 14
	FeatsSystem.apply_stat_mods(s, FeatData.make_resilient(SRD.Ability.CONSTITUTION))
	assert_eq(s.constitution, 15)

func test_resilient_clamps_at_20():
	var s := _make_char()
	s.constitution = 20
	FeatsSystem.apply_stat_mods(s, FeatData.make_resilient(SRD.Ability.CONSTITUTION))
	assert_eq(s.constitution, 20)

# ── War Caster ────────────────────────────────────────────────────────────────

func test_war_caster_concentration_flag():
	var feats := [FeatData.make_war_caster()]
	assert_true(FeatsSystem.war_caster_concentration(feats))

func test_no_war_caster():
	assert_false(FeatsSystem.war_caster_concentration([]))

# ── Sharpshooter ──────────────────────────────────────────────────────────────

func test_sharpshooter_ignores_cover():
	var feats := [FeatData.make_sharpshooter()]
	assert_true(FeatsSystem.ignores_ranged_cover(feats))

func test_power_attack_penalty():
	assert_eq(FeatsSystem.power_attack_hit_bonus(true), -5)
	assert_eq(FeatsSystem.power_attack_hit_bonus(false), 0)

func test_power_attack_damage_bonus():
	assert_eq(FeatsSystem.power_attack_damage_bonus(true), 10)
	assert_eq(FeatsSystem.power_attack_damage_bonus(false), 0)

# ── GWM ───────────────────────────────────────────────────────────────────────

func test_gwm_detected():
	var feats := [FeatData.make_gwm()]
	assert_true(FeatsSystem.has_gwm(feats))

# ── Lucky ─────────────────────────────────────────────────────────────────────

func test_lucky_starts_with_3_points():
	var tracker := FeatsSystem.LuckyTracker.new()
	assert_eq(tracker.points, 3)

func test_lucky_spend_reduces_points():
	var tracker := FeatsSystem.LuckyTracker.new()
	assert_true(tracker.spend())
	assert_eq(tracker.points, 2)

func test_lucky_spend_fails_at_zero():
	var tracker := FeatsSystem.LuckyTracker.new()
	tracker.spend(); tracker.spend(); tracker.spend()
	assert_false(tracker.spend())

func test_lucky_resets_on_long_rest():
	var tracker := FeatsSystem.LuckyTracker.new()
	tracker.spend(); tracker.spend()
	tracker.long_rest_reset()
	assert_eq(tracker.points, 3)

# ── has_feat / generic queries ────────────────────────────────────────────────

func test_has_feat_by_name():
	var feats := [FeatData.make_alert(), FeatData.make_mobile()]
	assert_true(FeatsSystem.has_feat(feats, "Alert"))
	assert_false(FeatsSystem.has_feat(feats, "Lucky"))

func test_multiple_initiative_bonuses_stack():
	# unlikely in real play but the math should work
	var feats := [FeatData.make_alert(), FeatData.make_alert()]
	assert_eq(FeatsSystem.initiative_bonus(feats), 10)

# ── Custom feat via on_apply ──────────────────────────────────────────────────

func test_custom_feat_on_apply_called():
	var s := _make_char()
	var custom := FeatData.new()
	custom.feat_name = "Custom"
	custom.on_apply = func(char): char.strength = 20
	FeatsSystem.apply_stat_mods(s, custom)
	assert_eq(s.strength, 20)

func test_custom_feat_on_apply_overrides_defaults():
	var s := _make_char(30)
	# Set speed_bonus but also on_apply — on_apply wins
	var custom := FeatData.new()
	custom.speed_bonus = 999
	custom.on_apply = func(_char): pass  # intentionally does nothing
	FeatsSystem.apply_stat_mods(s, custom)
	assert_eq(s.speed, 30)  # not 1029 — on_apply bypassed speed_bonus
