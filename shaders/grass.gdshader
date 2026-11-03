shader_type spatial;
render_mode cull_disabled;

// Each tuft sinks into the ground with distance, so grass fades out without a hard edge.
// Most tufts go sooner, which keeps it thick up close without the cost further away.
// Vertex color holds the grass color in sRGB, and its alpha holds the tuft's luck.
// GrassField.tuft_share() works out the same fade, to skip tufts that have sunk.

uniform float fade_start = 120.0;
uniform float fade_end = 220.0;
uniform float early_fade = 0.35;

void vertex() {
	vec3 tuft = MODEL_MATRIX[3].xyz;
	float reach = mix(early_fade, 1.0, COLOR.a * COLOR.a);
	float distance_to_camera = length(tuft - CAMERA_POSITION_WORLD);
	VERTEX *= 1.0 - smoothstep(fade_start * reach, fade_end * reach, distance_to_camera);
}

void fragment() {
	// Lit like the ground it stands on, from both sides of the blade.
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
