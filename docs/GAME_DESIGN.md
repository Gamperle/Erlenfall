# Erlenfall: Game Design Document

Status: first draft, based on the answers in [TASK.md](../TASK.md). "Erlenfall" is a placeholder for both the game and the village. It reads naturally in English and German (*Erle* = alder, *Fall* = fall, as in the rockfall).

## Pitch

You inherit your late grandfather's house in a mountain village that a landslide cut off from the world. By forging, brewing, and building with your own hands, you help the people who stayed bring Erlenfall back to life, until it becomes a walled small town.

Reference: *My Time at Portia*, with a much more realistic look.

Project type: free, open-source hobby project by one developer and Claude, open to contributors.

## Defining moment

You walk into a small village with a few outlying farms, surrounded by high, misty mountains, and an NPC greets you with gratitude for your work. Every part of the game should build toward this feeling.

## Story

**Background.** A landslide destroyed the main road into Erlenfall and buried the mine, the village's main income. Isolated and poorer, many people left and buildings fell into disrepair. Only wood and farming remain.

**Player.** The player inherits their late grandfather's house and comes to support their grandmother and cousin.

**Conflict.** There is no villain, only people with different interests. The main obstacle is the current mayor, who feels threatened by the newcomer's engagement but comes around eventually.

**Tone.** Hopeful, with some darker moments. The world is high fantasy, but magic is limited and solves no problem by itself.

**Structure.** A main story of 5-10 hours with player choices that change how the town develops, followed by an endless sandbox.

## World

- About 1 km x 1 km, walkable end to end in about 5 minutes. Expand only once this area is full.
- The village at the center, outlying farms, forest, the buried mine, and the landslide site, ringed by mountains.
- Day/night cycle and simple weather. No seasons at first.

## Crafting

Crafting is the core of the game. It combines **free experimentation** (combine materials to discover results) with **minigames** (the quality of your hands-on work affects the result).

| Phase | Crafts |
| --- | --- |
| First playable | Smithing |
| Launch | Smithing, alchemy, carpentry |
| Later | Cooking, tailoring and leatherwork, pottery, enchanting, jewelry |

- **Quality:** items have tiers, determined by materials and minigame performance.
- **Customization:** selected parts, such as blade and handle, can be chosen and change the 3D model.
- **Materials:** gathering (mining, chopping, foraging, farming, hunting) and trading are both viable.
- **Progression:** skill grows through practice, better tools, processed materials, and improvement items.

## Village development

- **Scripted growth:** quests repair and add buildings at set places.
- **Taking part:** the player adds parts to a building or delivers raw materials to a resident such as the smith.
- **Village to town:** marked by population, new buildings, and a town wall.
- **NPCs:** 10-15 named characters with simple daily routines, friendships, and personal quests.
- **Economy:** selling goods, supplying shops, taxes, and resource management.
- **Setbacks:** scripted story events for now, such as raids or poor harvests.

## Combat

Combat is about 15% of play time and is simple, real-time, and often avoidable.

- Attack, block, and dodge, with options to sneak or talk.
- Melee, bows, thrown potions, and magic, which are added gradually (see Milestones). Crafted items drive combat.
- Enemies are mostly animals, goblins, and other non-humans. Human enemies are rare.
- On death, you wake up in the village and lose some gathered materials.

## Presentation

- **Camera:** switchable third and first person.
- **Audio:** free libraries, with no voice acting.
- **Languages:** English and German from the start. All player-facing text goes through translation keys.

## Technical decisions

| Topic | Decision |
| --- | --- |
| Engine | Godot 4.7.2 stable, upgraded on purpose |
| Language | GDScript; C++ (GDExtension) only where profiling shows a need |
| Renderer | Forward+ on desktop, with quality settings for integrated graphics |
| Platforms | Linux and Windows; a reduced Web build later |
| Input | Keyboard and mouse, and controller |
| Saving | Autosave, plus manual save at a bed |
| Multiplayer | Single-player. Possible online co-op later, so game state stays separate from presentation where this costs little, without building networking now |
| Mods | No official support at launch, but items, recipes, and quests live in data files |
| Licenses | Code: MIT. Art, music, and story: CC BY-SA 4.0 |
| Large files | Git LFS |
| Releases | GitHub Releases, built by GitHub Actions |
| Workflow | Branches and pull requests, tested by you at milestones |

