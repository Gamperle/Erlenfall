shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;

// UV measures meters across the river in x and along it in y.

uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 deep_color : source_color;
uniform vec3 shallow_color : source_color;
uniform float flow_speed = 0.9;
uniform float ripple_strength = 0.5;
uniform float full_depth = 0.7;
uniform float foam_depth = 0.45;
uniform vec3 foam_color : source_color = vec3(0.82, 0.88, 0.9);
// Where someone wades: world x, world z, and how strongly they stir the water (0 is nobody).
// The game fills the first `wader_count` entries; low graphics sets the count to 0.
const int MAX_WADERS = 8;
uniform vec4 waders[MAX_WADERS];
uniform int wader_count = 0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Rings that spread from each wader. Returns the slope of the water in x and y, and the foam on the crests in z.
vec3 wader_rings(vec2 at) {
	vec2 gradient = vec2(0.0);
	float foam = 0.0;
	for (int i = 0; i < wader_count; i++) {
		vec2 away = at - waders[i].xy;
		float distance_to = length(away);
		float reach = 0.6 + 1.4 * waders[i].z;
		float fade = (1.0 - smoothstep(0.0, reach, distance_to)) * waders[i].z;
		float phase = distance_to * 9.0 - TIME * 5.0;
		gradient += normalize(away + vec2(0.0001)) * cos(phase) * fade;
		foam += fade * smoothstep(0.55, 1.0, sin(phase));
	}
	return vec3(gradient, foam);
}

float ripples(vec2 uv) {
	float slow = texture(detail_noise, uv * vec2(0.05, 0.016) + vec2(0.0, -TIME * flow_speed * 0.035)).r;
	float quick = texture(detail_noise, uv * vec2(0.13, 0.05) + vec2(0.31, -TIME * flow_speed * 0.11)).r;
	return slow * 0.6 + quick * 0.4;
}

void fragment() {
	float step_size = 0.25;
	float here = ripples(UV);
	vec2 slope = vec2(ripples(UV + vec2(step_size, 0.0)) - here, ripples(UV + vec2(0.0, step_size)) - here) / step_size;
	NORMAL = normalize(NORMAL - (TANGENT * slope.x + BINORMAL * slope.y) * ripple_strength);

	// How much water lies between this surface and the river bed behind it.
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, texture(depth_texture, SCREEN_UV).r);
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float thickness = clamp((VERTEX.z - behind.z / behind.w) / full_depth, 0.0, 1.0);

	// Ripples around anyone wading, and foam on their crests.
	vec3 stirred = wader_rings(world_position.xz);
	vec3 stirred_view = (VIEW_MATRIX * vec4(stirred.x, 0.0, stirred.y, 0.0)).xyz;
	NORMAL = normalize(NORMAL - stirred_view * 0.35);

	// Foam where the water is shallow, broken up by moving noise so it laps at the shore.
	float depth_meters = thickness * full_depth;
	float lapping = texture(detail_noise, UV * vec2(0.4, 0.4) + vec2(0.0, -TIME * 0.05)).r;
	float edge = 1.0 - smoothstep(0.0, foam_depth * (0.5 + lapping), depth_meters);
	float foam = clamp(edge + stirred.z * 0.6, 0.0, 1.0);

	float streaks = smoothstep(0.62, 0.74, here);
	vec3 water = mix(shallow_color, deep_color, pow(thickness, 0.7)) + vec3(0.1, 0.12, 0.13) * streaks;
	ALBEDO = mix(water, foam_color, foam * 0.9);
	ALPHA = clamp(mix(0.22, 0.9, thickness) + foam * 0.5, 0.0, 1.0);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}
