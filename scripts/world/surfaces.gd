class_name Surfaces
extends RefCounted
## Shared procedural materials, reused so that similar surfaces batch together.

enum Pattern { PLASTER, WOOD, SHINGLES, STONE, CROPS }

const SHADER := preload("res://shaders/surface.gdshader")

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
