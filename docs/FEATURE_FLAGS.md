# Feature flags

Feature flags turn parts of the game on and off without changing code. They are static: `scripts/feature_flags.gd` reads them from files when they are first needed, and they don't change during play.

The defaults are in [`data/feature_flags.json`](../data/feature_flags.json).

## File format

```json
{
	"flags": {
		"torches": true,
		"torch_burn_time_enabled": false,
		"torch_burns_out": { "all": ["torches", "torch_burn_time_enabled"] }
	},
	"values": {
		"torch_burn_seconds": 600
	}
}
```

- **Flags** are either `true`/`false`, or an aggregate.
- **Values** are the numbers or text that go with a feature.

Code reads them with `FeatureFlags.enabled("torch_burns_out")` and `FeatureFlags.value("torch_burn_seconds")`. A recipe can depend on a flag with `"requires_flag"`.

## Aggregates

An aggregate works out its value from other flags. A rule has exactly one operator:

| Rule | True when |
|---|---|
| `{ "all": [a, b] }` | every part is true |
| `{ "any": [a, b] }` | at least one part is true |
| `{ "not": a }` | the part is false |

Each part can be a flag name, another aggregate's name, `true`/`false`, or a nested rule. For example: `{ "all": ["torches", { "not": "hardcore_mode" }] }`.

An unknown flag, a flag that depends on itself, or an invalid rule logs an error and counts as false.

## Mods and load order

**Mods override flags according to their load order.** The base file is applied first, then each mod's file in order, so the last mod to set a name wins.

- Overriding replaces that one flag or value entirely. Everything else stays as it was.
- A mod can replace a plain flag with an aggregate, or the other way around.
- Aggregates are worked out after all the files are applied, so they always use the final values, including those from mods loaded later.

For example, a mod that loads last can give torches a burn time of five minutes with this file:

```json
{
	"flags": { "torch_burn_time_enabled": true },
	"values": { "torch_burn_seconds": 300 }
}
```

`FeatureFlags.load_layers(mod_paths)` takes the mods' files in load order. There is no mod loader yet, so the game currently only uses the base file: see [#52](https://github.com/Gamperle/Erlenfall/issues/52).

## Interface flags

| Name | Default | Effect |
|---|---|---|
| `compass` | `true` | Shows the compass at the top of the screen |
| `realistic_villagers` | `true` | Uses the MakeHuman models for villagers who have one, instead of the simple figures |
| `realistic_enemies` | `true` | Uses rigged models for enemies who have one |
| `realistic_player` | `true` | Uses a rigged model for the player |
| `performance_overlay` | `true` | Shows the performance measurements at the top right |
| `river_fine_collision` | `true` | Makes the ground near the river collide exactly where it is drawn, using the mesh's own triangles. Off leaves the coarser collision for the whole map, which costs less to load and to simulate |
| `terrain_seam_cells` | `true` | Gives each coarse terrain cell beside the river's fine ones a fine grid too, which meets the fine cells on the true ground and bends evenly towards the coarse cells beyond. Off keeps the fine cells' outer edges straight along the coarse cells, which creases the ground there, with about 15,000 fewer triangles and a little less loading time |

## Graphics flags

| Name | Default | Effect |
|---|---|---|
| `surface_relief` | `true` | Gives the photo surfaces of buildings, roads, rocks, and the ground their normal, roughness, and occlusion maps from `assets/textures/*_relief.png`, so they catch the light and stones poke through grass. Off draws them flat, with one texture read fewer per photo, which costs about 5% of the frame rate on a Radeon 680M |
| `screen_ambient_occlusion` | `true` | Darkens corners, eaves, and the ground under things on high graphics. Off never does, which saves about 1.3 ms a frame on a Radeon 680M, most of it for the extra normal buffer that it needs whatever its quality |

## Player flags and values

