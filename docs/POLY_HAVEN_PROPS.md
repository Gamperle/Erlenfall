# Poly Haven models as a prop source

Research for [#68](https://github.com/Gamperle/Erlenfall/issues/68), done on 2026-11-09 from Poly Haven's license page and public API (`api.polyhaven.com`). No model was downloaded, viewed, or tried in the game, and nothing was added to the repository.

## License

[Poly Haven's license page](https://polyhaven.com/license) says all its HDRIs, textures, and 3D models are CC0. Credit isn't required, commercial use is allowed, and the assets can be redistributed inside a product. The page doesn't mention AI training. This matches how the game already uses its textures ([ASSETS.md](../ASSETS.md)).

- The CC0 grant covers the assets only. Poly Haven's logos, renders, and site text are not CC0.
- Its [public API](https://github.com/Poly-Haven/Public-API) asks for a "Powered by Poly Haven" credit only from apps built on the live API. Downloading a model by hand doesn't need it.
- Each model has its own author (for example Kirill Sannikov for the painted wooden furniture). Log them in ASSETS.md as the textures are, even though CC0 doesn't require it.

## What the catalog holds

The API lists 521 models, and 140 have a `polycount` under 5,000. Poly Haven doesn't define the field on its API page, so whether it counts triangles or quads is unconfirmed. At these counts that is at most a 2x difference.

Little of it is medieval. Most small models are modern household, workshop, and industrial objects (cleaners, tools, plastic crates, TVs), with a farmhouse look at best. API dimensions are in millimeters.

### Under 5,000 and a plausible fit

| Model | Polycount | Author | Fits |
| --- | --- | --- | --- |
| `painted_wooden_table` | 600 | Kirill Sannikov | Farmhouse and inn table, about 2.4 m long |
| `painted_wooden_bench` | 630 | Kirill Sannikov | Inn and farm bench |
| `painted_wooden_stool` | 676 | Kirill Sannikov | Inn and forge |
| `painted_wooden_chair_01` | 724 | Kuutti Siitonen | Houses |
| `painted_wooden_chair_02` | 1,246 | | Houses |
| `painted_wooden_shelves` | 524 | Kirill Sannikov | Houses |
| `painted_wooden_cabinet_02` | 966 | Kirill Sannikov | Houses; the game's `cupboard_*` is AI-made today |
| `painted_wooden_nightstand` | 470 | Kirill Sannikov | Bedroom |
| `wooden_table_02` | 196 | Serhii Khromov | Cheapest table; its look is unchecked |
| `WoodenTable_01` | 952 | | Plain old table |
| `Shelf_01` | 182 | Gabriel Radic | Workshop and storage |
| `CheeseBox_01` | 884 | Gabriel Radic | Small farm clutter |
| `carved_wooden_plate` | 2,112 | Jan Martens | Table clutter |
| `wooden_candlestick` | 3,328 | Josh Dean | Table clutter |
| `stone_fire_pit` | 3,887 | Sebastian Platen | Camp props |
| `ceramic_pot`, `planter_pot_clay` | about 3,100 to 3,600 | | Farm and kitchen clutter |
| `wooden_axe_02` | 2,218 | Ulan Cabanilla | Wood-chopping props; the game has its own held axe |

### Just over 5,000, worth reducing

`wooden_bucket_01` (5,116), `wooden_crate_02` (5,176), `wooden_crate_01` (6,576), `wooden_ladder_02` (6,126), `wooden_ladder` (8,492), `wooden_lantern_01` (8,321), `vintage_oil_lamp` (7,208), `wooden_bookshelf_worn` (10,106). Each is within about 2x of the budget, so a decimation step should reach it.

### Not usable as they are

- Poly Haven has no anvil, kiln, forge, furnace, well, cart, plough, or hay.
- Right kind of object, 3x to 20x too heavy: `Lantern_01` (33,902), `treasure_chest` (103,330), `tree_stump_01` (41,046), `spinning_wheel_01` (52,023), `wicker_basket_*` (17,000+), `wooden_barrels_01` (33,142). The small barrels (`Barrel_01`, `barrel_03`) are painted industrial drums.
- Everything modern: shed tools, plastic, cleaners, electronics.

## Fit with the performance budget

The props in `assets/props/` come from the generation pipeline at a per-object face budget (500 to 3,000 faces for props in [the asset list](ASSET_LIST.md)). The smoke test requires each prop to have one mesh with one textured surface. The open performance issues are [#41](https://github.com/Gamperle/Erlenfall/issues/41) (older hardware, quality options) and [#146](https://github.com/Gamperle/Erlenfall/issues/146) (draw calls, found on characters).

- **Faces.** The painted furniture (470 to 1,250) is at or below the generated props' budget, so it adds no face cost. The 5,000+ models need reducing to 1,000 to 3,000.
- **Draw calls.** This is the larger risk, as #146 showed. A model may have several meshes or materials. The `painted_wooden_table` glTF holds only about 25 KB of geometry, so it is probably small, but each model's mesh and material count must be checked, and merged to one surface to pass the smoke test.
- **Textures.** Each model ships diffuse, normal (OpenGL and DirectX), and a packed ARM map (ambient occlusion, roughness, metal), from 1K to 8K. At 1K, `painted_wooden_table` is about 1.75 MB of JPEGs and `wooden_bucket_01` about 2.3 MB. Every prop with its own three maps costs texture memory, which matters for #41's older hardware. A shared atlas or 512 px maps may be needed if many are used. The ARM map matches how the surfaces already use occlusion and roughness.
- **Distance.** The game already stops drawing small props far away (`visibility_range_end`), which works for these too.

## Fit with the pipeline

1. **Format.** Poly Haven offers glTF (`.gltf`, `.bin`, and texture files), Blender, FBX, and USD. The game uses `.glb`, so take the glTF and repack it in Blender. glTF is Y-up and in meters like Godot, so these need no turning (unlike TRELLIS.2 output).
2. **Existing steps.** `size_glb.py` and the prop tuner (`data/prop_tuning.json`) work on any `.glb`.
3. **New work.** A Blender script to merge meshes and materials into one surface, decimate if needed, downscale textures, and write a `.glb`. It runs on the CPU with no asset PC.
4. **Logging.** Each model gets a row in ASSETS.md with its `polyhaven.com/a/<name>` link, author, CC0, and any edits, as the textures have.
5. **Style.** The painted furniture is farmhouse furniture with worn paint, close to the game's realistic surfaces, but it must be judged beside the generated props in the game.

## Recommended shortlist

The lowest-risk set for inn and farmhouse interiors, to try in this order:

1. `painted_wooden_table`, `painted_wooden_bench`, `painted_wooden_stool` (one author and paint style, all under 700)
2. `painted_wooden_shelves`, `painted_wooden_cabinet_02`, `painted_wooden_chair_01`
3. `wooden_bucket_01` and `wooden_crate_02`, after reduction
4. `CheeseBox_01` and `carved_wooden_plate` as table clutter

Skip the stumps, barrels, chest, and lanterns: the generation pipeline already makes those, and Poly Haven's are heavy or modern.

## Not yet known

- How the models look beside the surfaces and the generated props, and each one's mesh, material, and draw call count. This needs a Godot trial with a few models downloaded (a few MB each at 1K).
- What `polycount` counts.
- Whether a mix of CC0 and generated props holds together visually.

The trial and the decision on whether to adopt these are tracked in the issues linked from the pull request.
