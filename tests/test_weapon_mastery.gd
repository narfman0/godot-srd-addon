## SRD 5.2.1 Weapon Mastery properties through AttackResolver.
extends GutTest

var srd: SRDContent

func before_all():
	srd = SRDContent.new()

func _fighter(weapon: String, level: int = 3, extra := {}) -> Combatant:
	var opts := {"weapon_masteries": [weapon]}
	opts.merge(extra)
	return srd.make_character("Ilse", "fighter", level, [16, 14, 14, 8, 12, 10], weapon,
		"chain-mail", false, ["athletics"], "", opts)

func _dummy(n: String = "Dummy", hp: int = 100, ac: int = 10) -> Combatant:
	var s := CharacterStats.new()
	s.character_name = n
	s.max_hp = hp
	s.reset()
	var eq := EquipmentSlots.new()
	eq.natural_ac = ac
	var c := Combatant.new(s, null, eq)
	c.dies_at_zero_hp = true
	return c

func test_mastery_counts_per_class():
	assert_eq(srd.weapon_mastery_count("fighter", 1), 3)
	assert_eq(srd.weapon_mastery_count("fighter", 17), 6)
	assert_eq(srd.weapon_mastery_count("barbarian", 1), 2)
	assert_eq(srd.weapon_mastery_count("rogue", 1), 2)
	assert_eq(srd.weapon_mastery_count("paladin", 1), 2)
	assert_eq(srd.weapon_mastery_count("ranger", 1), 2)
	assert_eq(srd.weapon_mastery_count("wizard", 20), 0)
	assert_eq(srd.weapon_mastery_count("cleric", 5), 0)

func test_weapons_carry_mastery():
	assert_eq(srd.make_weapon("longsword").mastery, "sap")
	assert_eq(srd.make_weapon("greataxe").mastery, "cleave")
	assert_eq(srd.make_weapon("rapier").mastery, "vex")
	assert_eq(srd.weapon_property("topple").data.mastery, true)

func test_no_mastery_without_the_feature():
	var w := srd.make_character("Teo", "wizard", 3, [8, 14, 14, 16, 12, 10], "quarterstaff")
	assert_false(w.kit.can_use_mastery(w.weapon))
	var ev := AttackResolver.weapon_attack(w, _dummy(), {"d20": 15, "save_d20": 1})
	assert_false(ev.has("mastery"))

func test_sap_gives_disadvantage_on_next_attack():
	var f := _fighter("longsword")
	var t := _dummy()
	var ev := AttackResolver.weapon_attack(f, t, {"d20": 15, "average": true})
	assert_eq(ev.mastery, "sap")
	assert_true(t.effects.has_rider("disadvantage_on_attack"))
	var t_atk := AttackResolver.weapon_attack(t, f, {"d20": 15, "d20_2": 3})
	assert_true(t_atk.disadvantage)
	assert_eq(t_atk.d20, 3)
	assert_false(t.effects.has_rider("disadvantage_on_attack"), "spent by the roll")

func test_sap_expires_at_start_of_attackers_turn():
	var f := _fighter("longsword")
	var t := _dummy()
	AttackResolver.weapon_attack(f, t, {"d20": 15, "average": true})
	SRDEffects.turn_started([f, t], f)
	assert_false(t.effects.has_rider("disadvantage_on_attack"))

func test_slow_reduces_speed_once():
	var f := _fighter("javelin")
	var t := _dummy()
	AttackResolver.weapon_attack(f, t, {"d20": 15, "average": true})
	AttackResolver.weapon_attack(f, t, {"d20": 15, "average": true})
	assert_eq(t.speed, 20, "two Slow hits never exceed 10 feet")
	SRDEffects.turn_started([f, t], f)
	assert_eq(t.speed, 30)

func test_push_only_large_or_smaller():
	var f := _fighter("warhammer")
	var ev := AttackResolver.weapon_attack(f, _dummy(), {"d20": 15, "average": true})
	assert_eq(ev.get("push_feet"), 10)
	var huge := _dummy("Giant")
	huge.size = "huge"
	ev = AttackResolver.weapon_attack(f, huge, {"d20": 15, "average": true})
	assert_false(ev.has("push_feet"))

func test_topple_on_failed_con_save():
	var f := _fighter("quarterstaff")
	var t := _dummy()
	var ev := AttackResolver.weapon_attack(f, t, {"d20": 15, "average": true, "save_d20": 2})
	assert_eq(ev.topple.dc, 8 + 3 + 2)  # Str +3, PB +2
	assert_false(ev.topple.saved)
	assert_true(t.conditions.has(SRD.Condition.PRONE))
	var t2 := _dummy()
	ev = AttackResolver.weapon_attack(f, t2, {"d20": 15, "average": true, "save_d20": 20})
	assert_false(t2.conditions.has(SRD.Condition.PRONE))

func test_vex_grants_advantage_on_next_attack_against_that_target():
	var r := srd.make_character("Corvin", "rogue", 3, [8, 16, 14, 12, 12, 10], "rapier", "leather-armor")
	var t := _dummy()
	AttackResolver.weapon_attack(r, t, {"d20": 15, "average": true, "sneak_attack": false})
	assert_true(r.effects.has_rider("advantage_vs", t.name))
	var ev := AttackResolver.weapon_attack(r, t, {"d20": 4, "d20_2": 17, "average": true})
	assert_true(ev.advantage)
	assert_eq(ev.d20, 17)

func test_graze_damages_on_a_miss():
	var f := _fighter("greatsword")
	var t := _dummy("Dummy", 100, 30)
	var ev := AttackResolver.weapon_attack(f, t, {"d20": 5})
	assert_false(ev.hit)
	assert_eq(ev.mastery, "graze")
	assert_eq(ev.damage_dealt, 3)  # Str modifier
	assert_eq(t.current_hp, 97)

func test_cleave_offers_one_extra_attack_without_modifier():
	var f := _fighter("greataxe")
	var ev := AttackResolver.weapon_attack(f, _dummy(), {"d20": 15, "average": true})
	assert_true(ev.get("cleave_available", false))
	var second := _dummy("Second")
	var ev2 := AttackResolver.weapon_attack(f, second, {"d20": 15, "average": true, "cleave": true})
	assert_eq(ev2.damage, 6, "1d12 average, no Str modifier")
	var ev3 := AttackResolver.weapon_attack(f, _dummy(), {"d20": 15, "average": true})
	assert_false(ev3.get("cleave_available", false), "once per turn")
	SRDEffects.turn_started([f], f)
	assert_true(AttackResolver.weapon_attack(f, _dummy(), {"d20": 15, "average": true}).get("cleave_available", false))

func test_nick_flags_light_extra_attack():
	var f := _fighter("dagger")
	var ev := AttackResolver.weapon_attack(f, _dummy(), {"d20": 15, "average": true})
	assert_eq(ev.mastery, "nick")
	var light := AttackResolver.weapon_attack(f, _dummy(), {"d20": 15, "average": true, "light_extra": true})
	assert_eq(light.damage, 2, "1d4 average; no modifier without Two-Weapon Fighting")

func test_tactical_master_swaps_in_push():
	var f := _fighter("longsword", 9)
	var ev := AttackResolver.weapon_attack(f, _dummy(), {"d20": 15, "average": true, "mastery_override": "push"})
	assert_eq(ev.mastery, "push")
	var low := _fighter("longsword", 3)
	ev = AttackResolver.weapon_attack(low, _dummy(), {"d20": 15, "average": true, "mastery_override": "push"})
	assert_eq(ev.mastery, "sap", "Tactical Master is level 9")
