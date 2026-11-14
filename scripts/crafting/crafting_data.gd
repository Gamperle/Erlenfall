class_name CraftingData
extends RefCounted
## Read-only access to the items, qualities, and recipes in the data file.

const DATA_PATH := "res://data/crafting.json"

static var _data: Dictionary = {}


static func item_name(item_id: String) -> String:
	return TranslationServer.translate(_get_data()["items"][item_id]["name"])


## Builds the item's look from its "model" parts, or returns null if it has none. Weapons stand on their grip, pointing up.
## The variant (see variant_key) says which option each part uses. Parts without a choice keep their own look.
static func item_model(item_id: String, variant: String = "") -> Node3D:
	var parts: Array = _get_data()["items"].get(item_id, {}).get("model", [])
	if parts.is_empty():
		return null
	var model := Node3D.new()
	model.name = "ItemModel"
	var choices := variant_choices(item_id, variant)
	for part: Dictionary in parts:
		var option := _option(choices.get(part.get("slot", ""), ""))
		var size := Vector3(part["size"][0], part["size"][1], part["size"][2])
		if option.has("size_scale"):
			size *= Vector3(option["size_scale"][0], option["size_scale"][1], option["size_scale"][2])
		var mesh := BoxMesh.new()
		mesh.size = size
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(option.get("color", part["color"]))
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


## Health the item restores when used, or 0 if it can't be used.
static func heal_amount(item_id: String) -> float:
	return float(_get_data()["items"].get(item_id, {}).get("use", {}).get("heal", 0.0))


static func is_material(item_id: String) -> bool:
	return _get_data()["items"][item_id].get("material", false)


static func quality_name(quality_id: String) -> String:
	for quality: Dictionary in _get_data()["qualities"]:
		if quality["id"] == quality_id:
			return TranslationServer.translate(quality["name"])
	return ""


## The slots the player can choose parts for when making this item, such as "grip" and "blade". Empty if the feature is off.
static func part_slots(item_id: String) -> Array[String]:
	var slots: Array[String] = []
	if FeatureFlags.enabled("crafting_parts"):
		for slot: String in _get_data()["items"].get(item_id, {}).get("parts", {}):
			slots.append(slot)
	return slots


## The options for one slot. The first is the plain, default one.
static func part_options(item_id: String, slot: String) -> Array[String]:
	var options: Array[String] = []
	for option_id: String in _get_data()["items"].get(item_id, {}).get("parts", {}).get(slot, []):
		options.append(option_id)
	return options


static func slot_name(slot: String) -> String:
	return TranslationServer.translate(_get_data()["part_slots"].get(slot, slot))


static func option_name(option_id: String) -> String:
	return TranslationServer.translate(_option(option_id).get("name", option_id))


## Turns choices (slot to option) into the text kept with the item, such as "blade=broad,grip=ebony".
## Slots left on their default are left out, so a plain item and an item from before parts existed are the same.
static func variant_key(item_id: String, choices: Dictionary) -> String:
	var pairs := PackedStringArray()
	var slots: Array = _get_data()["items"].get(item_id, {}).get("parts", {}).keys()
	slots.sort()
	for slot: String in slots:
		var options := part_options(item_id, slot)
		var chosen: String = choices.get(slot, "")
		if chosen != "" and options.has(chosen) and chosen != options[0]:
			pairs.append("%s=%s" % [slot, chosen])
	return ",".join(pairs)


## The choices in a variant, for the slots and options that still exist. Others are ignored, so saves survive data changes.
static func variant_choices(item_id: String, variant: String) -> Dictionary:
	var choices := {}
	if variant == "":
		return choices
	for pair in variant.split(","):
		var halves := pair.split("=")
		if halves.size() == 2 and part_options(item_id, halves[0]).has(halves[1]):
			choices[halves[0]] = halves[1]
	return choices


## The chosen parts as text for display, such as "Broad, Ebony". Empty for a plain item.
static func variant_text(item_id: String, variant: String) -> String:
	var names := PackedStringArray()
	var choices := variant_choices(item_id, variant)
	for slot: String in part_slots_in_data(item_id):
		if choices.has(slot):
			names.append(option_name(choices[slot]))
	return ", ".join(names)


## Like part_slots, but also when the feature is off, so items that already have parts keep their look.
static func part_slots_in_data(item_id: String) -> Array[String]:
	var slots: Array[String] = []
	for slot: String in _get_data()["items"].get(item_id, {}).get("parts", {}):
		slots.append(slot)
	return slots


## Returns how hard this item hits with this quality and these parts, or 0 if it isn't a weapon.
static func weapon_damage(item_id: String, quality_id: String, variant: String = "") -> float:
	var damage: float = _get_data()["items"][item_id].get("damage", 0.0)
	for option_id: String in variant_choices(item_id, variant).values():
		damage *= float(_option(option_id).get("damage_multiplier", 1.0))
	for quality: Dictionary in _get_data()["qualities"]:
		if quality["id"] == quality_id:
			return damage * float(quality["damage_multiplier"])
	return damage


## How much this bow (or arrow, or flask) scales the damage of what it shoots, from its own strength, quality, and parts.
## Items with no "ranged_damage_multiplier" still scale by quality and parts.
static func ranged_multiplier(item_id: String, quality_id: String = "", variant: String = "") -> float:
	var multiplier := float(_get_data()["items"].get(item_id, {}).get("ranged_damage_multiplier", 1.0))
	for option_id: String in variant_choices(item_id, variant).values():
		multiplier *= float(_option(option_id).get("damage_multiplier", 1.0))
	for quality: Dictionary in _get_data()["qualities"]:
		if quality["id"] == quality_id:
			return multiplier * float(quality["damage_multiplier"])
	return multiplier


## The items that can fire this projectile type, such as every bow for "arrow". Items name it in "fires".
static func launchers(projectile_id: String) -> Array[String]:
	var found: Array[String] = []
	for item_id: String in _get_data()["items"]:
		if _get_data()["items"][item_id].get("fires", "") == projectile_id:
			found.append(item_id)
	return found


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


static func _option(option_id: String) -> Dictionary:
	return _get_data().get("part_options", {}).get(option_id, {})


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data
