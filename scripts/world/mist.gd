class_name Mist
extends Node3D
## Bands of drifting mist that hang around the mountains.

const SHADER := preload("res://shaders/mist.gdshader")
const BANDS: Array[Dictionary] = [
	{ "radius": 620.0, "height": 110.0, "y": 175.0, "density": 1.0 },
	{ "radius": 540.0, "height": 80.0, "y": 125.0, "density": 0.9 },
]

var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true

	for band in BANDS:
		var mesh := CylinderMesh.new()
		mesh.top_radius = band["radius"]
		mesh.bottom_radius = band["radius"]
		mesh.height = band["height"]
		mesh.cap_top = false
		mesh.cap_bottom = false
		mesh.radial_segments = 48
		mesh.rings = 1

		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("mist_noise", texture)
		material.set_shader_parameter("density", band["density"])
		_materials.append(material)
		mesh.material = material

		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position.y = band["y"]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


func set_color(color: Color) -> void:
	for material in _materials:
		material.set_shader_parameter("mist_color", color)
