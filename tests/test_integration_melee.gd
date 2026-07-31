## Integration test: full melee combat scenario from initiative to death/stability.
## No random rolls — all outcomes injected for determinism.
extends GutTest

func _make_fighter(name: String, hp: int = 30) -> CharacterStats:
	var c := CharacterStats.new()
	c.character_name = name
	c.strength = 16    # +3
	c.dexterity = 12   # +1
	c.constitution = 14  # +2
	c.max_hp = hp; c.level = 3; c.reset()
	c.set_save_proficiency(SRD.Ability.STRENGTH, true)
	c.set_save_proficiency(SRD.Ability.CONSTITUTION, true)
	return c

func _make_longsword() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_name = "Longsword"
	w.weapon_type = SRD.WeaponType.MARTIAL
	w.damage_type = SRD.DamageType.SLASHING
	w.die_count = 1; w.die_sides = 8
	return w

func test_initiative_order_built_correctly():
	var a := _make_fighter("Alpha")
	var b := _make_fighter("Beta")
	var order := CombatOrder.new()
	order.set_order([
		{ "char": a, "roll": 18, "total": 19 },
		{ "char": b, "roll": 10, "total": 11 },
	])
	assert_eq(order.current().character_name, "Alpha")

func test_attack_applies_damage_and_action_used():
	var attacker := _make_fighter("Attacker")
	var target := _make_fighter("Target")
	var weapon := _make_longsword()
	var eq := EquipmentSlots.new(); eq.equip_armor(ArmorData.make_chain_mail())
	var ae := ActionEconomy.new(30)

	# Apply damage directly (bypassing random rolls)
	var initial_hp := target.current_hp
	DamageResolver.apply(target, 8, SRD.DamageType.SLASHING)
	ae.use_action()

	assert_true(target.current_hp < initial_hp)
	assert_false(ae.has_action)

func test_character_drops_to_zero_hp():
	var target := _make_fighter("Target", 10)
	DamageResolver.apply(target, 10, SRD.DamageType.SLASHING)
	assert_true(target.is_at_zero_hp())
	assert_false(target.is_alive())

func test_death_save_path_to_stable():
	var dying := _make_fighter("Dying")
	dying.current_hp = 0
	var saves := DeathSaveTracker.new()
	saves.roll(15); saves.roll(12); saves.roll(11)
	assert_true(saves.is_stable)
	assert_false(saves.is_dead)

func test_death_save_path_to_death():
	var dying := _make_fighter("Dying")
	dying.current_hp = 0
	var saves := DeathSaveTracker.new()
	saves.roll(5); saves.roll(3); saves.roll(2)
	assert_true(saves.is_dead)

func test_full_combat_loop_one_character_wins():
	## Full deterministic combat: Alpha deals 15 damage per turn, Beta deals 10.
	## Alpha HP=30, Beta HP=20. Expected: Beta drops at round 2.
	var alpha := _make_fighter("Alpha", 30)
	var beta  := _make_fighter("Beta", 20)
	var order := CombatOrder.new()
	order.set_order([
		{ "char": alpha, "roll": 20, "total": 21 },
		{ "char": beta,  "roll": 10, "total": 11 },
	])

	var death_saves: Dictionary = {}  # char_name → DeathSaveTracker

	var max_rounds := 10
	for _round in max_rounds:
		var current := order.current()
		var other := beta if current == alpha else alpha

		if not other.is_alive():
			# Other is already dying — check death saves
			var ds: DeathSaveTracker = death_saves.get(other.character_name, null)
			if ds == null:
				ds = DeathSaveTracker.new(); death_saves[other.character_name] = ds
			ds.roll(10)  # steady success
		else:
			# Deal fixed damage for determinism
			var dmg := 15 if current == alpha else 10
			DamageResolver.apply(other, dmg, SRD.DamageType.SLASHING)

		order.advance()
		if not alpha.is_alive() or not beta.is_alive():
			if death_saves.get(beta.character_name, null) != null and \
					death_saves[beta.character_name].is_resolved():
				break

	# Beta hit for 15+15=30 damage (has 20 HP, drops after round 2)
	assert_false(beta.is_alive())
	assert_true(alpha.is_alive())

func test_reaction_opportunity_attack_spends_reaction():
	var ae := ActionEconomy.new(30)
	ae.use_reaction()
	assert_false(ae.has_reaction)
	ae.reset_turn()
	assert_false(ae.has_reaction)  # reaction doesn't reset on your turn
	ae.reset_reaction()
	assert_true(ae.has_reaction)
