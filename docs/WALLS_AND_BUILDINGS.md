# Walls and buildings

Research for [#61](https://github.com/Gamperle/Erlenfall/issues/61): how to make walls and buildings, since the [picture-to-model pipeline](ASSET_PIPELINE.md) can't. TripoSR and TRELLIS.2 see one picture, and SDXL draws a wall as a pattern that fills the frame. A stone wall works only when the picture has a clear outline, and every timber wall picture failed.

## What the game does now

Houses are already built in code, in `scripts/world/model_builder.gd`: plastered boxes, a stone base, timber beams, a door, windows, a roof, and a chimney. They use the world-mapped CC0 photo surfaces from [#45](https://github.com/Gamperle/Erlenfall/issues/45), and `ModelBuilder.merged` joins each building into one mesh with one surface per material. The smoke test checks that. What was missing was anything free-standing: field and farm walls, the fort's palisade, and the town wall of milestone 9.

## Options

| Option | Fits exact sizes | Look | Cost | License | Verdict |
| --- | --- | --- | --- | --- | --- |
| **Generated from pictures** (TripoSR, TRELLIS.2) | No | Walls come out as plain boxes or scraps | Asset PC time | Mixed, see [ASSET_PIPELINE.md](ASSET_PIPELINE.md) | Keep for props and the one stone wall that worked. Not for walls |
| **Code-built from boxes** (current houses) | Yes | Simple, but the photo surfaces carry it | None | Ours | The default for buildings |
| **Code-built from many small pieces** (new `stone_wall` and `palisade`) | Yes | Shows courses, gaps, and an uneven top, so it reads as laid stone or logs | 450 to 900 faces for 8 m of wall, one mesh | Ours | Use for free-standing walls and fences |
| **Kit-bashing a CC0 kit** (Quaternius Medieval Village MegaKit) | Only in its own 2 m grid | Good, but stylized | About 90 faces per section, a download and a style check | CC0 on the pack page, but see the license warning in [ASSET_LIST.md](ASSET_LIST.md) and [#66](https://github.com/Gamperle/Erlenfall/issues/66) | Possible for details such as window frames, after the license is settled |
| **Blender scripts** (a geometry nodes or Python wall generator) | Yes | Best control: bevels, baked occlusion, varied stones | Needs Blender here or on the asset PC, and output as `.glb` | Ours | Worth it only if the code-built walls look too plain in the running game |
| **Heightmap or normal-map bricks on a flat wall** | Yes | Cheap, but flat at the edges | Needs per-stone depth maps | Poly Haven maps are CC0 | Already partly there: the relief maps from [#156](https://github.com/Gamperle/Erlenfall/issues/156) give surfaces their grain |

## Recommendation

1. **Buildings stay code-built.** Extend `ModelBuilder` instead of generating models. The issue's own second batch of results agrees.
2. **Use the new small-piece builders for free-standing walls** (`ModelBuilder.stone_wall` and `ModelBuilder.palisade`). Both take a length, a height, and a seed, return a `StaticBody3D` with a box collider, and are deterministic, so they can be placed from `data/village_layout.json` like the other things there. They are a prototype and are not placed in the village yet.
3. **Do not download a kit yet. The MegaKit is not in the repository.** Whether the MegaKit's style and license fit is a decision for the maintainer.
4. **Skip Blender scripts for now.** They need a tool this environment doesn't have, and the code builders need no new tooling. Revisit after looking at the walls in the running game.

## The prototype

`stone_wall(length, height, thickness, seed)` lays rough blocks in courses of about 0.4 m, offsets every other course, trims the ends flush, and varies each block's length, depth, tilt, and one of three tints. `palisade(length, height, seed)` stands upright logs of slightly different heights side by side with a rail across them.

Both are verified in the smoke test: the result is one mesh with at most 3 surfaces, its size matches the request, and the same seed gives the same faces. An 8 m by 2.4 m wall is 864 faces. The tints are limited to three because every color is a material of its own, and the first try with a free color per block gave 51 surfaces.

Not checked, because this environment has no screen: how the walls look in the running game, lighting on the tilted blocks, and the cost of long walls such as a whole town circuit. A long wall should be built in sections of 8 to 10 m so the far ones can be culled.

## Open decisions

Tracked in [#209](https://github.com/Gamperle/Erlenfall/issues/209) (look and placement) and [#210](https://github.com/Gamperle/Erlenfall/issues/210) (whether to use a kit).
