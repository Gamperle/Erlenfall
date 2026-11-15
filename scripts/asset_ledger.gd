class_name AssetLedger
extends RefCounted
## Compares the files under assets/ with the rows of ASSETS.md (#271).
## Each row's first cell lists backticked paths. A path may be a pattern with `*` or `?`, and a
## bare pattern such as `*.jpg` applies to the folder of the path before it. A row needs a
## source and a license. Run alone with `godot --headless --path . --script res://tools/check_assets.gd`.

const LEDGER := "res://ASSETS.md"
const ASSETS_DIR := "res://assets"
## Files that need no row: Godot's import records and UIDs, Godot resources written by hand
## (no third-party content), and the license text that a row points to.
const EXEMPT_SUFFIXES := [".import", ".uid", ".tres", ".res"]
const EXEMPT_FILES := ["assets/ui/fonts/OFL.txt"]


static func problems(ledger_path: String = LEDGER, assets_dir: String = ASSETS_DIR) -> PackedStringArray:
	var result := PackedStringArray()
	var file := FileAccess.open(ledger_path, FileAccess.READ)
	if file == null:
		result.append("%s can't be read" % ledger_path)
		return result
	var patterns: Array[String] = []
	for line in file.get_as_text().split("\n"):
		if not line.begins_with("| `"):
			continue
		var cells := line.split(" | ")
		if cells.size() < 5:
			result.append("ASSETS.md row has fewer than 5 columns: %s" % line.left(80))
			continue
		var paths := _paths_in(cells[0])
		var label: String = paths[0] if not paths.is_empty() else cells[0]
		if cells[1].strip_edges().is_empty():
			result.append("ASSETS.md row has no source: %s" % label)
		if cells[3].strip_edges().is_empty():
			result.append("ASSETS.md row has no license: %s" % label)
		for pattern in paths:
			patterns.append(pattern)
			if not _any_match(pattern, _files(assets_dir)):
				result.append("ASSETS.md lists a file that does not exist: %s" % pattern)
	for path in _files(assets_dir):
		if EXEMPT_FILES.has(path) or EXEMPT_SUFFIXES.any(func(suffix): return path.ends_with(suffix)):
			continue
		if not patterns.any(func(pattern): return path.match(pattern)):
			result.append("%s has no entry in ASSETS.md" % path)
	return result


## The paths in a row's first cell, with bare patterns put in the folder of the path before them.
static func _paths_in(cell: String) -> Array[String]:
	var paths: Array[String] = []
	var folder := ""
	var parts := cell.split("`")
	for i in range(1, parts.size(), 2):
		var path := parts[i]
		if not path.contains("/") and not folder.is_empty():
			path = folder + "/" + path
		folder = path.get_base_dir()
		paths.append(path)
	return paths


static func _any_match(pattern: String, files: Array) -> bool:
	return files.any(func(path): return path.match(pattern))


static var _cache := {}


## Files under the folder, as paths starting with `assets/`.
static func _files(dir: String) -> Array:
	if not _cache.has(dir):
		_cache[dir] = _walk(dir, "assets")
	return _cache[dir]


static func _walk(dir: String, prefix: String) -> Array:
	var found := []
	for name in DirAccess.get_files_at(dir):
		found.append(prefix + "/" + name)
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_walk(dir + "/" + sub, prefix + "/" + sub))
	return found
