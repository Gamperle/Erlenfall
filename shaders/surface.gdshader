shader_type spatial;

// Photo surfaces, mapped in world space so they don't need UV coordinates.

const int PLASTER = 0;
const int CROPS = 4;

uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tile_metres = 2.0;
uniform float photo_strength = 1.0;
uniform vec3 base_color : source_color;
uniform int pattern = 0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 facing = abs(world_normal);
	vec2 uv = facing.x > facing.z ? world_position.zy : world_position.xy;
	if (facing.y > 0.85) {
		uv = world_position.xz;
	}

	float noise = texture(detail_noise, uv * 0.13).r;
	float fine = texture(detail_noise, uv * 0.61).r;

	if (pattern == CROPS) {
		float rows = smoothstep(0.25, 0.55, abs(fract(world_position.x * 0.8) - 0.5) * 2.0);
		ALBEDO = base_color * (0.8 + noise * 0.25 + fine * 0.15) * (0.55 + 0.45 * rows + fine * 0.2);
	} else {
		// The photo adds detail, and dividing by its average keeps base_color as the overall color.
		vec3 photo = texture(surface_texture, uv / tile_metres).rgb;
		vec3 average = textureLod(surface_texture, vec2(0.5), 12.0).rgb;
		ALBEDO = base_color * mix(vec3(1.0), photo / max(average, vec3(0.02)), photo_strength) * (0.85 + noise * 0.3);
	}
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
