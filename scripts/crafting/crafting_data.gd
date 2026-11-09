class_name CraftingData
extends RefCounted
## Read-only access to the items, qualities, and recipes in the data file.

const DATA_PATH := "res://data/crafting.json"

static var _data: Dictionary = {}


static func item_name(item_id: String) -> String:
	return TranslationServer.translate(_get_data()["items"][item_id]["name"])


## Builds the item's look from its "model" parts, or returns null if it has none. Weapons stand on their grip, pointing up.
static func item_model(item_id: String) -> Node3D:
	var parts: Array = _get_data()["items"].get(item_id, {}).get("model", [])
	if parts.is_empty():
		return null
	var model := Node3D.new()
	model.name = "ItemModel"
	for part: Dictionary in parts:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(part["size"][0], part["size"][1], part["size"][2])
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(part["color"])
		material.roughness = 0.55
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Vector3(part["at"][0], part["at"][1], part["at"][2])
		model.add_child(instance)
	return model


## How far the item's model reaches up from its origin.
static func item_length(item_id: String) -> float:
	var length := 0.0
	for part: Dictionary in _get_data()["items"][item_id].get("model", []):
		length = maxf(length, float(part["at"][1]) + float(part["size"][1]) / 2.0)
	return length


static func is_material(item_id: String) -> bool:
	return _get_data()["items"][item_id].get("material", false)


static func quality_name(quality_id: String) -> String:
	for quality: Dictionary in _get_data()["qualities"]:
		if quality["id"] == quality_id:
			return TranslationServer.translate(quality["name"])
	return ""


## Returns how hard this item hits with this quality, or 0 if it isn't a weapon.
static func weapon_damage(item_id: String, quality_id: String) -> float:
	var damage: float = _get_data()["items"][item_id].get("damage", 0.0)
	for quality: Dictionary in _get_data()["qualities"]:
		if quality["id"] == quality_id:
			return damage * float(quality["damage_multiplier"])
	return damage


## Returns the id of the best quality tier this score reaches.
static func quality_for_score(score: float) -> String:
	var best := ""
	for quality: Dictionary in _get_data()["qualities"]:
		if score >= quality["min_score"]:
			best = quality["id"]
	return best


## The skill levels start at 1. Each entry of the skill's "level_xp" is the practice needed for the next level.
static func skill_level(skill_id: String, xp: int) -> int:
	var level := 0
	for needed: int in _get_data()["skills"][skill_id]["level_xp"]:
		if xp >= needed:
			level += 1
	return maxi(level, 1)


static func skill_max_level(skill_id: String) -> int:
	return _get_data()["skills"][skill_id]["level_xp"].size()


## Returns the practice needed for the next level, or 0 at the highest level.
static func skill_next_xp(skill_id: String, xp: int) -> int:
	var level := skill_level(skill_id, xp)
	var thresholds: Array = _get_data()["skills"][skill_id]["level_xp"]
	return 0 if level >= thresholds.size() else int(thresholds[level])


static func skill_name(skill_id: String) -> String:
	return TranslationServer.translate(_get_data()["skills"][skill_id]["name"])


static func skill_ids() -> Array:
	return _get_data()["skills"].keys()


static func recipes_for(station: String) -> Array[Dictionary]:
	var recipes: Array[Dictionary] = []
	for recipe: Dictionary in _get_data()["recipes"]:
		if recipe["station"] == station and (not recipe.has("requires_flag") or FeatureFlags.enabled(recipe["requires_flag"])):
			recipes.append(recipe)
	return recipes


## Returns the recipe using exactly these materials, or an empty dictionary.
static func find_recipe(station: String, materials: Dictionary) -> Dictionary:
	for recipe in recipes_for(station):
		var inputs: Dictionary = recipe["inputs"]
		if inputs.size() != materials.size():
			continue
		var matches := true
		for item_id: String in inputs:
			if int(materials.get(item_id, 0)) != int(inputs[item_id]):
				matches = false
				break
		if matches:
			return recipe
	return {}


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data
