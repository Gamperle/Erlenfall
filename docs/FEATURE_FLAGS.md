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

## Grass values

| Name | Default | Effect |
|---|---|---|
| `grass_far_distance` | `60` | From this many meters away, a cell of grass uses simpler tufts |
| `grass_far_blade_share` | `0.5` | The share of a tuft's blades that simpler tufts keep. Each is one wider triangle instead of three |
| `grass_draw_scale_low` | `0.6` | How far grass reaches on low graphics, as a share of the full 220 meters |
| `grass_draw_scale_medium` | `0.8` | The same on medium graphics |
| `grass_draw_scale_high` | `1.0` | The same on high graphics |
