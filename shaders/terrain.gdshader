shader_type spatial;

// Vertex color holds the grass color in sRGB, and alpha holds the landslide mask.
// Everything else is decided per pixel, which hides the coarse terrain grid.

uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D lush_grass_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dry_grass_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_texture_2 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D snow_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D snow_texture_2 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rubble_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rubble_texture_2 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 rubble_color : source_color;
uniform vec3 rock_color : source_color;
uniform vec3 snow_color : source_color;
uniform float snow_height = 165.0;
// These tint the grass, so 1 leaves it as it is.
uniform vec3 lush_grass_tint = vec3(0.7, 0.92, 0.62);
uniform vec3 dry_grass_tint = vec3(1.4, 1.15, 0.6);

// Turning the second layer of a photo keeps its pattern from lining up with the first.
const mat2 TURN = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));

varying vec3 world_position;
varying vec3 world_normal;

// The photo's detail around 1, so the colors set here stay the overall colors. Each read
// passes its own gradients because most of them sit in branches, where a GPU can't work
// the gradients out itself.
vec3 detail(sampler2D photo, vec2 uv, vec2 dx, vec2 dy) {
	return textureGrad(photo, uv, dx, dy).rgb / max(textureLod(photo, vec2(0.5), 12.0).rgb, vec3(0.02));
}

// The same detail as brightness only, for surfaces whose photos would tint the color.
float brightness(sampler2D photo, vec2 uv, vec2 dx, vec2 dy) {
	return dot(detail(photo, uv, dx, dy), vec3(0.3, 0.6, 0.1));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float broad = texture(detail_noise, world_position.xz * 0.03).r;
	float fine = texture(detail_noise, world_position.xz * 0.21).r;
	// Whole meadows lean lush or dry, with smaller patches inside them.
	float meadow = texture(detail_noise, world_position.xz * 0.0043).r;
	float patches = texture(detail_noise, world_position.xz * 0.019).r;

	vec2 flat_uv = world_position.xz;
	vec2 flat_dx = dFdx(flat_uv);
	vec2 flat_dy = dFdy(flat_uv);
	// Shifting by height stops the rock from stretching down steep slopes.
	vec2 slope_uv = flat_uv + world_position.y;
	vec2 slope_dx = dFdx(slope_uv);
	vec2 slope_dy = dFdy(slope_uv);

	// Each cover has its own weight, and a photo is only read where its cover shows.
	float dryness = smoothstep(0.38, 0.62, meadow * 0.6 + patches * 0.4);
	float steep = smoothstep(0.86, 0.72, world_normal.y + (broad - 0.5) * 0.12);
	float high = smoothstep(85.0, 125.0, world_position.y + (broad - 0.5) * 50.0);
	float rocky = max(steep, high);
	float mask = smoothstep(0.42, 0.58, COLOR.a + (broad - 0.5) * 0.5);
	float snow_line = smoothstep(snow_height - 12.0, snow_height + 12.0, world_position.y + (broad - 0.5) * 60.0);
	float snow = snow_line * smoothstep(0.45, 0.7, world_normal.y + (fine - 0.5) * 0.2);

	// Fine detail can't be seen far away, so distant ground skips those photos, which saves
	// more time than anything else here.
	float near = 1.0 - smoothstep(45.0, 90.0, length(VERTEX));

	vec3 ground = pow(COLOR.rgb, vec3(2.2));
	if (rocky < 1.0 && mask < 1.0 && snow < 1.0) {
		vec3 grass = vec3(1.0);
		// Lush and dry meadows use different photos, and a few patches wear down to soil.
		float lush = (1.0 - smoothstep(0.3, 0.5, dryness + (fine - 0.5) * 0.25)) * near;
		float dry = smoothstep(0.55, 0.8, dryness + (fine - 0.5) * 0.25) * near;
		if (near > 0.0) {
			grass = mix(grass, detail(grass_texture, flat_uv / 2.0, flat_dx / 2.0, flat_dy / 2.0), near);
		}
		if (lush > 0.0) {
			grass = mix(grass, detail(lush_grass_texture, TURN * flat_uv / 3.1, TURN * flat_dx / 3.1, TURN * flat_dy / 3.1), lush);
		}
		if (dry > 0.0) {
			grass = mix(grass, detail(dry_grass_texture, TURN * flat_uv / 1.7, TURN * flat_dx / 1.7, TURN * flat_dy / 1.7), dry);
		}
		grass = mix(grass, detail(grass_texture, TURN * flat_uv / 11.0, TURN * flat_dx / 11.0, TURN * flat_dy / 11.0), 0.5);
		ground *= mix(vec3(1.0), grass, 0.7);
		ground *= mix(lush_grass_tint, dry_grass_tint, dryness);

		float worn = smoothstep(0.62, 0.72, patches * 0.65 + fine * 0.35);
		if (worn > 0.0) {
			vec3 soil = textureLod(soil_texture, vec2(0.5), 12.0).rgb;
			if (near > 0.0) {
				soil = mix(soil, textureGrad(soil_texture, flat_uv / 1.9, flat_dx / 1.9, flat_dy / 1.9).rgb, near);
			}
			ground = mix(ground, soil * 0.75, worn * 0.8);
		}
	}

	// Rock shows on steep ground and takes over high up.
	if (rocky > 0.0) {
		float strata = texture(detail_noise, vec2(world_position.x * 0.01, world_position.y * 0.12)).r;
		float rock_detail = brightness(rock_texture, slope_uv / 2.4, slope_dx / 2.4, slope_dy / 2.4);
		float other_rock = smoothstep(0.42, 0.58, patches * 0.6 + strata * 0.4) * near;
		if (other_rock > 0.0) {
			rock_detail = mix(rock_detail, brightness(rock_texture_2, TURN * slope_uv / 3.3, TURN * slope_dx / 3.3, TURN * slope_dy / 3.3), other_rock);
		}
		vec3 rock = rock_color * (0.55 + strata * 0.9) * rock_detail * brightness(rock_texture, TURN * slope_uv / 37.0, TURN * slope_dx / 37.0, TURN * slope_dy / 37.0);
		ground = mix(ground, rock, rocky);
	}

	if (mask > 0.0) {
		float rubble_detail = brightness(rubble_texture, flat_uv / 2.0, flat_dx / 2.0, flat_dy / 2.0);
		float gravel = smoothstep(0.42, 0.58, patches + (fine - 0.5) * 0.3) * near;
		if (gravel > 0.0) {
			rubble_detail = mix(rubble_detail, brightness(rubble_texture_2, TURN * flat_uv / 1.8, TURN * flat_dx / 1.8, TURN * flat_dy / 1.8), gravel);
		}
		vec3 rubble = rubble_color * rubble_detail * brightness(rubble_texture, TURN * flat_uv / 13.0, TURN * flat_dx / 13.0, TURN * flat_dy / 13.0);
		ground = mix(ground, rubble, mask);
	}

	// Snow gathers on flatter ground above the snow line.
	if (snow > 0.0) {
		float snow_detail = brightness(snow_texture, slope_uv / 6.0, slope_dx / 6.0, slope_dy / 6.0);
		float crust = smoothstep(0.42, 0.58, patches + (fine - 0.5) * 0.3) * near;
		if (crust > 0.0) {
			// This photo has dark gaps in the snow, so only part of it shows.
			snow_detail = mix(snow_detail, brightness(snow_texture_2, TURN * slope_uv / 4.3, TURN * slope_dx / 4.3, TURN * slope_dy / 4.3), crust * 0.5);
		}
		ground = mix(ground, snow_color * snow_detail, snow);
	}

	ALBEDO = ground * (0.75 + fine * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
