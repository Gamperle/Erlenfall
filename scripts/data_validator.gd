class_name DataValidator
extends RefCounted
## Checks the JSON files in a data folder for missing fields, wrong types, and broken references
## (an unknown item, quest, objective, villager, or station id), and reports every problem found.
##
## Each problem is one line that starts with the file and the exact entry, for example
## `crafting.json: recipes[forge_axe].inputs: unknown item "iron_ingott"`. An empty list means the
## data is fine. Pass a mod's data folder to check it: files the folder does not have are skipped,
## and references are checked against the files that are there.
##
## From the command line: `godot --headless --path . --script res://tools/validate_data.gd -- <folder>`.

const DATA_DIR := "res://data"
const FILES: Array[String] = [
	"crafting.json", "dialogue.json", "enemies.json", "feature_flags.json", "projectiles.json",
	"prop_tuning.json", "quests.json", "village_layout.json", "villager_routines.json",
]
const EFFECT_TYPES: Array[String] = ["start_quest", "advance_quest", "set_flag", "take_item", "give_item", "calm_enemy", "provoke_enemy"]
const CONDITIONS: Array[String] = ["objective", "quest_done", "flag", "not_flag", "has_item"]

var _problems: Array[String] = []
var _files: Dictionary = {}
var _items: Dictionary = {}
var _quests: Dictionary = {}
var _npcs: Dictionary = {}
var _stations: Dictionary = {}
var _markers: Dictionary = {}


## Reads every data file in the folder and returns what is wrong with them. For a mod's folder, pass
## the game's own folder as the base: the mod's entries are added to it, so a mod can refer to the
## game's items and quests.
static func validate_directory(dir: String = DATA_DIR, base_dir: String = "") -> Array[String]:
	var validator := DataValidator.new()
	var files := {}
	for file in FILES:
		for folder in [base_dir, dir]:
			var path: String = folder.path_join(file)
			if folder.is_empty() or not FileAccess.file_exists(path):
				continue
			var json := JSON.new()
			if json.parse(FileAccess.get_file_as_string(path)) != OK:
				validator._problems.append("%s: line %d: %s" % [path.trim_prefix(folder + "/"), json.get_error_line(), json.get_error_message()])
			elif files.has(file) and files[file] is Dictionary and json.data is Dictionary:
				files[file].merge(json.data, true)
			else:
				files[file] = json.data
	return validator.validate_files(files)


## Checks data that is already parsed, as a dictionary from file name to contents.
func validate_files(files: Dictionary) -> Array[String]:
	_files = files
	_collect_ids()
	for file: String in files:
		if not FILES.has(file):
			_add(file, "", "is not a known data file")
	for file in FILES:
		if not files.has(file):
			continue
		var check := Callable(self, "_check_" + file.get_basename())
		if files[file] is Dictionary:
			check.call(files[file])
		else:
			_add(file, "", "must be an object")
	return _problems


func _collect_ids() -> void:
	var crafting := _dict(_files.get("crafting.json"))
	_items = _dict(crafting.get("items"))
	_quests = _dict(_files.get("quests.json"))
	var layout := _dict(_files.get("village_layout.json"))
	for npc: Variant in _array(layout.get("npcs")):
		_npcs[_dict(npc).get("id")] = true
		_markers[_dict(npc).get("id")] = true
	for building: Variant in _array(layout.get("buildings")):
		_markers[_dict(building).get("id")] = true
	_markers[_dict(layout.get("mine")).get("id")] = true
	for station: Variant in _array(layout.get("stations")):
		_stations[_dict(station).get("id")] = true
		_markers[_dict(station).get("id")] = true
	for site: Variant in _array(layout.get("repair_sites")):
		_markers[_dict(site).get("flag")] = true


## The conversations that enemies open, named by "talk.dialogue" in the enemy data. They belong to no villager.
func _talk_dialogues() -> Dictionary:
	var ids := {}
	for enemy: Variant in _dict(_files.get("enemies.json")).values():
		var talk: Variant = _dict(enemy).get("talk")
		if talk is Dictionary and talk.get("dialogue") is String:
			ids[talk["dialogue"]] = true
	return ids


func _add(file: String, path: String, message: String) -> void:
	_problems.append("%s: %s: %s" % [file, path, message] if not path.is_empty() else "%s: %s" % [file, message])


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _array(value: Variant) -> Array:
	return value if value is Array else []


