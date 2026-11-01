shader_type spatial;

// Vertex color holds the grass color in sRGB, and alpha holds the landslide mask.
// Everything else is decided per pixel, which hides the coarse terrain grid.

uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D snow_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rubble_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 rubble_color : source_color;
uniform vec3 rock_color : source_color;
uniform vec3 snow_color : source_color;
uniform float snow_height = 165.0;

varying vec3 world_position;
varying vec3 world_normal;

// The photo's detail around 1, so the colors set here stay the overall colors.
vec3 detail(sampler2D photo, vec2 uv) {
	return texture(photo, uv).rgb / max(textureLod(photo, vec2(0.5), 12.0).rgb, vec3(0.02));
}

// The same detail as brightness only, for surfaces whose photos would tint the color.
float brightness(sampler2D photo, vec2 uv) {
	return dot(detail(photo, uv), vec3(0.3, 0.6, 0.1));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float broad = texture(detail_noise, world_position.xz * 0.03).r;
	float fine = texture(detail_noise, world_position.xz * 0.21).r;
	float strata = texture(detail_noise, vec2(world_position.x * 0.01, world_position.y * 0.12)).r;

	vec2 flat_uv = world_position.xz;
	// Shifting by height stops the rock from stretching down steep slopes.
	vec2 slope_uv = flat_uv + world_position.y;

	vec3 ground = pow(COLOR.rgb, vec3(2.2));
	ground *= mix(vec3(1.0), mix(detail(grass_texture, flat_uv / 2.0), detail(grass_texture, flat_uv / 11.0), 0.5), 0.7);

	// Rock shows on steep ground and takes over high up.
	float steep = smoothstep(0.86, 0.72, world_normal.y + (broad - 0.5) * 0.12);
	float high = smoothstep(85.0, 125.0, world_position.y + (broad - 0.5) * 50.0);
	vec3 rock = rock_color * (0.55 + strata * 0.9) * brightness(rock_texture, slope_uv / 2.4) * brightness(rock_texture, slope_uv / 37.0);
	ground = mix(ground, rock, max(steep, high));

	float mask = smoothstep(0.42, 0.58, COLOR.a + (broad - 0.5) * 0.5);
	ground = mix(ground, rubble_color * brightness(rubble_texture, flat_uv / 2.0) * brightness(rubble_texture, flat_uv / 13.0), mask);

	// Snow gathers on flatter ground above the snow line.
	float snow_line = smoothstep(snow_height - 12.0, snow_height + 12.0, world_position.y + (broad - 0.5) * 60.0);
	float snow = snow_line * smoothstep(0.45, 0.7, world_normal.y + (fine - 0.5) * 0.2);
	ground = mix(ground, snow_color * brightness(snow_texture, slope_uv / 6.0), snow);

	ALBEDO = ground * (0.75 + fine * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
