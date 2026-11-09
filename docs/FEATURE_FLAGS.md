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

`FeatureFlags.load_layers(mod_paths)` takes the mods' files in load order. The game calls it with the mods listed in `user://mods/load_order.json`: see [MODS.md](MODS.md).

## Interface flags

| Name | Default | Effect |
|---|---|---|
| `compass` | `true` | Shows the compass at the top of the screen |
| `villager_routines` | `true` | Villagers follow their daily routines from [`data/villager_routines.json`](../data/villager_routines.json), walking to a place at the hours it names. Off keeps everyone where the layout puts them |
| `realistic_villagers` | `true` | Uses the MakeHuman models for villagers who have one, instead of the simple figures |
| `realistic_enemies` | `true` | Uses rigged models for enemies who have one |
| `realistic_player` | `true` | Uses a rigged model for the player |
| `crafting_parts` | `true` | Lets the player choose the parts (grip, blade) of a weapon when crafting it. Off makes every weapon with its plain parts. Weapons already made keep their parts |
| `performance_overlay` | `true` | Shows the performance measurements at the top right |
| `river_fine_collision` | `true` | Makes the ground near the river collide exactly where it is drawn, using the mesh's own triangles. Off leaves the coarser collision for the whole map, which costs less to load and to simulate |
| `terrain_seam_cells` | `true` | Gives each coarse terrain cell beside the river's fine ones a fine grid too, which meets the fine cells on the true ground and bends evenly towards the coarse cells beyond. Off keeps the fine cells' outer edges straight along the coarse cells, which creases the ground there, with about 15,000 fewer triangles and a little less loading time |
| `rough_ground_fine_cells` | `true` | Makes the terrain cells fine where the landslide's rubble bends faster than a 4 m cell can follow, so the ground there no longer creases along the grid. Off keeps them coarse, with fewer triangles and a little less loading time |

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

## Sneaking

Holding the sneak key (Ctrl, or pressing the left stick) slows the player and makes enemies notice them from less far away. It does not stop an enemy that is already chasing, and it can't be used while rolling or blocking. Talking as a way out of fights is not built yet: see [#206](https://github.com/Gamperle/Erlenfall/issues/206).

| Name | Default | Effect |
|---|---|---|
| `sneaking` | `true` | Turns the sneak stance on or off. Off ignores the sneak key |
| `sneak_speed_factor` | `0.5` | The share of walking speed that a sneaking player moves at. Sneaking replaces sprinting. A default pick, for the maintainer to balance |
| `sneak_notice_factor` | `0.35` | The share of an enemy's `aggro_range` at which it notices a sneaking player: 14 m becomes 4.9 m for a goblin. A default pick, for the maintainer to balance |

## Ranged flags and values

