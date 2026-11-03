## A directory of JSON content rows ({kind, slug, name, page, data}) indexed by kind and slug.
## The default pack is extracted from the SRD 5.2.1 PDF by tools/extract_srd.py; a game can
## layer its own rows (homebrew monsters, renamed setting content) with a second load_dir().
class_name SRDContentPack
extends RefCounted

const DEFAULT_DIR := "res://addons/srd/data/srd-5.2.1"
## Hand-authored rules on top of the extraction (spell mechanics the extractor can't read).
const AUTHORED_DIR := "res://addons/srd/data/authored"

var meta: Dictionary = {}
var _rows: Dictionary = {}  # kind -> { slug -> row }

## Load every *.json under dir (recursively). Later files win on duplicate kind+slug,
## so a homebrew pack can be layered over the SRD with load_dir() twice.
static func load_default() -> SRDContentPack:
	var pack := SRDContentPack.new()
	pack.load_dir(DEFAULT_DIR)
	pack.load_dir(AUTHORED_DIR)
	return pack

func load_dir(dir: String) -> void:
	for path in _json_files(dir):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			push_error("SRDContentPack: failed to parse %s" % path)
			continue
		if path.get_file() == "meta.json":
			meta = parsed
			continue
		add_rows(parsed if parsed is Array else [parsed])

## Add rows directly (tests, rows a game builds in code). Later rows win on kind+slug.
func add_rows(rows_in: Array) -> void:
	for row in rows_in:
		if row is Dictionary and row.has("kind") and row.has("slug"):
			if not _rows.has(row.kind):
				_rows[row.kind] = {}
			_rows[row.kind][row.slug] = row

func has_row(kind: String, slug: String) -> bool:
	return _rows.has(kind) and _rows[kind].has(slug)

## Full row ({kind, slug, name, data}) or an empty Dictionary.
func get_row(kind: String, slug: String) -> Dictionary:
	return _rows.get(kind, {}).get(slug, {})

func slugs(kind: String) -> Array:
	var out: Array = _rows.get(kind, {}).keys()
	out.sort()
	return out

func rows(kind: String) -> Array:
	return _rows.get(kind, {}).values()

func count(kind: String) -> int:
	return _rows.get(kind, {}).size()

static func _json_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		push_error("SRDContentPack: cannot open %s" % dir)
		return out
	for f in da.get_files():
		if f.ends_with(".json"):
			out.append(dir.path_join(f))
	for d in da.get_directories():
		out.append_array(_json_files(dir.path_join(d)))
	return out
