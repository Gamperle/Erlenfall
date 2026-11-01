shader_type spatial;

// Vertex color holds the ground color in sRGB, and alpha holds the landslide mask.
// Sampling noise per pixel hides the coarse terrain grid and breaks up the landslide edge.

uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap;
uniform vec3 rubble_color : source_color;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float broad = texture(detail_noise, world_position.xz * 0.03).r;
	float fine = texture(detail_noise, world_position.xz * 0.21).r;
	float mask = smoothstep(0.42, 0.58, COLOR.a + (broad - 0.5) * 0.5);
	vec3 ground = mix(pow(COLOR.rgb, vec3(2.2)), rubble_color, mask);
	ALBEDO = ground * (0.75 + fine * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
