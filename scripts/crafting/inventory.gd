class_name Inventory
extends RefCounted
## Item stacks, kept separately per item and quality.

signal changed

var _stacks: Dictionary = {}


func add(item_id: String, amount: int = 1, quality: String = "") -> void:
	var stack_key := _key(item_id, quality)
	_stacks[stack_key] = int(_stacks.get(stack_key, 0)) + amount
	changed.emit()


func count(item_id: String) -> int:
	var total := 0
	for entry in entries():
		if entry["id"] == item_id:
			total += entry["count"]
	return total


## Removes the amount if available, across qualities, and reports whether it did.
func remove(item_id: String, amount: int = 1) -> bool:
	if count(item_id) < amount:
		return false
	var remaining := amount
	for entry in entries():
		if entry["id"] != item_id or remaining == 0:
			continue
		var taken := mini(remaining, int(entry["count"]))
		var stack_key := _key(item_id, entry["quality"])
		_stacks[stack_key] -= taken
		if _stacks[stack_key] == 0:
			_stacks.erase(stack_key)
		remaining -= taken
	changed.emit()
	return true


## Returns dictionaries with "id", "quality", and "count", sorted for stable display.
func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var keys := _stacks.keys()
	keys.sort()
	for stack_key: String in keys:
		var parts := stack_key.split(":")
		result.append({ "id": parts[0], "quality": parts[1], "count": _stacks[stack_key] })
	return result


func _key(item_id: String, quality: String) -> String:
	return "%s:%s" % [item_id, quality]
