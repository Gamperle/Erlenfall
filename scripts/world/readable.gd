class_name Readable
extends Interactable
## A sign, note, or book with a text from data/notes.json. Using it opens the reading panel (see
## ReadingUI), which adds the text to the journal's notes the first time it is read.

var note_id := ""


func interact(player: Player) -> void:
	get_tree().call_group(ReadingUI.GROUP, "open_note", note_id, player)
