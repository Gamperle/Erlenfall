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

	float streaks = smoothstep(0.62, 0.74, here);
	ALBEDO = mix(shallow_color, deep_color, thickness) + vec3(0.1, 0.12, 0.13) * streaks;
	ALPHA = mix(0.3, 0.88, thickness);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}
