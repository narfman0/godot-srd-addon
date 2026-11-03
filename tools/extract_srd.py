#!/usr/bin/env python3
"""Extract structured JSON from the official SRD 5.2.1 PDF (CC-BY-4.0).

    tools/.venv/bin/python tools/extract_srd.py            # writes addons/srd/data/srd-5.2.1/

Coverage grows section by section. Each section parser is independent, keyed off the PDF's
bookmarks and fonts, and writes one JSON file of {kind, slug, name, page, data} rows.
Currently: spells (with effect riders), monsters, weapons, weapon and mastery properties,
armor, classes (core traits + the 20-level features table), class features, subclasses,
class options (Metamagic, Eldritch Invocations), species, backgrounds, feats, magic items.
 Not yet: the rules glossary.

Requires PyMuPDF: python3 -m venv tools/.venv && tools/.venv/bin/pip install pymupdf
"""
import hashlib, json, re, sys, urllib.request
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "tools/srd_source/SRD_CC_v5.2.1.pdf"
PDF_URL = "https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf"
PDF_SHA256 = "8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87"
OUT = ROOT / "addons/srd/data/srd-5.2.1"

ABILITIES = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"]
ABBR = {a[:3].lower(): a[:3].lower() for a in ABILITIES}
DAMAGE_TYPES = ["Acid", "Bludgeoning", "Cold", "Fire", "Force", "Lightning", "Necrotic",
                "Piercing", "Poison", "Psychic", "Radiant", "Slashing", "Thunder"]
DMG = "|".join(DAMAGE_TYPES)
DICE = r"\d+d\d+(?:\s*[+−-]\s*\d+)?"

# ── PDF access ────────────────────────────────────────────────────────────────

def ensure_pdf() -> None:
    if not PDF.exists():
        PDF.parent.mkdir(parents=True, exist_ok=True)
        print(f"downloading {PDF_URL}")
        urllib.request.urlretrieve(PDF_URL, PDF)
    digest = hashlib.sha256(PDF.read_bytes()).hexdigest()
    if digest != PDF_SHA256:
        sys.exit(f"{PDF} sha256 {digest} != expected {PDF_SHA256}")

def section_pages(doc, title: str) -> range:
    """0-based page range of a level-2 bookmark, up to the next level-2 bookmark."""
    toc = [(lvl, t, p) for lvl, t, p in doc.get_toc() if lvl == 2]
    for i, (_, t, p) in enumerate(toc):
        if t == title:
            end = toc[i + 1][2] if i + 1 < len(toc) else doc.page_count + 1
            return range(p - 1, end - 1)
    raise KeyError(title)

class Line:
    __slots__ = ("text", "spans", "x", "y", "page")

    def __init__(self, spans, page):
        self.spans = spans
        self.text = re.sub(r"[ \t\xa0]+", " ", "".join(s["text"] for s in spans)).strip()
        self.x, self.y = spans[0]["bbox"][0], spans[0]["bbox"][1]
        self.page = page

    def font(self, i=0) -> str:
        s = self.spans[i]
        return f'{s["font"]}:{s["size"]:.1f}'

    def has_font(self, prefix: str) -> bool:
        return any(f'{s["font"]}:{s["size"]:.1f}'.startswith(prefix) for s in self.spans)

    def paragraph_start(self) -> bool:
        return self.spans[0]["text"].startswith("\t")

def page_lines(doc, pages) -> list[Line]:
    """Lines in reading order: left column, then right column, per page. Running headers dropped."""
    out = []
    for pn in pages:
        cols = ([], [])
        for b in doc[pn].get_text("dict")["blocks"]:
            for l in b.get("lines", []):
                spans = [s for s in l["spans"] if s["text"].strip() or s["text"] == "\t"]
                spans = [s for s in spans if s["text"]]
                if not spans or not "".join(s["text"] for s in spans).strip():
                    continue
                line = Line(spans, pn + 1)
                if line.y > 735:  # page footer
                    continue
                cols[0 if line.x < 297 else 1].append(line)
        out += cols[0] + cols[1]
    return out

def page_lines_raw(doc, pages) -> list[Line]:
    """Lines sorted top-to-bottom then left-to-right per page, ignoring columns (for full-width tables)."""
    out = []
    for pn in pages:
        lines = [Line([s for s in l["spans"] if s["text"]], pn + 1)
                 for b in doc[pn].get_text("dict")["blocks"] for l in b.get("lines", [])
                 if "".join(s["text"] for s in l["spans"]).strip()]
        out += sorted((ln for ln in lines if ln.y <= 735), key=lambda ln: (round(ln.y / 4), ln.x))
    return out

def join_text(lines: list[Line]) -> str:
    """Rejoin wrapped lines: de-hyphenate, keep paragraph breaks (tab-indented lines)."""
    text = ""
    for ln in lines:
        t = ln.text
        if not text:
            text = t
        elif ln.paragraph_start():
            text += "\n" + t
        elif text.endswith("-") and t[:1].islower():
            text = text[:-1] + t
        else:
            text += " " + t
    return text.strip()

def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower().replace("’", "").replace("'", "")).strip("-")

def num(s: str) -> int:
    return int(s.replace("−", "-").replace("–", "-").replace(" ", ""))

def dice(s: str) -> str:
    return re.sub(r"\s+", "", s.replace("−", "-"))

def row(kind: str, name: str, page: int, data: dict) -> dict:
    return {"kind": kind, "slug": slug(name), "name": name, "page": page, "data": data}

# ── Spells ────────────────────────────────────────────────────────────────────

SPELL_HEAD = re.compile(r"^(?:Level (\d) (\w+)|(\w+) Cantrip) \((.*)")

def parse_spells(doc) -> list[dict]:
    lines = page_lines(doc, section_pages(doc, "Spells"))
    starts = [i for i in range(len(lines) - 1)
              if lines[i].font().startswith("GillSans-SemiBold") and lines[i].font().endswith(":12.0")
              and SPELL_HEAD.match(lines[i + 1].text)]
    spells = []
    for n, i in enumerate(starts):
        end = starts[n + 1] if n + 1 < len(starts) else len(lines)
        block = lines[i:end]
        # Trim trailing section headings (e.g. a level-2 "Spell Descriptions" header)
        while block and block[-1].font().startswith("GillSans-SemiBold") and len(block) > 2:
            block = block[:-1]
        spells.append(_spell(block))
    return spells

