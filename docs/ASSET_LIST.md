# Asset list

This lists the 3D models and surfaces the game needs, in the order to make them. Part 1 replaces what's in the game now, part 2 builds the [defining scene](GAME_DESIGN.md#defining-moment), and part 3 is for later milestones. Audio is tracked in [#23](https://github.com/Gamperle/Erlenfall/issues/23).

Variants are the number of different models to make, not how many appear in the world. The sources and face budgets are proposals to test, and the budgets target integrated graphics.

## Sources

| Key | Source | Best for |
| --- | --- | --- |
| **Build** | Modeled by hand or in code, with CC0 surface textures ([#61](https://github.com/Gamperle/Erlenfall/issues/61), [#45](https://github.com/Gamperle/Erlenfall/issues/45)) | Buildings, walls, roads, and anything that must fit exact sizes |
| **Gen** | The [TripoSR pipeline](ASSET_PIPELINE.md), after cleanup ([#55](https://github.com/Gamperle/Erlenfall/issues/55)) and the SDXL license check ([#60](https://github.com/Gamperle/Erlenfall/issues/60)) | Solid, standalone props |
| **CC0** | A CC0 library such as Poly Haven, Kenney, or Quaternius, if a suitable model exists | Plants, rocks, and rigged characters and animals |

TripoSR doesn't produce rigged models, so anything that walks or fights needs a CC0 model or manual rigging. Every asset goes in [ASSETS.md](../ASSETS.md).

## Part 1: Replace what's in the game (milestone 6)

### Characters

| Asset | Variants | Used for | Source | Faces |
| --- | --- | --- | --- | --- |
| Human body, rigged, with walk, idle, attack, block, and dodge | 2 | Player and villagers | CC0 | 15,000, with clothes and hair |
| Clothes and hair sets | 5 | Hedda, Bertram, Mira, Greta, and Brandt | CC0 | Included |
| Player clothes and hair | 1 | Player | CC0 | Included |
| Goblin, rigged, with walk, attack, and death | 1 | Goblin camp | CC0 | 4,000 |

### Buildings

Each is sized to its entry in `data/village_layout.json`.

| Asset | Variants | Used for | Source | Faces |
| --- | --- | --- | --- | --- |
| Grandfather's house | 1 | Player's home | Build | 3,000 |
| Grandmother's house | 1 | Hedda's home | Build | 3,000 |
| Forge | 1 | Bertram's workplace | Build | 3,000 |
| Inn, damaged and repaired | 2 | Greta's inn and the first quest | Build | 4,000 |
| Town hall | 1 | Brandt's workplace | Build | 5,000 |
| Farmhouse | 3 | North, west, and south farms | Build | 3,000 |
| Ruined house | 3 | Abandoned houses | Build | 2,500 |

### Crafting and quest props

| Asset | Variants | Used for | Source | Faces |
| --- | --- | --- | --- | --- |
| Furnace | 1 | Smelting | Gen | 3,000 |
| Anvil on a stump | 1 | Forging | Gen | 2,000 |
| Bed | 1 | Saving and sleeping | Gen | 1,500 |
| Ladder | 1 | Inn repair | Build | 300 |
| Wood pile | 2 | Gathering wood | Gen | 1,500 |
| Iron ore rock | 2 | Gathering ore | Gen | 1,000 |
| Coal rock | 2 | Gathering coal | Gen | 1,000 |

### Held items

| Asset | Variants | Used for | Source | Faces |
| --- | --- | --- | --- | --- |
| Iron dagger | 1 | Weapon | Gen | 500 |
| Iron sword | 1 | Weapon | Gen | 800 |
| Iron axe | 1 | Weapon | Gen | 800 |
| Torch | 1 | Light | Build | 300 |

### Landscape

| Asset | Variants | Used for | Source | Faces |
| --- | --- | --- | --- | --- |
| Fir tree, with lower detail for distance | 3 | Forest | CC0 | 1,500 |
| Grass tuft | 3 | Meadows | CC0 | 50 |
| Crops | 2 | Fields | CC0 | 200 |
| Boulder | 4 | Landslide and valley | CC0 | 500 |

### Surfaces

These are done, using CC0 textures from Poly Haven listed in [ASSETS.md](../ASSETS.md).

| Surface | Used for |
| --- | --- |
| Grass, dirt, rock, and snow | Terrain |
| Packed dirt road | Roads |
| Rubble | Landslide |
| Plaster, timber, stone, and roof shingles | Buildings |

## Part 2: Build the defining scene (milestone 6)

These are new, and they make Erlenfall feel lived in when you walk into it.

| Asset | Variants | Used for | Source | Faces |
| --- | --- | --- | --- | --- |
| Wooden fence and gate | 2 | Farms and gardens | Build | 300 |
| Stone well | 1 | Village square | Gen | 1,500 |
| Hay cart | 1 | Farms | Gen | 2,000 |
| Barrel | 1 | Forge and inn | Gen | 800 |
| Crate | 1 | Around the village | Gen | 300 |
| Sack | 1 | Farms and inn | Gen | 500 |
| Bench | 1 | Village square | Gen | 500 |
| Inn sign and forge sign | 2 | Marking buildings | Build | 200 |
| Lantern on a post | 1 | Light at night | Gen | 800 |
| Haystack | 1 | Farms | Gen | 800 |
| Broken road section and rubble | 2 | Where the landslide cut the road | Build | 1,500 |
| Buried mine entrance | 1 | North of the village | Build | 3,000 |
| Goblin tent and campfire | 2 | Goblin camp | Gen | 1,500 |
| Broadleaf tree, such as alder | 2 | The village's namesake | CC0 | 1,500 |
| Bush and wildflowers | 3 | Meadows and roadsides | CC0 | 200 |

## Part 3: Later milestones

These are grouped by need, and they can be refined when each milestone starts.

| Milestone | Assets | Source |
| --- | --- | --- |
| 7: Launch crafts | Alchemy table, cauldron, bottles and potions, herbs, carpentry bench, saw, planks, and furniture to craft | Gen, CC0 |
| 7: Items | Ingots, nails, and crafted items shown in 3D ([#12](https://github.com/Gamperle/Erlenfall/issues/12)), and interchangeable blades and handles ([#13](https://github.com/Gamperle/Erlenfall/issues/13)) | Gen |
| 8: Living village | 5 to 10 more villagers, market stalls, shop goods, and building interiors ([#39](https://github.com/Gamperle/Erlenfall/issues/39)) | CC0, Build, Gen |
| 8: Animals | Farm animals, and wildlife to hunt or fight, all rigged | CC0 |
| 9: Town | Town wall and gate, new town buildings, the repaired road, and the reopened mine | Build |
| 9: Enemies | More non-human enemies, all rigged | CC0 |
| 10: Beyond | Bows and arrows, magic effects, and tools and stations for cooking, tailoring, pottery, enchanting, and jewelry | Gen, CC0 |

## Sources found for what can't be generated

This covers parts 1 and 2 for assets that TripoSR can't make: anything rigged, thin plants and grass, and walls. Nothing here has been downloaded or tried in the game. Licenses are as stated on each pack's page, so check them again when downloading.

| Need | Best candidate | License | What's known | Check before use |
| --- | --- | --- | --- | --- |
| Human bodies and hair | [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) | CC0 | 6 bodies, 20 hairstyles, FBX and glTF, works with the animation library | About 13,000 triangles each, above the budget of 5,000. About 60-70% of the pack is free |
| Clothes | [Quaternius Modular Character Outfits: Fantasy](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html) | CC0 | 12 outfits from 62 parts, each with 3 texture variations, FBX and glTF | Whether the free part has enough plain village clothes |
| Character animations | [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) | CC0 | 120+ animations on the same rig, including 8-direction movement, combat, and death | The page doesn't name idle, block, or dodge |
| Goblin | [Quaternius Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html) | CC0 | 50 animated monsters, including glTF | The page doesn't list a goblin. [A free animated monster pack's page](https://quaternius.itch.io/lowpoly-animated-monsters) offers its goblin only to Patreon supporters |
| Goblin, alternative | [Low Poly Goblin (Rigged)](https://opengameart.org/content/low-poly-goblin-rigged) on OpenGameArt | CC0, per search results only | Rigged but not animated, Blend and FBX | The page couldn't be opened, so its license and quality need checking |
| Goblin, fallback | The human body above, smaller, with green skin and ears | CC0 | Reuses the human animations | Whether it reads as a goblin |
| Trees, plants, and rocks | [Quaternius Stylized Nature MegaKit](https://quaternius.com/packs/stylizednaturemegakit.html) | CC0 | 40 trees, 35 plants and flowers, 27 rocks, FBX, OBJ, and glTF | Face counts aren't listed, and it may look too stylized. Whether it has firs and alders |
| Trees and rocks, alternative | [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) | CC0 | 330 files, tagged tree, rock, and foliage | Formats aren't listed on the page, and it may look too simple |
| Crops | [Quaternius Ultimate Crops](https://quaternius.com/packs/ultimatecrops.html) | CC0 | 100+ models with 5 growth stages, FBX, OBJ, and Blend | Which crops it has. It needs converting to glTF |
| Walls and buildings, if built from parts | [Quaternius Medieval Village MegaKit](https://quaternius.com/packs/medievalvillagemegakit.html) | CC0 | 304 modular walls, floors, stairs, roofs, doors, and windows, FBX, OBJ, and glTF | Whether it can match the building sizes in the layout. About 60-70% of the pack is free |
| Animals, for milestone 8 | [Quaternius Ultimate Animated Animals](https://quaternius.com/packs/ultimateanimatedanimals.html) | CC0 | 12 animals with 12+ animations each | Which animals it has |

**[Poly Haven's models](https://polyhaven.com/models) don't fit as they are.** They have the right kinds of objects (`fir_tree_01`, `boulder_01`, `grass_medium_01`) and the most realistic look, but they are far too detailed. Its small `fir_sapling` has about 433,000 faces, and `grass_medium_01` about 1.6 million. They would need heavy reduction, while the [boulder](https://polyhaven.com/a/boulder_01), at about 124,000 faces, is the most realistic option to try reducing. That holds for plants and rocks, but not for the whole catalog: 140 of its 521 models are under 5,000, mostly furniture and small props. See [the review of Poly Haven as a prop source](POLY_HAVEN_PROPS.md).

### Test results

A small set was tried in the game at 1280x720 on a Radeon 680M, in a temporary copy of the project. Nothing from it is in the repository yet.

| Model | Faces | Result |
| --- | --- | --- |
| Pines, Stylized Nature MegaKit | 1,600 to 5,000 | Look much better than the current firs. 450 trees would add up to about 2 million faces, so they need lower detail versions at a distance |
| Grass, flowers, and bushes, same kit | 300 to 900 | Too bright and cartoonish as they are, and the grass is up to 1.9 m tall. They need recoloring and scaling, and they are too heavy to use in the numbers grass needs |
| Rock, same kit | 342 | Fits |
| Plaster walls, Medieval Village MegaKit | 86 to 96 per 2 m section | Timber frames and stone fit the village well and are very cheap. Roofs and corners are untested |
| Mannequin, Universal Animation Library | 13,744 | Plays its idle animation in Godot. It's a yellow test figure, so it needs a body and clothes |
| Goblin, OpenGameArt | 1,198 | Reads clearly as a goblin but has no animations. Whether the human animations can be applied to it is untested |

| Dressed villager, [MakeHuman / MPFB](https://static.makehumancommunity.org/mpfb.html) with its [CC0 system assets](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html) | 5,169 | Far closer to the realistic look. Walk, idle, sword, and roll work with the Universal Animation Library through Godot's retargeting. Its eyes look too dark, it has no eyebrows yet, and the clothes are modern ([#76](https://github.com/Gamperle/Erlenfall/issues/76)) |

**Getting the packs.** OpenGameArt has CC0 copies of the [nature](https://opengameart.org/content/stylized-nature-megakit), [village](https://opengameart.org/content/medieval-village-megakit), and [animation](https://opengameart.org/content/universal-animation-library) packs, each with a CC0 `License` file inside. These contain only the free part of each pack. The base characters and fantasy outfits aren't there, and their itch.io pages couldn't be opened by a script ([#66](https://github.com/Gamperle/Erlenfall/issues/66)).

**License warning.** Quaternius's pack pages say CC0, but the site also has a [Quaternius Asset License](https://quaternius.com/license.html), dated 2026-08-28, that forbids redistributing assets on their own, even modified. A public repository may count as that, so only use copies that include a CC0 license file, and record that file with each asset ([#66](https://github.com/Gamperle/Erlenfall/issues/66)).

**Consistency.** These packs are stylized, while the game aims for a grounded look. Using one creator's packs for characters, plants, and buildings should keep them consistent, and the first download should be a test of a few models against the new surfaces.

## Order of work

1. **Surfaces.** Done.
2. **Trees, grass, and rocks.** These take up most of the view.
3. **Buildings.** These set the village's look.
4. **Characters.** The rig must work before any of the held items can be fitted.
5. **Props.** These depend on the pipeline's open issues.
6. **Part 2.** This uses the same materials and tools as above.
