## Deterministic or random battle simulator for testing and game logic.
##
## Deterministic mode (fixed_d20 > 0, use_average_damage = true):
##   All d20 rolls use fixed_d20 (try 11 for median, 20 to guarantee hits).
##   All damage dice use floor((sides+1)/2) — integer average.
##   This makes every battle outcome exactly predictable for assertions.
class_name BattleSimulator
extends RefCounted

## Options
var fixed_d20: int = 0          # 0 = random; 1-20 = always use this value
var fixed_save_d20: int = 0     # 0 = follow fixed_d20; 1-20 = pin saving throws (e.g. Undead Fortitude) separately
var use_average_damage: bool = false
var max_rounds: int = 20

## Result returned by run().
class BattleResult:
	var party_won: bool = false
	var enemy_won: bool = false
	var draw: bool = false       # max_rounds hit with no winner
	var rounds_elapsed: int = 0
	var round_logs: Array = []   # Array[Dictionary] — one entry per round

	func winner() -> String:
		if party_won: return "party"
		if enemy_won: return "enemies"
		return "draw"

## Run a full battle between two sides.
## party and enemies are both Array[Combatant].
## Returns a BattleResult.
func run(party: Array, enemies: Array) -> BattleResult:
	var result := BattleResult.new()
	var all_combatants: Array = party + enemies

	# Build initiative order
	var order := _build_order(all_combatants)

	for round_num in range(1, max_rounds + 1):
		result.rounds_elapsed = round_num
		var round_log := { "round": round_num, "events": [], "end_state": {} }

		for idx in order.size():
			var actor: Combatant = order[idx]
			if not actor.can_act():
				# Dying: roll death save
				if actor.is_down and not actor.death_saves.is_resolved():
					var d20 := _d20()
					actor.death_saves.roll(d20)
					round_log["events"].append({
						"type": "death_save",
						"actor": actor.name,
						"d20": d20,
						"successes": actor.death_saves.successes,
						"failures": actor.death_saves.failures,
						"stable": actor.death_saves.is_stable,
						"dead": actor.death_saves.is_dead,
					})
				continue

			actor.action_economy.reset_turn()

			# Pick best living target from the opposing side
			var targets := enemies if _is_in(actor, party) else party
			var target: Combatant = _pick_target(targets)
			if target == null:
				continue  # no valid targets — side is wiped

			# Attack action
			if actor.action_economy.use_action():
				var event := _resolve_attack(actor, target)
				round_log["events"].append(event)

		# Snapshot end-of-round state
		round_log["end_state"] = _snapshot(party, enemies)
		result.round_logs.append(round_log)

		# Check win condition
		if _all_down(enemies):
			result.party_won = true
			break
		if _all_down(party):
			result.enemy_won = true
			break

	if not result.party_won and not result.enemy_won:
		result.draw = true

	return result

## Return the round log for a specific round (1-indexed).
func get_round(result: BattleResult, round_num: int) -> Dictionary:
	if round_num < 1 or round_num > result.round_logs.size():
		return {}
	return result.round_logs[round_num - 1]

## Count events of a given type in a round.
func count_events(result: BattleResult, round_num: int, type: String) -> int:
	var log := get_round(result, round_num)
	if log.is_empty(): return 0
	var count := 0
	for ev in log["events"]:
		if ev.get("type", "") == type:
			count += 1
	return count

# ── Private ──────────────────────────────────────────────────────────────────

func _build_order(combatants: Array) -> Array:
	var entries: Array = []
	for c in combatants:
		var dex: int = c.stats.get_ability(SRD.Ability.DEXTERITY)
		var mod := SRDRules.ability_modifier(dex)
		var roll := _d20()
		entries.append({ "combatant": c, "total": roll + mod, "dex": dex })
	entries.sort_custom(func(a, b):
		if a["total"] != b["total"]: return a["total"] > b["total"]
		return a["dex"] > b["dex"]
	)
	var order: Array = []
	for e in entries:
		order.append(e["combatant"])
	return order

func _resolve_attack(actor: Combatant, target: Combatant) -> Dictionary:
	var weapon := actor.weapon
	var d20 := _d20()
	var attack_mod := weapon.attack_bonus(actor.stats, actor.is_proficient_with_weapon)
	var crit := SRDRules.is_critical_hit(d20)
	var miss := SRDRules.is_critical_miss(d20)
	var target_ac := target.armor_class

	var hit := false
	if crit: hit = true
	elif miss: hit = false
	else: hit = SRDRules.attack_hits(d20, attack_mod, target_ac)

	var damage := 0
	var damage_dealt := 0
	if hit:
		damage = _roll_damage(weapon, actor.stats)
		if crit:
			damage += _roll_damage_dice_only(weapon)
		damage_dealt = target.take_damage(damage, weapon.damage_type, crit,
				fixed_save_d20 if fixed_save_d20 > 0 else fixed_d20)

	return {
		"type": "attack",
		"attacker": actor.name,
		"target": target.name,
		"d20": d20,
		"attack_mod": attack_mod,
		"target_ac": target_ac,
		"hit": hit,
		"crit": crit,
		"damage": damage,
		"damage_dealt": damage_dealt,
		"target_hp_after": target.stats.current_hp,
		"target_alive": target.is_alive,
		"undead_fortitude_saved": target.has_undead_fortitude and target.stats.current_hp == 1 and damage_dealt >= target.stats.max_hp,
	}

func _roll_damage(weapon: WeaponData, char: CharacterStats) -> int:
	if use_average_damage:
		return _avg_die(weapon.die_sides) * weapon.die_count + weapon._damage_mod(char)
	return weapon.roll_damage(char)

func _roll_damage_dice_only(weapon: WeaponData) -> int:
	if use_average_damage:
		return _avg_die(weapon.die_sides) * weapon.die_count
	return weapon.roll_damage_dice_only()

func _d20() -> int:
	return fixed_d20 if fixed_d20 > 0 else Dice.roll_d20()

func _avg_die(sides: int) -> int:
	return (sides + 1) / 2

func _pick_target(targets: Array) -> Combatant:
	var best: Combatant = null
	for t in targets:
		if not t.is_active: continue
		if best == null or t.stats.current_hp < best.stats.current_hp:
			best = t
	return best

func _is_in(c: Combatant, arr: Array) -> bool:
	return arr.has(c)

func _all_down(combatants: Array) -> bool:
	for c in combatants:
		if c.is_active: return false
	return true

func _snapshot(party: Array, enemies: Array) -> Dictionary:
	var party_hp := 0; var party_alive := 0
	for c in party:
		if c.is_active: party_alive += 1; party_hp += c.stats.current_hp
	var enemy_hp := 0; var enemy_alive := 0
	for c in enemies:
		if c.is_active: enemy_alive += 1; enemy_hp += c.stats.current_hp
	return {
		"party_alive": party_alive,
		"party_total_hp": party_hp,
		"enemy_alive": enemy_alive,
		"enemy_total_hp": enemy_hp,
	}
