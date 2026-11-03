extends GutTest
## Magic items: extraction, prices, attunement, and worn gear's effect on a Combatant.

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func _fighter() -> Combatant:
	return srd.make_character("F", "fighter", 5, [16, 12, 14, 8, 12, 10], "longsword", "chain-mail", true)

func test_magic_items_extracted():
	assert_eq(srd.pack.count("magic_item"), 258)
	var r := srd.pack.get_row("magic_item", "cloak-of-protection")
	assert_eq(r.data.rarity, "uncommon")
	assert_true(r.data.attunement)
	var w := srd.pack.get_row("magic_item", "weapon-1-2-or-3")
	assert_eq(w.data.variants, {"1": "uncommon", "2": "rare", "3": "very rare"})
	assert_true(srd.pack.has_row("magic_item", "amulet-of-proof-against-detection-and-location"), "wrapped names join")
	assert_eq(srd.pack.get_row("magic_item", "robe-of-the-archmagi").data.attunement_by,
		"a Sorcerer, Warlock, or Wizard")

func test_rarity_values():
	assert_eq(SRDItems.value_of("rare"), 4000)
	assert_eq(SRDItems.value_of("rare", true), 2000)
	assert_eq(SRDItems.value_of("artifact"), 0)

func test_cost_parsing():
	assert_eq(SRDItems.cost_gp("15 GP"), 15.0)
	assert_eq(SRDItems.cost_gp("5 SP"), 0.5)
	assert_eq(SRDItems.cost_gp("1,500 GP"), 1500.0)

func test_attunement_prerequisites():
	assert_true(SRDItems.can_attune("a Sorcerer, Warlock, or Wizard", "wizard", true))
	assert_false(SRDItems.can_attune("a Sorcerer, Warlock, or Wizard", "fighter", false))
	assert_true(SRDItems.can_attune("a Spellcaster", "cleric", true))
	assert_false(SRDItems.can_attune("a Spellcaster", "fighter", false))
	assert_true(SRDItems.can_attune("", "fighter", false))

func test_mods_stack_and_clear():
	var c := _fighter()
	var ac := c.armor_class
	var atk := c.attack_modifier()
	ItemEffects.apply(c, [{"ac": 1, "save": 1}, {"attack": 2, "damage": 2}])
	assert_eq(c.armor_class, ac + 1)
	assert_eq(c.attack_modifier(), atk + 2)
	assert_eq(c.stats.saving_throw_bonus(SRD.Ability.WISDOM), 2)
	ItemEffects.apply(c, [])
	assert_eq(c.armor_class, ac)
	assert_eq(c.attack_modifier(), atk)
	assert_eq(c.stats.saving_throw_bonus(SRD.Ability.WISDOM), 1)

func test_set_ability_changes_hp_retroactively():
	var c := _fighter()
	var hp := c.stats.max_hp
	ItemEffects.apply(c, [{"set_ability": {"con": 19}}])
	assert_eq(c.stats.constitution, 19)
	assert_eq(c.stats.max_hp, hp + 5 * 2, "CON +2 -> +4: two more HP per level")
	assert_eq(c.current_hp, c.stats.max_hp)
	ItemEffects.apply(c, [])
	assert_eq(c.stats.max_hp, hp)

func test_set_ability_never_lowers():
	var c := _fighter()
	ItemEffects.apply(c, [{"set_ability": {"str": 15}}])
	assert_eq(c.stats.strength, 16)

func test_resistance_and_condition_immunity():
	var c := _fighter()
	ItemEffects.apply(c, [{"resist": ["fire"], "condition_immune": ["paralyzed"]}])
	assert_true(c.stats.has_resistance(SRD.DamageType.FIRE))
	assert_true("paralyzed" in c.condition_immunities)
	ItemEffects.apply(c, [])
	assert_false(c.stats.has_resistance(SRD.DamageType.FIRE))
	assert_false("paralyzed" in c.condition_immunities)

func test_extra_damage_on_hit():
	var c := _fighter()
	var t := srd.make_monster("ogre")
	ItemEffects.apply(c, [{"extra_damage": {"name": "Flame", "dice": "2d6", "type": "fire"}}])
	var ev := AttackResolver.weapon_attack(c, t, {"d20": 19, "average": true, "mastery": false})
	assert_eq(ev.rider_damage.name, "Flame")
	assert_gt(ev.damage_dealt, ev.damage)

func test_magic_weapon_damage_reaches_the_attack():
	var c := _fighter()
	var t := srd.make_monster("ogre")
	var before: int = AttackResolver.weapon_attack(c, t, {"d20": 19, "average": true, "mastery": false}).damage
	ItemEffects.apply(c, [{"attack": 3, "damage": 3}])
	var after: int = AttackResolver.weapon_attack(c, t, {"d20": 19, "average": true, "mastery": false}).damage
	assert_eq(after, before + 3)

func test_adamantine_turns_crits_into_hits():
	var c := _fighter()
	var t := _fighter()
	ItemEffects.apply(t, [{"crit_immune": true}])
	var ev := AttackResolver.weapon_attack(c, t, {"d20": 20})
	assert_true(ev.hit)
	assert_false(ev.crit)

func test_bracers_need_no_armor_or_shield():
	var w := srd.make_character("W", "wizard", 5, [8, 14, 14, 16, 12, 10], "quarterstaff")
	var ac := w.armor_class
	ItemEffects.apply(w, [{"unarmored_ac": 2}])
	assert_eq(w.armor_class, ac + 2)
	var f := _fighter()
	var fac := f.armor_class
	ItemEffects.apply(f, [{"unarmored_ac": 2}])
	assert_eq(f.armor_class, fac)

func test_spell_bonuses_move_dc_and_attack():
	var w := srd.make_character("W", "wizard", 5, [8, 14, 14, 16, 12, 10], "quarterstaff")
	var fb := srd.make_spell("fire-bolt", SRD.Ability.INTELLIGENCE)
	var dc := fb.spell_save_dc(w.stats)
	var atk := fb.spell_attack_bonus(w.stats)
	ItemEffects.apply(w, [{"spell_dc": 2, "spell_attack": 2}])
	assert_eq(fb.spell_save_dc(w.stats), dc + 2)
	assert_eq(fb.spell_attack_bonus(w.stats), atk + 2)

func test_mithral_drops_stealth_disadvantage():
	var c := srd.make_character("H", "fighter", 5, [16, 12, 14, 8, 12, 10], "longsword", "plate-armor", true)
	assert_true(c.equipment.has_stealth_disadvantage())
	ItemEffects.apply(c, [{"heavy_stealth": true}])
	assert_false(c.equipment.has_stealth_disadvantage())
