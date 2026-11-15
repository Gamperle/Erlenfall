# Erlenfall

A 3D fantasy RPG prototype about crafting and rebuilding. A landslide cut a mountain village off from the world. You inherit your grandfather's house, and with forge, cauldron and workbench you help turn the village into a small town.

> **This is an experiment, not a serious game project.** Erlenfall exists to find out how far current AI-based workflows can go in game development: writing the code, the design and lore, the 3D props, the textures and the tests. It is not meant to ship, and there's no promise of a finished game, a release date or support. The name "Erlenfall" is a placeholder.

## What the experiment is

One developer directs, and Claude (Anthropic's AI model, through Claude Code) writes most of the code, documents and issue tracking. Image and 3D models run on a local GPU. The aim is to see where this works well and where it still breaks, and to write that down honestly.

| Area | How it's made |
| --- | --- |
| Code | GDScript in Godot 4, written by Claude and reviewed and tested by the maintainer at each milestone |
| Design, lore and dialogue | Drafted by Claude from the maintainer's answers, see [the design document](docs/GAME_DESIGN.md) and [the lore bible](docs/LORE.md) |
| 3D props | Text to picture with FLUX.2 klein 4B, picture to textured mesh with TRELLIS.2, sizing in Blender. See [the asset pipeline](docs/ASSET_PIPELINE.md) |
| Buildings and walls | Built in code, because picture-to-model generation can't produce them, see [Walls and buildings](docs/WALLS_AND_BUILDINGS.md) |
| Characters | A mix of a parametric human base (MakeHuman) and CC0 animation libraries, see [the asset list](docs/ASSET_LIST.md) |
| Textures | CC0 photo surfaces from Poly Haven |
| Tests | A smoke test, a performance check and a memory check, run in CI |
| Tracking | Every problem found and not fixed immediately becomes a GitHub issue |

### What has gone well, and what hasn't

The honest answers are spread across the docs and issues, and these are the recurring ones:

- Props from text work best for solid, standalone objects: barrels, benches, anvils, carts, chests.
- They work badly for thin parts (tongs, saws), loose fibers (hay, sacks, wicker), glass, walls and anything that has to fit exact sizes. See [Known problems](docs/ASSET_PIPELINE.md#known-problems).
- Picking the right picture matters more than anything else in the pipeline, and a person or agent still has to look at every one. The model sometimes draws the wrong object, such as a bell for a bellows.
- Generated assets arrive without rigs, a consistent style or a sense of the game's world, so a lot of work is deciding, sizing, placing and checking.
- AI-generated assets raise open licensing and copyright questions, which are tracked in [#73](https://github.com/Gamperle/Erlenfall/issues/73).

## Status

Early prototype with placeholder and generated art. You can walk a valley with a village and outlying farms in first or third person, with day and night, weather, a forge minigame, dialogue and quests in English and German, a first enemy type, and save and load. The [design document](docs/GAME_DESIGN.md) lists the milestones, and the project may stop at any of them.

## Run it

1. Install [Godot 4.7.2](https://godotengine.org/) and [Git LFS](https://git-lfs.com/). The 3D models and textures are stored in Git LFS and add up to several hundred MB, so a clone is large.
2. Clone the repository, then import and run the project:

```bash
git clone https://github.com/Gamperle/Erlenfall.git
```

```bash
godot --path Erlenfall --import
```

```bash
godot --path Erlenfall
```

Save files are stored in Godot's user data folder. To run the tests: `godot --headless --path . --script res://tests/smoke_test.gd`.

## Documentation

- [Game design and milestones](docs/GAME_DESIGN.md)
- [Lore](docs/LORE.md)
- [Asset pipeline](docs/ASSET_PIPELINE.md) and [its step-by-step guide](tools/asset_pipeline/README.md)
- [Asset list](docs/ASSET_LIST.md) and [assets to create next](docs/ASSETS_TO_CREATE.md)
- [Making mods](docs/MODS.md), with a [working example](docs/example_mods/README.md)
- [Every third-party and AI-generated asset](ASSETS.md), with tools, prompts and seeds

## Contributing

Contributions are welcome, but please keep in mind that this is a hobby experiment. For anything bigger than a small fix, open an issue first. See [CONTRIBUTING.md](CONTRIBUTING.md). Anything you add that you didn't create entirely yourself, including AI-generated content, must be listed in [ASSETS.md](ASSETS.md).

## License

- Code: [MIT](LICENSE)
- Art, music, story and other creative content: [CC BY-SA 4.0](LICENSE-ASSETS), unless [ASSETS.md](ASSETS.md) lists a different license for a file

Generated assets also depend on the licenses of the tools that made them, such as TRELLIS.2 and DINOv3 (which asks for "Built with DINOv3" attribution). The details are in [the pipeline's licensing section](docs/ASSET_PIPELINE.md#licensing).