Bows and thrown flasks are the first slice of [#29](https://github.com/Gamperle/Erlenfall/issues/29). Projectile types are in [`data/projectiles.json`](../data/projectiles.json): damage, speed, gravity, lifetime, hit radius, splash radius, cooldown, the item the player must carry (`requires_item`), the item that is used up (`ammo_item`), and which button fires it (`shoot` is R, `throw` is G). The damage, speed, and cooldown numbers are placeholders until the maintainer balances them. The bow, arrows, and flasks have no crafting recipes yet, so the player starts with some.

| Name | Default | Effect |
|---|---|---|
| `ranged_weapons` | `true` | Allows firing and throwing projectiles |
| `ranged_starting_items` | `true` | Gives the player a short bow, arrows, and fire flasks once per game, because they can't be crafted yet |
| `ranged_starting_arrows` | `10` | How many arrows the player starts with |
| `ranged_starting_flasks` | `3` | How many fire flasks the player starts with |

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

## Crafting skill flags and values

Skill grows by practice: each recipe has a `skill` and an `xp` amount in `data/crafting.json`, and the skill's `level_xp` list says how much practice each level needs. The numbers are placeholders for the maintainer to tune (#14).

| Name | Default | Effect |
|---|---|---|
| `crafting_skill` | `true` | Turns skill progression on or off. Off gives no practice, no bonuses, and hides the skills line |
| `skill_target_width_per_level` | `0.015` | How much wider the forging target gets for each level above 1, as a share of the bar (the plain width is 0.14) |
| `skill_speed_reduction_per_level` | `0.03` | How much slower the forging marker moves for each level above 1, as a share of its speed |

## Enemy navigation values

Enemies walk straight at their target until something blocks them, then search a small grid for a way around it. They also search when water lies ahead, since a bridge can be quicker, and they plan around other enemies that stand still, such as one attacking in a narrow gap.

| Name | Default | Effect |
|---|---|---|
| `enemy_path_cell_size` | `0.35` | The size in meters of a grid cell. A gap is certain to be found when it's at least a body's width plus one cell wide, which is 1 m for a goblin at 0.35. Narrower gaps are found only when they line up with the grid. Smaller cells find narrower gaps but search more cells, so scale `enemy_path_max_nodes` by the square of the change |
| `enemy_path_max_nodes` | `3000` | How many cells one search looks at before it settles for the nearest point it found |
| `enemy_path_budget_steps` | `100` | How much work all searches may do per physics frame. A search step counts 1 and checking a new cell counts 10. On a Radeon 680M laptop, 100 is about 1 ms whether it goes to search steps or to new cells (#148); line checks still check new cells outside the budget. A search that runs out carries on in the next frame |
| `enemy_path_cache_seconds` | `5` | How long enemies remember which cells are blocked before checking them again |
| `enemy_path_water_cost` | `3` | How many times as much a step through deep water counts as one on dry land, so enemies take a bridge unless it's far out of the way. Wading is about 1.8 times as slow, so values below that make enemies wade even where the bridge is quicker |
| `enemy_crowd_wait_seconds` | `3` | How long an enemy that other enemies block, such as in a narrow gap, waits before it looks for a way again. It plans around enemies that stand still, and waits only when there's no other way. It looks again sooner when the way clears or one of them moves |
| `river_fine_margin` | `3.0` | How many meters past the river's banks the terrain mesh, and its collision, stay finer. Below 3 some banks end up in coarse cells, where the ground is less exact |
| `rough_ground_deviation` | `0.25` | How far in meters the ground at a cell's center may lie from the average of its four corners before the cell turns fine. Lower values make more cells fine |

## Grass values

| Name | Default | Effect |
|---|---|---|
| `grass_far_distance` | `60` | From this many meters away, a cell of grass draws one simpler tuft for all its species, in a single draw call |
| `grass_far_blade_share` | `0.5` | The share of blades that the simpler tuft has (of 8). Each is one wider triangle instead of three |
| `grass_draw_scale_low` | `0.6` | How far grass reaches on low graphics, as a share of the full 220 meters |
| `grass_draw_scale_medium` | `0.8` | The same on medium graphics |
| `grass_draw_scale_high` | `1.0` | The same on high graphics |

## Village values

| Name | Default | Effect |
|---|---|---|
| `small_prop_draw_distance` | `80` | How many meters away props smaller than 0.6 m, such as bowls and hammers, stop being drawn, along with their shadows. At 80 m they are a few pixels across |
| `villager_walk_speed` | `1.2` | How fast villagers walk to their next place, in meters per second |
| `villager_routine_tick_seconds` | `0.5` | How often the clock is checked for a villager's next stop. Villagers only do work while they are walking |

### Villager routines

A routine is a list of stops in `data/villager_routines.json`, by villager id. A stop starts at an hour (`from`, 0 to 24, increasing) and lasts until the next one, wrapping past midnight. It gives a place (`x`, `z`) and which way to face there (`facing`, degrees). A stop with no place means home, where `data/village_layout.json` puts the villager. Villagers walk in a straight line, stop while a conversation is open, and are put straight at their place if the time jumps by more than two hours, such as when sleeping.