## Checks that a dictionary has the fields in the spec. A spec maps a key to its type name ("string",
## "number", "int", "bool", "array", "object", "color", "vec3", "text" for a translation key) and
## whether it is required. Returns true if the value is a dictionary.
func _fields(file: String, path: String, value: Variant, spec: Dictionary) -> bool:
	if not value is Dictionary:
		_add(file, path, "must be an object")
		return false
	for key: String in spec:
		var kind: String = spec[key][0]
		if not value.has(key):
			if spec[key][1]:
				_add(file, path, "missing \"%s\"" % key)
			continue
		if not _is_type(value[key], kind):
			_add(file, "%s.%s" % [path, key], "must be %s, not %s" % [kind, JSON.stringify(value[key])])
	return true


static func _is_type(value: Variant, kind: String) -> bool:
	match kind:
		"string", "text":
			return value is String
		"number":
			return value is float or value is int
		"int":
			return (value is float and value == floorf(value)) or value is int
		"bool":
			return value is bool
		"array":
			return value is Array
		"object":
			return value is Dictionary
		"color":
			return value is String and Color.html_is_valid(value)
		"vec3":
			return value is Array and value.size() == 3 and value.all(func(n: Variant) -> bool: return n is float or n is int)
	return true


func _known(file: String, path: String, id: Variant, known: Dictionary, what: String) -> void:
	if not known.has(id):
		_add(file, path, "unknown %s \"%s\"" % [what, id])


func _check_item_counts(file: String, path: String, counts: Variant) -> void:
	if not counts is Dictionary:
		_add(file, path, "must be an object of item ids and counts")
		return
	for item: String in counts:
		_known(file, path, item, _items, "item")
		if not _is_type(counts[item], "int") or counts[item] < 1:
			_add(file, "%s.%s" % [path, item], "count must be a whole number of at least 1")


func _check_crafting(data: Dictionary) -> void:
	var file := "crafting.json"
	for key in ["items", "part_options", "part_slots", "skills", "qualities", "recipes"]:
		if not data.has(key):
			_add(file, "", "missing \"%s\"" % key)
	var options := _dict(data.get("part_options"))
	var slots := _dict(data.get("part_slots"))
	var skills := _dict(data.get("skills"))
	for id: String in _items:
		var path := "items[%s]" % id
		if not _fields(file, path, _items[id], { "name": ["text", true], "material": ["bool", false], "damage": ["number", false], "ranged_damage_multiplier": ["number", false], "fires": ["string", false], "model": ["array", false], "parts": ["object", false], "use": ["object", false] }):
			continue
		var item: Dictionary = _items[id]
		if item.has("use") and _fields(file, path + ".use", item["use"], { "heal": ["number", true] }) and item["use"]["heal"] <= 0:
			_add(file, path + ".use.heal", "must be more than 0")
		var model_slots := []
		for i in _array(item.get("model")).size():
			var part: Variant = item["model"][i]
			_fields(file, "%s.model[%d]" % [path, i], part, { "size": ["vec3", true], "at": ["vec3", true], "color": ["color", true], "slot": ["string", false] })
			if part is Dictionary and part.has("slot"):
				model_slots.append(part["slot"])
		var parts := _dict(item.get("parts"))
		for slot: String in parts:
			if not slots.has(slot):
				_add(file, "%s.parts" % path, "unknown slot \"%s\"" % slot)
			elif not model_slots.has(slot):
				_add(file, "%s.parts.%s" % [path, slot], "the model has no part for this slot")
			for option: Variant in _array(parts[slot]):
				_known(file, "%s.parts.%s" % [path, slot], option, options, "part option")
	for id: String in options:
		_fields(file, "part_options[%s]" % id, options[id], { "name": ["text", true], "color": ["color", true], "size_scale": ["vec3", false], "damage_multiplier": ["number", false] })
	for id: String in skills:
		var path := "skills[%s]" % id
		if _fields(file, path, skills[id], { "name": ["text", true], "level_xp": ["array", true] }) and skills[id].has("level_xp"):
			var previous := -1.0
			for xp: Variant in skills[id]["level_xp"]:
				if not _is_type(xp, "number") or xp <= previous:
					_add(file, "%s.level_xp" % path, "must be numbers that increase")
					break
				previous = xp
	var previous_score := -1.0
	var qualities: Array = _array(data.get("qualities"))
	for i in qualities.size():
		var path := "qualities[%d]" % i
		if _fields(file, path, qualities[i], { "id": ["string", true], "name": ["text", true], "min_score": ["number", true], "damage_multiplier": ["number", true] }) and qualities[i].has("min_score") and _is_type(qualities[i]["min_score"], "number"):
			if qualities[i]["min_score"] <= previous_score:
				_add(file, "%s.min_score" % path, "must be higher than the quality before it")
			previous_score = qualities[i]["min_score"]
	var seen := {}
	var recipes: Array = _array(data.get("recipes"))
	for i in recipes.size():
		var recipe: Variant = recipes[i]
		var name: String = str(_dict(recipe).get("id", i))
		var path := "recipes[%s]" % name
		if not _fields(file, path, recipe, { "id": ["string", true], "station": ["string", true], "inputs": ["object", true], "result": ["string", true], "count": ["int", true], "skill": ["string", false], "xp": ["number", false], "strikes": ["int", false], "speed": ["number", false], "requires_flag": ["string", false] }):
			continue
		if seen.has(name):
			_add(file, path, "duplicate recipe id")
		seen[name] = true
		if _files.has("village_layout.json"):
			_known(file, path + ".station", recipe.get("station"), _stations, "station")
		_known(file, path + ".result", recipe.get("result"), _items, "item")
		if recipe.has("skill"):
			_known(file, path + ".skill", recipe["skill"], skills, "skill")
		if recipe.has("inputs"):
			_check_item_counts(file, path + ".inputs", recipe["inputs"])