def _spell(block: list[Line]) -> dict:
    name = block[0].text
    m = SPELL_HEAD.match(block[1].text)
    k = 2
    head = block[1].text
    while not head.endswith(")") and k < len(block):  # class list wraps
        head += " " + block[k].text
        k += 1
    classes = [c.strip() for c in head[head.index("(") + 1:-1].split(",")]
    level = int(m.group(1)) if m.group(1) else 0
    school = m.group(2) or m.group(3)

    fields, body = {}, []
    key = None
    for ln in block[k:]:
        fm = re.match(r"^(Casting Time|Range|Components|Duration):\s*(.*)", ln.text)
        if fm and not body:
            key = fm.group(1)
            fields[key] = fm.group(2)
        elif key and ln.has_font("GillSans") and not body:
            fields[key] += " " + ln.text
        else:
            key = None
            body.append(ln)
    text = join_text(body)
    higher = cantrip = ""
    paras = text.split("\n")
    for p in list(paras):
        if p.startswith("Using a Higher-Level Spell Slot."):
            higher = p.split(".", 1)[1].strip(); paras.remove(p)
        elif p.startswith("Cantrip Upgrade."):
            cantrip = p.split(".", 1)[1].strip(); paras.remove(p)
    text = "\n".join(paras)

    casting = fields.get("Casting Time", "")
    duration = fields.get("Duration", "")
    comps = fields.get("Components", "")
    material = re.search(r"M \((.*)\)", comps)
    data = {
        "level": level,
        "school": school.lower(),
        "classes": [c.lower() for c in classes],
        "casting_time": re.sub(r"\s+or Ritual$", "", casting),
        "ritual": casting.endswith("or Ritual"),
        "range": _spell_range(fields.get("Range", "")),
        "components": [c for c in ("V", "S", "M") if re.search(rf"(^|,\s*){c}\b", comps)],
        "material": material.group(1) if material else "",
        "duration": re.sub(r"^Concentration, up to ", "", duration),
        "concentration": duration.startswith("Concentration"),
        "text": text,
        "higher_levels": higher,
        "cantrip_upgrade": cantrip,
    }
    data["mechanics"] = _spell_mechanics({**data, "_name": name})
    return row("spell", name, block[0].page, data)

def _spell_range(r: str) -> dict:
    out = {"raw": r}
    if m := re.match(r"^(\d+) (feet|miles?)", r):
        out["feet"] = int(m.group(1)) * (5280 if m.group(2).startswith("mile") else 1)
    elif r.startswith("Self"):
        out["self"] = True
    elif r.startswith("Touch"):  # "Touch Component: V, S": a wrapped header line
        out["touch"] = True
    if m := re.search(r"(\d+)-foot(?:-radius)? (Cone|Cube|Line|Sphere|Emanation|Cylinder)", r):
        out["area"] = {"shape": m.group(2).lower(), "size": int(m.group(1))}
    return out

def _spell_mechanics(d: dict) -> dict:
    """Best-effort mechanics from the description. Absent keys mean 'not detected', not 'none'."""
    t = d["text"]
    mech = {}
    if m := re.search(r"(melee|ranged) spell attack", t, re.I):
        mech["attack"] = m.group(1).lower()
    if m := re.search(rf"({'|'.join(ABILITIES)}) saving throw", t):
        mech["save"] = m.group(1)[:3].lower()
        mech["half_on_save"] = "half as much damage" in t
    parts = [{"dice": dice(a), "type": b.lower()} for a, b in re.findall(rf"({DICE}) ({DMG}) damage", t)]
    if parts:
        mech["damage"] = parts
    if m := re.search(rf"regains?.{{0,40}}?Hit Points equal to ({DICE})", t):
        mech["healing"] = dice(m.group(1))
    if "area" not in d["range"]:
        if m := re.search(r"(\d+)-foot(?:-radius|-long)?,?.{0,20}?(Sphere|Cone|Cube|Line|Cylinder|Emanation)", t):
            mech["area"] = {"shape": m.group(2).lower(), "size": int(m.group(1))}
    else:
        mech["area"] = d["range"]["area"]
    if m := re.search(rf"increases by ({DICE}) for each spell slot level above (\d)", d["higher_levels"]):
        mech["upcast_dice"] = dice(m.group(1))
    if m := re.findall(rf"(\d+) \(({DICE})\)", d["cantrip_upgrade"]):
        mech["cantrip_dice"] = {lvl: dice(dd) for lvl, dd in m}
    _spell_riders(d, mech)
    mech.update(SPELL_OVERRIDES.get(slug(d.get("_name", "")), {}))
    return mech

NUMBER_WORDS = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6}

def _duration_rounds(duration: str) -> int:
    """'1 minute' -> 10 rounds; 0 for instantaneous or open-ended durations."""
    if m := re.match(r"(?:Concentration, up to )?(\d+) (round|minute|hour)", duration):
        return int(m.group(1)) * {"round": 1, "minute": 10, "hour": 600}[m.group(2)]
    return 0

def _spell_riders(d: dict, mech: dict) -> None:
    """Conservative patterns for the effects AbilityData/SpellResolver can apply: darts and rays,
    flat modifiers, speed reduction, push, advantage riders, AC and d4 buffs, teleports,
    target counts, and reaction triggers. Each effect carries when it expires."""
    t, hl = d["text"], d["higher_levels"]
    rounds = _duration_rounds(d["duration"])
    for_duration = {"expires": "start_of_turn", "of": "caster", "turns": max(rounds, 1)}
    # "Force damage equal to 1d8 plus your spellcasting ability modifier"
    if m := re.search(rf"({DMG}) damage equal to ({DICE})( plus your spellcasting ability modifier)?", t):
        mech.setdefault("damage", []).append({"dice": dice(m.group(2)), "type": m.group(1).lower()})
        if m.group(3):
            mech["damage_add_modifier"] = True
    if re.search(rf"Hit Points equal to {DICE} plus your spellcasting ability modifier", t):
        mech["healing_add_modifier"] = True
    if m := re.search(rf"(?:healing|damage) increases by ({DICE}) for (?:each|every) (?:spell )?slot level above", hl):
        mech["upcast_dice"] = dice(m.group(1))
    # Darts and rays: one damage roll (and attack roll, for rays) per projectile
    if m := re.search(r"(?:create|hurl) (two|three|four) (?:glowing )?(?:fiery )?(darts|rays)", t):
        mech["projectiles"] = NUMBER_WORDS[m.group(1)]
        if "attack" not in mech:
            mech["auto_hit"] = True
    if re.search(r"one (?:more|additional) (?:dart|ray) for each", hl):
        mech["upcast_projectiles"] = 1
    if m := re.search(r"(?:up to|bless up to) (two|three|four|five|six) creatures", t):
        mech["max_targets"] = NUMBER_WORDS[m.group(1)]
    if re.search(r"one additional creature for each spell slot level above", hl):
        mech["upcast_targets"] = 1
    effects = []
    if m := re.search(r"Speed is reduced by (\d+) feet until the start of your next turn", t):
        effects.append({"on": "hit", "type": "speed_penalty", "amount": int(m.group(1)),
                        "expires": "start_of_turn", "of": "caster", "turns": 1})
    if re.search(r"can’t make Opportunity Attacks until the start of its next turn", t):
        effects.append({"on": "hit", "type": "no_opportunity_attacks",
                        "expires": "start_of_turn", "of": "target", "turns": 1})
    if m := re.search(r"is pushed (\d+) feet away from you", t):
        effects.append({"on": "fail", "type": "push", "feet": int(m.group(1))})
    if re.search(r"the next attack roll made against it before the end of your next turn has Advantage", t):
        effects.append({"on": "hit", "type": "advantage_to_attackers", "uses": 1,
                        "expires": "end_of_turn", "of": "caster", "turns": 2})
    if m := re.search(r"\+(\d+) bonus to AC", t):
        exp = {"expires": "start_of_turn", "of": "caster", "turns": 1} \
            if "Until the start of your next turn" in t else for_duration
        effects.append({"on": "apply", "type": "ac_bonus", "amount": int(m.group(1)), **exp})
    if m := re.search(r"adds (1d\d+) to the attack roll or save", t):
        effects.append({"on": "apply", "type": "bonus_die", "die": dice(m.group(1)),
                        "applies": ["attack", "save"], **for_duration})
    if m := re.search(r"adds (1d\d+) to any ability check", t):
        effects.append({"on": "apply", "type": "bonus_die", "die": dice(m.group(1)),
                        "applies": ["check"], **for_duration})
    if m := re.search(r"you teleport up to (\d+) feet", t):
        effects.append({"on": "apply", "type": "teleport", "feet": int(m.group(1)), "self": True})
    if effects:
        mech["effects"] = effects
    if m := re.match(r"Reaction, which you take (.*)", d["casting_time"]):
        mech["reaction_trigger"] = m.group(1)

