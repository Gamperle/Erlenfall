class_name SaveGame
extends RefCounted
## Writes and reads progress as JSON. Each write goes to a temporary file first and the previous
## save is kept as a ".bak" file, so a crash mid-write never destroys the only copy. A damaged
## file counts as no save unless its backup is still good.

const BELOW_GROUND_MARGIN := 1.5
const DEFAULT_PATH := "user://save.json"
const VERSION := 1
const SLOTS := 3
const BACKUP_SUFFIX := ".bak"
const TEMP_SUFFIX := ".tmp"


## The save files in slot order. The first is the file from before slots existed.
static func slot_paths() -> Array[String]:
	var paths: Array[String] = [DEFAULT_PATH]
	for slot in range(2, SLOTS + 1):
		paths.append("user://save_%d.json" % slot)
	return paths


## Returns the most recently saved of these files, or an empty string if none holds a save.
static func latest(paths: Array[String]) -> String:
	var found := ""
	var newest := -1
	for path in paths:
		if exists(path) and FileAccess.get_modified_time(path) > newest:
			found = path
			newest = FileAccess.get_modified_time(path)
	return found


## Returns when this file was saved, in the player's local time.
static func saved_at_text(path: String) -> String:
	var local_time: int = FileAccess.get_modified_time(path) + int(Time.get_time_zone_from_system()["bias"]) * 60
	return Time.get_datetime_string_from_unix_time(local_time, true).left(16)


## True if this slot holds a save that can be loaded, either itself or through its backup.
static func exists(path: String) -> bool:
	return not _read(path).is_empty() or not _read(path + BACKUP_SUFFIX).is_empty()


## True if the file is there but can't be read, so loading it would fall back to the backup (or fail).
static func is_damaged(path: String) -> bool:
	return FileAccess.file_exists(path) and _read(path).is_empty()


## True if the previous save of this slot is still readable.
static func has_backup(path: String) -> bool:
	return not _read(path + BACKUP_SUFFIX).is_empty()


static func write(path: String, player: Player, day_night: DayNight, village: Village) -> void:
	var data := {
		"version": VERSION,
		"position": [player.position.x, player.position.y, player.position.z],
		"health": player.health.current,
		"inventory": player.inventory.to_data(),
		"known_recipes": player.known_recipes.keys(),
		"skill_xp": player.skill_xp,
		"torch_given": player.torch_given,
		"ranged_given": player.ranged_given,
		"torch_lit": player.torch_lit,
		"torch_burned_seconds": player.torch_burned_seconds,
		"quests": player.quests.to_data(),
		"hour": day_night.hour,
		"world": village.to_data(),
	}
	var temp_path := path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save the game: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# An unreadable file must not replace a good backup.
	if not _read(path).is_empty():
		DirAccess.copy_absolute(path, path + BACKUP_SUFFIX)
	var error := DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		push_error("Could not save the game: %s" % error_string(error))
		DirAccess.remove_absolute(temp_path)


## Applies a saved game and reports whether there was one to apply.
static func apply(path: String, player: Player, day_night: DayNight, village: Village) -> bool:
	var data := _read(path)
	if data.is_empty():
		data = _read(path + BACKUP_SUFFIX)
		if data.is_empty():
			return false
		push_warning("The save %s is damaged. Loaded its backup." % path)
		# Make the backup the slot again, so the next save doesn't treat the damage as current.
		DirAccess.copy_absolute(path + BACKUP_SUFFIX, path)
	var saved_position: Array = data["position"]
	player.position = Vector3(saved_position[0], saved_position[1], saved_position[2])
	# Saves can come from before the land changed shape.
	var ground: float = village.terrain.height_at(player.position.x, player.position.z)
	if player.position.y < ground - BELOW_GROUND_MARGIN:
		player.position.y = ground
	player.health.current = data["health"]
	player.health.changed.emit()
	player.inventory.load_data(data["inventory"])
	player.known_recipes.clear()
	for recipe_id: String in data["known_recipes"]:
		player.known_recipes[recipe_id] = true
	# Games saved before skills existed don't have this.
	player.skill_xp.clear()
	for skill_id: String in data.get("skill_xp", {}):
		if CraftingData.skill_ids().has(skill_id):
			player.skill_xp[skill_id] = int(data["skill_xp"][skill_id])
	# Games saved before torches existed don't have these.
	player.torch_given = data.get("torch_given", false)
	player.ranged_given = data.get("ranged_given", false)
	player.torch_burned_seconds = data.get("torch_burned_seconds", 0.0)
	var can_light: bool = FeatureFlags.enabled("torches") and player.inventory.count(Player.TORCH_ITEM) > 0
	player.set_torch_lit(data.get("torch_lit", false) and can_light)
	day_night.hour = data["hour"]
	# Games saved before enemies and gathering spots were saved don't have this.
	if data.has("world"):
		village.load_data(data["world"])
	# Last, because quest changes trigger an autosave.
	player.quests.load_data(data["quests"])
	return true


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("version") == VERSION:
		return data
	return {}
