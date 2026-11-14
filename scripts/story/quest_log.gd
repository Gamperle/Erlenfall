class_name QuestLog
extends RefCounted
## Tracks quest progress and story flags. Objectives within a quest run in order.

signal changed

const DATA_PATH := "res://data/quests.json"

static var _quests: Dictionary = {}

var flags: Dictionary = {}
## The quest the player pinned in the journal. Empty tracks every active quest.
var tracked := ""

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
		if not is_active(quest_id) or not _is_shown(quest_id):
			continue
		var objective := _current(quest_id)
		var text := TranslationServer.translate(objective["text"])
		if objective.has("item"):
			text += " (%d/%d)" % [inventory.count(objective["item"]), objective["count"]]
		lines.append("%s: %s" % [TranslationServer.translate(_get_quests()[quest_id]["title"]), text])
	return lines


## Returns the current objectives' places, for those that have one: a named place in the
## village, or x and z. Village.marker_position turns either into a position.
func objective_markers(inventory: Inventory) -> Array:
	var markers := []
	for quest_id: String in _stages:
		if not _is_shown(quest_id):
			continue
		var objective := _current(quest_id)
		var marker: Variant = objective.get("marker")
		var alternative: Dictionary = objective.get("marker_when_carrying", {})
		if not alternative.is_empty() and inventory.count(alternative["item"]) > 0:
			marker = alternative["marker"]
		if marker != null:
			markers.append(marker)
	return markers


## Pins one active quest, so the tracker and the compass show only it. Returns false if it isn't active.
func track(quest_id: String) -> bool:
	if not is_active(quest_id):
		return false
	tracked = quest_id
	changed.emit()
	return true


## Goes back to tracking every active quest.
func untrack() -> void:
	if tracked != "":
		tracked = ""
		changed.emit()


## Every quest the player has started, active ones first, for the journal. Each entry has the id,
## the translated title, `done`, `tracked`, and the `objectives` reached so far, each with its
## translated text and whether it is `done`. Item progress comes from the inventory.
func journal_entries(inventory: Inventory) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for finished in [false, true]:
		for quest_id: String in _stages:
			if is_done(quest_id) != finished:
				continue
			var objectives: Array[Dictionary] = []
			var reached := _objectives(quest_id)
			for index in mini(_stages[quest_id] + 1, reached.size()):
				var objective: Dictionary = reached[index]
				var text := TranslationServer.translate(objective["text"])
				var done: bool = index < _stages[quest_id]
				if objective.has("item") and not done:
					text += " (%d/%d)" % [inventory.count(objective["item"]), objective["count"]]
				objectives.append({ "text": text, "done": done })
			entries.append({
				"id": quest_id, "title": TranslationServer.translate(_get_quests()[quest_id]["title"]),
				"done": finished, "tracked": quest_id == tracked and not finished, "objectives": objectives,
			})
	return entries


func to_data() -> Dictionary:
	return { "stages": _stages.duplicate(), "flags": flags.keys(), "tracked": tracked }


func load_data(data: Dictionary) -> void:
	_stages.clear()
	var stages: Dictionary = data["stages"]
	for quest_id: String in stages:
		_stages[quest_id] = int(stages[quest_id])
	flags.clear()
	for flag: String in data["flags"]:
		flags[flag] = true
	# Games saved before the journal don't have this.
	tracked = data.get("tracked", "")
	if not is_active(tracked):
		tracked = ""
	changed.emit()


## False for quests hidden by a pinned quest.
func _is_shown(quest_id: String) -> bool:
	return tracked == quest_id or not is_active(tracked)


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
