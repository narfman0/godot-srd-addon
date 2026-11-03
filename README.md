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
| Magic items, rules glossary | Not yet |

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
  `SRDEffects.turn_started(all, actor)` / `SRDEffects.turn_ended(all, actor)`. Games layer their own rows (homebrew
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
