#!/usr/bin/env python3
"""Extract structured JSON from the official SRD 5.2.1 PDF (CC-BY-4.0).

    tools/.venv/bin/python tools/extract_srd.py            # writes addons/srd/data/srd-5.2.1/

Coverage grows section by section. Each section parser is independent, keyed off the PDF's
bookmarks and fonts, and writes one JSON file of {kind, slug, name, page, data} rows.
Currently: spells, monsters, weapons, armor, class core traits. Not yet: class features,
subclasses, species, backgrounds, feats, magic items.

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
    data["mechanics"] = _spell_mechanics(data)
    return row("spell", name, block[0].page, data)

def _spell_range(r: str) -> dict:
    out = {"raw": r}
    if m := re.match(r"^(\d+) (feet|miles?)", r):
        out["feet"] = int(m.group(1)) * (5280 if m.group(2).startswith("mile") else 1)
    elif r.startswith("Self"):
        out["self"] = True
    elif r == "Touch":
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
    return mech

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
        out.append(_class(name, lines))
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

SPELLCASTING = {
    "Bard": ("cha", "full"), "Cleric": ("wis", "full"), "Druid": ("wis", "full"),
    "Sorcerer": ("cha", "full"), "Wizard": ("int", "full"), "Paladin": ("cha", "half"),
    "Ranger": ("wis", "half"), "Warlock": ("cha", "pact"),
}

# ── Main ──────────────────────────────────────────────────────────────────────

PARSERS = {
    "spells": parse_spells,
    "monsters": parse_monsters,
    "weapons": parse_weapons,
    "armor": parse_armor,
    "classes": parse_classes,
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
