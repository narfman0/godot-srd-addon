# godot-srd-addon

D20 rules engine for Godot 4.7: action economy, conditions, concentration, death saves,
AoE, initiative, opportunity attacks, spell resolution, and combat AI — plus loaders that
build those systems from the **System Reference Document 5.2.1**.

## SRD content

`addons/srd/data/srd-5.2.1/` is extracted straight from the official SRD 5.2.1 PDF
(2024 rules) by `tools/extract_srd.py`, which downloads the PDF and checks its SHA-256.
Coverage grows a section at a time:

| Section | Status |
|---|---|
| Spells (339) | Header fields, full text, mechanics: attack/save, damage, healing, area, upcast, cantrip scaling, darts/rays, target counts, timed effects (speed loss, push, Advantage riders, AC and d4 buffs, teleport), reaction triggers |
| Monsters (330) | Full stat blocks: AC, HP, speeds, size, ability scores and saves, defenses, senses, CR/XP, traits, actions with parsed attacks and saves |
| Weapons (38), Armor (13) | Complete tables, including each weapon's mastery |
| Weapon properties (18) | Property and mastery rules text (Cleave ... Vex) |
| Classes (12) | Core traits, spellcasting, and the full 20-level features table (proficiency, features, Rages, Sneak Attack, Cantrips, Prepared Spells, slots...) |
| Class features (232) | Every "Level N: Feature" section with text, named sub-entries, levels gained, embedded tables |
| Subclasses (12) | Tagline, intro, features, always-prepared spells |
| Class options (38) | Metamagic (cost) and Eldritch Invocations (prerequisite) |
| Species (9), Backgrounds (4), Feats (17) | Traits, ability scores, feat categories and prerequisites |
| Magic items (258) | Category, rarity (per +N variant), attunement and prerequisites, text; values in `SRDItems` |
| Rules glossary | Not yet |

`addons/srd/data/authored/spell_overrides.json` is hand-written on top of the extraction:
mechanics the text parser can't read (Hold Person, Haste, Hunter's Mark, Mage Armor...), and
`disabled` for spells that aren't ordinary casts (the smites). `SRDContent.make_spell` merges it.

```bash
python3 -m venv tools/.venv && tools/.venv/bin/pip install pymupdf
tools/.venv/bin/python tools/extract_srd.py            # all sections
tools/.venv/bin/python tools/extract_srd.py monsters   # or just one
```

`SRDContent` turns the rows into runtime objects:

```gdscript
var srd := SRDContent.new()
var wizard := srd.make_class("wizard")                     # ClassData (slots, saves, skills)
var fireball := srd.make_spell("fireball", SRD.Ability.INTELLIGENCE)   # AbilityData
var goblin := srd.make_monster("goblin-warrior", 1)        # Combatant from the stat block
var sword := srd.make_weapon("longsword")                  # WeaponData
var hero := srd.make_character("Rynn", "fighter", 5, [16, 12, 14, 10, 10, 8],
	"longsword", "chain-mail", true, ["athletics"])        # Combatant with HP, AC, slots
```

Spells whose effects `AbilityData` can't express yet carry the `partial` tag (several damage
parts, or a rider in the text with no extracted effect); spells with no detected damage,
healing, or effect carry `no_mechanics`.

### Rules beyond the stat line

- `make_character()` attaches a `ClassKit` (`combatant.kit`): features held at the level,
  limited uses (Second Wind, Action Surge, Channel Divinity, Arcane Recovery...), Weapon
  Mastery picks, and the feature logic. `kit.feature_report()` says which are implemented.
- `AttackResolver.weapon_attack(attacker, target, opts)` resolves a weapon attack with
  Advantage sources, Bless dice, crit range, Fighting Styles, Sneak Attack, Divine Strike,
  and the eight mastery properties. Positional facts come from the game (`opts`, or the
  `AttackResolver.ally_adjacent` callable for Sneak Attack).
- `SpellResolver.cast(...)` handles attack/save spells with riders, darts and rays,
  healing (reviving a creature at 0 HP), buffs, self effects, and Concentration cleanup.
- `ActiveEffects` (`combatant.effects`) holds timed effects; drive expiry with
  `SRDEffects.turn_started(all, actor)` / `SRDEffects.turn_ended(all, actor)`.
- **Critical Hits.** Spell attacks roll their dice twice on a crit and tell
  `SpellResolver.apply_damage(target, amount, type, is_crit)`. Hits from within 5 ft. on a
  Paralyzed or Unconscious target are automatic crits (weapon and spell attacks): pass
  `opts.within_5ft`, or set `AttackResolver.within_5ft` once (a `func(attacker, target) -> bool`).
  The same fact decides Prone's Advantage (within 5 ft.) or Disadvantage (beyond).
- **Cover.** `opts.cover` (`SRD.Cover`, or `{target name: SRD.Cover}` for spells) adds +2 / +5
  to AC against attacks and to Dexterity saves. The game measures it from its geometry.
