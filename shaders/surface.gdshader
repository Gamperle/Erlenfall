shader_type spatial;

// Procedural surfaces, mapped in world space so they don't need UV coordinates.

const int PLASTER = 0;
const int WOOD = 1;
const int SHINGLES = 2;
const int STONE = 3;
const int CROPS = 4;

uniform sampler2D detail_noise : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 base_color : source_color;
uniform int pattern = 0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Dark lines between staggered rows of tiles or blocks.
float tile_edges(vec2 uv, vec2 size, float width) {
	float row = floor(uv.y / size.y);
	vec2 cell = fract(vec2(uv.x / size.x + mod(row, 2.0) * 0.5, uv.y / size.y));
	float edge_x = min(cell.x, 1.0 - cell.x) * size.x;
	float edge_y = min(cell.y, 1.0 - cell.y) * size.y;
	return smoothstep(0.0, width, min(edge_x, edge_y));
}

void fragment() {
	vec3 facing = abs(world_normal);
	vec2 uv = facing.x > facing.z ? world_position.zy : world_position.xy;
	if (facing.y > 0.85) {
		uv = world_position.xz;
	}

	float noise = texture(detail_noise, uv * 0.13).r;
	float fine = texture(detail_noise, uv * 0.61).r;
	float shade = 0.8 + noise * 0.25 + fine * 0.15;

	if (pattern == WOOD) {
		float grain = texture(detail_noise, vec2(uv.x * 0.08, uv.y * 1.3)).r;
		shade = 0.65 + grain * 0.7;
	} else if (pattern == SHINGLES) {
		vec2 roof_uv = vec2(facing.x > facing.z ? world_position.z : world_position.x, world_position.y);
		shade *= 0.55 + 0.45 * tile_edges(roof_uv, vec2(0.45, 0.28), 0.035);
	} else if (pattern == STONE) {
		shade *= 0.5 + 0.5 * tile_edges(uv, vec2(0.7, 0.35), 0.05);
	} else if (pattern == CROPS) {
		float rows = smoothstep(0.25, 0.55, abs(fract(world_position.x * 0.8) - 0.5) * 2.0);
		shade *= 0.55 + 0.45 * rows + fine * 0.2;
	}

	ALBEDO = base_color * shade;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
