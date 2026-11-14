class_name Readables
extends RefCounted
## The texts the player can read in the world (signs, notes, books), from data/notes.json.
## Each entry is { "type": sign | note | book, "title": key, "text": key, "sets_flag": flag (optional) }.
## The places they stand are in data/village_layout.json under "readables". See the `readables` flag.

const PATH := "res://data/notes.json"
const TYPES: Array[String] = ["sign", "note", "book"]

static var _data: Dictionary = {}
static var _loaded := false


static func all() -> Dictionary:
	if not _loaded:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
		_loaded = true
	return _data


static func has(note_id: String) -> bool:
	return all().has(note_id)


## The entry for a text, or an empty dictionary if there is none.
static func entry(note_id: String) -> Dictionary:
	return all().get(note_id, {})


## The kind of thing that holds the text: sign, note, or book.
static func type_of(note_id: String) -> String:
	return String(entry(note_id).get("type", "note"))


## The prompt that goes with a text's kind, such as PROMPT_READ_SIGN.
static func prompt_key(note_id: String) -> String:
	return "PROMPT_READ_" + type_of(note_id).to_upper()