## Spells whose rules the patterns above can't express. Each value merges over the
## heuristic mechanics; keep entries to what the spell's text says.
SPELL_OVERRIDES = {
    # 2024 Sleep: Wis save or Incapacitated until the end of its next turn, then repeat the save;
    # a second failure means Unconscious for the duration. Ends on damage.
    "sleep": {"effects": [
        {"on": "fail", "type": "condition", "condition": "incapacitated", "ends_on_damage": True,
         "expires": "end_of_turn", "of": "target", "turns": 1,
         "repeat_save": {"on_fail": {"type": "condition", "condition": "unconscious", "ends_on_damage": True,
                                     "expires": "start_of_turn", "of": "caster", "turns": 10}}}],
        # "Creatures that don't sleep, such as elves, or that have Immunity to the Exhaustion
        # condition automatically succeed"; magical-sleep marks "magic can't put it to sleep"
        "immune_if": ["exhaustion", "magical-sleep"]},
    # Shield also negates Magic Missile; the trigger is "hit by an attack roll or targeted by Magic Missile".
    "shield": {"effects": [
        {"on": "apply", "type": "ac_bonus", "amount": 5, "self": True,
         "expires": "start_of_turn", "of": "caster", "turns": 1},
        {"on": "apply", "type": "immune_to_spell", "spell": "magic-missile", "self": True,
         "expires": "start_of_turn", "of": "caster", "turns": 1}]},
    # The force persists for the duration; later turns repeat the attack as a Bonus Action.
    "spiritual-weapon": {"summon": {"repeat_as": "bonus_action", "move_feet": 20, "rounds": 10}},
}

# ── Monsters ──────────────────────────────────────────────────────────────────

STAT_FIELDS = ["AC", "Initiative", "HP", "Speed", "Skills", "Resistances", "Vulnerabilities",
               "Immunities", "Gear", "Senses", "Languages", "CR"]
SUBSECTIONS = ["Traits", "Actions", "Bonus Actions", "Reactions", "Legendary Actions"]

def parse_monsters(doc) -> list[dict]:
    pages = range(section_pages(doc, "Monsters").start, doc.page_count)
    lines = page_lines(doc, pages)
    starts = [i for i in range(len(lines) - 1)
              if lines[i].font().startswith("GillSans-SemiBold:14.8")
              and lines[i + 1].font().startswith("Optima-Italic")]
    out = []
    for n, i in enumerate(starts):
        end = starts[n + 1] if n + 1 < len(starts) else len(lines)
        block = [ln for ln in lines[i:end] if not ln.font().startswith("GillSans-SemiBold:18")]
        out.append(_monster(block))
    return out

def _monster(block: list[Line]) -> dict:
    name = block[0].text
    tl = block[1].text
    m = re.match(r"^(\w+(?: or \w+)?) (\w+)(?: \(([^)]*)\))?, (.*)$", tl)
    data = {"size": m.group(1).lower(), "type": m.group(2).lower(),
            "tags": [t.strip().lower() for t in (m.group(3) or "").split(",") if t.strip()],
            "alignment": m.group(4).lower()} if m else {"type_line": tl}

    fields, grid, entries = {}, [], {s: [] for s in SUBSECTIONS}
    section, key = None, None
    for ln in block[2:]:
        if ln.font().startswith("GillSans:12.0") and ln.text in SUBSECTIONS:
            section, key = ln.text, None
            continue
        if section is None:
            if ln.font().startswith("GillSans") and not ln.font().startswith("GillSans:12"):
                grid.append(ln)
                continue
            if ln.spans[0]["font"] == "Optima-Bold":
                key = None
                for f in STAT_FIELDS:
                    if ln.text.startswith(f + " "):
                        key = f
                        fields[f] = ln.text[len(f):].strip()
                        break
            elif key:
                fields[key] += " " + ln.text
            continue
        if ln.spans[0]["font"] == "Optima-BoldItalic":
            entries[section].append([ln])
        elif entries[section]:
            entries[section][-1].append(ln)
        else:  # e.g. legendary action preamble
            entries[section].append([ln])

    data.update(_stat_fields(fields))
    data["abilities"] = _ability_grid(grid)
    for s in SUBSECTIONS:
        key = s.lower().replace(" ", "_")
        data[key] = [_monster_entry(join_text(e)) for e in entries[s]]
    return row("monster", name, block[0].page, data)

def _stat_fields(f: dict) -> dict:
    d = {}
    if m := re.match(r"(\d+)", f.get("AC", "")):
        d["ac"] = int(m.group(1))
    if m := re.match(r"([+−-]\d+)", f.get("Initiative", "")):
        d["initiative"] = num(m.group(1))
    if m := re.match(rf"(\d+)(?: \(({DICE})\))?", f.get("HP", "")):
        d["hp"] = int(m.group(1))
        d["hp_dice"] = dice(m.group(2)) if m.group(2) else ""
    speed = {}
    for part in f.get("Speed", "").split(","):
        if m := re.match(r"\s*(?:(\w+) )?(\d+) ft\.(.*)", part):
            speed[(m.group(1) or "walk").lower()] = int(m.group(2))
            if "hover" in m.group(3).lower():
                speed["hover"] = True
    d["speed"] = speed
    d["skills"] = {slug(k): num(v) for k, v in re.findall(r"([A-Z][\w ]+?) ([+−-]\d+)", f.get("Skills", ""))}
    d["resistances"] = _damage_list(f.get("Resistances", ""))
    d["vulnerabilities"] = _damage_list(f.get("Vulnerabilities", ""))
    imm = f.get("Immunities", "")
    dmg_part, _, cond_part = imm.partition(";")
    d["damage_immunities"] = _damage_list(dmg_part)
    conds = cond_part if cond_part else ("" if _damage_list(imm) else imm)
    d["condition_immunities"] = [c.strip().lower() for c in conds.split(",") if c.strip()]
    d["gear"] = [g.strip() for g in f.get("Gear", "").split(",") if g.strip()]
    senses = f.get("Senses", "")
    d["senses"] = {k.lower(): int(v) for k, v in re.findall(r"(Blindsight|Darkvision|Tremorsense|Truesight) (\d+) ft", senses)}
    if m := re.search(r"Passive Perception (\d+)", senses):
        d["passive_perception"] = int(m.group(1))
    d["languages"] = f.get("Languages", "")
    # Tolerates the SRD's own typos: "700 XP", "XP 700;PB", "13,000in lair"
    cr = f.get("CR", "")
    if m := re.match(r"([\d/]+) \((?:XP )?([\d,]+)", cr):
        d["cr"] = m.group(1)
        d["xp"] = int(m.group(2).replace(",", ""))
    if m := re.search(r"PB \+(\d+)", cr):
        d["proficiency_bonus"] = int(m.group(1))
    return d

