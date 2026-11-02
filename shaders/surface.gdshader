shader_type spatial;

// Photo surfaces, mapped in world space so they don't need UV coordinates.

const int PLASTER = 0;
const int CROPS = 4;

uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_texture_2 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_texture_3 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tile_metres = 2.0;
uniform float tile_metres_2 = 2.0;
// No width means this surface has no third photo.
uniform float tile_metres_3 = 0.0;
uniform float area_softness = 0.05;
uniform float area_frequency = 0.037;
uniform float photo_strength = 1.0;
uniform vec3 base_color : source_color;
uniform int pattern = 0;

varying vec3 world_position;
varying vec3 world_normal;

// Dividing by the photo's average keeps base_color as the overall color. Gradients are passed
// because these reads sit in branches, where a GPU can't work them out itself.
vec3 photo_detail(sampler2D photo, vec2 uv, vec2 dx, vec2 dy) {
	return textureGrad(photo, uv, dx, dy).rgb / max(textureLod(photo, vec2(0.5), 12.0).rgb, vec3(0.02));
}

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
		// Rows narrower than a pixel or two would blur into wavy bands, so fade to their average.
		rows = mix(rows, 0.6, smoothstep(0.1, 0.45, fwidth(world_position.x * 0.8)));
		ALBEDO = base_color * (0.8 + noise * 0.25 + fine * 0.15) * (0.55 + 0.45 * rows + fine * 0.2);
	} else {
		// The photo adds detail, and dividing by its average keeps base_color as the overall color.
		vec3 photo = texture(surface_texture, uv / tile_metres).rgb;
		photo /= max(textureLod(surface_texture, vec2(0.5), 12.0).rgb, vec3(0.02));
		// Areas of other photos keep large walls and roads from repeating.
		float area = texture(detail_noise, uv * area_frequency).r + (fine - 0.5) * 0.15;
		float other = smoothstep(0.5 - area_softness, 0.5 + area_softness, area);
		if (other > 0.0) {
			photo = mix(photo, photo_detail(surface_texture_2, uv / tile_metres_2, dFdx(uv) / tile_metres_2, dFdy(uv) / tile_metres_2), other);
		}
		if (tile_metres_3 > 0.0) {
			float third_area = texture(detail_noise, uv.yx * area_frequency * 1.7 + vec2(0.37, 0.61)).r + (fine - 0.5) * 0.15;
			float third = smoothstep(0.55 - area_softness, 0.55 + area_softness, third_area);
			if (third > 0.0) {
				photo = mix(photo, photo_detail(surface_texture_3, uv / tile_metres_3, dFdx(uv) / tile_metres_3, dFdy(uv) / tile_metres_3), third);
			}
		}
		ALBEDO = base_color * mix(vec3(1.0), photo, photo_strength) * (0.85 + noise * 0.3);
	}
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
