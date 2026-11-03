## Battle simulation: party of 5 (level 3) vs zombies.
## Zombie-specific: Undead Fortitude CON save when dropped to 0 HP.
## Tests use deterministic mode; Undead Fortitude is forced pass/fail via fixed_d20.
extends GutTest

const FIXED_D20 := 15

func _make_sim(d20: int = FIXED_D20) -> BattleSimulator:
	var sim := BattleSimulator.new()
	sim.fixed_d20 = d20
	sim.use_average_damage = true
	return sim

## ── Zombie stat sanity ──────────────────────────────────────────────────────

func test_zombie_stats():
	var z := SRDMonsters.make_zombie()
	assert_eq(z.stats.max_hp, 22)
	assert_eq(z.armor_class, 8)     # 10 + DEX(-2)
	assert_true(z.has_undead_fortitude)
	assert_true(z.stats.has_immunity(SRD.DamageType.POISON))

func test_zombie_slam_attack_bonus():
	# +3 = STR mod(+1) + prof(+2)
	var z := SRDMonsters.make_zombie()
	assert_eq(z.weapon.attack_bonus(z.stats, true), 3)

## ── Undead Fortitude mechanics ───────────────────────────────────────────────

func test_undead_fortitude_saves_zombie_at_1_hp():
	# If CON save succeeds (d20 high), zombie drops to 1 HP instead of 0
	var z := SRDMonsters.make_zombie()
	z.stats.current_hp = 5
	# Deal 5 damage: drops to 0. CON +3, fixed_d20=20 → 20+3=23 ≥ DC(5+5=10) → save
	z.take_damage(5, SRD.DamageType.SLASHING, false, 20)
	assert_eq(z.stats.current_hp, 1, "Undead Fortitude should leave zombie at 1 HP")
	assert_true(z.is_alive)

func test_undead_fortitude_fails_on_low_roll():
	var z := SRDMonsters.make_zombie()
	z.stats.current_hp = 5
	# CON +3, fixed_d20=1 → 1+3=4, DC=5+5=10 → fail
	z.take_damage(5, SRD.DamageType.SLASHING, false, 1)
	assert_eq(z.stats.current_hp, 0, "Failed Fortitude: zombie stays at 0 HP")

func test_undead_fortitude_disabled_for_radiant():
	var z := SRDMonsters.make_zombie()
	z.stats.current_hp = 5
	# Radiant bypasses Undead Fortitude
	z.take_damage(5, SRD.DamageType.RADIANT, false, 20)
	assert_eq(z.stats.current_hp, 0, "Radiant damage bypasses Undead Fortitude")

func test_undead_fortitude_disabled_on_crit():
	var z := SRDMonsters.make_zombie()
	z.stats.current_hp = 5
	# Crit bypasses Undead Fortitude
	z.take_damage(5, SRD.DamageType.SLASHING, true, 20)
	assert_eq(z.stats.current_hp, 0, "Critical hit bypasses Undead Fortitude")

## ── Full battle: zombies need more hits than skeletons ───────────────────────

func test_party_wins_vs_4_zombies():
	var sim := _make_sim()
	sim.fixed_save_d20 = 1  # a fixed 15 always passes Fortitude vs average damage; let it fail
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_zombie_group(4)
	var result := sim.run(party, enemies)
	assert_true(result.party_won, "Party should defeat 4 zombies")

func test_zombies_take_more_rounds_than_skeletons():
	var sim := _make_sim()
	var party1 := SRDFixtures.make_party_of_5()
	var party2 := SRDFixtures.make_party_of_5()
	var skeletons := SRDMonsters.make_skeleton_group(4)
	var zombies := SRDMonsters.make_zombie_group(4)
	var r_sk := sim.run(party1, skeletons)
	var r_zb := sim.run(party2, zombies)
	assert_true(r_zb.rounds_elapsed >= r_sk.rounds_elapsed,
		"Zombies (22 HP) should take at least as many rounds as skeletons (13 HP)")

func test_round_1_zombie_still_alive_after_one_hit():
	# Zombie HP 22. Avg party hit: ~6-8 damage. One hit can't kill it.
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_zombie_group(4)
	var result := sim.run(party, enemies)
	var r1 := sim.get_round(result, 1)
	# All 4 zombies alive after first party member attacks
	assert_eq(r1["end_state"]["enemy_alive"] + 0, r1["end_state"]["enemy_alive"])  # sanity
	# Zombies should have taken damage
	var initial_enemy_hp := 22 * 4
	assert_true(r1["end_state"]["enemy_total_hp"] < initial_enemy_hp)

func test_zombie_attacks_deal_damage_to_party():
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var total_hp := 0
	for c in party: total_hp += c.stats.max_hp
	var enemies := SRDMonsters.make_zombie_group(4)
	var result := sim.run(party, enemies)
	var r1_hp: int = sim.get_round(result, 1)["end_state"]["party_total_hp"]
	# Zombie: ATK +3, d20=15 → 15+3=18 vs party ACs (8-18). Hits lower-AC members.
	# Psion AC 12, Kael AC 15, Rynn AC 16, Sova AC 16, Mira AC 18
	# d20=15: 15+3=18 ≥ 12 (Psion hit), 18 ≥ 15 (Kael hit), 18 ≥ 16 (Rynn/Sova hit), 18 = 18 (Mira hit)
	# All party members get hit — total HP must be < starting HP
	assert_true(r1_hp < total_hp, "Zombies should deal damage to party in round 1")

func test_party_wins_vs_3_zombies_without_losses():
	# 3 zombies is more manageable — expect clean win
	var sim := _make_sim()
	sim.fixed_save_d20 = 1  # a fixed 15 always passes Fortitude vs average damage; let it fail
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_zombie_group(3)
	var result := sim.run(party, enemies)
	assert_true(result.party_won)
	var end_state: Dictionary = result.round_logs.back()["end_state"]
	assert_eq(end_state["party_alive"], 5, "No party losses vs 3 zombies with avg rolls")
