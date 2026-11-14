# Contributing

Contributions are welcome. For anything larger than a small fix, please open an issue first, and check [the design document](docs/GAME_DESIGN.md) for the current milestone.

## Workflow

1. Create a branch from `main`.
2. Make your change, run the game to confirm it works, and run the smoke test: `godot --headless --path . --script res://tests/smoke_test.gd`.
3. Open a pull request that describes what changed and how you tested it.

## Performance check

`godot --headless --path . --script res://tests/perf_check.gd` flies a fixed camera path through the village and compares the result with the budgets in `tests/perf_budgets.json`. CI runs it after the smoke test, and it takes about a minute.

Headless Godot has no real renderer, so draw calls, primitives, and frame time read zero there. The headless run instead counts what produces them, and these counts are exact and repeat from run to run: nodes, mesh instances, mesh surfaces (each is a draw call, and another for its shadow), MultiMesh nodes and instances, triangles, and the grass tufts within drawing distance of each camera point, both as grown (`grass_tufts`) and as drawn after the per-distance detail bands thin them out (`grass_tufts_drawn`). (The grass itself grows on worker threads and varies, so its tufts are counted from the same seeded growth and bands the game uses.) Each is gated against its budget.

The `path_search` entry measures enemy path search cost with a few fixed searches (listed in `SEARCHES` in `tests/perf_check.gd`, plus one over the first bridge). Each starts with the search grids forgotten and records `_steps` (cells expanded), `_cells` (cells checked against the physics world), and `_frames` (physics frames the step budget spreads it over), plus `search_steps_total`. Searches are counted in steps, not time, so they repeat exactly on any machine; a search that does not reach its goal fails the check. Change those routes only together with the budgets.

With a display, the check also renders the path and reports real draw calls, primitives, and the average and 99th-percentile frame time: `DISPLAY=:0 godot --path . --script res://tests/perf_check.gd`. Draw calls and primitives are gated against the `rendered` budgets. Frame time depends on the machine, so it is only printed, unless you add `--gate-frame-time`. Rendered runs vary a little, so their budgets have more headroom, and the CI does not run them. (Gating them in CI needs a runner with a GPU, or a software GL display such as xvfb with llvmpipe. See #291.)

After an intended change to the scene or the searches, write new budgets with `godot --headless --path . --script res://tests/perf_check.gd -- --update-budgets` (add a display to update the `rendered` ones) and commit `tests/perf_budgets.json`.

The results are printed as JSON. Add `--out=PATH` after `--` to also save them to a file, and compare two files with `diff` to see what a change did.

If a change fails the check on purpose (more buildings, a denser forest), look first for a cheaper way, such as joining meshes or using a MultiMesh. If the cost is worth it, update the budgets with `-- --update-budgets`. This adds headroom to the measured values (10% headless, 25% rendered), and only updates the mode you ran, so run it once headless and once with a display, and say in the pull request why the budgets grew.

## Memory check

`godot --headless --path . --script res://tests/memory_check.gd` loads the main scene, runs it for 15 simulated seconds and frees it, six times in a row. Then it plays 40 simulated seconds to let the village finish streaming in and a further 2 minutes while measuring. Throughout it prints static memory, object count, node count and orphan node count (the `Performance` monitors). It takes about 4 minutes, so CI does not run it. Run it before a change that creates scenes, resources or threads at runtime, and after anything that touches loading or freeing the world. `--loads=N` and `--minutes=N` after `--` change the number of loads and the length of the play session.

The first load is a warm-up. The check fails when a later load ends with more objects, orphan nodes or static memory than the one before it, or when the play session grows past its budget. A real leak grows with every load, so it trips the check. The budgets are constants at the top of `tests/memory_check.gd`: orphan nodes may not grow at all, objects may grow by 50 per load (500 over the play session) to allow for cache noise, and static memory by 4 MB per load (16 MB over the play session) because the allocator moves. They sit well above the measured growth, which is zero. If a change grows them on purpose, say why in the pull request.

## After pulling

Godot only registers new `class_name` scripts in `.godot/global_script_class_cache.cfg` when the editor or an import runs. If the game fails after a pull with `Identifier "..." not declared in the current scope`, rebuild the cache once:

```
godot --headless --path . --import
```

## Guidelines

- Use Godot 4.7.2 and GDScript. C++ needs a profiling result that justifies it.
- Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
- Keep items, recipes, and quests in data files, not in code.
- Put optional or tunable features behind [feature flags](docs/FEATURE_FLAGS.md). Mods can override flags, and the mod load order decides which one wins.
- Add all player-facing text to `localization/strings.csv`, in English and German.
- Play sounds on one of the audio buses in `scripts/audio_buses.gd`: `Music`, `Effects`, or `Ambience`, all feeding into `Master`. The buses are created at start-up, and the settings screen sets their volumes. Pick one with `AudioBuses.route(player, AudioBuses.EFFECTS)`.
- Large binary files go through Git LFS. See `.gitattributes`.

## Issue labels

Give every issue at least one area label. Add more when it fits, for example `graphics` and `world` for terrain creasing.

| Label | Covers |
|---|---|
| `gameplay` | Systems, combat, crafting, enemy behavior |
| `graphics` | Rendering, shaders, lighting, how the world looks |
| `performance` | Frame rate, draw calls, load times, search cost |
| `world` | Terrain, river, roads, buildings, village layout |
| `ui` | HUD, menus, compass |
| `art` | Models, textures, characters, other content art |
| `asset-pipeline` | Generating and importing models, textures, characters |
| `story` | Writing and characters |
| `audio` | Music and sound |
| `modding` | Mod loader and mod support |
| `legal` | Licenses and copyright |
| `platform` | Windows, Web, controllers, hardware |
| `tech` | Build, tooling, tests, engine |
| `accessibility` | Barriers for people with disabilities |

`needs testing`, `bug`, and the other labels say what kind of work or what state, and go on top of an area label.

## Licensing

By contributing, you agree that your code is licensed under [MIT](LICENSE) and your creative content under [CC BY-SA 4.0](LICENSE-ASSETS), unless the file is listed otherwise in [ASSETS.md](ASSETS.md).

Add every asset you did not create entirely yourself to [ASSETS.md](ASSETS.md), including AI-generated ones.

Scripts that run inside Blender and import `bpy` (`tools/asset_pipeline/render_preview.py`, `adjust_glb.py`, `cleanup_mesh.py`, `size_glb.py`, and `tools/character_pipeline/build_character.py`, `build_goblin.py`) stay under MIT, like the rest of the code. [Blender says](https://www.blender.org/about/license/) that published scripts using its Python API must be shared under a GPL-compliant license. MIT is widely regarded as GPL-compatible, so MIT is kept, but the maintainer hasn't confirmed this, and it isn't legal advice ([#67](https://github.com/Gamperle/Erlenfall/issues/67)). For a new Blender script, write it yourself, don't copy code from add-ons or forum posts without checking their license, and if you do copy code, note its source and license in the file's header.
