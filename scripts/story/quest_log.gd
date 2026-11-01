class_name QuestLog
extends RefCounted
## Tracks quest progress and story flags. Objectives within a quest run in order.

signal changed

const DATA_PATH := "res://data/quests.json"

static var _quests: Dictionary = {}

var flags: Dictionary = {}

var _stages: Dictionary = {}


func start(quest_id: String) -> void:
	if not _stages.has(quest_id):
		_stages[quest_id] = 0
		changed.emit()


func advance(quest_id: String) -> void:
	if _stages.has(quest_id) and not is_done(quest_id):
		_stages[quest_id] += 1
		changed.emit()


func is_active(quest_id: String) -> bool:
	return _stages.has(quest_id) and not is_done(quest_id)


func is_done(quest_id: String) -> bool:
	return _stages.has(quest_id) and _stages[quest_id] >= _objectives(quest_id).size()


## Returns the current objective's id, or an empty string if the quest isn't active.
func current_objective(quest_id: String) -> String:
	return _current(quest_id).get("id", "")


## Returns one line per active quest, with item progress taken from the inventory.
func tracker_lines(inventory: Inventory) -> PackedStringArray:
	var lines := PackedStringArray()
	for quest_id: String in _stages:
		if not is_active(quest_id):
			continue
		var objective := _current(quest_id)
		var text := TranslationServer.translate(objective["text"])
		if objective.has("item"):
			text += " (%d/%d)" % [inventory.count(objective["item"]), objective["count"]]
		lines.append("%s: %s" % [TranslationServer.translate(_get_quests()[quest_id]["title"]), text])
	return lines


func to_data() -> Dictionary:
	return { "stages": _stages.duplicate(), "flags": flags.keys() }


func load_data(data: Dictionary) -> void:
	_stages.clear()
	var stages: Dictionary = data["stages"]
	for quest_id: String in stages:
		_stages[quest_id] = int(stages[quest_id])
	flags.clear()
	for flag: String in data["flags"]:
		flags[flag] = true
	changed.emit()


func _current(quest_id: String) -> Dictionary:
	if not is_active(quest_id):
		return {}
	return _objectives(quest_id)[_stages[quest_id]]


func _objectives(quest_id: String) -> Array:
	return _get_quests()[quest_id]["objectives"]


static func _get_quests() -> Dictionary:
	if _quests.is_empty():
		_quests = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _quests