- **Monster Bonus Actions and Reactions** (`MonsterActions`). `make_monster()` parses the stat
  block into `combatant.bonus_actions` / `combatant.reactions`: `simple` (Nimble Escape's
  Disengage or Hide, Hasten's Dash and Disengage), `teleport` (Blink Dog, Shadow Step-style
  teleports with a `requires` the game answers and an Advantage rider), `ac_bonus` (Parry), and
  damage-triggered teleports that leave the creature Invisible until it attacks. Uses (1/Day,
  Recharge X) are tracked; `MonsterActions.start_turn(c)` rolls recharges. Authored keys in a
  pack row (`teleport_feet`, `condition`, `requires`, `usage`...) override the parse.
  `MonsterActions.reaction_for(c, "took_damage" | "hit_by_attack", ctx)` finds a reaction worth
  taking; `use(c, feature)` spends it and returns what the game must do (`teleport_feet`).
  Weapon riders ("if it had Advantage on the roll, an extra 2d6 Necrotic", once per turn) are
  `combatant.hit_riders`, applied by `AttackResolver`. `CombatAI.plan_turn()` folds them into the
  plan (`plan.monster_bonus`, `bonus_timing` "before_move" / "after_action",
  `retreat_after_action`); `CombatAI.plan_escape(ctx)` plans a getaway. Give
  `AIContext.requirement_met` a callable for lighting requirements.
- **Unarmed Strike** (`UnarmedStrike`): Shove (push 5 ft. or Prone) and Grapple, 2024 style:
  the target picks a STR or DEX save vs 8 + STR mod + PB; at most one size larger;
  Paralyzed / Unconscious targets fail. `fail_chance()` for previews.
- **Undead Fortitude** is a CON save (DC 5 + damage taken) the engine rolls in
  `Combatant.take_damage()`; the result is `combatant.last_undead_fortitude`
  (`{dc, d20, bonus, total, saved}` or `{blocked: "radiant" | "critical"}`) and appears as
  `undead_fortitude` on attack and spell events.
- **Summons** (`SpellSummon`, Spiritual Weapon): casting appends a `{type: "summon", summon}`
  event. The force keeps the cast's slot level, attacks from within 5 ft. of itself (a melee
  spell attack), lasts the duration (`turn_started()` on the caster's turns) and ends with
  Concentration. Later turns: `SpellResolver.summon_strike(summon, target)` after the game
  moves `summon.position` up to `move_feet`.
- **Initiative and Surprise.** `CombatOrder.roll(c, surprised)`: the stat block's Initiative
  for monsters (`combatant.initiative_bonus`), Disadvantage when surprised or Incapacitated,
  Advantage when Invisible (SRD 5.2.1 Surprise has no lost turn).
- **Pact Magic** slots come from the Warlock table (level 3: two 2nd-level slots), and
  `SRDLevelUp` drops the old level's slots when they move up. Games layer their own rows (homebrew
monsters, renamed setting content) with a second `SRDContentPack.load_dir()`.

When exporting a game, add `*.json` to the export filter so the pack ships.

The original Soldier/Ghost/Psion/Warden presets (`ClassData.make_*`) remain for Wayfarer.

## Tests

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Attribution

Portions of this content are from the System Reference Document 5.2.1 © 2025 Wizards of
the Coast LLC, available at <https://dnd.wizards.com/resources/systems-reference-document>
under the Creative Commons Attribution 4.0 International License. Wizards of the Coast
endorsement is not implied.

## Progression, gear and high-level play

- **`SRDProgression`**: `summary()` (what a level grants), `choices()` (what it asks: ASI or feat,
  masteries, Expertise, cantrips, prepared spells, Invocations, Metamagic, Mystic Arcanum, subclass
  options), `resolve()` (a plain build at a level -> scores, options, spells), `auto_answer()`.
- **`SRDRest`**: `short_rest_combatant(c, dice)` and `long_rest_combatant(c)` follow 5.2.1 (all Hit
  Point Dice back on a Long Rest) and fire rest-time features (Arcane Recovery, Natural Recovery,
  Sorcerous Restoration, Magical Cunning). The older `short_rest`/`long_rest` stay for other games.
- **`ItemEffects.apply(c, mods_list)`**: worn gear as plain `mods` Dictionaries; it resets to the
  bare character and folds them in, retroactive CON included.
- **`ClassKit`**: `finish(c)` applies passives (Unarmored Defense, speed, Slippery Mind, resistances);
  `FEATURE_ACTIONS`, `feature_actions()`, `can_use()`, `use_feature()` give a game a hotbar;
  `on_hit_extras()` feeds `AttackResolver` (Radiant Strikes, Colossus Slayer, Primal Strike), which
  also reads Hunter's Mark and Hex (`marked` effects), Cunning Strike and Savage Attacker.
  `IMPLEMENTED` lists what the engine or its game apply.
- **`MonsterSpells`**: stat-block Spellcasting (`parse`, `available`, `make_ability`) and save actions
  (`parse_save_actions`, `save_ability`, Recharge), resolved through `SpellResolver`.
- **`SpellPlanner`**: weighs candidate spells, in expected damage, against the plain attack and how
  long the fight will last.
