shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// A slowly drifting band of mist. It fades out at its top and bottom edges.

uniform sampler2D mist_noise : repeat_enable, filter_linear;
uniform vec3 mist_color : source_color;
uniform float density = 0.6;
uniform float drift = 0.002;

void fragment() {
	float a = texture(mist_noise, vec2(UV.x * 5.0 + TIME * drift, UV.y * 0.7)).r;
	float b = texture(mist_noise, vec2(UV.x * 11.0 - TIME * drift * 0.7, UV.y * 1.4 + 0.3)).r;
	float vertical = smoothstep(0.0, 0.4, UV.y) * smoothstep(1.0, 0.6, UV.y);
	ALBEDO = mist_color;
	ALPHA = clamp(smoothstep(0.32, 0.62, a * 0.65 + b * 0.35) * vertical * density, 0.0, 1.0);
}
