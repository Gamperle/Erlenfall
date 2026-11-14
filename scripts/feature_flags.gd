class_name FeatureFlags
extends RefCounted
## Read-only feature flags and values from data files. See docs/FEATURE_FLAGS.md.

const BASE_PATH := "res://data/feature_flags.json"

static var _flags: Dictionary = {}
static var _values: Dictionary = {}
static var _loaded := false


## Reloads the base file, then applies each mod's file in load order. Later files win.
## Without a call, the first use loads the mods listed in user://mods (see ModLoader).
static func load_layers(mod_paths: Array[String] = []) -> void:
	_flags = {}
	_values = {}
	_loaded = true
	_apply_layer(BASE_PATH)
	for path in mod_paths:
		_apply_layer(path)


## Returns whether a flag is on. A plain flag gives its value, and an aggregate works out its rule.
static func enabled(flag: String) -> bool:
	_ensure_loaded()
	return _evaluate_flag(flag, [])


static func value(key: String, fallback: Variant = null) -> Variant:
	_ensure_loaded()
	return _values.get(key, fallback)


static func _ensure_loaded() -> void:
	if not _loaded:
		load_layers(ModLoader.flag_files())


static func _apply_layer(path: String) -> void:
	var is_mod := path != BASE_PATH
	var layer: Variant = ModLoader.read_json(path)
	var checked: Dictionary = { "error": layer } if layer is String else ModLoader.check_flag_layer(layer)
	if checked.has("error"):
		push_error("Could not read the feature flags in %s: %s" % [path, checked["error"]])
		if is_mod:
			ModLoader.report(ModLoader.mod_of(path), ModLoader.FLAGS_FILE, ModLoader.ERROR, checked["error"])
		return
	_flags.merge(checked["flags"], true)
	_values.merge(checked["values"], true)
	if is_mod and not checked["notes"].is_empty():
		ModLoader.report(ModLoader.mod_of(path), ModLoader.FLAGS_FILE, ModLoader.OK, "", checked["notes"])


static func _evaluate_flag(flag: String, visiting: Array) -> bool:
	if not _flags.has(flag):
		push_error("Unknown feature flag: %s" % flag)
		return false
	if visiting.has(flag):
		push_error("Feature flag depends on itself: %s" % flag)
		return false
	return _evaluate_term(_flags[flag], visiting + [flag])


## A term is true or false, the name of a flag, or a rule with "all", "any", or "not".
static func _evaluate_term(term: Variant, visiting: Array) -> bool:
	if term is bool:
		return term
	if term is String:
		return _evaluate_flag(term, visiting)
	if term is Dictionary and term.size() == 1:
		if term.has("all"):
			return term["all"].all(func(part: Variant) -> bool: return _evaluate_term(part, visiting))
		if term.has("any"):
			return term["any"].any(func(part: Variant) -> bool: return _evaluate_term(part, visiting))
		if term.has("not"):
			return not _evaluate_term(term["not"], visiting)
	push_error("Invalid feature flag rule: %s" % str(term))
	return false