def _damage_list(s: str) -> list[str]:
    return [t.lower() for t in re.findall(DMG, s)]

def _ability_grid(grid: list[Line]) -> dict:
    spans = [s for ln in grid for s in ln.spans if s["size"] > 6.5]  # drop the 6pt MOD/SAVE header
    rows = {}
    for s in spans:
        rows.setdefault(round(s["origin"][1] / 6), []).append(s)  # baseline: small caps sit lower
    # Small-caps labels arrive as separate spans ("S" + "tr"): join same-font neighbours without spaces
    text = " ".join("".join(x["text"] if x["font"].endswith("SC700") else " " + x["text"]
                            for x in sorted(r, key=lambda s: s["bbox"][0]))
                    for _, r in sorted(rows.items()))
    text = re.sub(r"[\t\xa0]", " ", text)
    out = {}
    for ab, score, mod, save in re.findall(r"(Str|Dex|Con|Int|Wis|Cha)\s+(\d+)\s+([+−-]\d+)\s+([+−-]\d+)", text):
        out[ab.lower()] = {"score": int(score), "mod": num(mod), "save": num(save)}
    return out

def _monster_entry(text: str) -> dict:
    m = re.match(r"^([^.]*(?:\([^)]*\))?[^.]*)\.\s*(.*)$", text, re.S)
    name, rest = (m.group(1), m.group(2)) if m else (text, "")
    e = {"name": name.strip(), "text": rest.strip()}
    if m := re.search(r"\((Recharge [\d–-]+|\d+/Day[^)]*)\)", name):
        e["usage"] = m.group(1)
        e["name"] = name[:m.start()].strip()
    if m := re.search(r"(Melee or Ranged|Melee|Ranged) ?Attack Roll:\s*([+−-]\d+)", rest):
        atk = {"kind": m.group(1).lower().replace(" or ", "_or_"), "bonus": num(m.group(2))}
        if r := re.search(r"reach (\d+) ft", rest):
            atk["reach"] = int(r.group(1))
        if r := re.search(r"range (\d+)/(\d+) ft", rest):
            atk["range"] = [int(r.group(1)), int(r.group(2))]
        hit = rest.split("Hit:", 1)[1] if "Hit:" in rest else ""
        # "5 (1d6 + 2) Slashing damage", or flat "1 Piercing damage" for tiny creatures
        atk["damage"] = [{"avg": int(a), "dice": dice(b) if b else a, "type": c.lower()}
                         for a, b, c in re.findall(rf"(\d+)(?: \(({DICE})\))? ({DMG}) damage", hit)]
        e["attack"] = atk
    if m := re.search(rf"({'|'.join(ABILITIES)}) Saving Throw: DC (\d+)", rest):
        e["save"] = {"ability": m.group(1)[:3].lower(), "dc": int(m.group(2))}
        e["damage"] = [{"avg": int(a), "dice": dice(b), "type": c.lower()}
                       for a, b, c in re.findall(rf"(\d+) \(({DICE})\) ({DMG}) damage", rest)]
    return e

# ── Equipment tables ──────────────────────────────────────────────────────────

def _table_rows(lines: list[Line], title: str, columns: list[str]) -> list[tuple[str, dict]]:
    """Rows of a GillSans table after the heading `title`. Returns (category, {col: text})."""
    start = next(i for i, ln in enumerate(lines) if ln.text == title and ln.font().startswith("GillSans-SemiBold:10.5"))
    k = start + 1
    head = []
    while k < len(lines) and lines[k].font().startswith("GillSans-SemiBold:9"):
        head.append(lines[k]); k += 1
    xs = {c: next(ln.x for ln in head if ln.text.startswith(c)) for c in columns}
    rows, cat, current = [], "", None
    for ln in lines[k:]:
        f = ln.font()
        if f.startswith("GillSans-SemiBold") or f.startswith("Cambria") or f.startswith("GillSans:11"):
            if rows:
                break
            continue
        if f.startswith("GillSans-Italic"):
            cat = ln.text
            continue
        if not f.startswith("GillSans:9.5"):
            continue
        col = max((c for c in columns if xs[c] <= ln.x + 8), key=lambda c: xs[c], default=columns[0])
        if col == columns[0]:
            current = {columns[0]: ln.text}
            rows.append((cat, current))
        elif current is not None:
            current[col] = (current.get(col, "") + " " + ln.text).strip()
    return rows

def parse_weapons(doc) -> list[dict]:
    lines = page_lines_raw(doc, section_pages(doc, "Equipment"))
    out = []
    for cat, r in _table_rows(lines, "Weapons", ["Name", "Damage", "Properties", "Mastery", "Weight", "Cost"]):
        dm = re.match(rf"({DICE}) ({DMG})", r.get("Damage", ""))
        props_raw = r.get("Properties", "—")
        props, extra = [], {}
        for p in re.split(r",\s*(?![^()]*\))", props_raw):
            p = p.strip()
            if not p or p == "—":
                continue
            base = p.split(" (")[0].lower().replace("-", "_").replace(" ", "_")
            props.append(base)
            if m := re.search(r"Range (\d+)/(\d+)", p):
                extra["range"] = [int(m.group(1)), int(m.group(2))]
            if m := re.search(r"Versatile \((\d+d\d+)\)", p):
                extra["versatile"] = m.group(1)
        category = cat.lower().replace(" weapons", "")
        out.append(row("weapon", r["Name"], 0, {
            "category": category,  # "simple melee", "martial ranged", ...
            "damage": dice(dm.group(1)) if dm else r.get("Damage", ""),
            "damage_type": dm.group(2).lower() if dm else "",
            "properties": props, **extra,
            "mastery": r.get("Mastery", "").lower(),
            **_weight_cost(r),
        }))
    return out

def _weight_cost(r: dict) -> dict:
    w, c = r.get("Weight", ""), r.get("Cost", "")
    if not c and (m := re.match(r"(.*lb\.)\s+(.*)", w)):
        w, c = m.group(1), m.group(2)
    return {"weight": w, "cost": c}

