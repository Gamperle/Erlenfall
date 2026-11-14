shader_type spatial;
// Stars, a moon disc, and drifting clouds drawn over the plain sky gradient on a big dome around the camera.
// Pure maths, no textures, so it runs the same in the Compatibility renderer.
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, blend_mix;

uniform float star_visibility : hint_range(0.0, 1.0) = 0.0;
uniform mat3 star_rotation = mat3(1.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
uniform float moon_visibility : hint_range(0.0, 1.0) = 0.0;
uniform float moon_size : hint_range(0.001, 0.2) = 0.035;
uniform vec3 cloud_light_color : source_color = vec3(1.0);
uniform vec3 cloud_shade_color : source_color = vec3(0.6);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
// How overcast the sky is: clouds go grey and hide the stars and the moon.
uniform float cloud_gloom : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cloud_offset = vec2(0.0);
uniform int cloud_octaves : hint_range(1, 5) = 4;

varying vec3 world_direction;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// The earlier dot-product hash gave whole rows of lattice cells a shared bias, so the higher cloud octaves drew a
// hard straight diagonal edge across the sky (#283). Keep this one free of that.
float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cloud_density(vec2 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	float total = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= cloud_octaves) {
			break;
		}
		sum += value_noise(p) * amplitude;
		total += amplitude;
		p = p * 2.03 + vec2(17.0, 9.0);
		amplitude *= 0.5;
	}
	return sum / total;
}

float star_layer(vec3 dir, float cells, float chance) {
	vec3 scaled = dir * cells;
	vec3 cell = floor(scaled);
	float rnd = hash13(cell);
	if (rnd < chance) {
		return 0.0;
	}
	// One star per cell at a random spot; its glow shrinks with distance from that spot.
	vec3 centre = cell + 0.25 + 0.5 * vec3(hash13(cell + 7.1), hash13(cell + 13.7), hash13(cell + 29.3));
	float d = length(scaled - centre);
	float brightness = 0.4 + 0.6 * fract(rnd * 91.7);
	return (1.0 - smoothstep(0.0, 0.16, d)) * brightness;
}

void vertex() {
	world_direction = VERTEX;
}

void fragment() {
	vec3 dir = normalize(world_direction);
	float above = smoothstep(-0.02, 0.12, dir.y);
	vec4 colour = vec4(0.0);

	if (star_visibility > 0.001 && dir.y > 0.0) {
		vec3 sd = star_rotation * dir;
		float stars = star_layer(sd, 90.0, 0.93) + star_layer(sd, 45.0, 0.9) * 1.3;
		colour = vec4(vec3(0.85, 0.9, 1.0), clamp(stars, 0.0, 1.0) * star_visibility * above);
	}

	if (moon_visibility > 0.001) {
		float angle = acos(clamp(dot(dir, normalize(moon_direction)), -1.0, 1.0));
		float disc = 1.0 - smoothstep(moon_size * 0.9, moon_size, angle);
		float halo = (1.0 - smoothstep(moon_size, moon_size * 3.0, angle)) * 0.07;
		float a = clamp(disc + halo, 0.0, 1.0) * moon_visibility;
		vec3 moon_colour = mix(vec3(0.6, 0.7, 0.95), vec3(0.95, 0.96, 1.0), disc);
		// Dark patches so the disc isn't flat.
		moon_colour *= 1.0 - 0.18 * disc * smoothstep(0.45, 0.65, value_noise(dir.xz * 90.0 + dir.y * 40.0));
		colour.rgb = mix(colour.rgb, moon_colour, a);
		colour.a = max(colour.a, a);
	}

	colour.a *= 1.0 - cloud_gloom * 0.9;

	if (dir.y > 0.0) {
		// Project the direction onto a flat cloud layer so clouds shrink toward the horizon.
		vec2 plane = dir.xz / (dir.y + 0.12);
		float density = cloud_density(plane * 0.9 + cloud_offset);
		float mass = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.25, density);
		// Thin edges catch the light and thick cores sit in shade. One density sample does it; the old shifted second
		// sample doubled the cloud cost and sharpened that streak (#283, #284).
		float thickness = clamp((density - (1.0 - cloud_coverage)) * 2.5, 0.0, 1.0);
		vec3 cloud_colour = mix(cloud_light_color, cloud_shade_color, thickness * 0.8);
		cloud_colour = mix(cloud_colour, cloud_shade_color * 1.1, cloud_gloom * 0.7);
		float cloud_alpha = mass * smoothstep(0.0, 0.2, dir.y) * mix(0.9, 1.0, cloud_gloom);
		float out_alpha = cloud_alpha + colour.a * (1.0 - cloud_alpha);
		colour.rgb = mix(colour.rgb, cloud_colour, cloud_alpha / max(out_alpha, 0.0001));
		colour.a = out_alpha;
	}

	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
