class_name DialogueRunner
extends RefCounted
## Steps through one conversation from the data file and applies its effects.
## Each character's first conversation whose conditions hold is the one that plays.

const DATA_PATH := "res://data/dialogue.json"

static var _data: Dictionary = {}

var _player: Player
var _nodes: Dictionary = {}
var _node: Dictionary = {}
## Whoever is being spoken to, if they react to effects like "calm_enemy".
var _talker: Object
## Gives a number from 0 to 1 for choices that only sometimes work. Tests swap it.
var roll := randf


func _init(npc_id: String, player: Player, talker: Object = null) -> void:
	_player = player
	_talker = talker
	for conversation: Dictionary in _get_data()[npc_id]:
		if _conditions_hold(conversation.get("when", {})):
			_nodes = conversation["nodes"]
			_enter(conversation["start"])
			return


func is_finished() -> bool:
	return _node.is_empty()


func text_key() -> String:
	return _node["text"]


## Returns the player's reply options as translation keys. Empty means just continue.
func choice_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for choice: Dictionary in _choices():
		keys.append(choice["text"])
	return keys


## Whether the player may walk away now. A node can ask for an answer with "must_answer": true.
func can_leave() -> bool:
	return not _node.get("must_answer", false)


## Moves on from the current line, using the given choice if it offers any.
func advance(choice_index: int = 0) -> void:
	var choices := _choices()
	var next: String = choices[choice_index].get("next", "") if choices.size() > 0 else _node.get("next", "")
	# A choice with a "chance" only works that often. Otherwise it goes to "fail_next".
	if choices.size() > 0 and choices[choice_index].has("chance") and float(roll.call()) >= float(choices[choice_index]["chance"]):
		next = choices[choice_index].get("fail_next", "")
	_enter(next)


## A node lists its own choices, or borrows another node's with "choices_of".
## A choice with a "when" is left out while its conditions don't hold.
func _choices() -> Array:
	var source: Dictionary = _nodes.get(_node["choices_of"], {}) if _node.has("choices_of") else _node
	var shown := []
	for choice: Dictionary in source.get("choices", []):
		if _conditions_hold(choice.get("when", {})):
			shown.append(choice)
	return shown


func _enter(node_id: String) -> void:
	_node = _nodes.get(node_id, {})
	for effect: Dictionary in _node.get("effects", []):
		_apply(effect)


func _apply(effect: Dictionary) -> void:
	match effect["type"]:
		"start_quest":
			_player.quests.start(effect["quest"])
		"advance_quest":
			_player.quests.advance(effect["quest"])
		"set_flag":
			_player.quests.flags[effect["flag"]] = true
		"take_item":
			_player.inventory.remove(effect["item"], int(effect["count"]))
		"give_item":
			_player.inventory.add(effect["item"], int(effect["count"]))
		"calm_enemy", "provoke_enemy":
			if _talker != null:
				_talker.apply_effect(effect)


func _conditions_hold(when: Dictionary) -> bool:
	var quests := _player.quests
	if when.has("objective") and quests.current_objective(when["objective"][0]) != when["objective"][1]:
		return false
	if when.has("quest_done") and not quests.is_done(when["quest_done"]):
		return false
	if when.has("flag") and not quests.flags.has(when["flag"]):
		return false
	if when.has("not_flag") and quests.flags.has(when["not_flag"]):
		return false
	if when.has("has_item") and _player.inventory.count(when["has_item"][0]) < int(when["has_item"][1]):
		return false
	return true


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data
