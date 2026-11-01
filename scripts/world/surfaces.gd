class_name Surfaces
extends RefCounted
## Shared world-mapped materials, reused so that similar surfaces batch together.

enum Pattern { PLASTER, WOOD, SHINGLES, STONE, CROPS, ROAD }

const SHADER := preload("res://shaders/surface.gdshader")
## Each surface's photo, the width in meters that the photo covers, and how strongly it shows.
const PHOTOS: Dictionary = {
	Pattern.PLASTER: [preload("res://assets/textures/plaster.jpg"), 2.0, 1.0],
	Pattern.WOOD: [preload("res://assets/textures/wood.jpg"), 1.0, 1.0],
	Pattern.SHINGLES: [preload("res://assets/textures/shingles.jpg"), 1.5, 1.0],
	Pattern.STONE: [preload("res://assets/textures/stone.jpg"), 1.5, 1.0],
	Pattern.ROAD: [preload("res://assets/textures/road.jpg"), 2.2, 0.5],
}

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
			material.set_shader_parameter("surface_texture", PHOTOS[pattern][0])
			material.set_shader_parameter("tile_metres", PHOTOS[pattern][1])
			material.set_shader_parameter("photo_strength", PHOTOS[pattern][2])
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
