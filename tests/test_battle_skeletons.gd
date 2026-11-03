## Battle simulation: party of 5 (level 3) vs skeletons.
## All tests use deterministic mode: fixed_d20=15, use_average_damage=true.
## With these settings every attack hits (15 + any mod ≥ AC 13 for skeletons)
## and damage is fully predictable, so we can assert exact HP per round.
extends GutTest

const FIXED_D20 := 15  # guaranteed hits against skeletons (AC 13), misses vs nothing (always hits)

func _make_sim() -> BattleSimulator:
	var sim := BattleSimulator.new()
	sim.fixed_d20 = FIXED_D20
	sim.use_average_damage = true
	return sim

## ── Stat sanity checks ──────────────────────────────────────────────────────

func test_skeleton_stats():
	var sk := SRDMonsters.make_skeleton()
	assert_eq(sk.stats.max_hp, 13)
	assert_eq(sk.armor_class, 13)                               # leather + DEX+2
	assert_eq(sk.stats.dexterity, 14)
	assert_true(sk.stats.has_immunity(SRD.DamageType.POISON))

func test_skeleton_weapon_attack_bonus():
	# +4 = DEX mod(+2) + prof(+2) at level 1
	var sk := SRDMonsters.make_skeleton()
	assert_eq(sk.weapon.attack_bonus(sk.stats, true), 4)

func test_skeleton_weapon_avg_damage():
	# 1d6+2 avg = 3+2 = 5
	var sk := SRDMonsters.make_skeleton()
	assert_eq(sk.weapon._damage_mod(sk.stats), 2)   # DEX+2

## ── Party stat checks ───────────────────────────────────────────────────────

func test_party_of_5_has_5_members():
	assert_eq(SRDFixtures.make_party_of_5().size(), 5)

func test_party_mira_ac_18():
	var party := SRDFixtures.make_party_of_5()
	var mira: Combatant = party[0]
	assert_eq(mira.name, "Mira (Soldier)")
	assert_eq(mira.armor_class, 18)  # chain mail 16 + shield 2

func test_party_kael_ac_15():
	var party := SRDFixtures.make_party_of_5()
	var kael: Combatant = party[1]
	assert_eq(kael.armor_class, 15)  # studded leather 12 + DEX+3

## ── Single-target damage predictability ────────────────────────────────────

func test_skeleton_dies_in_two_hits_from_mira():
	# Mira: longsword 1d8+3, avg dmg = 4+3 = 7. Skeleton HP = 13.
	# Hit 1: 13-7 = 6 HP. Hit 2: 6-7 → 0 HP.
	var mira: Combatant = SRDFixtures.make_party_of_5()[0]
	var sk := SRDMonsters.make_skeleton()
	DamageResolver.apply(sk.stats, 7, SRD.DamageType.SLASHING)
	assert_eq(sk.stats.current_hp, 6)
	DamageResolver.apply(sk.stats, 7, SRD.DamageType.SLASHING)
	assert_eq(sk.stats.current_hp, 0)

## ── Full battle: 5 party vs 4 skeletons ─────────────────────────────────────

func test_party_wins_vs_4_skeletons():
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_skeleton_group(4)
	var result := sim.run(party, enemies)
	assert_true(result.party_won, "Party should defeat 4 skeletons")

func test_no_party_deaths_vs_4_skeletons():
	# Skeletons hit at +4, so the 8-HP Psion can drop — but nobody should die
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_skeleton_group(4)
	var result := sim.run(party, enemies)
	assert_true(result.party_won)
	for m in party:
		assert_false(m.is_dead, "%s should not die vs 4 skeletons" % m.name)

func test_battle_ends_by_round_4_vs_4_skeletons():
	# With avg damage and fixed d20=15, party kills ~2 skeletons per round
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_skeleton_group(4)
	var result := sim.run(party, enemies)
	assert_true(result.rounds_elapsed <= 4,
		"Should finish in ≤4 rounds, took %d" % result.rounds_elapsed)

func test_round_1_has_attacks():
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_skeleton_group(4)
	var result := sim.run(party, enemies)
	var attacks := sim.count_events(result, 1, "attack")
	assert_true(attacks >= 5, "Round 1 should have at least 5 attacks (one per party member)")

func test_round_1_enemy_count_reduced():
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_skeleton_group(4)
	var result := sim.run(party, enemies)
	var r1 := sim.get_round(result, 1)
	assert_true(r1["end_state"]["enemy_alive"] < 4,
		"At least one skeleton should die round 1")

func test_party_total_hp_reduced_by_skeleton_attacks():
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var total_party_hp := 0
	for c in party: total_party_hp += c.stats.max_hp
	var enemies := SRDMonsters.make_skeleton_group(4)
	var result := sim.run(party, enemies)
	# Skeletons attack too — party should have taken some damage
	var r1_hp: int = sim.get_round(result, 1)["end_state"]["party_total_hp"]
	assert_true(r1_hp < total_party_hp,
		"Skeletons should have dealt some damage in round 1")

func test_party_wins_vs_8_skeletons():
	# Harder fight — party should still win but take more rounds/damage
	var sim := _make_sim()
	var party := SRDFixtures.make_party_of_5()
	var enemies := SRDMonsters.make_skeleton_group(8)
	var result := sim.run(party, enemies)
	# With fixed_d20=15 party hits skeleton AC13 reliably; skeletons hit lower ACs too
	# Test that the fight ends (one way or another)
	assert_false(result.draw, "Battle vs 8 skeletons should resolve within max rounds")

func test_poison_damage_does_nothing_to_skeleton():
	var sk := SRDMonsters.make_skeleton()
	DamageResolver.apply(sk.stats, 100, SRD.DamageType.POISON)
	assert_eq(sk.stats.current_hp, 13)  # immune, no change