def parse_armor(doc) -> list[dict]:
    lines = page_lines_raw(doc, section_pages(doc, "Equipment"))
    out = []
    for cat, r in _table_rows(lines, "Armor", ["Armor", "Armor Class", "Strength", "Stealth", "Weight", "Cost"]):
        ac = r.get("Armor Class", "")
        kind = cat.split(" ")[0].lower()  # light / medium / heavy / shield
        d = {"type": kind, "ac_raw": ac, "weight": r.get("Weight", ""), "cost": r.get("Cost", "")}
        if m := re.match(r"(\d+)", ac):
            d["base_ac"] = int(m.group(1))
        if m := re.match(r"\+(\d+)", ac):
            d["ac_bonus"] = int(m.group(1))
        d["dex"] = "Dex" in ac
        if m := re.search(r"max (\d+)", ac):
            d["dex_cap"] = int(m.group(1))
        if m := re.search(r"Str (\d+)", r.get("Strength", "")):
            d["strength"] = int(m.group(1))
        d["stealth_disadvantage"] = r.get("Stealth", "") == "Disadvantage"
        out.append(row("armor", r["Armor"], 0, d))
    return out

# ── Classes (core traits + slot progression only, for now) ───────────────────

CORE_LABELS = ["Primary Ability", "Hit Point Die", "Saving Throw Proficiencies", "Skill Proficiencies",
               "Weapon Proficiencies", "Tool Proficiencies", "Armor Training", "Starting Equipment"]

def parse_classes(doc) -> list[dict]:
    toc = doc.get_toc()
    names = [t for lvl, t, p in toc if lvl == 3 and section_pages(doc, "Classes").start < p <= section_pages(doc, "Classes").stop]
    lines = page_lines(doc, section_pages(doc, "Classes"))
    out = []
    for name in names:
        r = _class(name, lines)
        r["data"]["table"] = class_table(doc, name)
        out.append(r)
    return out

def _class(name: str, lines: list[Line]) -> dict:
    i = next(k for k, ln in enumerate(lines) if ln.text == f"Core {name} Traits")
    table = []
    for ln in lines[i + 1:]:
        if ln.text.startswith("Becoming a") or ln.font().startswith("GillSans-SemiBold:14"):
            break
        table.append(ln)
    table.sort(key=lambda ln: (ln.y, ln.x))
    left = min(ln.x for ln in table)
    label_buf, fields, cur, pending = "", {}, None, []
    for ln in table:
        label = "".join(s["text"] for s in ln.spans if s["font"] == "GillSans-SemiBold").strip()
        value = "".join(s["text"] for s in ln.spans if s["font"] != "GillSans-SemiBold").strip()
        if label and ln.x < left + 80:
            label_buf = (label_buf + " " + label).strip()
            for lab in CORE_LABELS:
                if label_buf.startswith(lab):
                    cur = lab
                    # Values that arrived while a wrapped label was still incomplete belong to it
                    fields[cur] = " ".join(pending + [value]).strip()
                    label_buf, pending, value = "", [], ""
                    break
            if value:
                pending.append(value)
        elif label_buf:
            pending.append(ln.text)
        elif cur:
            fields[cur] = (fields[cur] + " " + ln.text).strip()
    fields = {k: re.sub(r"(\w)- (\w)", r"\1\2", v.replace("\xa0", " ").replace("\xad", "")) for k, v in fields.items()}
    d = {"primary_ability": fields.get("Primary Ability", "")}
    if m := re.search(r"D(\d+)", fields.get("Hit Point Die", "")):
        d["hit_die"] = int(m.group(1))
    d["saves"] = [a[:3].lower() for a in ABILITIES if a in fields.get("Saving Throw Proficiencies", "")]
    sk = fields.get("Skill Proficiencies", "")
    if m := re.match(r"Choose any (\d+)", sk):
        d["skill_choices"] = {"count": int(m.group(1)), "options": ["any"]}
    elif m := re.match(r"Choose (\d+)(?: skills)?:? (.*)", sk):
        opts = re.split(r",\s*(?:or\s+)?|\s+or\s+", m.group(2))
        d["skill_choices"] = {"count": int(m.group(1)), "options": [slug(o) for o in opts if o]}
    elif m := re.match(r"Choose (\d+)", sk):
        d["skill_choices"] = {"count": int(m.group(1)), "options": ["any"]}
    d["weapon_proficiencies"] = fields.get("Weapon Proficiencies", "")
    d["armor_training"] = fields.get("Armor Training", "")
    d["tool_proficiencies"] = fields.get("Tool Proficiencies", "")
    d["starting_equipment"] = fields.get("Starting Equipment", "")
    # Spellcasting: stated in each class's Spellcasting feature; tabulated here until features are extracted
    if name in SPELLCASTING:
        d["spellcasting"] = dict(zip(("ability", "progression"), SPELLCASTING[name]))
    return row("class", name, lines[i].page, d)

CLASS_NAMES = ["Barbarian", "Bard", "Cleric", "Druid", "Fighter", "Monk", "Paladin", "Ranger",
               "Rogue", "Sorcerer", "Warlock", "Wizard"]

SPELLCASTING = {
    "Bard": ("cha", "full"), "Cleric": ("wis", "full"), "Druid": ("wis", "full"),
    "Sorcerer": ("cha", "full"), "Wizard": ("int", "full"), "Paladin": ("cha", "half"),
    "Ranger": ("wis", "half"), "Warlock": ("cha", "pact"),
}

# ── Class features, subclasses, class tables ─────────────────────────────────

def _heading_size(ln: Line) -> float:
    """Point size of a GillSans-SemiBold heading line, else 0."""
    s = ln.spans[0]
    return round(s["size"], 1) if s["font"] == "GillSans-SemiBold" and s["size"] >= 11.9 else 0

def _merge_headings(lines: list[Line]) -> list[Line]:
    """Join headings that wrap onto a second line ("Barbarian Subclass:" / "Path of the Berserker")."""
    out = []
    for ln in lines:
        prev = out[-1] if out else None
        if prev and _heading_size(ln) >= 14 and _heading_size(prev) == _heading_size(ln) \
                and prev.page == ln.page and abs(prev.x - ln.x) < 4 and 0 < ln.y - prev.y < 24:
            prev.spans = prev.spans + [{**ln.spans[0], "text": " "}] + ln.spans
            prev.text = re.sub(r"\s+", " ", prev.text + " " + ln.text).strip()
            continue
        out.append(ln)
    return out

def _named_paragraphs(lines: list[Line]) -> tuple[str, list[dict]]:
    """Split body text into a lead and named sub-entries ("Divine Spark. As a Magic action...").
    A paragraph whose first word run is Bold/BoldItalic starts an entry; following unnamed
    paragraphs belong to it. Returns (lead text, [{name, text}])."""
    paras: list[list[Line]] = []
    for ln in lines:
        if not paras or ln.paragraph_start() or _bold_lead(ln):
            paras.append([ln])
        else:
            paras[-1].append(ln)
    lead, entries = [], []
    for p in paras:
        name = _bold_lead(p[0])
        text = join_text(p)
        body = text[len(name):].strip() if name and text.startswith(name) else text
        if name and entries and _bold_upright(p[0]) and not _bold_upright(entries[-1]["_ln"]):
            # Upright-bold choices nested under an italic-bold entry (Goliath's Giant Ancestry)
            entries[-1].setdefault("options", []).append({"name": name.rstrip(". "), "text": body})
        elif name:
            entries.append({"name": name.rstrip(". "), "text": body, "_ln": p[0]})
        elif entries:
            entries[-1]["text"] += "\n" + text
        else:
            lead.append(text)
    for e in entries:
        e.pop("_ln")
    return "\n".join(lead), entries

