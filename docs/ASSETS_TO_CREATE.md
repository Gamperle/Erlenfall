# Assets to create

The next props to make for a complete **forge**, **lumberjack's yard**, **carpenter's workshop**, **mine**, and **small storage buildings**. **Status: proposed, waiting for the maintainer's greenlight.** Nothing here has been drawn or generated yet.

This is a working list. When an entry is made, its row moves to [ASSETS.md](../ASSETS.md) with the prompt, seed, and tool versions, and the finished models go in `assets/props`. The general asset order is in [ASSET_LIST.md](ASSET_LIST.md).

## How these will be made

- **Gen** props go through the [asset pipeline](ASSET_PIPELINE.md): FLUX.2 klein 4B draws candidates, TRELLIS.2 builds the mesh, Blender sets the real size. They go in one new batch, `tools/asset_pipeline/batches/klein3.json`, with first seed **8000** (klein1 uses 6000, klein2 7000).
- **Build** items are buildings and long pieces that must fit exact sizes, so they are code-built in `ModelBuilder`, as [WALLS_AND_BUILDINGS.md](WALLS_AND_BUILDINGS.md) recommends. They don't use the asset PC.
- Run the Gen batch about ten names at a time, because SSH sessions to the PC drop. Drawing six candidates per name and keeping the best two is cheap, and I'll show you contact sheets before any model is built.
- Estimated GPU time for everything below: about 5 to 7 hours, mostly TRELLIS.2 at 3 to 9 minutes per item.

**Already in the game and not repeated here:** anvil, forge hearth (3 variants), furnace, kiln, hammer, barrel, bucket, crate, chest, cupboard, desk, stool, bench, sack, haystack, wood pile, hand cart, campfire, lantern, cauldron, swords, doors, stone wall.

**Columns.** *Size* is the longest side in meters. *Faces* is the budget. *Risk* marks things the pipeline is known to do badly: thin parts (tongs, saws), loose fibers (hay, sacks, rope), and glass-like or hollow shapes. Risky items get extra candidates and may be dropped or code-built instead.

## Gen props

### Forge (12)

| Name | Subject drawn | Size | Faces | Risk |
| --- | --- | --- | --- | --- |
| `bellows` | large leather and wood forge bellows with two paddle handles and an iron nozzle | 1.0 | 3000 | Medium: the model doesn't reliably know bellows |
| `tongs` | pair of long blacksmith tongs with flat jaws, lying open | 0.6 | 800 | High: thin parts |
| `quench_trough` | long low wooden trough of dark water, bound with iron bands | 1.2 | 2500 | Low |
| `grindstone` | round stone grinding wheel on a wooden frame with a foot treadle | 1.1 | 3500 | Medium: spokes and crank |
| `anvil_stump_small` | small bench anvil with a flat top on a short oak block | 0.5 | 1500 | Low |
| `tool_rack_forge` | wooden wall rack holding hammers, tongs, and chisels | 1.2 | 3000 | High: many thin tools |
| `coal_bin` | open wooden bin heaped with black coal lumps | 1.0 | 2500 | Low |
| `ingot_stack` | neat stack of rough iron ingots | 0.5 | 1500 | Low |
| `blade_rack` | upright wooden rack holding three unfinished sword blades | 1.0 | 2500 | Medium |
| `workbench_forge` | heavy scarred timber workbench with an iron vise bolted on one side | 1.6 | 4000 | Low |
| `hot_iron_stand` | iron stand holding a glowing bar, for the forging minigame | 0.8 | 1500 | Medium: the glow won't bake in, so it's added in game |
| `forge_hood` | tapered stone and iron smoke hood over a hearth | 1.8 | 3500 | Medium |

### Lumberjack (12)

| Name | Subject drawn | Size | Faces | Risk |
| --- | --- | --- | --- | --- |
| `chopping_block` | thick round oak chopping block, scarred on top | 0.5 | 1500 | Low |
| `axe_in_block` | woodcutter's axe stuck upright in a chopping block | 0.9 | 2000 | Medium: thin handle |
| `splitting_maul` | heavy splitting maul with a wedge-shaped iron head | 0.9 | 1000 | Medium |
| `felled_log` | long felled fir log with bark and a clean cut end | 3.5 | 3000 | Low |
| `log_stack` | stack of whole round logs piled and chocked at the ends | 2.4 | 5000 | Low |
| `tree_stump` | wide stump of a felled fir with roots and an axe-cut top | 1.0 | 3000 | Low |
| `sawbuck` | X-legged wooden sawbuck holding a log | 1.3 | 2500 | Low |
| `crosscut_saw` | long two-man crosscut saw with two wooden handles | 1.5 | 1000 | High: thin blade |
| `log_sled` | low wooden log sled with iron-shod runners | 2.2 | 3500 | Medium |
| `log_cart` | two-wheeled timber cart loaded with logs | 3.0 | 6000 | Medium |
| `sawpit_frame` | wooden sawpit frame with a log held on top and a pit saw | 3.0 | 5000 | High: it may draw a room |
| `cant_hook` | long wooden cant hook with an iron hook | 1.5 | 800 | High: thin parts |

