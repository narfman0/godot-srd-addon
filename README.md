# godot-srd-addon

D20 rules engine for Godot 4.7: action economy, conditions, concentration, death saves,
AoE, initiative, opportunity attacks, spell resolution, and combat AI — plus loaders that
build those systems from the **System Reference Document 5.2.1**.

## SRD content

`addons/srd/data/srd-5.2/` is a vendored copy of grimoire's `content-packs/srd-5.2`
(refresh with `tools/sync_srd_pack.sh`). `SRDContent` turns its rows into runtime objects:

```gdscript
var srd := SRDContent.new()
var wizard := srd.make_class("wizard")                     # ClassData (slots, saves, skills)
var fireball := srd.make_spell("fireball", SRD.Ability.INTELLIGENCE)   # AbilityData
var goblin := srd.make_monster("goblin", 1)                # Combatant from the stat block
var sword := srd.make_weapon("longsword")                  # WeaponData
```

Spells whose effects `AbilityData` can't yet express carry the `partial` tag; pack rows
with no mechanics yet carry `stub`.

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