| Name | Default | Effect |
|---|---|---|
| `lift_buried_player` | `true` | Puts a player who ends up inside the ground, for example from an old save, back on top of it. A ray looks down from above at the ground's own collision, so roofs and bridges never lift anyone |
| `buried_player_depth` | `0.1` | How many meters the ground has to reach above the player's feet before they are lifted |
| `buried_player_ray_height` | `6.0` | How many meters above the land, or the feet if they are higher, the ray starts. It has to start above the collision, which can lie a little higher than the land's exact height |
| `axe_in_hand_seconds` | `1.5` | How long the axe stays in hand after a chop, before the strongest weapon comes back |

## Torch flags

| Name | Default | Effect |
|---|---|---|
| `torches` | `true` | Turns the whole torch feature on or off |
| `torch_crafting_enabled` | `true` | Allows crafting torches |
| `torch_starting_item_enabled` | `true` | Gives the player one torch |
| `torch_burn_time_enabled` | `false` | Makes torches burn out instead of lasting forever |
| `forest` | `true` | The dense forest in the west, whose trees can be felled with an axe |
| `torch_recipe` | aggregate | `torches` and `torch_crafting_enabled` |
| `torch_at_start` | aggregate | `torches` and `torch_starting_item_enabled` |
| `torch_burns_out` | aggregate | `torches` and `torch_burn_time_enabled` |
| `torch_burn_seconds` | `600` | How long one torch burns when burn time is on |
| `interface_min_scale` | `0.9` | The smallest size the interface shrinks to in a small window, as a share of its full size |
| `controls_hint_seconds` | `30` | How long the controls line stays on screen when play starts. It shows again in the pause menu. 0 keeps it on screen |

## Enemy navigation values

Enemies walk straight at their target until something blocks them, then search a small grid for a way around it. They also search when water lies ahead, since a bridge can be quicker, and they plan around other enemies that stand still, such as one attacking in a narrow gap.

| Name | Default | Effect |
|---|---|---|
| `enemy_path_cell_size` | `0.5` | The size in meters of a grid cell. Smaller cells find narrower gaps but search more cells |
| `enemy_path_max_nodes` | `1500` | How many cells one search looks at before it settles for the nearest point it found |
| `enemy_path_budget_steps` | `70` | How much work all searches may do per physics frame. A search step counts 1 and checking a new cell counts 3. On a Radeon 680M laptop, 70 is about 0.6 to 0.9 ms when it's all search steps, and up to about 3 ms when it's mostly new cells (#148). A search that runs out carries on in the next frame |
| `enemy_path_cache_seconds` | `5` | How long enemies remember which cells are blocked before checking them again |
| `enemy_path_water_cost` | `3` | How many times as much a step through deep water counts as one on dry land, so enemies take a bridge unless it's far out of the way. Wading is about 1.8 times as slow, so values below that make enemies wade even where the bridge is quicker |
| `enemy_crowd_wait_seconds` | `3` | How long an enemy that other enemies block, such as in a narrow gap, waits before it looks for a way again. It plans around enemies that stand still, and waits only when there's no other way. It looks again sooner when the way clears or one of them moves |
| `river_fine_margin` | `3.0` | How many meters past the river's banks the terrain mesh, and its collision, stay finer. Below 3 some banks end up in coarse cells, where the ground is less exact |

## Grass values

| Name | Default | Effect |
|---|---|---|
| `grass_far_distance` | `60` | From this many meters away, a cell of grass uses simpler tufts |
| `grass_far_blade_share` | `0.5` | The share of a tuft's blades that simpler tufts keep. Each is one wider triangle instead of three |
| `grass_draw_scale_low` | `0.6` | How far grass reaches on low graphics, as a share of the full 220 meters |
| `grass_draw_scale_medium` | `0.8` | The same on medium graphics |
| `grass_draw_scale_high` | `1.0` | The same on high graphics |

## Village values

| Name | Default | Effect |
|---|---|---|
| `small_prop_draw_distance` | `80` | How many meters away props smaller than 0.6 m, such as bowls and hammers, stop being drawn, along with their shadows. At 80 m they are a few pixels across |