func _check_quests(data: Dictionary) -> void:
	var file := "quests.json"
	for quest_id: String in data:
		var path := "[%s]" % quest_id
		if not _fields(file, path, data[quest_id], { "title": ["text", true], "objectives": ["array", true] }):
			continue
		var objectives: Array = data[quest_id].get("objectives", [])
		if objectives.is_empty():
			_add(file, path + ".objectives", "a quest needs at least one objective")
		var seen := {}
		for i in objectives.size():
			var objective: Variant = objectives[i]
			var name: String = str(_dict(objective).get("id", i))
			var opath := "%s.objectives[%s]" % [path, name]
			if not _fields(file, opath, objective, { "id": ["string", true], "text": ["text", true], "item": ["string", false], "count": ["int", false], "marker": ["", false], "marker_when_carrying": ["object", false] }):
				continue
			if seen.has(name):
				_add(file, opath, "duplicate objective id")
			seen[name] = true
			if objective.has("item"):
				_known(file, opath + ".item", objective["item"], _items, "item")
			if objective.has("marker"):
				_check_marker(file, opath + ".marker", objective["marker"])
			if objective.has("marker_when_carrying"):
				var carrying: Dictionary = objective["marker_when_carrying"]
				if _fields(file, opath + ".marker_when_carrying", carrying, { "item": ["string", true], "marker": ["", true] }):
					_known(file, opath + ".marker_when_carrying.item", carrying.get("item"), _items, "item")
					if carrying.has("marker"):
						_check_marker(file, opath + ".marker_when_carrying.marker", carrying["marker"])


func _check_marker(file: String, path: String, marker: Variant) -> void:
	if marker is String:
		if _files.has("village_layout.json"):
			_known(file, path, marker, _markers, "marker place")
	elif not (marker is Array and marker.size() == 2 and marker.all(func(n: Variant) -> bool: return n is float or n is int)):
		_add(file, path, "must be a place name or [x, z]")


func _check_dialogue(data: Dictionary) -> void:
	var file := "dialogue.json"
	for npc_id: String in data:
		if _files.has("village_layout.json") and not _talk_dialogues().has(npc_id):
			_known(file, "[%s]" % npc_id, npc_id, _npcs, "villager")
		if not data[npc_id] is Array:
			_add(file, "[%s]" % npc_id, "must be a list of conversations")
			continue
		for i in data[npc_id].size():
			_check_conversation(file, "%s[%d]" % [npc_id, i], data[npc_id][i])


