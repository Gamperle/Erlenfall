# TASK: 3D Fantasy Crafting RPG (Godot)

## The idea so far

- 3D fantasy RPG with a small open world centered on one small village
- Story: bring the village back on its feet and grow it into a small town
- Gameplay: mainly crafting by making objects (smithing, alchemy, other crafts), with a little combat
- Engine: Godot
- Open source, synced to GitHub (account: `Gamperle`)

## Current state

These questions have been answered. The results are in [the game design document](docs/GAME_DESIGN.md), which also lists the open questions and milestones.

## How to answer

Write your answer under each question, or tick a box. **Suggested** is what I will assume if you leave a question blank, so you only need to answer where you disagree. Questions marked ⭐ shape the project the most.

---

## 1. Scope and goals

1. ⭐ What is this project to you: a hobby to learn and enjoy, a game to finish and release for free, or something you may sell later?
   - Suggested: a hobby project that ends in a free release.
   - Answer:
2. ⭐ How long should a full playthrough last?
   - [ ] 1-2 hours
   - [x] 5-10 hours (suggested)
   - [ ] 20+ hours
   - [x] Endless sandbox after the story ends
3. How much time can you put in per week, and who is working on it (just you and Claude, or others too)?
   - Answer: just me and claude
4. What is your experience with Godot, programming, and 3D modeling?
   - Answer: godot minimal, programming very good, 3d modeling only limited cad
5. Which existing games are closest to what you imagine, and what do you like about each? (For example: Dragon Quest Builders, Fable, Kingdom Come: Deliverance, Stardew Valley, My Time at Portia, Valheim, Potion Craft.)
   - Answer: my time at portia but much more realistic optic style
6. What should the first playable version contain?
   - Suggested: one part of the village, one craft (smithing), one enemy type, ,and one quest that repairs a building.
   - Answer: yes

## 2. Story and world

7. ⭐ What happened to the village: war, plague, a curse, a monster, economic collapse, or a natural disaster?
   - Answer: landslide of a mountain destroyed the main access to the village, its now more remote location and isolation caused many people to leave and buildings to fal into despair. The landslide also destroyed the main village income the mine. Now only wood farming are remaining as icnome.
8. Who is the player, and why do they come or stay? (For example: an heir to a ruined forge, a returning native, an exiled apprentice.)
   - Answer: Inhereted their late gradnfathers house, came to support grandma and cousin
9. Is there a main antagonist or threat, or is the rebuilding itself the conflict?
   - Answer: no real antagonist just people with different agencies, one major issue is the current mayor who is eeled  threatened by the new engament of the protagonist but he will come around eventually
10. What is the tone?
    - [ ] Cozy and warm
    - [X] Hopeful with some darker moments (suggested)
    - [ ] Grim and low fantasy
    - [ ] Humorous
11. How magical is the world: no visible magic, subtle magic, or high fantasy with creatures and spells?
    - Answer: high fantasy but magic ids not all powerfull
12. How should the story be delivered?
    - [ ] Linear main story
    - [x] Main story with player choices that change how the town develops (suggested)
    - [ ] Multiple endings
13. How large is the world, and which areas surround the village? (For example: forest, mine, ruins, river, swamp.)
    - Suggested: about 1 km x 1 km, walkable end to end in 5 minutes.
    - Answer: that fine sofar, only after filling the world we shall expand further
14. What languages should the game support at launch?
    - Suggested: English first, built so that translations can be added later.
    - Answer: english and german

## 3. Crafting (core gameplay)

15. ⭐ How should crafting play?
    - [ ] Hands-on minigames, such as hammering hot metal in rhythm or mixing potions by hand (suggested)
    - [ ] Menu-based recipes with materials and a timer
    - [ ] Free experimentation, where you combine things and discover results
    - [x] A mix (say which) Free experimentation with minigames
