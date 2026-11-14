class_name JournalNotes
extends RefCounted
## The notes the player has found, shown on the journal's Notes tab. Readable notes in the world
## (not built yet, see issue #268) call `add` when the player reads one.

signal changed

## Each note is { "id": String, "title": translation key, "text": translation key }, oldest first.
var _notes: Array[Dictionary] = []


## Adds a note and returns true, or returns false if the player already has this one.
func add(note_id: String, title_key: String, text_key: String) -> bool:
	if has(note_id):
		return false
	_notes.append({ "id": note_id, "title": title_key, "text": text_key })
	changed.emit()
	return true


func has(note_id: String) -> bool:
	return _notes.any(func(note: Dictionary) -> bool: return note["id"] == note_id)


func count() -> int:
	return _notes.size()


## The notes with translated titles and texts, newest first.
func entries() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for note in _notes:
		found.push_front({ "id": note["id"], "title": TranslationServer.translate(note["title"]), "text": TranslationServer.translate(note["text"]) })
	return found


func to_data() -> Array:
	return _notes.duplicate(true)


## Loads saved notes. Entries that aren't well formed are skipped.
func load_data(data: Array) -> void:
	_notes.clear()
	for entry: Variant in data:
		if entry is Dictionary and entry.get("id") is String and entry.get("title") is String and entry.get("text") is String and not has(entry["id"]):
			_notes.append({ "id": entry["id"], "title": entry["title"], "text": entry["text"] })
	changed.emit()