## Resolved conflicts in the answers

These answers pulled against each other. The decision below applies until you change it.

1. **Art style.** "Much more realistic than Portia" and the ticked "low-poly and stylized" conflict. Decision: **grounded stylized**, with realistic proportions, materials, and lighting, at moderate polygon counts. This fits the misty mountain scene and integrated graphics.
2. **Web vs. look and C++.** Web builds only support Godot's simpler Compatibility renderer, and C++ extensions need a separate Web build. Decision: **desktop comes first**. Web is a reduced build that starts after the first playable version.
3. **Scope of combat and crafts.** "All" weapons and eight crafts are long-term goals. Decision: they are added in stages, so the first version stays achievable.

## Open questions for you

1. **Time per week** (question 3) and **anything you do not want** (question 57) were left blank. Neither blocks work.
2. **Story.** To discuss at a later point, as you asked. Claude drafts the first-playable dialogue for your review.

## Licensing and AI assets

**Commercial use.** The project itself is free and non-commercial. MIT and CC BY-SA allow others to sell copies or derivatives, and that is accepted.

**AI asset tool.** Generation runs locally on an AMD Radeon RX 7900 XT. The default for milestone 6 is [TripoSR](https://github.com/VAST-AI-Research/TripoSR) (MIT), which uses about 6 GB of video memory and has no hard dependency on NVIDIA libraries in its requirements. It targets CUDA, so running it through AMD's ROCm has to be tested first; milestone 6 starts with that test. Its output is draft quality, so expect cleanup in Blender. TRELLIS and TRELLIS.2 are MIT-licensed but require an NVIDIA GPU, and Hunyuan3D is not an option because its license excludes the EU, the UK, and South Korea.

Realistic surfaces can come from CC0 material libraries such as [Poly Haven](https://polyhaven.com/), which suit the art style better than draft-quality generated textures.

Until then, the game's art is built in code from simple shapes and procedural materials (`scripts/world/model_builder.gd`, `scripts/world/humanoid.gd`, `shaders/`). To test the generator, see [tools/asset_test](../tools/asset_test/README.md). AI assets need rigging and style checks, and their copyright status varies by country and tool, so each one is logged in [ASSETS.md](../ASSETS.md).

## Milestones

Each milestone ends with a playable build for you to test.

| # | Milestone | Done when |
| --- | --- | --- |
| 0 | Foundation | The project opens and runs, with repository, licenses, and languages set up |
| 1 | Walk the valley | You can walk through a placeholder village and terrain in both camera modes, with day/night, on keyboard and controller |
| 2 | First forge | You can gather ore, smelt it, and forge an item through a minigame, with quality tiers and data-driven recipes |
| 3 | First friends | Dialogue and quest systems work in both languages, with the grandmother, cousin, mayor, and smith |
| 4 | First fight | Attack, block, and dodge work against one enemy type, and death returns you to the village |
| 5 | **First playable** | One part of the village, smithing, one enemy type, and one quest that repairs a building play from start to finish, with save and load, built automatically for Linux and Windows |
| 6 | Real look | A consistent art style and asset pipeline replace the placeholders, including the misty mountain scene |
| 7 | Launch crafts | Alchemy, carpentry, and free experimentation are added, along with thrown potions |
| 8 | The living village | NPC routines, personal quests, the economy, and scripted setbacks work |
| 9 | Village to town | The full 5-10 hour story, the town wall, player choices, and sandbox play are complete |
| 10 | Beyond | Remaining crafts, bows, magic, Web build, and possible world expansion or co-op |