def _bold_upright(ln: Line) -> bool:
    return next((s["font"] for s in ln.spans if s["text"].strip()), "") == "Cambria-Bold"

def _bold_lead(ln: Line) -> str:
    out = ""
    for s in ln.spans:
        if not s["text"].strip() and not out:
            continue
        if "Bold" in s["font"] and s["font"].startswith("Cambria"):
            out += s["text"]
        else:
            break
    out = re.sub(r"\s+", " ", out).strip()
    return out if out.endswith(".") else ""

LEVEL_HEAD = re.compile(r"^Level (\d+): (.+)$")

def parse_class_features(doc) -> tuple[list[dict], list[dict], list[dict]]:
    """Every "Level N: Feature" section of the 12 classes and their SRD subclasses, plus the
    option lists (Metamagic, Eldritch Invocations). Returns (features, subclasses, options)."""
    sec = section_pages(doc, "Classes")
    # The last subclass (Evoker) shares its page with the start of "Character Origins"
    lines = _merge_headings(page_lines(doc, range(sec.start, sec.stop + 1)))
    features, subclasses, options = [], [], []
    cls = sub = None
    mode = None  # "features" | "subclass" | "options" | None
    cur = None   # row being filled; its body lines in cur["_lines"]
    group = ""
    table_on = False

    def flush():
        nonlocal cur
        if cur is not None:
            body = cur.pop("_lines")
            if cur["kind"] == "class_option":
                # Leading italic lines: "Cost: 2 Sorcery Points" / "Prerequisite: Level 5+ Warlock"
                head = []
                while body and body[0].spans[0]["font"] == "Cambria-Italic" and not body[0].paragraph_start():
                    head.append(body.pop(0).text)
                h = " ".join(head)
                if m := re.match(r"Cost: (\d+) Sorcery Points?", h):
                    cur["data"]["cost"] = int(m.group(1))
                if m := re.match(r"Prerequisite: (.*)", h):
                    cur["data"]["prerequisite"] = m.group(1).strip()
                    if lv := re.search(r"Level (\d+)\+", h):
                        cur["data"]["min_level"] = int(lv.group(1))
            lead, entries = _named_paragraphs(body)
            cur["data"]["text"] = join_text(body)
            tables = []
            for tb in cur.pop("_tables", []):
                rows_by_y: dict = {}
                for t in tb["lines"]:
                    rows_by_y.setdefault((t.page, round(t.y / 6)), []).append(t)
                rows = []
                for _, r in sorted(rows_by_y.items()):
                    cells = [c.text for c in sorted(r, key=lambda c: c.x)]
                    # A wrapped cell sits on its own line: fold it into the row above
                    if rows and len(cells) == 1 and not re.fullmatch(r"\d+", cells[0]) and len(rows[-1]) <= 2 \
                            and re.fullmatch(r"\d+", rows[-1][0]):
                        if len(rows[-1]) == 1:
                            rows[-1].append(cells[0])
                        else:
                            rows[-1][-1] = (rows[-1][-1] + " " + cells[0]).strip()
                        continue
                    rows.append(cells)
                if rows:
                    tables.append({"title": tb["title"], "rows": rows})
            if tables:
                cur["data"]["tables"] = tables
                # "<Subclass> Spells" tables: class level -> spells always prepared
                for tb in tables:
                    if tb["title"].endswith("Spells") or tb["title"].endswith("Land"):
                        sp = cur["data"].setdefault("prepared_spells", {})
                        key = "" if tb["title"].endswith("Spells") else slug(tb["title"].split()[0])
                        for r in tb["rows"]:
                            if len(r) == 2 and r[0].isdigit():
                                names = [slug(n) for n in re.split(r",\s*", r[1]) if n.strip()]
                                (sp.setdefault(key, {}) if key else sp)[r[0]] = names
            if entries:
                cur["data"]["entries"] = entries
                cur["data"]["lead"] = lead
        cur = None

    for ln in lines:
        size = _heading_size(ln)
        if size >= 18:
            flush(); cls, sub, mode = ln.text, None, None
            continue
        if size >= 14:
            flush()
            if m := re.match(rf"^{re.escape(cls)} Subclass: (.+)$", ln.text):
                sub, mode = m.group(1).strip(), "subclass"
                cur = row("subclass", sub, ln.page, {"class": slug(cls), "tagline": ""})
                cur["_lines"] = []
                subclasses.append(cur)
            elif ln.text == f"{cls} Class Features":
                mode = "features"
            elif ln.text.endswith("Options"):
                mode, group = "options", ln.text
            else:
                mode = None
            continue
        if size >= 12:
            flush()
            m = LEVEL_HEAD.match(ln.text)
            if m and mode in ("features", "subclass"):
                name = m.group(2).strip()
                owner = slug(cls) + ("-" + slug(sub) if mode == "subclass" else "")
                cur = row("feature", f"{owner}-{name}", ln.page, {
                    "class": slug(cls), "subclass": slug(sub) if mode == "subclass" else "",
                    "level": int(m.group(1)), "feature": name})
                cur["name"] = name
                cur["_lines"] = []
                features.append(cur)
            elif mode == "options":
                cur = row("class_option", f"{slug(cls)}-{ln.text}", ln.page,
                          {"class": slug(cls), "group": group})
                cur["name"] = ln.text
                cur["_lines"] = []
                options.append(cur)
            continue
        if cur is not None and cur["kind"] == "feature":
            # Tables titled inside a feature, e.g. a subclass's always-prepared spells
            if ln.font().startswith("GillSans-SemiBold:10.5") and not ln.text.endswith("Features"):
                cur.setdefault("_tables", []).append({"title": ln.text, "lines": []})
                table_on = True
                continue
            if table_on and ln.spans[0]["font"].startswith("GillSans") and ln.spans[0]["size"] < 10:
                if not ln.font().startswith("GillSans-SemiBold"):
                    cur["_tables"][-1]["lines"].append(ln)
                continue
        table_on = False
        if cur is None or not ln.spans[0]["font"].startswith("Cambria"):
            continue  # other tables and text outside a feature
        if cur["kind"] == "subclass" and ln.spans[0]["font"] == "Cambria-Italic" and not cur["_lines"] and not cur["data"]["tagline"]:
            cur["data"]["tagline"] = ln.text
            continue
        cur["_lines"].append(ln)
    flush()
    # Levels each class feature appears at in the class table ("Action Surge (two uses)" at 17)
    tables = {}
    for f in features:
        d = f["data"]
        if d["subclass"]:
            d["levels"] = [d["level"]]
            continue
        if d["class"] not in tables:
            cname = next(n for n in CLASS_NAMES if slug(n) == d["class"])
            tables[d["class"]] = class_table(doc, cname)
        lv = [r["level"] for r in tables[d["class"]]
              if any(re.sub(r"\s*\(.*\)$", "", x) == d["feature"] for x in r["features"])]
        d["levels"] = lv or [d["level"]]
    # Subclasses list the slugs of their features
    for s in subclasses:
        s["data"]["features"] = [f["slug"] for f in features if f["data"]["subclass"] == s["slug"] and f["data"]["class"] == s["data"]["class"]]
    return features, subclasses, options

