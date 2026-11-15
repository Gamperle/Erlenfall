class_name CreditsData
extends RefCounted
## Reads ASSETS.md into the entries of the credits screen, so that the screen can't drift from the
## asset list. Rows with the same source, author, and license are merged into one entry.

const ASSETS_PATH := "res://ASSETS.md"
const PROJECT_LICENSES := ["res://LICENSE", "res://LICENSE-ASSETS"]

static var _link := _make_regex("\\[([^\\]]*)\\]\\([^)]*\\)")


## The entries and notes of the given ASSETS.md text. Each entry is a Dictionary with "source",
## "author", "license" and "files" (Array[String]); notes are the paragraphs after the table starts.
static func parse(text: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	var by_key := {}
	var notes: Array[String] = []
	var in_table := false
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("|"):
			in_table = true
			var cells := _cells(line)
			if cells.size() < 4 or cells[0] == "File" or cells[0].begins_with("---"):
				continue
			var key := "%s|%s|%s" % [cells[1], cells[2], cells[3]]
			if not by_key.has(key):
				by_key[key] = {"source": plain(cells[1]), "author": plain(cells[2]), "license": plain(cells[3]), "files": [] as Array[String]}
				entries.append(by_key[key])
			by_key[key]["files"].append_array(_files(cells[0]))
		elif in_table and line != "":
			notes.append(plain(line))
	return {"entries": entries, "notes": notes}


## The data of the real asset list, or an empty result when it can't be read.
static func load_assets() -> Dictionary:
	return parse(read_text(ASSETS_PATH))


static func read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


## Text without the Markdown that the screen can't show: links become their label, and code marks go.
static func plain(text: String) -> String:
	return _link.sub(text, "$1", true).replace("`", "").strip_edges()


## A short text of the files: the folder once if they share it, then the names.
static func files_text(files: Array) -> String:
	var folders := {}
	for file: String in files:
		folders[file.get_base_dir()] = true
	if folders.size() != 1:
		return ", ".join(PackedStringArray(files))
	var names: PackedStringArray = []
	for file: String in files:
		names.append(file.get_file())
	return "%s: %s" % [String(folders.keys()[0]).trim_prefix("assets/"), ", ".join(names)]


static func _cells(line: String) -> PackedStringArray:
	var cells: PackedStringArray = []
	for cell in line.trim_prefix("|").trim_suffix("|").split(" | "):
		cells.append(cell.strip_edges())
	return cells


static func _files(cell: String) -> Array[String]:
	var files: Array[String] = []
	for part in cell.split(","):
		var path := part.replace("`", "").strip_edges()
		if path != "":
			files.append(path)
	return files


static func _make_regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex
