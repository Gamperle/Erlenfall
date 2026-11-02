# Character pipeline

Builds rigged villagers from short recipes. Everything used is CC0, so the results can be stored in this repository under [ASSETS.md](../../ASSETS.md).

**Status: experimental.** No character is in the game yet. See [#76](https://github.com/Gamperle/Erlenfall/issues/76).

## Setup

1. Install Blender 5.2 and the [MPFB](https://extensions.blender.org/add-ons/mpfb/) extension.
2. Download these CC0 packs from [MakeHuman's asset packs](https://static.makehumancommunity.org/assets/assetpacks.html) and unzip them, outside the repository: MakeHuman system assets, Pants 01, Shirts 01, and Skirts 01. The men's recipes will also need Suits 02 and Bodyparts 05.

Only use packs marked CC0. Packs marked CC-BY need credit and aren't used here.

## Building

```bash
blender --background --python build_character.py -- villagers.json hedda /path/to/packs /path/to/hedda.glb
```

The packs argument can list several folders, separated by commas.

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
| `hair`, `hair_color` | Hair, and an optional sRGB color to repaint it |
| `brows`, `eyes` | Eyebrows and eyes |

## Importing into Godot

Set these on the model's `Skeleton3D` in the import settings, for both the characters and the animation library:

- **Bone map:** use `SkeletonProfileHumanoid`. On characters, leave the finger bones out, because the animations' finger poses turn the hands into claws. They then keep their relaxed rest pose.
- **Silhouette fix:** turn it on, with a threshold of 3 degrees, since the bodies rest in an A-pose.

## Things that went wrong

- **Severe stretching:** the bones didn't line up with the mesh. `stand_on_ground` keeps them aligned.
- **Dark eyes, hidden eyebrows:** materials were exported as blended, which Godot can't sort. `finish_materials` makes them opaque or cut out.
- **Skin through clothes:** `remove_covered_skin` deletes the body under clothes before reducing it.
- **Spiky hands:** reducing the whole body at once destroys the fingers. `reduce_body` gives hands and the head their own budgets.
