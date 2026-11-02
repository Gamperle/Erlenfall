class_name Surfaces
extends RefCounted
## Shared world-mapped materials, reused so that similar surfaces batch together.

enum Pattern { PLASTER, WOOD, SHINGLES, STONE, CROPS, ROAD, IRON_ORE, COAL, BOULDER }

const SHADER := preload("res://shaders/surface.gdshader")
## Each surface's photos, each with the width in meters that it covers.
const PHOTOS: Dictionary = {
	Pattern.PLASTER: [[preload("res://assets/textures/plaster.jpg"), 2.0], [preload("res://assets/textures/plaster_2.jpg"), 1.8], [preload("res://assets/textures/plaster_3.jpg"), 1.0]],
	Pattern.WOOD: [[preload("res://assets/textures/wood.jpg"), 1.0], [preload("res://assets/textures/wood_2.jpg"), 2.0]],
	Pattern.SHINGLES: [[preload("res://assets/textures/shingles.jpg"), 1.5], [preload("res://assets/textures/shingles_2.jpg"), 3.0]],
	Pattern.STONE: [[preload("res://assets/textures/stone.jpg"), 1.5], [preload("res://assets/textures/stone_2.jpg"), 1.7], [preload("res://assets/textures/stone_3.jpg"), 2.0]],
	Pattern.ROAD: [[preload("res://assets/textures/road.jpg"), 2.2], [preload("res://assets/textures/road_2.jpg"), 2.25]],
	Pattern.IRON_ORE: [[preload("res://assets/textures/iron_ore.jpg"), 1.5], [preload("res://assets/textures/iron_ore_2.jpg"), 2.2], [preload("res://assets/textures/iron_ore_3.jpg"), 1.5]],
	Pattern.COAL: [[preload("res://assets/textures/coal.jpg"), 2.0], [preload("res://assets/textures/rock_3.jpg"), 1.5]],
	Pattern.BOULDER: [[preload("res://assets/textures/boulder.jpg"), 1.8], [preload("res://assets/textures/boulder_2.jpg"), 1.4], [preload("res://assets/textures/rock_3.jpg"), 1.5]],
}
## How strongly the photos show, where it isn't the full strength.
const PHOTO_STRENGTH: Dictionary = { Pattern.ROAD: 0.5 }
## The photos on a road fade over a wide area, so that its look changes gradually.
const AREA_SOFTNESS: Dictionary = { Pattern.ROAD: 0.35 }
## How often the photos change per meter. Rocks are small, so each one needs its own mix.
const AREA_FREQUENCY: Dictionary = { Pattern.IRON_ORE: 0.3, Pattern.COAL: 0.3, Pattern.BOULDER: 0.15 }

static var _noise_texture: NoiseTexture2D
static var _cache: Dictionary = {}


static func get_material(pattern: Pattern, color: Color) -> ShaderMaterial:
	var key := "%d:%s" % [pattern, color.to_html()]
	if not _cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("detail_noise", noise_texture())
		material.set_shader_parameter("base_color", color)
		material.set_shader_parameter("pattern", int(pattern))
		if PHOTOS.has(pattern):
			var photos: Array = PHOTOS[pattern]
			for i in photos.size():
				var suffix := "" if i == 0 else "_%d" % (i + 1)
				material.set_shader_parameter("surface_texture" + suffix, photos[i][0])
				material.set_shader_parameter("tile_metres" + suffix, photos[i][1])
			material.set_shader_parameter("photo_strength", PHOTO_STRENGTH.get(pattern, 1.0))
			material.set_shader_parameter("area_softness", AREA_SOFTNESS.get(pattern, 0.05))
			material.set_shader_parameter("area_frequency", AREA_FREQUENCY.get(pattern, 0.037))
		_cache[key] = material
	return _cache[key]


## A seamless noise texture shared by the world's shaders.
static func noise_texture() -> NoiseTexture2D:
	if _noise_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 6
		noise.frequency = 0.02
		noise.fractal_octaves = 4
		_noise_texture = NoiseTexture2D.new()
		_noise_texture.noise = noise
		_noise_texture.seamless = true
		_noise_texture.generate_mipmaps = true
	return _noise_texture