def _span_box(ln: Line) -> tuple[float, float]:
    return ln.spans[0]["bbox"][0], ln.spans[-1]["bbox"][2]

def _cell(v: str):
    v = v.strip()
    if v in ("—", "–", "-"):
        return 0
    if re.fullmatch(r"[+]?\d+", v):
        return int(v)
    return v

def class_table(doc, name: str) -> list[dict]:
    """The "<Class> Features" table: one dict per level with proficiency_bonus, features
    (names), and every class column (rages, sneak_attack, cantrips, prepared_spells, slots...)."""
    sec = section_pages(doc, "Classes")
    title = f"{name} Features"
    for pn in sec:
        lines = page_lines_raw(doc, [pn])
        start = next((i for i, ln in enumerate(lines) if ln.text == title and ln.font().startswith("GillSans-SemiBold:10.5")), None)
        if start is not None:
            break
    else:
        return []
    head, body = [], []
    top = lines[start].y
    for ln in lines[start + 1:]:
        f = ln.font()
        if f.startswith("GillSans-SemiBold:9") and not body:
            head.append(ln)
        elif f.startswith("GillSans:9") or f.startswith("GillSans-Italic:9"):
            body.append(ln)
        elif body:
            break
    # Columns: header fragments stacked vertically share a centre
    cols = []
    for h in sorted(head, key=lambda l: l.y):
        if "Spell Slots" in h.text:
            continue
        x0, x1 = _span_box(h)
        c = (x0 + x1) / 2
        for col in cols:
            if abs(col["c"] - c) < 14 and h.y > col["y"]:
                col["label"] += " " + h.text.strip(); col["y"] = h.y
                break
        else:
            cols.append({"label": h.text.strip(), "c": c, "x0": x0, "y": h.y})
    for col in cols:
        lab = col["label"]
        col["key"] = f"slot_{lab}" if re.fullmatch(r"\d", lab) else slug(lab).replace("-", "_")
    level_col = next(c for c in cols if c["key"] == "level")
    feat_col = next(c for c in cols if c["key"] == "class_features")
    others = [c for c in cols if c is not feat_col]
    rows, cur = [], None
    for ln in body:
        x0, x1 = _span_box(ln)
        if abs(x0 - feat_col["x0"]) < 4:
            col = feat_col
        else:
            col = min(others, key=lambda c: abs(c["c"] - (x0 + x1) / 2))
        if col is level_col and re.fullmatch(r"\d+", ln.text):
            cur = {"level": int(ln.text), "_y": ln.y, "class_features": ""}
            rows.append(cur)
            continue
        if cur is None:
            continue
        if col is feat_col:
            cur["class_features"] = (cur["class_features"] + " " + ln.text).strip()
        elif abs(ln.y - cur["_y"]) < 5:
            cur[col["key"]] = _cell(ln.text)
    out = []
    for r in rows:
        r.pop("_y")
        feats = [f.strip() for f in re.split(r",\s*(?![^()]*\))", r.pop("class_features")) if f.strip() and f.strip() != "—"]
        out.append({"level": r.pop("level"), "proficiency_bonus": r.pop("proficiency_bonus", 0),
                    "features": feats, **r})
    return out

# ── Origins (backgrounds, species) and feats ─────────────────────────────────

def _entries_after(lines: list[Line], start_heading: str, stop_size: float) -> list[tuple[Line, list[Line]]]:
    """(heading, body lines) for each 12pt heading after the 14pt `start_heading`, until a
    heading of `stop_size` or more."""
    out, on = [], False
    for ln in lines:
        size = _heading_size(ln)
        if size >= 14 and ln.text == start_heading:
            on = True
            continue
        if not on:
            continue
        if size >= stop_size:
            break
        if size >= 12:
            out.append((ln, []))
        elif out:
            out[-1][1].append(ln)
    return out

def _gill_fields(body: list[Line]) -> tuple[dict, list[Line]]:
    """'Label: value' lines set in GillSans (background and species headers) and the rest."""
    fields, rest, key = {}, [], None
    for ln in body:
        if ln.spans[0]["font"] == "GillSans-SemiBold" and ":" in ln.text:
            key, _, v = ln.text.partition(":")
            fields[key.strip()] = v.strip()
        elif key and ln.spans[0]["font"].startswith("GillSans") and not rest:
            fields[key] += " " + ln.text
        else:
            key = None
            rest.append(ln)
    return {k: re.sub(r"(\w)- (\w)", r"\1\2", v).strip() for k, v in fields.items()}, rest

def parse_backgrounds(doc) -> list[dict]:
    sec = section_pages(doc, "Character Origins")
    lines = page_lines(doc, range(sec.start, sec.stop + 1))
    out = []
    for head, body in _entries_after(lines, "Background Descriptions", 14):
        f, _ = _gill_fields(body)
        feat = re.sub(r"\s*\(see “Feats”\)", "", f.get("Feat", ""))
        skills = [slug(s) for s in re.split(r"\s+and\s+|,\s*", f.get("Skill Proficiencies", "")) if s]
        out.append(row("background", head.text, head.page, {
            "ability_scores": [a[:3].lower() for a in ABILITIES if a in f.get("Ability Scores", "")],
            "feat": feat, "feat_slug": slug(re.sub(r"\s*\(.*\)", "", feat)),
            "skills": skills, "tool": f.get("Tool Proficiency", ""), "equipment": f.get("Equipment", ""),
        }))
    return out

def parse_species(doc) -> list[dict]:
    sec = section_pages(doc, "Character Origins")
    lines = page_lines(doc, range(sec.start, sec.stop + 1))
    out = []
    for head, body in _entries_after(lines, "Species Descriptions", 18):
        f, rest = _gill_fields(body)
        rest = [ln for ln in rest if ln.spans[0]["font"].startswith("Cambria")]
        lead, traits = _named_paragraphs(rest)
        d = {"creature_type": f.get("Creature Type", "").lower(), "size": f.get("Size", ""),
             "sizes": [s.lower() for s in re.findall(r"\b(Small|Medium|Large)\b", f.get("Size", ""))],
             "text": lead, "traits": traits}
        if m := re.match(r"(\d+)", f.get("Speed", "")):
            d["speed"] = int(m.group(1))
        dv = next((t for t in traits if t["name"] == "Darkvision"), None)
        if dv and (m := re.search(r"range of (\d+) feet", dv["text"])):
            d["darkvision"] = int(m.group(1))
        out.append(row("species", head.text, head.page, d))
    return out