func _check_conversation(file: String, path: String, entry: Variant) -> void:
	if not _fields(file, path, entry, { "when": ["object", false], "start": ["string", true], "nodes": ["object", true] }):
		return
	_check_conditions(file, path + ".when", entry.get("when", {}))
	var nodes: Dictionary = _dict(entry.get("nodes"))
	if entry.has("start") and entry["start"] is String and not nodes.has(entry["start"]):
		_add(file, path + ".start", "unknown node \"%s\"" % entry["start"])
	for node_id: String in nodes:
		var npath := "%s.nodes[%s]" % [path, node_id]
		if not _fields(file, npath, nodes[node_id], { "text": ["text", true], "next": ["string", false], "choices": ["array", false], "effects": ["array", false], "choices_of": ["string", false] }):
			continue
		var node: Dictionary = nodes[node_id]
		if node.has("next") and not nodes.has(node["next"]):
			_add(file, npath + ".next", "unknown node \"%s\"" % node["next"])
		if node.has("choices_of") and not nodes.has(node["choices_of"]):
			_add(file, npath + ".choices_of", "unknown node \"%s\"" % node["choices_of"])
		var choices: Array = _array(node.get("choices"))
		for i in choices.size():
			var cpath := "%s.choices[%d]" % [npath, i]
			if not _fields(file, cpath, choices[i], { "text": ["text", true], "next": ["string", false], "when": ["object", false], "chance": ["number", false], "fail_next": ["string", false] }):
				continue
			if choices[i].has("chance") and _is_type(choices[i]["chance"], "number") and (choices[i]["chance"] < 0 or choices[i]["chance"] > 1):
				_add(file, cpath + ".chance", "must be between 0 and 1")
			if choices[i].has("chance") != choices[i].has("fail_next"):
				_add(file, cpath, "\"chance\" and \"fail_next\" go together")
			if choices[i].has("fail_next") and not nodes.has(choices[i]["fail_next"]):
				_add(file, cpath + ".fail_next", "unknown node \"%s\"" % choices[i]["fail_next"])
			if choices[i].has("next") and not nodes.has(choices[i]["next"]):
				_add(file, cpath + ".next", "unknown node \"%s\"" % choices[i]["next"])
			if choices[i].has("when"):
				_check_conditions(file, cpath + ".when", choices[i]["when"])
		var effects: Array = _array(node.get("effects"))
		for i in effects.size():
			_check_effect(file, "%s.effects[%d]" % [npath, i], effects[i])


func _check_conditions(file: String, path: String, when: Variant) -> void:
	if not when is Dictionary:
		_add(file, path, "must be an object")
		return
	for key: String in when:
		var value: Variant = when[key]
		var here := "%s.%s" % [path, key]
		if not CONDITIONS.has(key):
			_add(file, here, "unknown condition")
		elif key == "objective":
			if not (value is Array and value.size() == 2 and value[0] is String and value[1] is String):
				_add(file, here, "must be [quest, objective]")
			else:
				_check_objective(file, here, value[0], value[1])
		elif key == "quest_done":
			_known(file, here, value, _quests, "quest")
		elif key == "has_item":
			if not (value is Array and value.size() == 2 and value[0] is String and _is_type(value[1], "int")):
				_add(file, here, "must be [item, count]")
			else:
				_known(file, here, value[0], _items, "item")
		elif not value is String:
			_add(file, here, "must be a flag name")


func _check_objective(file: String, path: String, quest: String, objective: String) -> void:
	if not _quests.has(quest):
		_add(file, path, "unknown quest \"%s\"" % quest)
		return
	for entry: Variant in _array(_dict(_quests[quest]).get("objectives")):
		if _dict(entry).get("id") == objective:
			return
	_add(file, path, "quest \"%s\" has no objective \"%s\"" % [quest, objective])


func _check_effect(file: String, path: String, effect: Variant) -> void:
	if not _fields(file, path, effect, { "type": ["string", true] }) or not effect.has("type"):
		return
	var type: Variant = effect["type"]
	if not EFFECT_TYPES.has(type):
		_add(file, path + ".type", "unknown effect \"%s\"" % type)
		return
	match type:
		"start_quest", "advance_quest":
			if _fields(file, path, effect, { "quest": ["string", true] }):
				_known(file, path + ".quest", effect.get("quest"), _quests, "quest")
		"set_flag":
			_fields(file, path, effect, { "flag": ["string", true] })
		"calm_enemy":
			if _fields(file, path, effect, { "seconds": ["number", true] }) and _is_type(effect.get("seconds"), "number") and effect["seconds"] <= 0:
				_add(file, path + ".seconds", "must be more than 0")
		"provoke_enemy":
			pass
		_:
			if _fields(file, path, effect, { "item": ["string", true], "count": ["int", true] }):
				_known(file, path + ".item", effect.get("item"), _items, "item")


