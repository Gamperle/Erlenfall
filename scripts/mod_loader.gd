class_name ModLoader
extends RefCounted
## Finds data-only mods in user://mods. See docs/MODS.md.
##
## A mod is a folder with a "feature_flags.json" file. "load_order.json" lists the folders to
## load, first to last. Nothing else is read, and mods never run code.
##
## A broken mod never stops the game. Each mod gets a load result in `results`, the problems are
## written to the log, and the settings screen and a start-up notice show them.

const MODS_DIR := "user://mods"
const LOAD_ORDER_FILE := "load_order.json"
const FLAGS_FILE := "feature_flags.json"

const OK := "ok"
const SKIPPED := "skipped"
const ERROR := "error"

## One entry per mod (or per "load_order.json" problem) from the latest load:
## { "mod": String, "file": String, "status": OK, SKIPPED, or ERROR, "reason": String,
## "notes": Array[String] } (notes are the parts of a loaded mod that were ignored).
static var results: Array[Dictionary] = []


## Returns each listed mod's feature flag file, in load order. A mod that is missing, has an
## unsafe name, or has no flag file is skipped and recorded, and a repeated mod loads once.
static func flag_files(mods_dir: String = MODS_DIR) -> Array[String]:
	results = []
	var files: Array[String] = []
	var order_path := mods_dir.path_join(LOAD_ORDER_FILE)
	if not FileAccess.file_exists(order_path):
		return files
	var order: Variant = read_json(order_path)
	if order is String:
		record(LOAD_ORDER_FILE, LOAD_ORDER_FILE, ERROR, order)
		return files
	if not order is Dictionary or not order.get("mods", []) is Array:
		record(LOAD_ORDER_FILE, LOAD_ORDER_FILE, ERROR, "expected an object like {\"mods\": [\"name\"]}")
		return files
	var seen: Array[String] = []
	for mod in order["mods"]:
		if not is_safe_name(mod):
			record(str(mod), LOAD_ORDER_FILE, SKIPPED, "not a plain folder name")
			continue
		if seen.has(mod):
			record(mod, LOAD_ORDER_FILE, SKIPPED, "listed twice")
			continue
		seen.append(mod)
		var path := mods_dir.path_join(mod).path_join(FLAGS_FILE)
		if not DirAccess.dir_exists_absolute(mods_dir.path_join(mod)):
			record(mod, mod, SKIPPED, "folder not found")
			continue
		if not FileAccess.file_exists(path):
			record(mod, FLAGS_FILE, SKIPPED, "file not found")
			continue
		files.append(path)
		record(mod, FLAGS_FILE, OK)
	return files


## A mod's name is its folder name: one plain segment, so it can't point outside the mods folder.
static func is_safe_name(mod: Variant) -> bool:
	if not mod is String or mod.is_empty() or mod.begins_with("."):
		return false
	return not (mod.contains("/") or mod.contains("\\") or mod.contains(":"))


## Reads a JSON file. Returns the parsed value, or an error message String if it can't be read
## or isn't valid JSON. A file holding a bare string is reported too, since no mod file is text.
static func read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "could not open the file"
	var json := JSON.new()
	if json.parse(file.get_as_text()) != Error.OK:
		return "invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]
	if json.data is String:
		return "expected an object, found text"
	return json.data


## The mod a flag file belongs to: its folder's name.
static func mod_of(path: String) -> String:
	return path.get_base_dir().get_file()


## Checks one mod's flag file contents. Returns { "flags", "values", "notes" } with only the
## usable parts, or { "error": reason } if the file as a whole is unusable (nothing is applied).
static func check_flag_layer(layer: Variant) -> Dictionary:
	if not layer is Dictionary:
		return { "error": "expected an object with \"flags\" and \"values\"" }
	var notes: Array[String] = []
	var flags := {}
	var values := {}
	for key: Variant in layer:
		if key != "flags" and key != "values":
			notes.append("ignored unknown key \"%s\"" % str(key))
	for section: String in ["flags", "values"]:
		if layer.has(section) and not layer[section] is Dictionary:
			return { "error": "\"%s\" must be an object" % section }
	for flag: Variant in layer.get("flags", {}):
		if _is_valid_term(layer["flags"][flag], 0):
			flags[flag] = layer["flags"][flag]
		else:
			notes.append("ignored flag \"%s\": not true, false, a flag name, or a rule" % str(flag))
	for key: Variant in layer.get("values", {}):
		var value: Variant = layer["values"][key]
		if value is int or value is float or value is String or value is bool:
			values[key] = value
		else:
			notes.append("ignored value \"%s\": must be a number, text, or true/false" % str(key))
	return { "flags": flags, "values": values, "notes": notes }


## Sets a mod's result (adding it if the mod has none yet) and logs it.
static func report(mod: String, file: String, status: String, reason: String, notes: Array[String] = []) -> void:
	for result in results:
		if result["mod"] == mod:
			result["file"] = file
			result["status"] = status
			result["reason"] = reason
			result["notes"] = notes
			_log(result)
			return
	record(mod, file, status, reason, notes)


static func record(mod: String, file: String, status: String, reason: String = "", notes: Array[String] = []) -> void:
	var result := { "mod": mod, "file": file, "status": status, "reason": reason, "notes": notes }
	results.append(result)
	_log(result)


## One line for each problem: "mod (file): reason". Mods that loaded cleanly add nothing.
static func problem_lines() -> Array[String]:
	var lines: Array[String] = []
	for result in results:
		var where := "%s (%s)" % [result["mod"], result["file"]]
		if result["status"] != OK:
			lines.append("%s: %s" % [where, result["reason"]])
		for note in result["notes"]:
			lines.append("%s: %s" % [where, note])
	return lines


static func _log(result: Dictionary) -> void:
	var where := "Mod %s (%s)" % [result["mod"], result["file"]]
	if result["status"] == ERROR:
		push_error("%s: error, %s" % [where, result["reason"]])
	elif result["status"] == SKIPPED:
		push_warning("%s: skipped, %s" % [where, result["reason"]])
	for note in result["notes"]:
		push_warning("%s: %s" % [where, note])


static func _is_valid_term(term: Variant, depth: int) -> bool:
	if term is bool or term is String:
		return true
	if depth > 16 or not term is Dictionary or term.size() != 1:
		return false
	if term.has("not"):
		return _is_valid_term(term["not"], depth + 1)
	for op in ["all", "any"]:
		if term.has(op):
			if not term[op] is Array:
				return false
			return term[op].all(func(part: Variant) -> bool: return _is_valid_term(part, depth + 1))
	return false
