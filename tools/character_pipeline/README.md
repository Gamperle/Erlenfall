# Character pipeline

Builds rigged villagers from short recipes. Everything used is CC0, so the results can be stored in this repository under [ASSETS.md](../../ASSETS.md).

**Status: experimental.** The villagers, the player, and goblins are in the game, behind the `realistic_villagers`, `realistic_player`, and `realistic_enemies` flags. See [#76](https://github.com/Gamperle/Erlenfall/issues/76).

## Setup

1. Install Blender 5.2 and the [MPFB](https://extensions.blender.org/add-ons/mpfb/) extension.
2. Download these CC0 packs from [MakeHuman's asset packs](https://static.makehumancommunity.org/assets/assetpacks.html) and unzip them, outside the repository: MakeHuman system assets, Bodyparts 05, Pants 01, Shirts 01, Skirts 01, and Suits 02.

Only use packs marked CC0. Packs marked CC-BY need credit and aren't used here.

## Building

```bash
blender --background --python build_character.py -- villagers.json hedda /path/to/packs /path/to/hedda.glb
```

The packs argument can list several folders, separated by commas.

## Budget

Each character is about 15,000 triangles with 1024-pixel textures. A test with 50 animated characters on a Radeon 680M at 1280x720 ran at about 130 FPS. Results are in [#76](https://github.com/Gamperle/Erlenfall/issues/76).

## Checking from all sides

`turntable.gd` shows each character in a folder in turn and saves 8 views, 45 degrees apart, plus one sheet per character with all 8. Run it from a Godot project that has imported the characters:

```bash
godot --path . --script res://tools/character_pipeline/turntable.gd -- res://path/to/characters /path/to/output res://path/to/animations.glb
```

The animation library is optional. With one, characters stand in the first frame of its `Idle` animation, and they need the import settings below.

## Recipes

| Key | Meaning |
| --- | --- |
| `id` | The character's name |
| `shape` | MPFB body settings, such as `gender`, `age`, `muscle`, and `weight`, from 0 to 1. An `age` of 0.5 is a young adult, and values near 0.3 look like a child |
| `skin` | Skin material |
| `clothes` | Clothes and shoes |
| `footwear` | Which clothes reach the ground |
| `colors` | Plain sRGB colors that replace a part's printed pattern |
| `tucked` | Layers cut off where another layer covers them, as `{ "under": "over" }` |
| `covered_by` | Parts removed where another part covers them, as `{ "hidden": "over" }` |
| `under_hem` | Lower layers cut off under a top's hem, as `{ "under": "top" }` |
| `trim_above` | Parts cut off above a height in meters, such as shoe shafts inside pants |
| `hair`, `hair_color` | Hair, and an optional sRGB color to repaint it |
| `beard` | Beard or moustache |
| `smooth_chest` | Tight clothes whose chest area is smoothed |
| `brows`, `eyes` | Eyebrows and eyes |

## Importing into Godot

Set these on the model's `Skeleton3D` in the import settings, for both the characters and the animation library:

- **Bone map:** use `SkeletonProfileHumanoid`. On characters, leave the finger bones out, because the animations' finger poses turn the hands into claws. They then keep their relaxed rest pose.
- **Silhouette fix:** turn it on, with a threshold of 3 degrees, since the bodies rest in an A-pose.

- **Posture:** the animations lean these bodies forward, and by a different amount for each body. `scripts/world/posture_modifier.gd` measures the first pose of each character and turns the back and neck back to the bodies' own rest posture, in every animation. `CharacterModel` and `turntable.gd` add it.

## Goblin

`build_goblin.py` exports the OpenGameArt goblin. Its proportions don't work with the human animations, so `scripts/world/creature_model.gd` poses its bones in code.

## Things that went wrong

To tell whether a flaw comes from the assets or this script, add `full` to the end of the build command. It skips removing hidden parts and all reduction.

- **Severe stretching:** the bones didn't line up with the mesh. `stand_on_ground` moves the bones and the mesh together.
- **Hunched shoulders:** without MakeHuman's joint helpers, MPFB gives every body its default skeleton, with the shoulders and neck in the wrong places. `create_human` keeps the helpers, so the rig fits each body.
- **Dark eyes, hidden eyebrows:** materials were exported as blended, which Godot can't sort. `finish_materials` makes them opaque or cut out.
- **Skin through clothes:** `remove_covered` deletes the body under clothes before reducing it, but keeps a margin at cuffs, collars, and hems. Without the margin, there are gaps at the wrists and neck. It also never removes the head or neck, because a hole there shows the red inside of the mouth.
- **Spiky hands:** reducing the whole body at once destroys the fingers. `reduce_body` gives hands and the head their own budgets.
