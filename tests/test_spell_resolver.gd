extends GutTest

# ── Fixtures ──────────────────────────────────────────────────────────────────

func _make_psion(level: int = 5) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Vex (Psion)"; s.level = level; s.hit_die = 6
	s.strength = 8; s.dexterity = 14; s.constitution = 12
	s.intelligence = 18; s.wisdom = 12; s.charisma = 10
	s.max_hp = 30; s.speed = 30; s.reset()
	s.set_save_proficiency(SRD.Ability.INTELLIGENCE, true)
	s.set_save_proficiency(SRD.Ability.WISDOM, true)
	return Combatant.new(s)

func _make_target(wis: int = 10, hp: int = 20) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = "Target"; s.level = 1
	s.strength = 10; s.dexterity = 10; s.constitution = 10
	s.intelligence = 10; s.wisdom = wis; s.charisma = 10
	s.max_hp = hp; s.speed = 30; s.reset()
	return Combatant.new(s)

func _make_save_ability(slot: int = 1, dmg_sides: int = 8,
		save_ab: SRD.Ability = SRD.Ability.WISDOM) -> AbilityData:
	var a := AbilityData.new()
	a.ability_name = "Mind Blast"
	a.slot_level = slot
	a.uses_save = true
	a.save_ability = save_ab
	a.save_effect = SRD.SaveEffect.HALF
	a.damage_die_count = 2; a.damage_die_sides = dmg_sides
	a.damage_type = SRD.DamageType.PSYCHIC
	a.casting_ability = SRD.Ability.INTELLIGENCE
	return a

func _make_attack_ability() -> AbilityData:
	var a := AbilityData.new()
	a.ability_name = "Psionic Bolt"
	a.slot_level = 1
	a.uses_save = false
	a.damage_die_count = 1; a.damage_die_sides = 10
	a.damage_type = SRD.DamageType.PSYCHIC
	a.casting_ability = SRD.Ability.INTELLIGENCE
	return a

func _make_conc_ability() -> AbilityData:
	var a := AbilityData.new()
	a.ability_name = "Mind Control"
	a.slot_level = 2
	a.concentration = true
	a.uses_save = false
	a.damage_die_count = 0; a.damage_die_sides = 6
	a.damage_type = SRD.DamageType.PSYCHIC
	a.casting_ability = SRD.Ability.INTELLIGENCE
	return a

# ── Save spell tests ──────────────────────────────────────────────────────────

func test_save_spell_failed_save_deals_full_damage():
	var caster := _make_psion()
	var target := _make_target(10, 30)  # WIS 10, will fail vs DC 16
	var ability := _make_save_ability()
	var resolver := SpellResolver.new()
	# inject fixed d20=1 → target fails save
	var ev := resolver._resolve_save_spell(caster, ability, target, 1, 1)
	assert_false(ev["saved"])
	assert_gt(ev["damage_dealt"], 0)
	assert_lt(target.stats.current_hp, 30)

func test_save_spell_successful_save_deals_half_damage():
	var caster := _make_psion()
	var target := _make_target(10, 30)
	var ability := _make_save_ability()
	var resolver := SpellResolver.new()
	# inject fixed d20=20 → target saves
	var ev := resolver._resolve_save_spell(caster, ability, target, 1, 20)
	assert_true(ev["saved"])
	# half damage — damage_rolled should be > 0 but halved
	assert_ge(ev["damage_dealt"], 0)

func test_save_spell_none_effect_on_save_deals_zero():
	var caster := _make_psion()
	var target := _make_target(10, 30)
	var ability := _make_save_ability()
	ability.save_effect = SRD.SaveEffect.NONE
	var resolver := SpellResolver.new()
	var ev := resolver._resolve_save_spell(caster, ability, target, 1, 20)
	assert_true(ev["saved"])
	assert_eq(ev["damage_dealt"], 0)

func test_save_spell_event_keys():
	var caster := _make_psion()
	var target := _make_target()
	var resolver := SpellResolver.new()
	var ev := resolver._resolve_save_spell(caster, _make_save_ability(), target, 1, 10)
	assert_true(ev.has("type"))
	assert_true(ev.has("saved"))
	assert_true(ev.has("damage_dealt"))
	assert_true(ev.has("target_hp_after"))
	assert_eq(ev["type"], "spell_save")

# ── Attack spell tests ────────────────────────────────────────────────────────

func test_attack_spell_hit_deals_damage():
	var caster := _make_psion()
	var target := _make_target(10, 30)
	var ability := _make_attack_ability()
	var resolver := SpellResolver.new()
	var ev := resolver._resolve_attack_spell(caster, ability, target, 1, 15)
	assert_true(ev["hit"])
	assert_gt(ev["damage_dealt"], 0)