func _check_enemies(data: Dictionary) -> void:
	var file := "enemies.json"
	for id: String in data:
		var path := "[%s]" % id
		_fields(file, path, data[id], {
			"name": ["text", true], "model": ["string", false], "model_height": ["number", false], "shape": ["string", false], "color": ["color", true], "skin": ["color", false],
			"height": ["number", true], "radius": ["number", true], "health": ["number", true], "damage": ["number", true], "speed": ["number", true],
			"aggro_range": ["number", true], "leash_range": ["number", true], "attack_range": ["number", true], "windup_seconds": ["number", true],
			"recover_seconds": ["number", true], "respawn_seconds": ["number", true], "drops": ["array", false], "talk": ["object", false],
		})
		if not data[id] is Dictionary:
			continue
		if data[id].has("model") and data[id]["model"] is String and not ResourceLoader.exists(data[id]["model"]):
			_add(file, path + ".model", "file not found: %s" % data[id]["model"])
		if data[id].get("talk") is Dictionary:
			var talk: Dictionary = data[id]["talk"]
			var tpath := path + ".talk"
			if _fields(file, tpath, talk, { "dialogue": ["string", true], "range": ["number", true], "wary_seconds": ["number", true] }):
				if talk.get("dialogue") is String and _files.has("dialogue.json") and not _dict(_files["dialogue.json"]).has(talk["dialogue"]):
					_add(file, tpath + ".dialogue", "unknown conversation \"%s\"" % talk["dialogue"])
				if _is_type(talk.get("range"), "number") and _is_type(data[id].get("attack_range"), "number") and (talk["range"] <= data[id]["attack_range"] or talk["range"] > Player.INTERACT_DISTANCE):
					_add(file, tpath + ".range", "must be more than attack_range and at most the player's reach (%s)" % Player.INTERACT_DISTANCE)
		var drops: Array = _array(data[id].get("drops"))
		for i in drops.size():
			var dpath := "%s.drops[%d]" % [path, i]
			if _fields(file, dpath, drops[i], { "item": ["string", true], "chance": ["number", true], "min": ["int", true], "max": ["int", true] }):
				_known(file, dpath + ".item", drops[i].get("item"), _items, "item")
				if drops[i].has("min") and drops[i].has("max") and drops[i]["min"] is float and drops[i]["max"] is float and drops[i]["min"] > drops[i]["max"]:
					_add(file, dpath, "min is more than max")


func _check_projectiles(data: Dictionary) -> void:
	var file := "projectiles.json"
	for id: String in data:
		var path := "[%s]" % id
		if not _fields(file, path, data[id], {
			"action": ["string", true], "requires_item": ["string", true], "ammo_item": ["string", true], "damage": ["number", true], "speed": ["number", true],
			"gravity": ["number", true], "lifetime": ["number", true], "radius": ["number", true], "splash_radius": ["number", true], "cooldown": ["number", true],
			"size": ["vec3", true], "color": ["color", true],
		}):
			continue
		for key in ["requires_item", "ammo_item"]:
			if data[id].get(key) is String and not data[id][key].is_empty():
				_known(file, "%s.%s" % [path, key], data[id][key], _items, "item")


func _check_prop_tuning(data: Dictionary) -> void:
	var props := _dict(data.get("props"))
	if not data.get("props") is Dictionary:
		_add("prop_tuning.json", "", "missing \"props\"")
	for id: String in props:
		_fields("prop_tuning.json", "props[%s]" % id, props[id], { "lift": ["number", false], "scale": ["number", false] })


func _check_feature_flags(data: Dictionary) -> void:
	if not data.get("flags") is Dictionary:
		_add("feature_flags.json", "", "missing \"flags\"")


func _check_villager_routines(data: Dictionary) -> void:
	var file := "villager_routines.json"
	for id: String in data:
		var path := "[%s]" % id
		if _files.has("village_layout.json"):
			_known(file, path, id, _npcs, "villager")
		if not data[id] is Array:
			_add(file, path, "must be a list of stops")
			continue
		var previous := -1.0
		for i in data[id].size():
			var spath := "%s[%d]" % [path, i]
			if not _fields(file, spath, data[id][i], { "from": ["number", true], "x": ["number", false], "z": ["number", false], "facing": ["number", false], "via": ["array", false], "activity": ["string", false], "indoors": ["bool", false] }):
				continue
			var stop: Dictionary = data[id][i]
			var via: Array = stop.get("via", []) if stop.get("via") is Array else []
			for j in via.size():
				if not (via[j] is Array and via[j].size() == 2 and _is_type(via[j][0], "number") and _is_type(via[j][1], "number")):
					_add(file, "%s.via[%d]" % [spath, j], "must be an [x, z] pair of numbers")
			if stop.get("activity") is String and not Npc.ACTIVITIES.has(stop["activity"]):
				_add(file, spath + ".activity", "must be one of %s" % [Npc.ACTIVITIES.keys()])
			if stop.has("x") != stop.has("z"):
				_add(file, spath, "a stop needs both x and z, or neither")
			if stop.get("from") is float:
				if stop["from"] < 0.0 or stop["from"] >= 24.0 or stop["from"] <= previous:
					_add(file, spath + ".from", "stops must start at increasing hours from 0 to 24")
				previous = stop["from"]


