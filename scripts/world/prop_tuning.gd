class_name PropTuning
extends RefCounted
## Per-model size and height corrections for the generated props, from data/prop_tuning.json.
## The prop tuner scene writes the file. A model without an entry keeps scale 1 and lift 0.

const PATH := "res://data/prop_tuning.json"
const DEFAULT := { "scale": 1.0, "lift": 0.0 }

static var _entries: Dictionary = {}
static var _loaded := false


## Returns the entry for a model, by its file name without ".glb", such as "anvil_2".
static func get_entry(model_name: String) -> Dictionary:
	_ensure_loaded()
	return _entries.get(model_name, DEFAULT)


## Scales a model and raises it by its lift, in meters. Lift is added after scaling.
static func apply(model: Node3D, model_name: String) -> void:
	var entry := get_entry(model_name)
	model.scale = Vector3.ONE * float(entry["scale"])
	model.position.y += float(entry["lift"])


## Stores an entry and writes the file. Entries back at the default are dropped, so the file only
## lists models that need a correction.
static func set_entry(model_name: String, scale: float, lift: float) -> void:
	_ensure_loaded()
	if is_equal_approx(scale, 1.0) and is_zero_approx(lift):
		_entries.erase(model_name)
	else:
		_entries[model_name] = { "scale": snappedf(scale, 0.001), "lift": snappedf(lift, 0.001) }
	var names := _entries.keys()
	names.sort()
	var sorted := {}
	for key: String in names:
		sorted[key] = _entries[key]
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({ "props": sorted }, "\t") + "\n")


static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_entries = {}
	if not FileAccess.file_exists(PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary and data.get("props") is Dictionary:
		for key: String in data["props"]:
			var entry: Dictionary = data["props"][key]
			_entries[key] = { "scale": float(entry.get("scale", 1.0)), "lift": float(entry.get("lift", 0.0)) }