16. Which crafts do you want? Tick all that apply and underline the ones needed at launch.
    - [ ] Smithing
    - [ ] Alchemy
    - [ ] Carpentry
    - [ ] Cooking
    - [ ] Tailoring and leatherwork
    - [ ] Pottery
    - [ ] Enchanting
    - [ ] Jewelry
    - Other: all of them
    - Suggested: smithing, alchemy, and carpentry at launch. yes
17. Does item quality matter, so that better work or materials give better items?
    - Suggested: yes, with a few quality tiers.
    - Answer: yes with tiers
18. Can players customize what they make (shapes, parts, materials), and should it change the 3D model?
    - Suggested: yes for a few parts, such as a blade and a handle.
    - Answer: yes as you suggest
19. How do players get materials: mining, chopping, foraging, farming, hunting, trading, or a combination?
    - Answer: both shall be viable
20. How does the player get better: skill levels from practice, recipes from NPCs, teachers, or better tools and workshops?
    - Answer: from pratice and tools and processing items, and impovement items

## 4. Building up the village

21. ⭐ How does the village grow?
    - [x] Scripted: complete quests and buildings get repaired in set places (suggested)
    - [ ] Semi-free: choose what to build on fixed plots
    - [ ] Free: place buildings anywhere
22. Does the player physically take part in construction, or deliver materials and let NPCs do the work?
    - Answer: he shall add parts to it or deliver raw meterial to a redident smith and such
23. What marks the path from village to town? (For example: population, new shops, walls, a market, a town hall, a change of title.)
    - Answer: pops and buildings yes, and a wall
24. Should NPCs have daily routines, friendships, and personal quests?
    - Suggested: simple routines and a personal quest for each key character. Roughly 10-15 named NPCs.
    - Answer: yes
25. Is there a town economy: selling goods, shops the player supplies, taxes, or resource management?
    - Answer: yes
26. Can the town suffer setbacks (raids, poor harvests), or does progress only go forward?
    - Answer: yes but scripted so far

## 5. Combat

27. ⭐ What kind of combat?
    - [x] Simple real-time action: attack, block, dodge (suggested)
    - [ ] Souls-like and demanding
    - [ ] Turn-based
    - [x] Avoidable, with options to sneak or talk
28. What weapons and abilities are there: melee only, bows, thrown potions, or magic?
    - Suggested: melee and thrown potions, so that crafted items drive combat.
    - Answer: all
29. What share of play time should combat take, and can the player die? What happens if they do?
    - Suggested: about 15%; on death you wake up in the village and lose some gathered materials.
    - Answer: yes
30. What do you fight: wolves and bandits, monsters, bosses?
    - Answer: mostly non humans, animals goblins etc, humans only rarely

## 6. Look, sound, and camera

31. ⭐ What art style?
    - [x] Low-poly and stylized (suggested: realistic for a small team, and free assets exist)
    - [ ] Hand-painted stylized
    - [ ] Pixelated 3D (PS1 style)
    - [ ] Realistic (much more work and harder to keep consistent)
32. ⭐ Where should the art come from?
    - [ ] Free CC0 packs first (for example Kenney, Quaternius), replaced over time (suggested)
    - [ ] You make models in Blender
    - [ ] Community or commissioned artists
    - [x] AI-generated assets (these can raise licensing and contributor concerns)
33. Which camera?
    - [x] Third person (suggested)
    - [x] First person
    - [ ] Fixed isometric or top-down
34. Should there be a day/night cycle, weather, and seasons?
    - Suggested: day/night and simple weather; no seasons at first.
    - Answer: yes
35. Where should music and sound come from: free libraries, your own work, or a contributor? Do you want voice acting?
    - Suggested: CC0 or CC-BY libraries, with no voice acting.
    - Answer: free libraries , this hall be a non commercial open source project

## 7. Platforms and technical choices

