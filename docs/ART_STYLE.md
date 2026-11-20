# Art style guide

For [#272](https://github.com/Gamperle/Erlenfall/issues/272). One page for everyone who adds art: props, buildings, characters, and the interface. It writes down what the repository already does, so the look stops drifting and [#21](https://github.com/Gamperle/Erlenfall/issues/21) (replace the placeholder art) has a target. It is a **draft for the maintainer's approval**: the direction below is the existing one, and the "Gaps" section lists where the game does not match it yet.

## The look in one line

**Grounded stylized**: realistic proportions, materials, and lighting at moderate polygon counts, in a misty alpine valley. This is the decision in [the design document](GAME_DESIGN.md#resolved-conflicts-in-the-answers) ("much more realistic than *My Time at Portia*"). Aim for **worn and handmade, not ruined and not clean**: weathered timber, plaster, iron, clay and wool that people use every day. Nothing glows, nothing is neon, and nothing is a cartoon.

![A village scene in the game: plastered timber-frame houses, a plank bridge, a path and forested slopes](art_style/village.jpg)

*The game today (`tools/asset_pipeline/shoot_props.gd`): plastered timber-frame houses with a stone base and a brown-red shingle roof, a river, dirt paths, and low-poly trees against misty mountains.*

## Palette and materials

Colors come from the code and the data, not from taste. Keep new art inside them.

| Surface | Look | Source of truth |
| --- | --- | --- |
| Timber (frames, posts, doors) | Dark brown, `(0.20, 0.13, 0.08)`; lighter weathered `(0.40, 0.29, 0.19)` for palisades and fences. Never near-black (the first palisade was, see [#209](WALLS_AND_BUILDINGS.md#in-the-village-209)) | `ModelBuilder` constants |
| Plaster | Warm off-white to pale grey with light staining | Poly Haven `clay_plaster` photos in `assets/textures` |
| Stone | Cool grey `(0.42, 0.40, 0.37)`, rough blocks in 0.4 m courses, three tints at most per wall | `ModelBuilder.stone_wall` |
| Roofs | Brown-red `(0.36, 0.24, 0.18)`, ribbed, with darker patches | `ModelBuilder` |
| Iron | Dark blue-grey `(0.16, 0.17, 0.19)`, matte, no mirror shine | `ModelBuilder` |
| Cloth | Muted earth dyes: rust, ochre, moss green, undyed cream, brick red. No saturated primaries | `villagers.json` `colors` |
| Fire and lamps | The only warm, bright, emissive things: orange `(1.0, 0.45, 0.1)` | `ModelBuilder.FIRE_COLOR` |
| Sun, sky | Warm daylight `(1.0, 0.95, 0.85)`, orange dusk, blue-white moon, cool grey haze toward the mountains | `scripts/world/day_night.gd` |
| Interface | Dark plank and brown wood panels, cream text `(0.93, 0.88, 0.76)`, amber for links and focus, cream parchment for notes with dark ink | `assets/ui/erlenfall_theme.tres`, `tools/ui_pipeline/build_ui_textures.py` |

**Materials are real-world, not painted.** Surfaces are CC0 photographs (Poly Haven) with relief maps, world-mapped on code-built geometry, or PBR maps baked by the pipeline on generated props. Roughness is high everywhere except wet water, glazed clay, and glass. Avoid painted or hand-drawn texture looks, outlines, and cel shading.

**Wear and moss.** Wear shows at edges, at the foot of walls, and on roofs: scuffs, grain, rust on iron, soot at forges. Moss and lichen are allowed on north-facing stone, roofs, and old timber, in patches, never as an all-over blanket. A building that is in use is weathered, a building that the story marks as ruined is `ruined: true`, and a prop in a workshop looks handled (wood worn pale where hands go, iron dark with use).

## Proportions and scale

The world is in meters. A person is about 1.7 m, a door 2.1 m by 1.1 m (`ModelBuilder.DOOR_SIZE`), a stone course 0.4 m, a timber beam 0.22 m, a house foundation 0.6 m, a roof 2.5 m high with a 1 m overhang. Props are sized from the batch file's `meters` (the longest side) and then checked in the game with [the prop tuner](../tools/prop_tuner), so a prop is never sized by eye in the image.

Face budgets and texture tiers come from the 105 props in `tools/asset_pipeline/batches/klein1.json` to `klein5.json`. A budget is the batch file's `faces`.

| Longest side | Examples | Face budget (range in use) | Texture tier |
| --- | --- | --- | --- |
| under 0.3 m | bowl, ingot, nails, potion | 500 to 1,200 | 512 px |
| 0.3 to 0.7 m | cauldron, hammer, jug, lantern, stool | 800 to 3,000 | 512 px |
| 0.7 to 1.25 m | anvil, barrel, chest, desk, sword | 600 to 6,000 | 512 px |
| 1.25 to 2.5 m | cupboard, door, kiln, bench, wood pile | 800 to 6,000 | 1,024 px |
| over 2.5 m | forge, well, haystack, log cart, sawpit | 2,500 to 8,000 | 1,024 px |

- **Tiers:** the pipeline bakes everything at 1,024 px, and `tools/asset_pipeline/shrink_textures.py` shrinks props of 1.25 m or less to 512 px ([#426](https://github.com/Gamperle/Erlenfall/issues/426)). `provenance.py validate` and `shrink_textures.py --check` fail a prop whose textures are larger than its tier ([#445](https://github.com/Gamperle/Erlenfall/issues/445)). The largest prop of each tier has about 400 px per meter (512 px over 1.25 m, 1,024 px over 2.5 m), and smaller props get more. Keep that as the minimum.
- **One mesh, one material.** A prop is one mesh with one material (base color, normal, roughness and occlusion). Buildings and walls are joined by `ModelBuilder.merged`, one surface per material, and the smoke test checks the surface count.
- **Characters:** about 15,000 triangles with 1,024 px textures each (`tools/character_pipeline/README.md`). Goblins are far lower (about 1,800 triangles) with a plain palette texture. Their normals are smoothed and their material is matte like the villagers' (`tools/character_pipeline/smooth_goblin.py`), but the faceted shape and flat palette colors remain a simpler style that fits the enemy (see Gaps).
- **Free-standing walls:** 450 to 900 faces for 8 m of wall, built in code.
- Shapes keep **a readable silhouette at 20 m**: chunky handles, thick straps, clear openings. Thin spikes, hair-thin ropes and glass are where generated models fail.

## Per area

![The village's own interface textures: dark planks, a hover state that is lighter, a pressed state that is darker, parchment, and a compass strip](art_style/ui.jpg)

![The five villagers, front view: muted earth-tone wool and linen, a smith in a tunic and a mayor in a deep red robe](art_style/characters.jpg)

*Interface textures from `assets/ui`, and villagers from `tools/character_pipeline/turntable.gd` (the characters stand in a T pose until the game's animations play).*

**Props.** Generated by the klein, TRELLIS.2, Blender pipeline ([the pipeline](ASSET_PIPELINE.md), [its walk-through](../tools/asset_pipeline/README.md)). Use solid, single objects with a clear shape: furniture, tools, containers, workshop fixtures. Material mix: aged oak and pine, black iron, fired clay, rope and sack cloth. The reference is the TRELLIS.2 set in `tools/asset_pipeline/examples/4_trellis_models.jpg` (barrel, chest, anvil on a stump, brick kiln, cart). Do not use generated models for walls, timber frames, or anything that must fit exact sizes ([#61](https://github.com/Gamperle/Erlenfall/issues/61)).

**Buildings and walls.** Code-built from boxes with `ModelBuilder` ([walls and buildings](WALLS_AND_BUILDINGS.md)): a stone base, plastered walls, dark timber beams on a regular frame, a shingled gable roof with an overhang, a chimney, a small door and square dark windows, and the world-mapped CC0 surfaces doing the detail. Stone walls and palisades show courses, gaps and an uneven top. Keep walls plain and the surfaces strong rather than adding greeble. Farms use the same house language, larger and without windows (barns).

**Characters.** Built from short recipes in `villagers.json` (MPFB and MakeHuman CC0 packs): real proportions, adult builds that follow age and job (stooped grandmother, broad smith), plain peasant clothing in muted dyes, one accent color per person (Brandt's red robe, Bertram's dark leather), natural hair colors, a hat or apron only where the job needs it. Check every character from 8 sides with `turntable.gd`. Packs under CC-BY are not used. Enemies (goblins) may be more stylized, but stay in the same palette: olive-green skin and brown rags.

**Interface.** Warm, hand-made and tactile: dark wood panels and plank buttons as nine-patches built from the game's own CC0 wood photos (`build_ui_textures.py`), in three states (normal, lighter hover, darker pressed, grey disabled). Cream serif text (Noto Serif, bold display cut for titles), amber highlights, parchment for notes and quest text. Use the theme (`erlenfall_theme.tres`) and its type variations (`TitleLabel`, `InkLabel`) instead of colors set on single nodes. No glossy gradients, glows or outlines. Check text size, high contrast, and color vision options ([CONTRIBUTING.md](../CONTRIBUTING.md)): never mark a state by color alone.

## What to avoid

- Cartoon outlines, cel shading, hand-painted textures, neon or fully saturated colors.
- Pristine, plastic, or mirror-shiny surfaces. Brand-new wood.
- All-over moss, dirt or damage that hides the shape. Photo noise as the only detail.
- Modern things: screws, printed text, plastic, sheet glass, electric light.
- Pictures of a room or scene, several objects, a cropped object, or a pattern that fills the frame as the source for a model.
- Mixing a flat-shaded low-poly look with textured realism in one scene (the trees do this today, [#460](https://github.com/Gamperle/Erlenfall/issues/460)).
- Sources with unclear rights. Own assets must not copy others' work or break a tool's license; third-party and generated files go in [ASSETS.md](../ASSETS.md), and generated ones also in `provenance/`.

## Checklist for a new asset

1. **Fit.** Does it belong to the story and the valley (see [the lore](LORE.md))? Is it on [the asset list](ASSET_LIST.md)? Which area rules apply?
2. **Size.** Fix the real size in meters first, then pick a face budget and texture tier from the table.
3. **Palette.** Colors inside the table above, matte, with edge wear and at most patchy moss.
4. **Silhouette.** Reads at 20 m, no thin spikes, one clear shape.
5. **Build.** One mesh, one material for props; correct front direction (the smoke test checks every prop is within 10 cm of the ground); `shrink_textures.py` run after sizing.
6. **In the game.** Look at it at noon, at dusk and in fog next to the player and a building (`shoot_props.gd`, `shoot_models.gd`, the prop tuner). Compare it with the examples, not with the picture.
7. **Records.** ASSETS.md row, provenance record, license. `godot --headless --path . --script res://tools/check_assets.gd` and `python3 tools/asset_pipeline/provenance.py validate` pass.
8. **Text.** Names go in `localization/strings.csv`, in English and German.

## Image prompt template

Pictures for props use FLUX.2 klein 4B and the fixed wrapper in `tools/asset_pipeline/draw_klein.py`. You only write the **subject**. It has proved itself on 105 props, so change the subject, not the wrapper:

```
A single {subject}, 3d game prop, straight-on front view at eye level, centered, the entire object visible
with empty space around it, isolated on a plain white background, realistic proportions,
worn handmade materials, soft even studio lighting. No text, no people, no other objects.
```

Write the subject as **material + object + the shape words that matter + state**. Good ones in the batches: "black iron blacksmith anvil with a pointed horn, on a wooden stump", "heavy arched wooden door with iron hinges in a stone frame", "wooden storage chest with iron bands, lid closed", "round village well with a low fieldstone wall, a small wooden shingle roof on two posts, and a wooden bucket on a rope". Say what is closed or empty ("lid closed", "empty top"), name the material (oak, cast iron, glazed clay), and avoid glass, hidden sides and walls. Draw six candidates, keep the best two, and reject what the pipeline's [picture rules](ASSET_PIPELINE.md#getting-good-pictures) reject.

The prompt is for the picture only. Interface textures are built from the CC0 photos by script, characters from recipes, and buildings in code, so they have no image prompt.

## Gaps today

Seen in the screenshot above, to be decided with the maintainer. They are tracked as issues, not fixed here.

- Trees and shrubs are flat-shaded low-poly shapes, while props, houses and ground are textured and realistic.
- ~~The plaster was heavily mottled and the grass strongly saturated~~ Fixed in [#461](https://github.com/Gamperle/Erlenfall/issues/461): plaster keeps 35% of its photos' color and shows the mossy photo on less of the wall (`Surfaces.PHOTO_SATURATION`, `SECOND_PHOTO_THRESHOLD`), and the grass tints and colors are more muted olive.
- Villagers show a T pose and little color or clothing variety beyond their sweater or robe; the goblin has smooth shading and a matte material now, but is still low-poly with flat palette colors instead of painted textures ([#462](https://github.com/Gamperle/Erlenfall/issues/462), [#474](https://github.com/Gamperle/Erlenfall/issues/474)).

Changes to this guide go in a pull request like any other, and the maintainer approves the direction ([#272](https://github.com/Gamperle/Erlenfall/issues/272)).
