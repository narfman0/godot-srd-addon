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
| Spells (339) | Header fields, full text, heuristic mechanics (attack/save, damage, healing, area, upcast, cantrip scaling) |
| Monsters (330) | Full stat blocks: AC, HP, speeds, ability scores and saves, defenses, senses, CR/XP, traits, actions with parsed attacks and saves |
| Weapons (38), Armor (13) | Complete tables |
| Classes (12) | Core traits and spellcasting progression only |
| Class features, subclasses, species, backgrounds, feats, magic items | Not yet |

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

Spells whose effects `AbilityData` can't express yet carry the `partial` tag; spells with no
detected damage or healing carry `no_mechanics`. Games layer their own rows (homebrew
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
