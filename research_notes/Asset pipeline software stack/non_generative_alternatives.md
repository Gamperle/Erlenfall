# Non-generative alternatives and hybrids for grounded stylized village props and buildings

Researched 2026-11-01 for Erlenfall (Godot 4.7.2; code MIT, art CC BY-SA 4.0; moderate polygon counts for integrated graphics).

Verification labels used below:
- **[V-page]**: read on the source's own page in this session.
- **[V-data]**: computed from Poly Haven's public API catalog, fetched once in this session.
- **[Search]**: seen only in a search-result summary, because the page itself was not read. Check it before relying on it.
- Everything under "Inferences" is my reasoning, not a sourced fact.

No model was downloaded, opened, or viewed in this research. All statements about style are therefore provisional, and no asset has been tested in the game.

## What CC0 and CC-BY or CC BY-SA compatible 3D model sources cover these objects, and how well do they match?

### Takeaway
Non-AI sources are stronger than the project's asset list assumes. Poly Haven has many grounded wooden props within or near budget, and Quaternius has the most consistent stylized kits. The real gaps are the anvil-and-forge set and any kiln, where only small OpenGameArt items or a Poly Haven masonry heater come close.

### Cited Findings

**Poly Haven: catalog facts [V-data]** ([API](https://api.polyhaven.com/assets?t=models))
- The catalog has 521 models. The median `polycount` is 11,146 (range 182 to 17.4 million); 140 models are under 5,000 and 358 are under 20,000.
- This matters because [docs/ASSET_LIST.md](https://github.com/Gamperle/Erlenfall/blob/main/docs/ASSET_LIST.md) judges Poly Haven only by its plants and boulder (433,000 to 1.6 million faces). The same catalog has many light props.

| Need | Poly Haven candidates (`polycount`) [V-data] | Asset list budget |
| --- | --- | --- |
| Table | `wooden_table_02` 196; `painted_wooden_table` 600; `WoodenTable_01` 952; `dining_table` 1,048; `WoodenTable_02` 1,514 | Not listed |
| Chair, stool, bench | `painted_wooden_bench` 630; `painted_wooden_stool` 676; `painted_wooden_chair_01` 724; `painted_wooden_chair_02` 1,246; `chinese_stool` 1,090 | Bench 500 |
| Storage | `Shelf_01` 182; `painted_wooden_shelves` 524; `painted_wooden_nightstand` 470; `painted_wooden_cabinet_02` 966; `painted_wooden_cabinet` 2,227 | Not listed |
| Bed | `vintage_day_bed` 2,715; `GothicBed_01` 18,741; `old_bed_frame` 49,990 | 1,500 |
| Barrel, crate | `barrel_03` 1,473, but its catalog category is metal drums; `wine_barrel_01` 10,820; `wooden_crate_02` 5,176; `wooden_crate_01` 6,576 | Barrel 800, crate 300 |
| Kitchen | `carved_wooden_plate` 2,112; `brass_pot_02` 3,344; `wooden_cutting_board` 3,520; `ceramic_pot` 3,592; `brass_pot_01` 3,760; `brass_pan_01` 4,340; `wooden_bowl_02` 4,666; `jug_01` 5,770; `wooden_spoon` 6,576; `pot_enamel_01` 11,416 | Not listed |
| Hand tools | `cross_pein_hammer` 2,124 (tagged blacksmith); `wooden_axe_02` 2,218; `handsaw_wood` 2,548; `sledgehammer_01` 2,596; `wooden_axe` 3,348; `wooden_hammer_01` 3,617; `wooden_bucket_01` 5,116; `rusted_spade_01` 11,436 | Axe 800 |
| Ladder | `wooden_ladder_02` 6,126; `wooden_ladder` 8,492 | 300 |
| Lighting | `wooden_candlestick` 3,328; `lantern_chandelier_01` 5,971; `wooden_lantern_01` 8,321 | Lantern on post 800 |
| Heat sources | `stone_fire_pit` 3,887; `scandinavian_masonry_heater` 9,350 (tagged fireplace and furnace); `barrel_stove` 11,404 | Furnace 3,000 |
| Stumps, baskets, chest | `tree_stump_01` 41,046; `wicker_basket_02` 17,850; `treasure_chest` 103,330 | Stump is part of the 2,000 anvil budget |
| Anvil, kiln, tongs, bellows, cauldron | None. A search of names, tags, and categories found no match | Anvil 2,000 |
| Buildings, walls | Only pieces such as `large_castle_door` 12,640 and `large_iron_gate` 38,140 appeared in my name filter. I did not review the whole "Architecture" category | Build |

- The site also has plenty that doesn't fit the setting, such as plastic crates, propane torches, and electric kettles [V-data]. It organizes models into 15 categories, including Furniture, Food & Kitchen, and Tools & Equipment ([Poly Haven models](https://polyhaven.com/models)) [V-page].
- Individual authors differ from one asset to the next: `painted_wooden_table` and `painted_wooden_stool` are both by Kirill Sannikov, while the buckets, axes, and hammers checked each have other authors [V-data]. `texel_density` also varies widely, from 940 on `large_castle_door` to 15,119 on `sledgehammer_01` [V-data] ([API](https://api.polyhaven.com/assets?t=models)).
- Assets are CC0, no credit is needed, and "You can redistribute them", including in products you sell. The Terms bar web scraping without permission and restrict logos, avatars, example renders, and text, not the assets ([Poly Haven license](https://polyhaven.com/license)) [V-page].

**Quaternius**
- Medieval Village MegaKit: 304 models, January 2025. It has interior and exterior walls, floors, stairs, roofs, doors, windows, and vines, on a snapping grid. Standard is about 60-70% of the pack for free; Pro adds the other 30-40%. Source adds .blend files and Godot, Unity, and Unreal setups with custom shaders for wear colors and per-model collisions. It is CC0, tested on Godot 4.3, in FBX, OBJ, and glTF ([Quaternius](https://quaternius.com/packs/medievalvillagemegakit.html)) [V-page].
- Pricing is reported as $9.99 for Pro and $14.99 for Source, and furniture and props appear in its itch.io listing ([itch.io](https://quaternius.itch.io/medieval-village-megakit)) [Search; direct fetch returned 403]. The Quaternius page doesn't mention props specifically [V-page], so these two conflict mildly on contents.
- Fantasy Props MegaKit: 211 models covering "weapons and tools to vegetables, potions, market stalls, chests, furniture". All use just 4 shared texture sets. CC0 with the same tiers. The page doesn't name an anvil, a barrel, kitchen items, or a forge ([Quaternius](https://quaternius.com/packs/fantasypropsmegakit.html)) [V-page].

**Kenney**
- Fantasy Town Kit: 160 files, CC0, tagged medieval, wall, town, building ([Kenney](https://kenney.nl/assets/fantasy-town-kit)) [V-page].
- Furniture Kit: 140 files, CC0, tagged furniture, interior, table, chair, bed ([Kenney](https://kenney.nl/assets/furniture-kit)) [V-page]. Its era isn't stated.
- Survival Kit: 80 files, CC0 ([Kenney](https://kenney.nl/assets/survival-kit)) [V-page]. Contents aren't itemized.
- All Kenney game assets are CC0 and credit is optional, but the logo is reserved. The support page doesn't discuss redistribution directly ([Kenney support](https://kenney.nl/support)) [V-page].

**OpenGameArt: all [Search], since direct fetches returned 403**
- [Low poly iron anvil](https://opengameart.org/content/low-poly-iron-anvil): CC0, about 258 triangles, 512 x 512 diffuse and specular maps.
- [Medieval Smith Pack](https://opengameart.org/content/medieval-smith-pack): CC0, Blender format, blacksmith props for a medieval village, by Daniel Andersson. The uploader isn't the author and says they can't fully verify the textures' licensing.
- [Blacksmith items](https://opengameart.org/content/blacksmith-items): anvil, furnace, hammer, and tub, under CC-BY-SA 3.0.
- [Medieval Village MegaKit](https://opengameart.org/content/medieval-village-megakit) and [Fantasy Town Kit](https://opengameart.org/content/fantasy-town-kit) are mirrored there, so the original sites are the better references.

**Sketchfab**
- The downloadable filter separates licenses. Free downloads are CC0 or CC BY variants, optionally with SA, NC, or ND; the Standard license is a store license ([Sketchfab license filters](https://sketchfab.com/blogs/community/refine-downloadable-model-searches-with-new-license-filters), [Sketchfab CC introduction](https://sketchfab.com/blogs/community/an-introduction-to-creative-commons-licenses)) [Search].
- The uploader alone chooses the license, and is "solely responsible" for that choice (§4.2.2) ([Sketchfab Terms](https://sketchfab.com/terms)) [V-page].

**ambientCG** publishes no models that I found evidence for in this research. It's covered under textures below.

### Inferences
- **Likely best for wooden furniture and small grounded props:** the `painted_wooden_*` set from Poly Haven (470 to 2,227 for the items listed, apart from `painted_wooden_sofa` at 5,826). Its low counts suggest it's hand-modeled rather than scanned. Authorship was verified only for the table and stool, and whether "painted" reads as rustic alpine needs a look at the pictures.
- **Style fit.** Poly Haven's closer match to "grounded" is my reading of its catalog of real-world objects. Quaternius and Kenney are stylized, and the existing asset list has the same concern. Kenney is probably the weakest fit for a grounded look, but this is unverified because I viewed no models.
- **Consistency ranking:** Quaternius, because of the shared texture sets and one author; then Kenney; then Poly Haven, with many authors and big density differences; then OpenGameArt and Sketchfab, which vary per item.
- **Polygon reduction is often realistic.** Many Poly Haven items are only 2 to 6 times over budget, and would need a decimation pass and normal bake rather than a full remodel. Those with fine geometry (ladder at 6,126 vs 300) are cheaper to build in code.
- **The forge set is the actual coverage gap:** anvil (small OpenGameArt item), forge and kiln (masonry heater reference, or Build). A masonry forge and kiln are mostly stone shapes, so Build with CC0 stone may beat both CC0 search and TripoSR.

### Gaps
- Face counts per model for Quaternius and Kenney aren't published on the pages read. The exact file lists aren't either, so anvil, barrel, and bucket presence in those packs is unconfirmed.
- It's unconfirmed whether Poly Haven's `polycount` counts triangles or quads, which affects budget comparisons by up to about 2 times. Its `texel_density` unit also isn't documented in what I read; I assume pixels per metre at maximum resolution.
- I didn't sweep Sketchfab or OpenGameArt systematically, because the sites blocked automated reading or search is limited. CC BY and CC BY-SA village kits there remain unsurveyed.
- I didn't check other sources, such as Kenney's other kits, Polygonal Mind, or Smithsonian Open Access.

## How do CC0 texture libraries combine with simple geometry?

### Takeaway
This is already working in the repository, so it's the lowest-risk path for walls and buildings. Simple shapes plus shared photo textures give the strongest consistency, and normal maps are the next step.

### Cited Findings
- Poly Haven textures are already in the game for terrain and buildings, as unedited 1K diffuse maps ([ASSETS.md](https://github.com/Gamperle/Erlenfall/blob/main/ASSETS.md)). Normal maps are still open ([#64](https://github.com/Gamperle/Erlenfall/issues/64)).
- ambientCG is entirely CC0, and you may "copy, modify, distribute" assets, including raw files in a project such as a video game. Credit is optional, and the license covers downloadable files and preview renders ([ambientCG license](https://docs.ambientcg.com/license/)) [V-page].
- Godot's StandardMaterial3D supports triplanar mapping in object or world space on UV1 and UV2, plus detail albedo and normal maps through a mask, which can combine with secondary UV or triplanar modes ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)) [V-page].
- Trim sheets are strips of tiling texture packed into one image so modular pieces can reuse them. Practitioners warn that stretching trims to fit breaks texel density, and they combine trims with tileables, sometimes through a second UV set ([Polycount trim-sheet threads](https://polycount.com/discussions/tagged/trim-sheet)) [Search; practitioner opinion].
- 0 A.D.'s official seamless terrain textures on OpenGameArt are CC-BY-SA 3.0 ([OpenGameArt](https://opengameart.org/content/0-ad-textures)) [Search].

### Inferences
- World-space triplanar suits generated walls, rubble, and foundations, because it avoids UV work and hides seams. Timber planks and shingles have a direction, so they need real UVs or a box projection with rotation.
- A small project trim sheet, built from CC0 planks, stone, and iron, could cover beams, door frames, furniture rails, and fence parts. It would share one material, which would also limit draw calls.
- Keeping textures in world units across code-built and imported items is what gives consistency. This extends the repository's existing approach, which uses a photo's detail around its average so game colors stay in charge.

### Gaps
- I found no measured cost for triplanar or detail layers on integrated graphics, and the Godot page doesn't state one. This needs testing under [#41](https://github.com/Gamperle/Erlenfall/issues/41).
- The ambientCG catalog size and its match for alpine timber, shingles, and plaster weren't checked.

## Which procedural modeling tools fit walls and buildings?

### Takeaway
Extending the project's own GDScript builder is the best fit for the buildings and walls that must match `data/village_layout.json`. Blender Geometry Nodes is a good optional step for richer kits, and the Quaternius kit is the best fast comparison. Building Tools and Sverchok are licensed acceptably, but neither adds much for this project.

### Cited Findings
- [#61](https://github.com/Gamperle/Erlenfall/issues/61) records that TripoSR can't make walls from generated pictures: a 222-face scrap and a plain box.
- Godot provides ArrayMesh (slightly faster, harder API), SurfaceTool (easier, with `generate_normals()` and `index()`), and MeshDataTool (not fast; only when topology data is needed). All run on the CPU. MultiMeshInstance3D is much cheaper for many copies, though instances of a surface share a material ([Godot procedural geometry](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/index.html)) [V-page].
- CSG is "mainly intended for prototyping", has no built-in UV mapping or 3D polygon editing, and can be baked to a MeshInstance3D or exported as glTF. The docs point to FuncGodot or Cyclops Level Builder for level design ([Godot CSG](https://docs.godotengine.org/en/stable/tutorials/3d/csg_tools.html)) [V-page].
- Building Tools: MIT license, version 1.0.13, stated as Blender 4.0 compatible. Features are floorplans, floors, doors, windows, roof, stairs, and balcony. The page shows no release date ([GitHub](https://github.com/ranjian0/building_tools)) [V-page].
- Sverchok: GPL-3.0, parametric node-based geometry aimed at architects and designers. The README lists Blender 5.1, 4.5, 3.6, and 2.8 ([GitHub](https://github.com/nortikin/sverchok)) [V-page].
- Auto-Building is a Geometry Nodes add-on that distributes user-supplied doors and windows over a simple mesh. It's listed as GPL, with free Lite and paid Full tiers ([Superhive](https://superhivemarket.com/products/auto-building)) [Search; no source repository confirmed]. BRiCKiTECT is a paid brick generator under a royalty-free license ([Superhive](https://superhivemarket.com/products/brickitect)) [Search].
- Blender says "What you create with Blender is your sole property", including .blend files. Published scripts using its Python API must carry a GPL-compliant license ([Blender license](https://www.blender.org/about/license/)) [V-page].
- Medieval Village MegaKit gives a grid-snapping modular alternative, tested on Godot 4.3 ([Quaternius](https://quaternius.com/packs/medievalvillagemegakit.html)) [V-page].

### Inferences

| Option | Fit | Why |
| --- | --- | --- |
| GDScript builder (ArrayMesh or SurfaceTool), baked to meshes | **Best first choice** | Already in use, sizes come from the layout file, adds no tool or license, is easy for an agent to change and to review as text. Bake results rather than regenerate at load if start-up time suffers |
| Blender Geometry Nodes | Good second | Better bevels, UVs, and scattering for hero pieces. Editable by hand, and the .blend can stay in the repository as source |
| Quaternius kit | Fast comparison | A good test of whether modular pieces can hit the layout's sizes. Risk: a grid may not match them, and the style may be too stylized |
| Building Tools | Optional | MIT, but seemingly aimed at Blender 4.0; maintenance is unverified, and the buildings are few and hand-specified |
| Sverchok | Skip | General parametric power and heavier than this job needs |
| Paid marketplace generators | Skip | Their sample assets may carry separate licensing, so each needs checking, and they add little |
| CSG | Blockouts only | Godot says so, and it lacks UV tools |

- **Licensing point for repository tooling:** a Blender Python script in `tools/` falls under Blender's GPL statement when published. MIT is generally regarded as GPL-compatible, but a maintainer should decide whether to mark such scripts as GPL. This isn't legal advice. It's also in tension with Building Tools being offered as MIT.
- Blender's page treats .blend files as the user's own artwork. It doesn't address Geometry Nodes groups specifically, and it's reasonable but unconfirmed to treat them likewise.
- The output of GPL add-ons such as Sverchok is probably not GPL-bound, by analogy with Blender's statement. I found no direct statement by Sverchok.
- Recommended building recipe: wall, timber frame, and roof generators with a few parameters (size, height, door and window slots, damage), plus shared CC0 materials, plus a few hand-made or CC0 "kit-bash" details such as doors and shutters. Damaged and ruined variants could come from the same generator, which would fit the inn repair and the ruined houses.

### Gaps
- I didn't read Blender's Geometry Nodes manual, so I've cited no official statement about its capabilities or glTF export.
- Building Tools' last commit date and Blender 5.x support aren't confirmed.
- No sourced comparison exists of time spent per building across these methods. It would have to come from a trial.
- The [Polycount modular environment wiki](https://wiki.polycount.com/wiki/Modular_environments) refused the connection, so grid and seam guidance isn't sourced from it.

## Which hybrids make sense?

### Takeaway
The best hybrid is to make AI the last resort. Use Build plus CC0 for structures, CC0 first for props, and AI only for bespoke solid props that have no CC0 match, retextured with the project's shared materials. A blockout through ControlNet is promising for concept art and for steadier TripoSR input images, but it's untested here.

### Cited Findings
- The project's asset list already assigns walls and buildings to Build, and solid props to Gen ([docs/ASSET_LIST.md](https://github.com/Gamperle/Erlenfall/blob/main/docs/ASSET_LIST.md)). Mesh cleanup and the SDXL license check are still open ([#55](https://github.com/Gamperle/Erlenfall/issues/55), [#60](https://github.com/Gamperle/Erlenfall/issues/60)).
- Invoke publishes a workflow that takes a rough grayscale render or viewport screenshot, extracts edges and depth, and feeds them to ControlNet so that the output keeps the original form ([Invoke](https://invoke.com/workflows/3d-item-blockout-to-concept-render)) [Search].
- A texture projection method: unwrap, render depth, generate with SDXL plus depth ControlNet, then project using stencil paint. The author reports that it works for some shapes and not others, and that background color sometimes bled onto the object. Rendering parts from several angles reduced blind spots ([Zenn](https://zenn.dev/rmake_blog/articles/0a9bc81cd1ff7f)) [Search]. An older guide describes similar steps ([Medium](https://medium.com/@mattzq/stable-diffusion-controlnet-texture-projection-workflow-with-blender-8dac4b7154c2)) [Search; may be dated].
- SDXL's license claims no rights in the output, but "No use of the output can contravene" its use restrictions, which is what makes the check in #60 relevant ([SDXL license](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md)) [V-page].
- Sketchfab bars using models tagged "NoAI" for AI purposes (§15(a)) and requires AI-made uploads to be labeled "CreatedWithAI" (§15(b), §4.4(vi)) ([Sketchfab Terms](https://sketchfab.com/terms)) [V-page].
- The design document says copyright status of AI assets varies by country and tool ([GAME_DESIGN.md](https://github.com/Gamperle/Erlenfall/blob/main/docs/GAME_DESIGN.md)).

### Inferences

| Object | Primary route | Parallel or fallback |
| --- | --- | --- |
| Walls, houses, inn, town hall, ruins | Build in GDScript with CC0 materials | Quaternius kit as a comparison |
| Forge, kiln, furnace (masonry) | Build; masonry heater and fire pit as reference or base | ControlNet concept art, then Build |
| Anvil | OpenGameArt CC0 anvil, or a simple hand model (a defined silhouette, few faces) | TripoSR once #55 is resolved |
| Table, chair, stool, bench, shelves, cabinet | Poly Haven `painted_wooden_*` and light tables | Quaternius Fantasy Props |
| Bed | Build or Quaternius; Poly Haven beds are heavy | TripoSR |
| Kitchen items (pots, bowls, jug, board) | Poly Haven, decimated and baked | Lathe-built in code: most are round shapes |
| Hand tools | Poly Haven, decimated, or code-built | TripoSR is weak on thin parts (inferred from wall and ladder-like results) |
| Barrel, bucket, crate | Build: simple and parametric | Poly Haven `wooden_crate_02`, `wooden_bucket_01` |
| Ladder, fence, sign, torch | Build | Already assigned there |
| Sacks, wood piles, ore rocks, stumps, carts, odd organic shapes | **AI remains useful** alongside CC0 | Poly Haven rocks and stumps, decimated |

- **Where AI still wins:** organic or irregular standalone items with no CC0 match, one-off story props, and concept art. **Where non-AI wins:** anything with exact sizes, straight edges, thin parts, or repeats. Also anything needing legal certainty, since CC0 sources avoid both #60 and the uncertain copyright status of AI output.
- **Retexture AI props.** Replacing baked TripoSR color with the shared wood, stone, and iron materials could address both the slow baking in [#62](https://github.com/Gamperle/Erlenfall/issues/62) and style consistency. It needs usable UVs, or triplanar in the shader.
- **ControlNet from a blockout** could also help the framing failure in #61: SDXL filled the frame with wall images, while a silhouette-constrained image wouldn't. Whether TripoSR does better with this is untested.
- **AI as concept art** is the lowest-risk hybrid legally, because the final mesh is hand- or code-built, though SDXL output used as a reference should still be noted in ASSETS.md if substantially copied.
- **Running in parallel:** a single-object bake-off (anvil or barrel) done by each route against the same budget, material, and lighting would settle this better than further desk research.

### Gaps
- No primary benchmark compares these hybrids for time or quality. The workflow sources are tutorials or vendor pages, and some search results looked auto-generated, so I excluded them.
- ControlNet model licenses weren't checked, and #60 should include them if this route is used.
- AMD ROCm support for ControlNet workflows was not checked.

## How do comparable games keep art consistent and unify mixed sources?

### Takeaway
I found good general advice but almost no real postmortems. The established tools are a written art standard, a shared palette and lighting, shared materials, one texel density, and a log of changes. Erlenfall's mist and shared shaders should help a lot, but this needs a visual test.

### Cited Findings
- 0 A.D. has an Art Design Document for contributors, calling for above-average color saturation and contrast within textures ([Wildfire Games](https://trac.wildfiregames.com/wiki/ArtDesignDocument?version=1)) [Search; this is a very old revision]. A forum member says its poly counts and texture sizes may be outdated, and that the game uses a classic non-PBR setup ([Wildfire forum](https://wildfiregames.com/forum/topic/22875-beginner-modding-questions/)) [Search; secondhand].
- Veloren's found style guide covers wiki formatting, not art ([Veloren wiki](https://wiki.veloren.net/wiki/Help:Style_guide?oldid=5724)) [Search].
- Wayline's guidance: set palette, light sources, and realism level before choosing assets; use a limited palette; apply global color grading (LUTs); use shaders for consistent materials; log asset edits ([Wayline: art style](https://www.wayline.io/blog/art-style-collaboration-avoiding-asset-pack-clashes), [Wayline: fixing clashes](https://www.wayline.io/blog/developer-checklist-fixing-asset-pack-art-clashes)) [Search; Wayline sells tools, so treat as general advice, not case studies].
- Quaternius achieves consistency by sharing 4 texture sets across 200 models ([Quaternius](https://quaternius.com/packs/fantasypropsmegakit.html)) [V-page]. Its kits' Source tier has shaders for customizable wear colors ([Quaternius](https://quaternius.com/packs/medievalvillagemegakit.html)) [V-page].
- Polycount practitioners call trim sheets the backbone of environment work under tight memory budgets, and use them with tileables at correct density ([Polycount](https://polycount.com/discussions/tagged/trim-sheet)) [Search; opinion].
- Poly Haven's own density values vary by about 16 times among the items sampled ([API](https://api.polyhaven.com/assets?t=models)) [V-data].

### Inferences
A unification recipe for mixed sources, in the order I'd apply it:
1. **Write a one-page art bible:** target palette, wear level, bevel size, real-world scale, texel density (for example, one value for buildings and a higher one for handheld items), and face budgets.
2. **Normalize on import:** scale to real size, decimate, bake normals, resize textures to the density target, and remove baked lighting from albedo.
3. **Replace source materials where possible** with a small shared library (wood, stone, iron, plaster, cloth). This is the single strongest unifier, and it hides source differences most.
4. **Tint and limit albedo** through a shared shader that keeps detail around a set color, as the terrain and building shaders already do. Add a shared roughness range.
5. **Unify with the scene:** fog, sun, ambient, and a single LUT or tonemap. The misty setting flattens distant contrast, which should hide differences, especially at range. Close-up props remain the risk.
6. **Prefer stylizing realism down over raising low-poly up.** Flat-colored Kenney-style pieces beside photo surfaces are likely to clash. Poly Haven items simplified and tinted are likely closer to "grounded stylized".
7. **Add a repeatable check:** one test scene with reference objects, lighting, and a turntable, with the smoke test checking face budgets and ASSETS.md entries.

Automating steps 2 and 7 in a script would serve CC0 and AI assets alike, which is another argument for running them in parallel.

### Gaps
- **No first-party postmortem on mixed-source 3D art** turned up, despite the search. The vdeijk [devlog](https://vdeijk.itch.io/the-orion-project/devlog/1000844/a-simple-trick-to-make-an-indie-game-look-great) appeared but wasn't read. GDC talks would be the next place to look.
- Veloren's and other open-source games' art guidelines (including Luanti and Godot's demo projects) weren't found or checked.
- The "16 times" figure is from 11 sampled assets, not the whole catalog. I also didn't verify it visually.

## What license compatibility applies to CC BY-SA 4.0 distribution for each source?

### Takeaway
CC0, CC BY, CC BY-SA 3.0, and CC BY-SA 4.0 can all ship in the repository, with credit where required. Anything NC, ND, GPL-only, or store-licensed can't. Sketchfab Standard and Fab Standard are the main traps.

### Cited Findings

| Source or license | Public repository under CC BY-SA 4.0? | Evidence | Status |
| --- | --- | --- | --- |
| Poly Haven (CC0) | **Yes.** Credit optional | "You can redistribute them" ([license](https://polyhaven.com/license)). Don't copy site renders or logos, and don't scrape | Verified |
| ambientCG (CC0) | **Yes.** Credit optional | Raw files may be included in a project ([license](https://docs.ambientcg.com/license/)) | Verified |
| Kenney (CC0) | **Yes.** Don't use the logo | CC0 and optional credit ([support](https://kenney.nl/support)). Redistribution isn't addressed in words there, and follows from CC0 | Inferred from CC0 |
| Quaternius Standard (CC0) | **Yes** | CC0, commercial use allowed ([page](https://quaternius.com/packs/medievalvillagemegakit.html)) | Verified as stated; check the license file in the download |
| Quaternius Pro or Source | **Likely yes**, if they're CC0 too | A summary says the same license applies to add-ons ([itch.io](https://quaternius.itch.io/medieval-village-megakit)) [Search] | Inferred; read the download's license file before committing paid files |
| OpenGameArt: CC0 items | **Yes**, but check each one | The Smith Pack's uploader can't verify its texture licensing ([page](https://opengameart.org/content/medieval-smith-pack)) [Search] | Page unread (403) |
| CC BY 4.0 or lower | **Yes.** Credit required, and SA applied to your changes | "CC BY is one-way compatible with BY-SA" ([CC wiki](https://wiki.creativecommons.org/wiki/ShareAlike_compatibility)); may be incorporated in BY-SA works, keeping notices and attribution ([CC FAQ](https://creativecommons.org/faq/)) | Verified |
| CC BY-SA 4.0 | **Yes** | The same license | Verified |
| CC BY-SA 3.0 | **Yes.** Adaptations may use later versions | BY-SA 3.0 adaptations may be under 3.0 or later ([CC compatible licenses](https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses/)). The wiki notes both versions' terms apply in a combined adaptation | Verified |
| GPLv3 asset | **No**, as a BY-SA 4.0 adaptation | BY-SA 4.0 to GPLv3 is one way only, so GPLv3 work can't become BY-SA ([CC](https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses/)) | Verified. It could sit in the repository only as a separately licensed file, which ASSETS.md permits; legal fit is unclear |
| Free Art License 1.3 | Compatible designation applies to BY-SA 4.0 adaptations going to FAL | [CC](https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses/) | Verified as a designation; direction for FAL to BY-SA not checked |
| NC or ND variants | **No.** CC FAQ allows no BY-SA relicense, and the project accepts commercial reuse by others | The design doc accepts others selling copies ([GAME_DESIGN.md](https://github.com/Gamperle/Erlenfall/blob/main/docs/GAME_DESIGN.md)). NC conflicts with this, and ND forbids changes such as decimation | Inferred; the CC page doesn't address them directly |
| Sketchfab CC0, CC BY, BY-SA | **Yes**, under the rules above, and record the license at download | Downloaders agree to the license's terms (§4.2.2). §4.1 says downloaded content "will always be subject to the most-current version" of the license ([Terms](https://sketchfab.com/terms)) | Verified as Terms; uploader's right to license is unverified, since the uploader is solely responsible |
| Sketchfab Standard | **No** | Bars distributing the asset as a standalone file (§2.2(b)) and sublicensing (§2.2(a)); and bars works whose primary value is the asset (§2.2(c)) ([licenses](https://sketchfab.com/licenses)) | Verified terms; applying them to a repository is an inference, though a strong one |
| Sketchfab Editorial | **No** | No commercial use; restricted to commentary (§2.3) ([licenses](https://sketchfab.com/licenses)) | Verified |
| Fab Standard | **Avoid** | Fab's summary reportedly allows only a private repository for collaborators and bars standalone redistribution ([Unreal forum](https://forums.unrealengine.com/t/standard-license-vs-github-source/2840541), [thread](https://forums.unrealengine.com/t/github-project-distribution-and-free-fab-assets/2665655)) [Search; community discussion] | EULA unread (403) |
| Fab CC listings | Unclear | A Sketchfab forum source says Fab offers only CC BY and Standard, not CC0, BY-SA, NC, or ND [Search, source from Sketchfab-filter results; not independently confirmed] | Treat as unverified |
| Blender and add-on output | **Yes**, your own work | "Sole property" ([Blender](https://www.blender.org/about/license/)). Scripts are a separate matter (see above) | Verified for Blender; inferred for add-ons |
| SDXL-assisted output | **Conditional** | No rights claimed, use restrictions carry over ([license](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md)); see [#60](https://github.com/Gamperle/Erlenfall/issues/60) | Verified terms; open project decision |

Other rules that apply:
- DRM: BY-SA licensees may not use effective technical measures that stop others from exercising the licensed rights. Access controls that don't limit further use are generally fine ([CC FAQ](https://creativecommons.org/faq/)) [V-page]. A store release with DRM wrapping BY-SA assets would need care.
- Sketchfab's §5(13) bars scraping content ([Terms](https://sketchfab.com/terms)) [V-page], and Poly Haven's Terms bar scraping without permission ([license](https://polyhaven.com/license)) [V-page]. Download by hand or through documented means.

### Inferences
- A downloaded model is **"CC0 on the page", not proof of provenance**. OpenGameArt and Sketchfab uploads can be rips or AI output, so prefer sources with known authors. Record the URL, author, license version, and date in ASSETS.md, ideally with a saved copy of the license notice.
- Modified CC0 assets can be released under the project's CC BY-SA 4.0 as your own additions; the CC0 original stays free for all. The project's "1K diffuse map, unedited" notes are a good pattern to keep.
- ASSETS.md and LICENSE-ASSETS already allow per-file exceptions, so CC BY items can be listed there with their required credit.
- Adding BY-SA 3.0 items (such as the OpenGameArt blacksmith set) makes a combined work carry both versions' terms. CC calls this unlikely to matter much in practice, and CC0 is still simpler.
- A stored .blend or texture counts as distributing the raw asset, so the Sketchfab §2.2(b) ban very likely bites even if the game also bundles it. This repository is public, so there's no "only packaged builds" escape.

### Gaps
- The full Fab EULA and OpenGameArt's licensing FAQ returned 403 and couldn't be read. OpenGameArt's OGA-BY and GPL 2 terms are therefore unverified.
- Whether a game is a BY-SA "adaptation" or a "collection" of separately licensed files wasn't settled by the FAQ section I could read. This matters for GPL or BY-SA 3.0 files in a mixed repository, and it's a legal question, not a research one.
- This is not legal advice. CC0's fallback behaviour in the EU and Germany wasn't researched.
