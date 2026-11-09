shader_type spatial;

// Photo surfaces, mapped in world space so they don't need UV coordinates.

const int PLASTER = 0;
const int CROPS = 4;

uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_texture_2 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_texture_3 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
// Each photo's relief map, built by tools/texture_pipeline: normal x and y, roughness, and occlusion.
uniform sampler2D surface_relief : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_relief_2 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_relief_3 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tile_metres = 2.0;
uniform float tile_metres_2 = 2.0;
// No width means this surface has no third photo.
uniform float tile_metres_3 = 0.0;
uniform float area_softness = 0.05;
uniform float area_frequency = 0.037;
uniform float photo_strength = 1.0;
uniform vec3 base_color : source_color;
uniform int pattern = 0;
// How much the relief's occlusion also darkens sunlight, not only the light from the sky.
uniform float relief_light_affect = 0.6;
// How strongly the relief bends the light, where 1 is as the maps were made.
uniform float relief_strength = 1.6;

varying vec3 world_position;
varying vec3 world_normal;
varying float edge_fade;

// Dividing by the photo's average keeps base_color as the overall color. Gradients are passed
// because these reads sit in branches, where a GPU can't work them out itself.
vec3 photo_detail(sampler2D photo, vec2 uv, vec2 dx, vec2 dy) {
	return textureGrad(photo, uv, dx, dy).rgb / max(textureLod(photo, vec2(0.5), 12.0).rgb, vec3(0.02));
}

// Bends the surface's normal by a relief map's x and y. The photo's u and v run along the
// given world directions, and an OpenGL normal map's y points to the top of the photo.
vec3 bent_normal(vec3 normal, vec2 tilt, vec3 along_u, vec3 along_v) {
	vec3 tangent = normalize(along_u - normal * dot(normal, along_u));
	vec3 bitangent = normalize(along_v - normal * dot(normal, along_v));
	return normalize(normal * sqrt(max(1.0 - dot(tilt, tilt), 0.0)) + tangent * tilt.x - bitangent * tilt.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	edge_fade = COLOR.a;
}

// One projection's photo detail and relief, with the areas of other photos that keep large
// walls and roads from repeating.
void sample_photos(vec2 uv, vec2 dx, vec2 dy, out vec3 photo, out vec4 relief) {
	float fine = textureGrad(detail_noise, uv * 0.61, dx * 0.61, dy * 0.61).r;
	photo = photo_detail(surface_texture, uv / tile_metres, dx / tile_metres, dy / tile_metres);
	relief = textureGrad(surface_relief, uv / tile_metres, dx / tile_metres, dy / tile_metres);
	float area = textureGrad(detail_noise, uv * area_frequency, dx * area_frequency, dy * area_frequency).r + (fine - 0.5) * 0.15;
	float other = smoothstep(0.5 - area_softness, 0.5 + area_softness, area);
	if (other > 0.0) {
		photo = mix(photo, photo_detail(surface_texture_2, uv / tile_metres_2, dx / tile_metres_2, dy / tile_metres_2), other);
		relief = mix(relief, textureGrad(surface_relief_2, uv / tile_metres_2, dx / tile_metres_2, dy / tile_metres_2), other);
	}
	if (tile_metres_3 > 0.0) {
		vec2 third_uv = uv.yx * area_frequency * 1.7 + vec2(0.37, 0.61);
		float third_area = textureGrad(detail_noise, third_uv, dx.yx * area_frequency * 1.7, dy.yx * area_frequency * 1.7).r + (fine - 0.5) * 0.15;
		float third = smoothstep(0.55 - area_softness, 0.55 + area_softness, third_area);
		if (third > 0.0) {
			photo = mix(photo, photo_detail(surface_texture_3, uv / tile_metres_3, dx / tile_metres_3, dy / tile_metres_3), third);
			relief = mix(relief, textureGrad(surface_relief_3, uv / tile_metres_3, dx / tile_metres_3, dy / tile_metres_3), third);
		}
	}
}

void fragment() {
	vec3 normal = normalize(world_normal);
	// The photos are mapped from three sides and blended by the normal, so no face stretches
	// a photo into streaks. Sides that face away hardly show and are skipped.
	vec3 sides = pow(abs(normal), vec3(4.0));
	sides = max(sides / (sides.x + sides.y + sides.z) - 0.05, 0.0);
	sides /= sides.x + sides.y + sides.z;
	vec2 side_uv[3] = vec2[3](world_position.zy, world_position.xz, world_position.xy);
	vec3 side_u[3] = vec3[3](vec3(0.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0));
	vec3 side_v[3] = vec3[3](vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0));
	vec2 side_dx[3] = vec2[3](dFdx(side_uv[0]), dFdx(side_uv[1]), dFdx(side_uv[2]));
	vec2 side_dy[3] = vec2[3](dFdy(side_uv[0]), dFdy(side_uv[1]), dFdy(side_uv[2]));
	// The side that faces most squarely sets the noise and the crop rows.
	int main_side = sides.y >= sides.x && sides.y >= sides.z ? 1 : (sides.x > sides.z ? 0 : 2);
	vec2 uv = side_uv[main_side];
	ROUGHNESS = 0.95;

	float noise = texture(detail_noise, uv * 0.13).r;
	float fine = texture(detail_noise, uv * 0.61).r;

	if (pattern == CROPS) {
		float rows = smoothstep(0.25, 0.55, abs(fract(world_position.x * 0.8) - 0.5) * 2.0);
		// Rows narrower than a pixel or two would blur into wavy bands, so fade to their average.
		rows = mix(rows, 0.6, smoothstep(0.1, 0.45, fwidth(world_position.x * 0.8)));
		ALBEDO = base_color * (0.8 + noise * 0.25 + fine * 0.15) * (0.55 + 0.45 * rows + fine * 0.2);
	} else {
		vec3 photo = vec3(0.0);
		vec4 relief = vec4(0.0);
		vec3 bend_sum = vec3(0.0);
		for (int i = 0; i < 3; i++) {
			if (sides[i] <= 0.0) {
				continue;
			}
			vec3 side_photo;
			vec4 side_relief;
			sample_photos(side_uv[i], side_dx[i], side_dy[i], side_photo, side_relief);
			photo += sides[i] * side_photo;
			relief.zw += sides[i] * side_relief.zw;
			// The relief shows as strongly as the photo does.
			bend_sum += sides[i] * bent_normal(normal, (side_relief.rg * 2.0 - 1.0) * relief_strength * photo_strength, side_u[i], side_v[i]);
		}
		// The photo adds detail, and dividing by its average keeps base_color as the overall color.
		ALBEDO = base_color * mix(vec3(1.0), photo, photo_strength) * (0.85 + noise * 0.3);
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(bend_sum), 0.0)).xyz);
		ROUGHNESS = mix(0.95, relief.z, photo_strength);
		AO = mix(1.0, relief.w, photo_strength);
		AO_LIGHT_AFFECT = relief_light_affect;
	}
	SPECULAR = 0.2;

	// Roads fade out towards their edges (by vertex alpha). Noise breaks that fade into ragged
	// patches of dirt, so the edge is never a straight line.
	if (edge_fade < 0.999) {
		ALPHA = edge_fade + (fine * 0.6 + noise * 0.4 - 0.5) * 1.5;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
}