### Carpenter (13)

| Name | Subject drawn | Size | Faces | Risk |
| --- | --- | --- | --- | --- |
| `workbench_carpenter` | long heavy woodworking bench with a front vise and a tail vise | 2.0 | 4500 | Low |
| `sawhorse` | pair of simple wooden sawhorses with a plank across | 1.0 | 2000 | Low |
| `plank_stack` | tidy stack of rough sawn planks, spaced with sticks | 2.0 | 3500 | Low |
| `timber_beams` | pile of squared timber beams, end on | 2.5 | 3000 | Low |
| `toolbox_carpenter` | open wooden carpenter's toolbox with saw, plane, and chisels | 0.7 | 3000 | High: loose small parts |
| `hand_plane` | wooden hand plane with a curled shaving | 0.3 | 800 | Medium |
| `hand_saw` | wooden-handled hand saw | 0.7 | 600 | High: thin blade |
| `shaving_horse` | long wooden shaving horse bench with a foot clamp | 1.3 | 2500 | Medium |
| `pole_lathe` | wooden pole lathe with a spring pole and treadle | 1.8 | 4500 | High: complex frame |
| `chair` | plain wooden chair with a rush-free solid seat | 0.9 | 2000 | Low |
| `table` | sturdy rectangular plank table on trestle legs | 1.6 | 2500 | Low |
| `open_shelf` | open wooden shelf unit with three empty shelves | 1.5 | 2500 | Low |
| `spoked_wheel` | large wooden cart wheel with spokes and an iron rim, for wheelwrighting | 1.2 | 3500 | Medium: spokes (TRELLIS.2 handles them) |

### Mine (12)