36. Which platforms?
    - [x] Linux and Windows (suggested)
    - [ ] macOS
    - [ ] Steam Deck
    - [x] Web
    - [ ] Mobile or console (note: console releases conflict with open tooling and need paid or licensed porting)
37. Which input devices: keyboard and mouse only, or controller as well?
    - Suggested: both.
    - Answer: both
38. What is the minimum hardware to target? Does the game need to run on integrated graphics?
    - Suggested: yes, integrated graphics from about the last 8 years.
    - Answer: yes
39. Which programming language?
    - [ ] GDScript (suggested: built into Godot, simplest setup and export)
    - [ ] C#
    - [x] GDScript plus C++ (GDExtension) where performance requires it
40. Which Godot version?
    - Suggested: the latest stable 4.x release, pinned for the project and upgraded on purpose.
    - Answer: yes
41. Single-player only, or multiplayer/co-op? Adding multiplayer later is very expensive, so this needs deciding now.
    - Suggested: single-player only.
    - Answer: yes, maybe online coop in future
42. How should saving work: anywhere, at a bed or checkpoint, or both with autosave?
    - Suggested: autosave plus manual save at a bed.
    - Answer: yes
43. Should the game support mods?
    - Suggested: keep items, recipes, and quests in data files so modding stays possible, with no official mod support at launch.
    - Answer: yes

## 8. Open source and GitHub

44. ⭐ Which license for the code?
    - [x] MIT: anyone can reuse it, including in closed-source games (suggested)
    - [ ] GPLv3: changes and derivatives must stay open source
    - [ ] Other:
45. ⭐ Which license for art, music, and story?
    - [x] CC BY-SA 4.0: open, with credit, and derivatives must share alike (suggested)
    - [ ] CC BY 4.0: open, with credit
    - [ ] CC0: no conditions
    - [ ] Keep story and art under all rights reserved, with only the code open
46. What are the game's working title and the GitHub repository name?
    - Suggested repository: `Gamperle/3DRPGGAME` until a title is chosen.
    - Answer:suggest a better placeholder name
47. Should the repository be public from day one, or private until the first playable version?
    - Suggested: public from day one.
    - Answer: yes
48. Do you want outside contributors? If so, I will add contribution guidelines and an issue tracker with labels.
    - Answer: yes
49. How should large binary files (models, textures, audio) be stored?
    - Suggested: Git LFS. Note that the GitHub free tier has limited LFS storage and bandwidth.
    - Answer: yes
50. Do you want GitHub Actions to build Linux and Windows versions automatically and publish releases?
    - Suggested: yes, once a first playable version exists.
    - Answer: yes
51. How should changes reach GitHub?
    - [ ] Claude commits and pushes to `main` directly
    - [x] Claude works on a branch and opens a pull request for you to review (suggested)
    - [ ] Claude commits locally and you push
52. Where do you want to release it: GitHub Releases, itch.io, or Steam? (Steam charges a fee per game.)
    - Suggested: GitHub Releases and itch.io.
    - Answer: so far only github

## 9. Working together

53. Which decisions do you want to make yourself, and what should I just decide? (For example: story and character writing, game balance, code architecture.)
    - Answer: story we will discuss at some point
54. Do you want to write the story and dialogue, or should I draft them for your review?
    - Answer: draft some for the mvp
55. May I install Godot and Blender on this machine, and do you prefer a particular way of installing (official download, Flatpak, Steam)?
    - Answer: do as you prefer
56. How would you like to test progress: after each small feature, or at larger milestones?
    - Answer: after milestones

## 10. Anything else

57. Is there anything you definitely do **not** want in this game?
    - Answer: 
58. Is there one scene or moment you already picture when you imagine this game?
    - Answer: walking into a small village which some outlier farms sorrounded by high mysti mountains and an npc greeting you gratefully for your work

---

## Next steps after you answer

1. Turn your answers into a game design document.
2. Set up the Godot project, git, the license, and the GitHub repository.
3. Plan milestones, starting with the first playable version.
