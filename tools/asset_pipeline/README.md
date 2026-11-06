# How Erlenfall makes props from text

Erlenfall's furniture, tools, and village clutter start as a sentence. FLUX.2 klein draws the object, TRELLIS.2 turns the picture into a textured, game-ready mesh, and Blender scales it to real size. This page walks through the second batch, `klein2`, which added 19 props to the village. Setup, access, and known problems are in [the pipeline reference](../../docs/ASSET_PIPELINE.md).

![A well: the drawn picture, the earlier TripoSR model, and the TRELLIS.2 model](examples/0_well_steps.jpg)

*One well, from left to right: the picture FLUX.2 klein drew, the model TripoSR made from it, and the model TRELLIS.2 made from it, both at 6,000 faces.*

## The steps

| Step | Tool | Where | Time for `klein2` |
| --- | --- | --- | --- |
| 1. Describe the objects | A batch file | Here | Minutes |
| 2. Draw 6 candidates each | FLUX.2 klein 4B (`draw_klein.py`) | Asset PC GPU | 72 pictures in 12 minutes |
| 3. Choose the best pictures | A person or agent, with `contact_sheet.py` | Here | Minutes |
| 4. Make a 3D model of each | TRELLIS.2 in ComfyUI (`run_trellis.ps1`) | Asset PC GPU | 1 to 25 minutes each, usually 3 to 9 |
| 5. Size them | Blender (`size_models.ps1`) | Asset PC CPU | Seconds each |
| 6. Place them and check | `data/village_layout.json`, `shoot_props.gd` | Here | Minutes |

The asset PC is a Windows machine with a Radeon RX 7900 XT, reached over SSH as `ASSET_PC`. Its work folder is `D:\erlenfall-assets`.

## 1. Describe the objects

A batch is a JSON file in [`batches`](batches). Each object has the subject to draw, a face budget, and its real size in meters, measured along its longest side. `turns` is optional, for models that come out facing sideways. `mode` only matters for the TripoSR fallback.

```json
{
	"seed": 7000,
	"objects": {
		"well": { "subject": "round village well with a low fieldstone wall, a small wooden shingle roof on two posts, and a wooden bucket on a rope", "faces": 6000, "meters": 2.6 },
		"crate": { "subject": "sturdy wooden crate made of rough planks, lid nailed shut", "faces": 1500, "meters": 0.7 }
	},
	"turns": { "well_1": -90 }
}
```

Every subject goes into the same style prompt, which asks for one object, straight on, on a white background. The full prompt is in [ASSETS.md](../../ASSETS.md). Candidate `n` of the object at position `i` uses seed `seed + 10 * i + n`, so give each batch a seed range no other batch uses. `klein1` used 6000 and `klein2` 7000.

Describe the shape, not just the name, such as "two large solid wooden wheels" or "lid nailed shut".

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
scp tools/asset_pipeline/{run_trellis.ps1,make_trellis.py,trellis2_api.json} ASSET_PC:D:/erlenfall-assets/
ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\run_trellis.ps1 -Batch klein2"
```

`run_trellis.ps1` starts ComfyUI on the PC, runs each picture in `klein2\input` through TRELLIS.2, and stops ComfyUI again. `-Names well_1,crate_4` limits it to some pictures. For each one, the workflow in `trellis2_api.json`:

1. removes the background with BiRefNet,
2. builds the shape in three stages, guided by DINOv3's reading of the picture,
3. remeshes it into one closed surface and reduces it to the object's face budget,
4. unwraps it and bakes base color, roughness, metallic, normal, and ambient occlusion maps at 1024 px.

Most models take 3 to 9 minutes. Small ones such as swords take about a minute, and detailed boxes such as chests and crates up to 25. The models land in `klein2\trellis`, and finished ones are skipped, so the script can be run again after a dropped connection. Long SSH sessions to this PC have dropped several times, so for a big batch, run it a few names at a time.

TRELLIS.2 sees only the front, like TripoSR did, but it gets thin parts, backs, and proportions much more right:

![TRELLIS.2 beside TripoSR for a hand cart and a crate](examples/3_trellis_vs_triposr.jpg)

*Left of each pair: TRELLIS.2. Right: TripoSR after cleanup. TripoSR's cleanup broke the crate completely.*

It does worse on loose, fibrous materials. It turned haystacks into brown lumps and gave a sack a dark pattern, so those props still use TripoSR models ([#154](https://github.com/Gamperle/Erlenfall/issues/154)). Check every model against its picture.

## 5. Size the models

```bash
ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\size_models.ps1 -Batch klein2"
```

`size_glb.py` scales each model to its real size, stands it on its base, and keeps its texture maps. TRELLIS.2 models usually face Godot's front already, but the well came out facing sideways, so `turns` in the batch file turns it by -90 degrees. Render each model from the front beside its picture to catch these.

![Some of the TRELLIS.2 props, as they face in the game](examples/4_trellis_models.jpg)

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

![The props in the village, at the goblin camp, by the forge, the furnace, the town hall, and a farm](examples/5_in_game.jpg)

Last, list every new file in [ASSETS.md](../../ASSETS.md) with its seed and subject, and run the smoke test. TRELLIS.2 models are Built with DINOv3, which ASSETS.md notes.

## Files

| File | Purpose |
| --- | --- |
| `batches/*.json` | Each batch's objects, sizes, face budgets, and turns |
| `draw_klein.py` | Draws candidates with FLUX.2 klein 4B |
| `contact_sheet.py` | Lays pictures out on one labeled page |
| `setup_comfy.ps1` | Installs ComfyUI with ROCm PyTorch and the TRELLIS.2 models |
| `run_trellis.ps1`, `make_trellis.py`, `trellis2_api.json` | Make models with TRELLIS.2 |
| `size_models.ps1`, `size_glb.py` | Scale models to real size for Godot |
| `shoot_props.gd` | Photographs placed props in the game |
| `make_models.ps1`, `run_triposr.py`, `render_preview.py`, `watchdog.ps1` | Make models with TripoSR, the fallback |
| `clean_models.ps1`, `cleanup_mesh.py`, `adjust_glb.py` | Clean and reshape TripoSR models |
| `check_mesh.py` | Prints a raw model's face count and whether it's watertight |
| `setup_pc.ps1`, `torchmcubes.py` | Set up the TripoSR and SDXL environments |
| `draw_pictures.py` | The older SDXL drawing script, kept for reference |

The example pictures are in [`examples`](examples). Its `.gdignore` keeps them out of the game.
