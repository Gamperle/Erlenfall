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

## The default size of a NoiseTexture2D.
const NOISE_SIZE := 512

## A relief map's color for a flat surface: no bend, rough, and not occluded.
const FLAT_RELIEF := Color(0.5, 0.5, 0.95, 1.0)

static var _flat_relief: ImageTexture
static var _noise_texture: NoiseTexture2D
static var _noise_values := PackedByteArray()
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
				material.set_shader_parameter("surface_relief" + suffix, relief_map(photos[i][0]))
				material.set_shader_parameter("tile_metres" + suffix, photos[i][1])
			material.set_shader_parameter("photo_strength", PHOTO_STRENGTH.get(pattern, 1.0))
			material.set_shader_parameter("area_softness", AREA_SOFTNESS.get(pattern, 0.05))
			material.set_shader_parameter("area_frequency", AREA_FREQUENCY.get(pattern, 0.037))
		_cache[key] = material
	return _cache[key]


## The relief map built for a photo by tools/texture_pipeline, or a flat one if relief is turned off.
static func relief_map(photo: Texture2D) -> Texture2D:
	if not FeatureFlags.enabled("surface_relief"):
		if _flat_relief == null:
			var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			image.set_pixel(0, 0, FLAT_RELIEF)
			_flat_relief = ImageTexture.create_from_image(image)
		return _flat_relief
	return load(photo.resource_path.get_basename() + "_relief.png")


## A seamless noise texture shared by the world's shaders.
static func noise_texture() -> NoiseTexture2D:
	if _noise_texture == null:
		_noise_texture = NoiseTexture2D.new()
		_noise_texture.noise = _detail_noise()
		_noise_texture.seamless = true
		_noise_texture.generate_mipmaps = true
	return _noise_texture


## Makes the values that ground_dryness reads. Call this before using it on worker threads.
static func prepare_ground_dryness() -> void:
	if _noise_values.is_empty():
		var image := _detail_noise().get_seamless_image(NOISE_SIZE, NOISE_SIZE)
		image.convert(Image.FORMAT_L8)
		_noise_values = image.get_data()


## How dry the ground looks from 0 to 1. Works the same as `dryness` in shaders/terrain.gdshader.
static func ground_dryness(x: float, z: float) -> float:
	var meadow := _noise_at(x * 0.0043, z * 0.0043)
	var patches := _noise_at(x * 0.019, z * 0.019)
	return smoothstep(0.38, 0.62, meadow * 0.6 + patches * 0.4)


## Reads the noise texture as a shader does, blending the nearest pixels.
static func _noise_at(u: float, v: float) -> float:
	var x := fposmod(u, 1.0) * NOISE_SIZE - 0.5
	var y := fposmod(v, 1.0) * NOISE_SIZE - 0.5
	var left := floori(x)
	var top := floori(y)
	var upper := lerpf(_noise_pixel(left, top), _noise_pixel(left + 1, top), x - left)
	var lower := lerpf(_noise_pixel(left, top + 1), _noise_pixel(left + 1, top + 1), x - left)
	return lerpf(upper, lower, y - top) / 255.0


static func _noise_pixel(x: int, y: int) -> float:
	return _noise_values[posmod(y, NOISE_SIZE) * NOISE_SIZE + posmod(x, NOISE_SIZE)]


static func _detail_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 6
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	return noise
