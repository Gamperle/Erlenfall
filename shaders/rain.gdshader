shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Rain streaks that stay off roofs and bridge decks: a drop below the top of whatever covers it (the
// roof map, one texel per metre) collapses to nothing. One texture read per corner, no extra draws.

uniform vec4 streak_color : source_color = vec4(0.75, 0.82, 0.95, 0.28);
uniform sampler2D roof_map : filter_nearest, repeat_disable;
uniform vec2 roof_origin = vec2(0.0);
uniform vec2 roof_size = vec2(1.0);

void vertex() {
	vec3 drop = MODEL_MATRIX[3].xyz;
	vec2 at = (drop.xz - roof_origin) / roof_size;
	if (at.x >= 0.0 && at.y >= 0.0 && at.x < 1.0 && at.y < 1.0 && drop.y < texture(roof_map, at).r) {
		VERTEX = vec3(0.0);
	}
	// A streak that always faces the camera, standing upright, at the size the particle has.
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[0] *= length(MODEL_MATRIX[0].xyz);
	facing[1] *= length(MODEL_MATRIX[1].xyz);
	facing[2] *= length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}

void fragment() {
	ALBEDO = streak_color.rgb;
	ALPHA = streak_color.a;
}