def parse_feats(doc) -> list[dict]:
    sec = section_pages(doc, "Feats")
    lines = page_lines(doc, range(sec.start, sec.stop + 2))  # bookmarks sit a page early here
    out, category = [], ""
    on = False
    cur = None
    for ln in lines:
        size = _heading_size(ln)
        if size >= 18:
            if on:
                break
            continue
        if size >= 14:
            on = ln.text.endswith("Feats") and ln.text != "Feat Descriptions"
            category = ln.text[:-len(" Feats")].lower().replace(" ", "_") if on else ""
            continue
        if not on:
            continue
        if size >= 12:
            cur = {"head": ln, "cat": [], "body": [], "category": category}
            out.append(cur)
        elif cur is not None:
            if ln.spans[0]["font"] == "Cambria-Italic" and not cur["body"]:
                cur["cat"].append(ln.text)
            else:
                cur["body"].append(ln)
    rows = []
    for c in out:
        cat = " ".join(c["cat"])
        prereq = re.search(r"\(Prerequisite: (.*)\)", cat)
        lead, entries = _named_paragraphs(c["body"])
        d = {"category": c["category"], "prerequisite": prereq.group(1).strip() if prereq else "",
             "repeatable": any(e["name"] == "Repeatable" for e in entries),
             "text": join_text(c["body"])}
        if entries:
            d["entries"], d["lead"] = entries, lead
        if m := re.search(r"Level (\d+)\+", d["prerequisite"]):
            d["min_level"] = int(m.group(1))
        rows.append(row("feat", c["head"].text, c["head"].page, d))
    return rows

def parse_weapon_properties(doc) -> list[dict]:
    """Weapon properties (Finesse, Light, ...) and the eight mastery properties (Cleave ... Vex)."""
    lines = page_lines(doc, section_pages(doc, "Equipment"))
    out = []
    for heading, mastery in (("Properties", False), ("Mastery Properties", True)):
        for head, body in _entries_after(lines, heading, 14):
            body = [ln for ln in body if ln.spans[0]["font"].startswith("Cambria")]
            out.append(row("weapon_property", head.text, head.page, {"mastery": mastery, "text": join_text(body)}))
    return out

# ── Magic items ───────────────────────────────────────────────────────────────

RARITIES = ["Common", "Uncommon", "Rare", "Very Rare", "Legendary", "Artifact"]
ITEM_CATEGORIES = ["Armor", "Potion", "Ring", "Rod", "Scroll", "Staff", "Wand", "Weapon", "Wondrous Item"]

def parse_magic_items(doc) -> list[dict]:
    """Magic Items A–Z: category, rarity (per +N variant where priced so), attunement, text."""
    lines = page_lines(doc, section_pages(doc, "Magic Items"))
    start = next(i for i, ln in enumerate(lines) if ln.text == "Magic Items A–Z")
    lines = lines[start + 1:]
    heads = [i for i, ln in enumerate(lines) if ln.has_font("GillSans-SemiBold:12.0")]
    out = []
    carried = ""  # a name that wrapped onto two heading lines
    for n, i in enumerate(heads):
        block = lines[i + 1:heads[n + 1] if n + 1 < len(heads) else len(lines)]
        meta, body = [], []
        for ln in block:
            (meta if ln.has_font("Cambria-Italic") and not body else body).append(ln)
        if not meta:
            carried = (carried + " " + lines[i].text).strip()
            continue
        name = (carried + " " + lines[i].text).strip()
        carried = ""
        text = join_text([ln for ln in body if ln.spans[0]["font"].startswith("Cambria")])
        out.append(row("magic_item", name, lines[i].page, _magic_item(" ".join(m.text for m in meta), text)))
    return out

def _magic_item(meta: str, text: str) -> dict:
    d: dict = {"meta": meta, "text": text}
    head = meta.split(",")[0]
    d["category"] = next((c for c in ITEM_CATEGORIES if head.startswith(c)), "Wondrous Item")
    m = re.search(r"\(([^)]*)\)", head)
    if m:
        d["applies_to"] = m.group(1)
    # "Rare (+2)" per variant, or one rarity; longest names first ("Very Rare" before "Rare")
    variants = {b: r for r, b in re.findall(r"(Very Rare|Uncommon|Common|Rare|Legendary)\s*\(\+(\d)\)", meta)}
    if variants:
        d["variants"] = {k: v.lower() for k, v in sorted(variants.items())}
    found = [r for r in sorted(RARITIES, key=len, reverse=True) if re.search(rf"\b{r}\b", meta, re.I)]
    picked = []
    rest = meta
    for r in found:
        if re.search(rf"\b{r}\b", rest, re.I):
            picked.append(r)
            rest = re.sub(rf"\b{r}\b", "", rest, flags=re.I)
    d["rarity"] = min(picked, key=RARITIES.index).lower() if picked else "varies"
    a = re.search(r"Requires Attunement(?: by ([^)]*))?", meta)
    d["attunement"] = bool(a)
    if a and a.group(1):
        d["attunement_by"] = a.group(1).strip()
    d["consumable"] = d["category"] in ("Potion", "Scroll")
    return d

# ── Main ──────────────────────────────────────────────────────────────────────

_FEATURES_CACHE: dict = {}

def _class_features_cached(doc, i: int) -> list[dict]:
    if "rows" not in _FEATURES_CACHE:
        _FEATURES_CACHE["rows"] = parse_class_features(doc)
    return _FEATURES_CACHE["rows"][i]

PARSERS = {
    "spells": parse_spells,
    "monsters": parse_monsters,
    "weapons": parse_weapons,
    "armor": parse_armor,
    "weapon_properties": parse_weapon_properties,
    "classes": parse_classes,
    "features": lambda doc: _class_features_cached(doc, 0),
    "subclasses": lambda doc: _class_features_cached(doc, 1),
    "class_options": lambda doc: _class_features_cached(doc, 2),
    "species": parse_species,
    "backgrounds": parse_backgrounds,
    "feats": parse_feats,
    "magic_items": parse_magic_items,
}

ATTRIBUTION = (
    "This work includes material from the System Reference Document 5.2.1 (\"SRD 5.2.1\") by "
    "Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed "
    "under the Creative Commons Attribution 4.0 International License, available at "
    "https://creativecommons.org/licenses/by/4.0/legalcode.\n"
)

def main() -> None:
    ensure_pdf()
    doc = pymupdf.open(PDF)
    OUT.mkdir(parents=True, exist_ok=True)
    only = sys.argv[1:] or list(PARSERS)
    for name in only:
        rows = PARSERS[name](doc)
        (OUT / f"{name}.json").write_text(json.dumps(rows, indent=1, ensure_ascii=False) + "\n")
        print(f"{name:10s} {len(rows)}")
    (OUT / "meta.json").write_text(json.dumps({
        "name": "System Reference Document 5.2.1", "version": "5.2.1",
        "source": PDF_URL, "sha256": PDF_SHA256,
        "extracted": sorted(p.stem for p in OUT.glob("*.json") if p.stem != "meta"),
    }, indent=1) + "\n")
    (OUT / "LICENSE").write_text(ATTRIBUTION)

if __name__ == "__main__":
    main()