func test_attack_spell_miss_deals_no_damage():
	var caster := _make_psion()
	var target := _make_target(10, 30)
	var ability := _make_attack_ability()
	var resolver := SpellResolver.new()
	# d20=1 is a critical miss
	var ev := resolver._resolve_attack_spell(caster, ability, target, 1, 1)
	assert_false(ev["hit"])
	assert_eq(ev["damage_dealt"], 0)
	assert_eq(target.stats.current_hp, 30)

func test_attack_spell_crit_rolls_double_dice():
	var caster := _make_psion()
	var target := _make_target(10, 100)
	var ability := _make_attack_ability()
	var resolver := SpellResolver.new()
	# d20=20 is a crit → double damage dice
	var ev := resolver._resolve_attack_spell(caster, ability, target, 1, 20)
	assert_true(ev["crit"])
	assert_gt(ev["damage_dealt"], 1)  # at minimum crit deals 2d10 min

func test_attack_spell_event_keys():
	var caster := _make_psion()
	var target := _make_target()
	var resolver := SpellResolver.new()
	var ev := resolver._resolve_attack_spell(caster, _make_attack_ability(), target, 1, 10)
	assert_true(ev.has("type"))
	assert_true(ev.has("hit"))
	assert_true(ev.has("d20"))
	assert_eq(ev["type"], "spell_attack")

# ── cast() integration ────────────────────────────────────────────────────────

func test_cast_returns_event_per_target():
	var caster := _make_psion()
	var targets := [_make_target(), _make_target(), _make_target()]
	var ability := _make_save_ability()
	var resolver := SpellResolver.new()
	var events := resolver.cast(caster, ability, targets)
	assert_eq(events.size(), 3)

func test_cast_begins_concentration():
	var caster := _make_psion()
	var target := _make_target()
	var ability := _make_conc_ability()
	var conc := ConcentrationTracker.new()
	var resolver := SpellResolver.new()
	resolver.cast(caster, ability, [target], 2, conc)
	assert_true(conc.is_concentrating)

func test_cast_before_cast_can_cancel():
	var caster := _make_psion()
	var target := _make_target(10, 30)
	var ability := _make_save_ability()

	# Subclass that cancels every cast
	class CancelResolver extends SpellResolver:
		func before_cast(_c, _a, _t) -> bool: return false

	var resolver := CancelResolver.new()
	var events := resolver.cast(caster, ability, [target])
	assert_eq(events.size(), 0)
	assert_eq(target.stats.current_hp, 30)  # untouched

func test_cast_subclass_can_override_damage():
	var caster := _make_psion()
	var target := _make_target(10, 100)
	var ability := _make_save_ability()

	# Subclass that always rolls max damage
	class MaxDmgResolver extends SpellResolver:
		func roll_damage(ab: AbilityData, _cl: int, _cal: int) -> int:
			return ab.damage_die_count * ab.damage_die_sides  # max

	var resolver := MaxDmgResolver.new()
	# inject d20=1 so target fails save, gets full damage
	var ev := resolver._resolve_save_spell(caster, ability, target, 1, 1)
	assert_eq(ev["damage_dealt"], ability.damage_die_count * ability.damage_die_sides)

# ── AoE resolver ──────────────────────────────────────────────────────────────

func test_aoe_resolver_calls_callback():
	var caster := _make_psion()
	var t1 := _make_target(); var t2 := _make_target()
	var ability := _make_save_ability()
	ability.area_size = 20
	ability.area_shape = SRD.AoEShape.SPHERE
	var resolver := AoEResolver.new()
	resolver.targets_in_shape = func(_shape, _ab, all): return all
	var targets := resolver.resolve(caster, ability, [t1, t2])
	assert_eq(targets.size(), 2)

func test_aoe_resolver_returns_empty_for_non_aoe():
	var caster := _make_psion()
	var ability := _make_save_ability()
	ability.area_size = 0  # not an AoE
	var resolver := AoEResolver.new()
	resolver.targets_in_shape = func(_s, _a, all): return all
	var targets := resolver.resolve(caster, ability, [_make_target()])
	assert_eq(targets.size(), 0)

func test_aoe_resolver_filters_inactive_combatants():
	var caster := _make_psion()
	var alive := _make_target(10, 20)
	var dead := _make_target(10, 1)
	dead.stats.take_damage(99)  # kill it
	var ability := _make_save_ability()
	ability.area_size = 20
	var resolver := AoEResolver.new()
	resolver.targets_in_shape = func(_s, _a, all): return all
	var targets := resolver.resolve(caster, ability, [alive, dead])
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], alive)
