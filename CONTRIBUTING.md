# Contributing

Contributions are welcome. For anything larger than a small fix, please open an issue first, and check [the design document](docs/GAME_DESIGN.md) for the current milestone.

## Workflow

1. Create a branch from `main`.
2. Make your change, run the game to confirm it works, and run the smoke test: `godot --headless --path . --script res://tests/smoke_test.gd`.
3. Open a pull request that describes what changed and how you tested it.

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

## Licensing

By contributing, you agree that your code is licensed under [MIT](LICENSE) and your creative content under [CC BY-SA 4.0](LICENSE-ASSETS), unless the file is listed otherwise in [ASSETS.md](ASSETS.md).

Add every asset you did not create entirely yourself to [ASSETS.md](ASSETS.md), including AI-generated ones.

Scripts that run inside Blender and import `bpy` (`tools/asset_pipeline/render_preview.py`, `adjust_glb.py`, `cleanup_mesh.py`, `size_glb.py`, and `tools/character_pipeline/build_character.py`, `build_goblin.py`) stay under MIT, like the rest of the code. [Blender says](https://www.blender.org/about/license/) that published scripts using its Python API must be shared under a GPL-compliant license. MIT is widely regarded as GPL-compatible, so MIT is kept, but the maintainer hasn't confirmed this, and it isn't legal advice ([#67](https://github.com/Gamperle/Erlenfall/issues/67)). For a new Blender script, write it yourself, don't copy code from add-ons or forum posts without checking their license, and if you do copy code, note its source and license in the file's header.