| Name | Subject drawn | Size | Faces | Risk |
| --- | --- | --- | --- | --- |
| `mine_cart` | small wooden and iron mine cart with four flanged wheels | 1.4 | 4000 | Low |
| `mine_cart_ore` | the same cart, full of rough iron ore | 1.4 | 4500 | Low |
| `wheelbarrow` | wooden wheelbarrow with one iron-rimmed wheel | 1.5 | 3500 | Medium |
| `pickaxe` | miner's pickaxe with a long wooden handle and iron head | 0.9 | 800 | Medium: thin handle |
| `ore_pile` | heap of crushed rust-brown ore chunks | 1.2 | 2500 | Low |
| `ore_baskets` | two wicker baskets filled with ore | 0.8 | 3000 | High: wicker |
| `ore_sacks` | two heavy stacked sacks of ore | 0.8 | 2500 | High: burlap, see [#154](https://github.com/Gamperle/Erlenfall/issues/154) |
| `windlass_well` | wooden windlass with a crank, rope, and bucket over a shaft | 1.8 | 4500 | Medium: rope |
| `mine_support_frame` | rough timber mine support: two posts and a lintel | 3.0 | 2500 | Low |
| `hanging_lantern_mine` | iron mining lantern with a hook and a cage | 0.4 | 1500 | Medium: glass |
| `miner_sledge` | stonemason's short heavy iron sledgehammer with a short wooden handle | 0.7 | 1200 | Medium: the drill was dropped, because the model drew a modern power drill |
| `rubble_pile` | heap of fallen angular grey rocks | 1.8 | 3000 | Low |

### Small storage (11)

| Name | Subject drawn | Size | Faces | Risk |
| --- | --- | --- | --- | --- |
| `barrel_stack` | pyramid of stacked wooden barrels, three over two | 1.8 | 5000 | Low |
| `crate_stack` | tower of stacked wooden crates of different sizes | 1.6 | 4500 | Low |
| `grain_bin` | tall square wooden grain bin with a hinged lid | 1.4 | 3000 | Low |
| `storage_shelf` | tall open wooden storage shelf with jars and baskets | 1.8 | 4000 | High: small clutter |
| `big_chest` | large iron-bound storage chest with a domed lid | 1.2 | 3500 | Low |
| `clay_jar` | large unglazed clay storage jar with a wooden lid | 0.8 | 1500 | Low |
| `staddle_stone` | mushroom-shaped stone that lifts a granary off the ground | 0.6 | 1000 | Low |
| `hay_bale` | square tied bale of straw | 0.7 | 1500 | High: fibers, see [#154](https://github.com/Gamperle/Erlenfall/issues/154) |
| `hanging_rack` | wooden rack of hanging dried herbs and onions | 1.2 | 3000 | High: loose fibers |
| `pallet` | low wooden pallet of rough boards, for lifting goods off the floor | 1.2 | 1200 | Low |
| `cellar_hatch` | sloped double wooden cellar hatch set in stone | 1.6 | 2500 | Medium |

That is **60 Gen names** in one batch. The ones marked High are tried but not promised.

## Build (code-made, no asset PC)

These need exact sizes and entries in `data/village_layout.json`. Each is built from `ModelBuilder` boxes and the existing CC0 surfaces, like the houses.

| Name | Used for | Notes |
| --- | --- | --- |
| `smithy_forge_shed` | Open-sided lean-to extension for the forge, with a chimney | Extends the forge at (15, 14) |
| `lumber_shed` | Open-fronted roofed shed for drying planks and logs | Next to the forest edge |
| `sawmill_lean_to` | Roofed frame over the sawpit, open on three sides | Pairs with `sawpit_frame` |
| `carpenter_workshop` | Small timber workshop with wide doors and a loft | One building |
| `small_barn` | Storage barn with a hay loft door and large double doors | 3 variants for the farms |
| `granary` | Timber store on `staddle_stone` supports with an outside stair | 1 or 2 variants |
| `tool_shed` | Tiny shed, one door, one window | 2 variants |
| `mine_rail_track` | Straight and curved rail pieces with sleepers | Pieces of 2 m, joined |
| `mine_timber_entrance` | Timbered entrance frame for the mine that fits the existing opening | Opening is 4.0 x 3.6 m |
| `ore_chute` | Wooden chute and hopper by the mine entrance | Small |
| `yard_fence_log` | Log fence and gate for the lumber yard | Reuses `palisade` |

## Open questions for you

1. **Greenlight scope.** All 60 Gen names, or a trimmed list? A sensible first cut is everything marked Low or Medium, which is about 40 names, and I'd save the High ones for a second pass.
2. **Build items.** Should I build them with `ModelBuilder` now, or leave them until the interiors work in [#39](https://github.com/Gamperle/Erlenfall/issues/39)?
3. **Interiors.** The carpenter and forge props only make sense indoors, which the game doesn't have yet beyond the forge. Make them anyway so interiors can use them?

## Remaining placeholder art ([#21](https://github.com/Gamperle/Erlenfall/issues/21))

An audit of the code and data on 2026-11-15 found what is still a primitive shape. "Now" means the asset pipeline can make it today.

| Placeholder | Where | What replaces it | Status |
| --- | --- | --- | --- |
| Crafted item models are boxes: iron ingot, nails, dagger, sword, axe, short bow, long bow | `data/crafting.json`, `CraftingData.item_model` | One generated model per item | **Now**, batch `klein4`: dagger, axe, bows, ingot, nails. The sword already exists as `sword_*` |
| Items with no model: arrow, torch, healing potion, fire flask, ore, coal | `data/crafting.json` | Generated models for what is held, thrown or placed | **Now**, batch `klein4` |
| Nine villagers (Konrad, Agnes, Wendel, Oswin, Albrecht, Jakob, Falk, Marek, Lene) are code-made figures | `data/village_layout.json`, [#191](https://github.com/Gamperle/Erlenfall/issues/191) | Rigged models from `tools/character_pipeline` | Blocked: needs Blender 5.2 with MPFB and the MakeHuman packs, which neither this machine nor the asset PC has |
| Wolf is a capsule quadruped | `BeastModel` | A rigged animal | Blocked: the pipeline makes no rigged models, and no CC0 wolf is chosen |
| Fir and leaf trees, bushes, grass and boulders are code-built | `scripts/world/village.gd` | Detailed foliage and rocks | Blocked: TRELLIS.2 does badly on foliage, and the CC0 packs wait on the license decision in [#66](https://github.com/Gamperle/Erlenfall/issues/66) |
| Crops are flat boxes | [#411](https://github.com/Gamperle/Erlenfall/issues/411) | Crop models | Needs a CC0 crops pack, same blocker |
| Buildings are code-built | `ModelBuilder` | Stays code-built, see [WALLS_AND_BUILDINGS.md](WALLS_AND_BUILDINGS.md) | Decided, with the pieces in [#436](https://github.com/Gamperle/Erlenfall/issues/436) |
