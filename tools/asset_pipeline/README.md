# How Erlenfall makes props from text

Erlenfall's furniture, tools, and village clutter start as a sentence. A picture model draws the object, an image-to-3D model turns the picture into a mesh, and Blender cleans the mesh for the game. This page walks through the second batch, `klein2`, which added 19 props to the village. Setup, access, and known problems are in [the pipeline reference](../../docs/ASSET_PIPELINE.md).

![A well at each step: the drawn picture, TripoSR's raw model, and the cleaned model](examples/0_well_steps.jpg)

*One well, from left to right: the picture FLUX.2 klein drew, the raw model TripoSR made from it, and the cleaned model at 6,000 faces.*

## The steps

| Step | Tool | Where | Time for `klein2` |
| --- | --- | --- | --- |
| 1. Describe the objects | A batch file | Here | Minutes |
| 2. Draw 6 candidates each | FLUX.2 klein 4B (`draw_klein.py`) | Asset PC GPU | 72 pictures in 12 minutes |
| 3. Choose the best pictures | A person or agent, with `contact_sheet.py` | Here | Minutes |
| 4. Make a 3D model of each | TripoSR and `rembg` (`make_models.ps1`) | Asset PC GPU and CPU | 24 models in about an hour |
| 5. Clean and size them | Blender (`clean_models.ps1`, `size_models.ps1`) | Asset PC CPU | 24 models in 11 minutes |
| 6. Place them and check | `data/village_layout.json`, `shoot_props.gd` | Here | Minutes |

The asset PC is a Windows machine with a Radeon RX 7900 XT, reached over SSH as `ASSET_PC`. Its work folder is `D:\erlenfall-assets`.

## 1. Describe the objects

A batch is a JSON file in [`batches`](batches). Each object has the subject to draw, a face budget, and its real size in meters, measured along its longest side. `mode` is optional: `long` stands thin objects like swords on end, and `keep` skips straightening.

```json
{
	"seed": 7000,
	"objects": {
		"well": { "subject": "round village well with a low fieldstone wall, a small wooden shingle roof on two posts, and a wooden bucket on a rope", "faces": 6000, "meters": 2.6 },
		"goblin_tent": { "subject": "small crude tent made of patched brown animal hides stretched over wooden poles", "faces": 4000, "meters": 2.4, "mode": "keep" }
	}
}
```

Every subject goes into the same style prompt, which asks for one object, straight on, on a white background. The full prompt is in [ASSETS.md](../../ASSETS.md). Candidate `n` of the object at position `i` uses seed `seed + 10 * i + n`, so give each batch a seed range no other batch uses. `klein1` used 6000 and `klein2` 7000.

Describe the shape, not just the name. "Two large solid wooden wheels" gave carts that TripoSR could rebuild, while thin spokes and ropes tend to melt.

## 2. Draw candidates

Copy the batch and the script over, then draw:

```bash
scp tools/asset_pipeline/batches/klein2.json ASSET_PC:D:/erlenfall-assets/batches/
scp tools/asset_pipeline/draw_klein.py ASSET_PC:D:/erlenfall-assets/
ssh ASSET_PC "Set-Location D:\erlenfall-assets; \$env:HF_HOME='D:\erlenfall-assets\hf-cache-bakeoff'; venv-bakeoff\Scripts\python.exe draw_klein.py klein2"
```

The first picture takes about a minute while the model loads, and each one after that about 9 seconds. Existing pictures are skipped, so a dropped connection costs nothing.

![Six candidates for the well](examples/1_well_candidates.jpg)

## 3. Choose the best pictures

Copy the candidates back and lay each object out on one page:

```bash
scp "ASSET_PC:D:/erlenfall-assets/klein2/candidates/*.png" candidates/
python3 tools/asset_pipeline/contact_sheet.py wells.jpg 6 220 candidates/well_*.png
```

Pick pictures that show the whole object from the front, with solid parts and nothing else in the frame. Keeping two per object leaves a spare if a model fails. Copy the chosen ones to `klein2\input` on the PC.

![The first choice for each object in klein2](examples/2_batch_choices.jpg)

FLUX.2 klein drew the right object in all 72 `klein2` candidates. It ignored "unlit" for the campfire, which suits a goblin camp anyway.

## 4. Make the models

```bash
ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\make_models.ps1 -Batch klein2"
```

TripoSR builds each model from its single picture, bakes a texture, and Blender renders a front and back preview. Each model takes 2 to 3 minutes, mostly for texture baking. Runs sometimes crash at startup on this PC, and the script retries them. In `klein2` all 24 worked on the first attempt. Run `watchdog.ps1` beside a long batch to stop runs that hang.

![The raw models for klein2](examples/3_raw_models.jpg)

The raw models have 50,000 to 500,000 faces and are often tilted. Their backs are guesses, because TripoSR only sees the front.

## 5. Clean and size the models

```bash
ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\clean_models.ps1 -Batch klein2"
ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\size_models.ps1 -Batch klein2"
```

`cleanup_mesh.py` removes loose bits, straightens the model, reduces it to its face budget, and bakes the detail into a new texture. `size_glb.py` then scales it to its real size and turns its front toward Godot's front. Put names in `klein2\keep.txt`, one per line, to clean only those.

Check the cleaned previews before using them. In `klein2`, straightening tipped both tents over, because it lines up the largest surfaces with the axes and a tent's sides slope. Those got `"mode": "keep"`. One crate came out as a black, broken shape, so the other crate is used in both places.

![The cleaned models for klein2](examples/4_cleaned_models.jpg)

## 6. Place them and check

Copy the files from `klein2\props` into `assets/props`, and add each one to `props` in `data/village_layout.json`. A prop can be placed in world coordinates, relative to a building, or on top of another prop:

```json
{"model": "well_1", "x": -6, "z": -6},
{"model": "crate_4", "building": "inn", "x": 4.4, "z": 6.3},
{"model": "bowl_1", "x": -0.3, "z": 0, "on": "desk_0"}
```

Interactive objects such as the bed and furnace take the model as `"asset"` in their own entries. Props 0.6 m or larger get a collision box.

Then photograph them in the game. Each shot takes a name, the point to look at, the camera's distance and height, and the direction it looks from:

```bash
godot --path . --script res://tools/asset_pipeline/shoot_props.gd -- shots square -5 -4 9 2.5 210 goblin_camp 118 -148 13 4 0
```

![The new props in the village, at the goblin camp, at a farm, by the inn, by the forge, and the new furnace](examples/5_in_game.jpg)

Last, list every new file in [ASSETS.md](../../ASSETS.md) with its seed and subject, and run the smoke test.

## Files

| File | Purpose |
| --- | --- |
| `batches/*.json` | Each batch's objects, sizes, and face budgets |
| `draw_klein.py` | Draws candidates with FLUX.2 klein 4B |
| `contact_sheet.py` | Lays pictures out on one labeled page |
| `make_models.ps1`, `run_triposr.py`, `render_preview.py` | Make models and previews with TripoSR |
| `watchdog.ps1` | Stops hung TripoSR runs |
| `clean_models.ps1`, `cleanup_mesh.py` | Straighten, reduce, and re-bake models |
| `size_models.ps1`, `size_glb.py` | Scale models to real size for Godot |
| `adjust_glb.py` | Stretches sword blades and thins walls, for objects TripoSR gets out of proportion |
| `shoot_props.gd` | Photographs placed props in the game |
| `check_mesh.py` | Prints a raw model's face count and whether it's watertight |
| `setup_pc.ps1`, `torchmcubes.py` | Set up the asset PC |
| `draw_pictures.py` | The older SDXL drawing script, kept for reference |

The example pictures are in [`examples`](examples). Its `.gdignore` keeps them out of the game.
