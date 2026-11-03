extends GutTest
## SRD 5.2.1 Short and Long Rests for a whole character.

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func test_short_rest_spends_hit_dice():
	var c := srd.make_character("F", "fighter", 5, [16, 12, 14, 8, 12, 10], "longsword")
	c.stats.current_hp = 10
	seed(4)
	var r := SRDRest.short_rest_combatant(c, 2)
	assert_eq(r.dice_spent, 2)
	assert_gte(r.healed, 2)
	assert_eq(c.stats.hit_dice_remaining, 3)

func test_short_rest_recovers_short_resources_only():
	var c := srd.make_character("F", "fighter", 9, [16, 12, 14, 8, 12, 10], "longsword")
	c.kit.spend("action_surge")
	c.kit.spend("indomitable")
	c.kit.spend("second_wind")
	var sw := c.kit.uses_left("second_wind")
	SRDRest.short_rest_combatant(c, 0)
	assert_eq(c.kit.uses_left("action_surge"), 1, "Action Surge: all")
	assert_eq(c.kit.uses_left("indomitable"), 0, "Indomitable: Long Rest")
	assert_eq(c.kit.uses_left("second_wind"), sw + 1, "Second Wind: one")

func test_warlock_slots_return_on_short_rest():
	var c := srd.make_character("W", "warlock", 5, [8, 14, 14, 12, 10, 16], "dagger")
	c.energy_slots.use_slot(3)
	c.kit.spend("magical_cunning")
	SRDRest.short_rest_combatant(c, 0)
	assert_eq(c.energy_slots.slots_remaining_at(3), 2)

func test_arcane_recovery_fires_once():
	var c := srd.make_character("W", "wizard", 6, [8, 14, 14, 16, 12, 10], "quarterstaff")
	c.energy_slots.use_slot(3)
	c.energy_slots.use_slot(3)
	var r := SRDRest.short_rest_combatant(c, 0)
	assert_eq(c.energy_slots.slots_remaining_at(3), 2, "budget 3: one level 3 slot")
	assert_eq(r.lines.size(), 1)
	c.energy_slots.use_slot(3)
	SRDRest.short_rest_combatant(c, 0)
	assert_eq(c.energy_slots.slots_remaining_at(3), 1, "once per Long Rest")

func test_sorcerous_restoration():
	var c := srd.make_character("S", "sorcerer", 6, [8, 14, 14, 10, 12, 16], "dagger")
	c.kit.spend("sorcery_points", 5)
	SRDRest.short_rest_combatant(c, 0)
	assert_eq(c.kit.uses_left("sorcery_points"), 4)

func test_long_rest_restores_everything():
	var c := srd.make_character("C", "cleric", 7, [14, 10, 14, 10, 16, 12], "mace")
	c.stats.current_hp = 3
	c.stats.temp_hp = 5
	c.stats.hit_dice_remaining = 0
	c.energy_slots.use_slot(4)
	c.kit.spend("channel_divinity")
	c.effects.add({"id": "x", "type": "ac_bonus", "amount": 1})
	SRDRest.long_rest_combatant(c)
	assert_eq(c.current_hp, c.stats.max_hp)
	assert_eq(c.stats.temp_hp, 0)
	assert_eq(c.stats.hit_dice_remaining, 7, "5.2.1: all Hit Point Dice")
	assert_eq(c.energy_slots.slots_remaining_at(4), 1)
	assert_eq(c.kit.uses_left("channel_divinity"), 3)
	assert_false(c.effects.has_id("x"))

func test_downed_character_cant_spend_dice():
	var c := srd.make_character("F", "fighter", 5, [16, 12, 14, 8, 12, 10], "longsword")
	c.stats.current_hp = 0
	assert_eq(SRDRest.short_rest_combatant(c, 3).dice_spent, 0)
