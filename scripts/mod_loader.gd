class_name ModLoader
extends RefCounted
## Finds data-only mods in user://mods. See docs/MODS.md.
##
## A mod is a folder with a "feature_flags.json" file. "load_order.json" lists the folders to
## load, first to last. Nothing else is read, and mods never run code.

const MODS_DIR := "user://mods"
const LOAD_ORDER_FILE := "load_order.json"
const FLAGS_FILE := "feature_flags.json"


## Returns each listed mod's feature flag file, in load order. A mod that is missing, has an
## unsafe name, or has no flag file is skipped with an error, and a repeated mod loads once.
static func flag_files(mods_dir: String = MODS_DIR) -> Array[String]:
	var files: Array[String] = []
	var order_path := mods_dir.path_join(LOAD_ORDER_FILE)
	if not FileAccess.file_exists(order_path):
		return files
	var order: Variant = JSON.parse_string(FileAccess.get_file_as_string(order_path))
	if not order is Dictionary or not order.get("mods", []) is Array:
		push_error("Could not read the mod load order in %s" % order_path)
		return files
	var seen: Array[String] = []
	for mod in order["mods"]:
		if not is_safe_name(mod):
			push_error("Skipping mod with an invalid name: %s" % str(mod))
			continue
		if seen.has(mod):
			push_error("Mod is listed twice: %s" % mod)
			continue
		seen.append(mod)
		var path := mods_dir.path_join(mod).path_join(FLAGS_FILE)
		if not FileAccess.file_exists(path):
			push_error("Mod %s has no %s" % [mod, FLAGS_FILE])
			continue
		files.append(path)
	return files


## A mod's name is its folder name: one plain segment, so it can't point outside the mods folder.
static func is_safe_name(mod: Variant) -> bool:
	if not mod is String or mod.is_empty() or mod.begins_with("."):
		return false
	return not (mod.contains("/") or mod.contains("\\") or mod.contains(":"))