func _check_village_layout(data: Dictionary) -> void:
	var file := "village_layout.json"
	var placed := { "x": ["number", true], "z": ["number", true] }
	var lists := {
		"buildings": { "id": ["string", true], "width": ["number", true], "depth": ["number", true], "height": ["number", true], "rotation": ["number", true], "color": ["color", true], "ruined": ["bool", false], "repaired_by_flag": ["string", false] },
		"fields": { "width": ["number", true], "depth": ["number", true], "rotation": ["number", true], "color": ["color", true] },
		"npcs": { "id": ["string", true], "name": ["text", true], "color": ["color", true], "hair": ["color", false], "model": ["string", false], "appears_when": ["object", false] },
		"enemies": { "type": ["string", true] },
		"repair_sites": { "quest": ["string", true], "objective": ["string", true], "flag": ["string", true], "model": ["string", true], "rotation": ["number", true], "prompt": ["text", true], "width": ["number", true], "depth": ["number", true], "height": ["number", true], "color": ["color", true] },
		"beds": { "model": ["string", true], "asset": ["string", false], "prompt": ["text", true], "width": ["number", true], "depth": ["number", true], "height": ["number", true], "color": ["color", true] },
		"stations": { "id": ["string", true], "model": ["string", true], "asset": ["string", false], "prompt": ["text", true], "width": ["number", true], "depth": ["number", true], "height": ["number", true], "work_spot": ["vec3", false], "color": ["color", true] },
		"resources": { "item": ["string", true], "prompt": ["text", true], "size": ["number", true], "uses": ["int", true], "respawn_seconds": ["number", true], "color": ["color", true] },
		"building_sites": { "id": ["string", true], "radius": ["number", true], "blend": ["number", true], "rise": ["number", true] },
		"hills": { "radius": ["number", true], "height": ["number", true] },
		"flat_areas": { "radius": ["number", true], "blend": ["number", true] },
	}
	for list: String in lists:
		if not data.get(list) is Array:
			_add(file, "", "missing list \"%s\"" % list)
			continue
		var spec: Dictionary = lists[list].duplicate()
		if list != "roads":
			spec.merge(placed)
		var seen := {}
		for i in data[list].size():
			var entry: Variant = data[list][i]
			var name: String = str(_dict(entry).get("id", i))
			var path := "%s[%s]" % [list, name]
			if not _fields(file, path, entry, spec):
				continue
			if entry.has("id"):
				if seen.has(entry["id"]):
					_add(file, path, "duplicate id")
				seen[entry["id"]] = true
			for key in ["model", "asset"]:
				if entry.get(key) is String and entry[key].begins_with("res://") and not ResourceLoader.exists(entry[key]):
					_add(file, "%s.%s" % [path, key], "file not found: %s" % entry[key])
			_check_layout_references(file, path, list, entry)
	_fields(file, "mine", data.get("mine"), { "id": ["string", true], "x": ["number", true], "z": ["number", true], "rotation": ["number", true], "width": ["number", true], "height": ["number", true], "opening_width": ["number", true], "opening_height": ["number", true], "seed": ["int", true], "plaza_radius": ["number", true], "plaza_blend": ["number", true], "compass": ["bool", false] })
	for i in _array(data.get("roads")).size():
		var road: Variant = data["roads"][i]
		if _fields(file, "roads[%d]" % i, road, { "width": ["number", true], "points": ["array", true] }) and road.has("points") and road["points"].size() < 2:
			_add(file, "roads[%d].points" % i, "a road needs at least two points")


func _check_layout_references(file: String, path: String, list: String, entry: Dictionary) -> void:
	if list == "enemies" and _files.has("enemies.json"):
		_known(file, path + ".type", entry.get("type"), _dict(_files["enemies.json"]), "enemy type")
	elif list == "resources":
		_known(file, path + ".item", entry.get("item"), _items, "item")
	elif list == "repair_sites":
		if _files.has("quests.json"):
			_check_objective(file, path, str(entry.get("quest")), str(entry.get("objective")))
	elif list == "npcs" and entry.has("appears_when"):
		_check_conditions(file, path + ".appears_when", entry["appears_when"])
