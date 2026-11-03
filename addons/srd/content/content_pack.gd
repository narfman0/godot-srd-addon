## A directory of JSON content rows ({kind, slug, name, data}) indexed by kind and slug.
## Shares its format with grimoire's content packs, so one SRD dataset feeds both projects.
class_name SRDContentPack
extends RefCounted

const DEFAULT_DIR := "res://addons/srd/data/srd-5.2"

var meta: Dictionary = {}
var _rows: Dictionary = {}  # kind -> { slug -> row }

## Load every *.json under dir (recursively). Later files win on duplicate kind+slug,
## so a homebrew pack can be layered over the SRD with load_dir() twice.
static func load_default() -> SRDContentPack:
	var pack := SRDContentPack.new()
	pack.load_dir(DEFAULT_DIR)
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
		for row in (parsed if parsed is Array else [parsed]):
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

## Items share one kind; filter by data.category ("weapon", "armor", ...).
func item_slugs(category: String) -> Array:
	var out := []
	for row in rows("item"):
		if row.data.get("category", "") == category:
			out.append(row.slug)
	out.sort()
	return out

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
