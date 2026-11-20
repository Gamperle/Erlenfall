# Asset generation pipeline

This pipeline makes 3D props from text. FLUX.2 klein 4B draws a picture, TRELLIS.2 turns it into a textured, game-ready mesh through ComfyUI, and Blender scales it to real size. It runs on a Windows PC with an AMD Radeon RX 7900 XT, controlled over SSH. TripoSR, the earlier image-to-3D model, remains as a fallback.

**Status: in use for props.** Every generated prop in the game is listed in [ASSETS.md](../ASSETS.md). SDXL output is not used (see "SDXL license" below). [The pipeline's README](../tools/asset_pipeline/README.md) walks through a batch with pictures.

Every picture and model should match [the art style guide](ART_STYLE.md): its palette, size and face-budget table, and the image prompt template.

## Workflow

| Step | Tool | Runs on | Time per item | Output |
| --- | --- | --- | --- | --- |
| Draw candidates | FLUX.2 klein 4B (`draw_klein.py`) | GPU | About 9 s, 7.9 GB | `<batch>\candidates\<object>_<n>.png` |
| Choose pictures | A person or agent | | | `<batch>\input\` |
| Make the model | TRELLIS.2 in ComfyUI (`run_trellis.ps1`, `make_trellis.py`) | GPU | 1 to 25 minutes, usually 3 to 9 | `<batch>\trellis\<name>.glb` |
| Set real size | Blender (`size_models.ps1`, `size_glb.py`) | CPU | Seconds | `<batch>\props\<name>.glb` |

TRELLIS.2 removes the background with BiRefNet, builds the shape in three stages, remeshes it into one closed surface, reduces it to the object's face budget, unwraps it, and bakes base color, roughness, metallic, normal, and ambient occlusion maps at 1024 px. No separate cleanup is needed. After sizing, `tools/asset_pipeline/shrink_textures.py` shrinks the textures of props up to 1.25 m to 512 px and keeps 1024 px for larger ones (#426).

The scripts are in [tools/asset_pipeline](../tools/asset_pipeline):

| File | Purpose |
| --- | --- |
| `batches/*.json` | Each batch's objects, with subject, face budget, real size, and first seed |
| `draw_klein.py` | Draws candidates for a batch with FLUX.2 klein |
| `contact_sheet.py` | Puts candidates or previews on one labeled page |
| `render_glb.py` | Renders a model from the front, side, and back in Blender, to compare it with its picture |
| `setup_comfy.ps1` | Installs ComfyUI with ROCm PyTorch and downloads the TRELLIS.2 models |
| `run_trellis.ps1`, `make_trellis.py`, `trellis2_api.json` | Start ComfyUI, make a batch's models, and stop it again |
| `size_models.ps1`, `size_glb.py` | Scale models to real size and turn them to face Godot's front |
| `polyhaven_prop.py` | Turns a Poly Haven glTF model into a single-surface prop (see "Poly Haven props") |
| `shoot_props.gd` | Photographs placed props in the game |
| [`tools/prop_tuner`](../tools/prop_tuner) | A scene for correcting each prop's size and height against the player, saved to `data/prop_tuning.json` |
| `setup_pc.ps1` | Installs the TripoSR and SDXL environments |
| `bench_bake.py` | Times the parts of TripoSR texture baking and writes variants for comparison |
| `make_models.ps1`, `make_masks.py`, `run_triposr.py`, `render_preview.py`, `watchdog.ps1`, `torchmcubes.py` | Make models with TripoSR, the fallback (BiRefNet masks) |
| `clean_models.ps1`, `cleanup_mesh.py`, `adjust_glb.py` | Clean TripoSR models, and reshape ones it gets out of proportion |
| `check_mesh.py` | Prints a raw model's face count and whether it's watertight |
| `draw_pictures.py` | The older SDXL drawing script, kept for reference |

## Poly Haven props

`tools/asset_pipeline/polyhaven_prop.py` turns a model from [Poly Haven](https://polyhaven.com/models) (CC0, see [POLY_HAVEN_PROPS.md](POLY_HAVEN_PROPS.md)) into a prop that passes the smoke test's one-mesh, one-textured-surface check (#220). It needs only Python with numpy and Pillow, not Blender or the asset PC:

```
python3 tools/asset_pipeline/polyhaven_prop.py painted_wooden_stool --provenance
```

It downloads the glTF from Poly Haven's public API (checking each file's MD5), bakes the node transforms and merges all meshes into one, and merges the materials into one: a single material keeps its UVs, several are packed into one atlas of base color, normal and ORM (occlusion, roughness, metal) maps. Parts whose material is see-through (glass) are left out, unless `--keep-blend` draws them opaque. Models over 3,000 faces (`--faces`) are reduced by quadric edge collapse that keeps UV islands, open edges and winding, and that also counts how far a collapse would slide the texture against the surface, so it reduces where the UVs are plain first. Textures are resized to the size tier of `shrink_textures.py` (512 px up to 1.25 m, else 1024 px) and embedded as PNG. The model is stood on the origin like `size_glb.py` does, at its real size unless `--meters` is given. The output is `assets/props/<name>.glb`; `size_glb.py` can still scale or turn it afterwards. `--provenance` writes a `polyhaven_prop` record in `provenance/props/` with the source URLs, SHA-256 of each downloaded file, author, license (CC0 1.0), settings and warnings. The script also prints an ASSETS.md row to paste. Its output was run through `size_glb.py` in Blender 5.2 (painted_wooden_stool and wooden_crate_01 scaled to 0.5 m: one mesh, one material, the three maps and the UVs came through, and the model stood on the origin) and loaded in the prop tuner (#481).

After adding a prop, add the ASSETS.md row, correct its size in the prop tuner, and raise the prop count in the smoke test's "all generated props are present" check. `provenance.py validate` then requires the record for any `assets/props` row whose source is `[Poly Haven: ...]`. The face limit and texture size are the pipeline's, not Poly Haven's, so a model that looks too soft at 3,000 faces can be given a higher `--faces`; the prop's look beside the generated props is a judgment for the maintainer.

Limits: skins and animations are dropped (the mesh stays in its bind pose), clearcoat, transmission and volume are ignored, a second UV set is ignored, and only triangle lists are read. Emissive glow is added to the base color (a prop has no emissive map), and `KHR_texture_transform` is applied to the UVs (one transform per material; maps with different ones are warned about). In an atlas, a triangle that tiles its texture across several repeats gets a cell holding the map repeated up to 4 times, each repeat at a fraction of the resolution; more than that is clamped. Each is reported as a warning in the record.

## Provenance records

Each generated asset has a small JSON record in [`provenance/`](../provenance) at the repository root, named after the asset: `provenance/props/anvil_2.json`, `provenance/characters/hedda.json`, `provenance/textures/grass_relief.json`, `provenance/ui/panel.json`. It sits outside `assets/` so that [ASSETS.md](../ASSETS.md) doesn't need a row for it. ASSETS.md stays the human-readable list, with the license. The record is the same facts as data, so a script can check them and an asset can be remade or replaced.

A prop's record holds the subject, the full prompt, the seed, the chosen candidate, and one stage for each step with its tool, tool versions, date, and settings:

| Stage | Written by | Records |
| --- | --- | --- |
| `image` | `draw_klein.py` | FLUX.2 klein model, model revision, Python, PyTorch, and diffusers versions, size, steps, guidance, candidate number, the picture's SHA-256 |
| `mesh` | `make_trellis.py` (TRELLIS.2), `run_triposr.py` (TripoSR) | TRELLIS.2 build, ComfyUI and PyTorch versions from the running server, face budget, SHA-256 of `trellis2_api.json` (which fixes the other settings), the picture's SHA-256, and `models`: every weight file the workflow loads (TRELLIS.2 and PIXAL3D diffusion models, both TRELLIS.2 VAEs, BiRefNet, DINOv3, MoGe) with its node, file name, path under `comfyui\models`, size, and SHA-256, so a swapped file shows in the record (#450). The writer hashes about 13 GB once per run (20 seconds on the PC); a file it can't find gets null, which fails validation. Records backfilled from ASSETS.md have `models: null`, because the files used then weren't recorded and aren't guessed. The files on the PC on 2026-11-28 (all dated 2026-11-04) have SHA-256 `birefnet.safetensors` `9ab37426...a154`, `dino_v3_L_naf_fp32.safetensors` `4ad2ec4e...290f`, `trellis_2_int8_convrot.safetensors` `d01952ad...3a31`. For TripoSR: its commit, PyTorch version, marching-cubes resolution, and the mask model: `helpers` says `BiRefNet` (with `models` naming `birefnet.safetensors` with size and SHA-256, the mask file's SHA-256, and the ComfyUI and PyTorch versions that made it, from `masks\mask_model.json`) or `rembg u2net` (with `models` naming `u2net.onnx`) |
| `cleanup` | `cleanup_mesh.py` | TripoSR props' automatic cleanup: Blender version, face budget and mode, faces before and after, pieces removed |
| `size` | `size_glb.py` | Blender version, size in meters, turn |

Characters (`build_character.py`, `build_goblin.py`) record the recipe, the Blender and MPFB versions, and SHA-256 of the output. The relief maps (`build_relief_maps.py`) record the Poly Haven texture, the downloaded maps' SHA-256, and the library versions. The interface textures (`build_ui_textures.py`) get one record each, in `provenance/ui/`, with the photos they were built from, the Python, NumPy, and Pillow versions, and SHA-256 of source and output. `manual_edits` lists changes made by hand afterward, each with its text and date, and is empty when none are known. `origin` is `pipeline` for a record a script wrote as the asset was made, and `backfill` for one rebuilt from ASSETS.md.

The scripts write the records on the asset PC, in `<batch>\provenance\<name>.json`, each step adding its stage. After the models are sized, copy them next to the models:

```bash
scp ASSET_PC:D:/erlenfall-assets/my_batch/provenance/*.json provenance/props/
```

Only copy the records of the pictures you chose, because the folder also holds one for every candidate (the records of the pictures in `<batch>\input` are the ones with a mesh stage). `make_trellis.py` writes `chosen_by` from the batch file's `"chosen_by"` key (for example `"chosen_by": "Claude for Markus Gamperle"`, as ASSETS.md words it), or from the `CHOSEN_BY` environment variable when it is run by hand, so set it before the models are made. A pipeline record without it fails validation. Run `python3 tools/asset_pipeline/provenance.py validate`. After editing an asset by hand, record it with `python3 tools/asset_pipeline/provenance.py note assets/props/anvil_2.glb "what you changed and why"`, and mention it in the ASSETS.md notes too.

`tools/asset_pipeline/provenance.py` also has:

- `validate` checks each record's fields, that its asset exists and has an ASSETS.md row, that every AI-generated prop, character model, relief map, and script-built UI texture in ASSETS.md has a record, and that seed and subject agree with ASSETS.md. CI runs it, with the unit checks in `test_provenance.py`.
- `backfill` writes records for props, characters, and relief maps that have none, from the ASSETS.md row, the batch file, and `villagers.json`, and never overwrites an existing record (`--force` does). Nothing is guessed: the 59 existing props have `null` for dates and for tool versions ASSETS.md doesn't give (the FLUX.2 revision, PyTorch, diffusers). They were drawn before the pipeline wrote records. The characters, the goblin, and the relief maps are backfilled the same way: the recipe or the Poly Haven asset name and the SHA-256 of the file as it is now, with `null` for dates and tool versions, because the scripts only write a record when run. The UI textures were rebuilt by their script, which produced identical files, so their records are `pipeline` records.

The records of the first run on the asset PC haven't been seen yet: the pipeline changes were written and checked with sample data, but not run on the GPU, so every record of the props is a `backfill` ([#273](https://github.com/Gamperle/Erlenfall/issues/273)). The TripoSR writers (`run_triposr.py`, `cleanup_mesh.py`) are likewise untested on the asset PC. Copy `provenance.py` next to them there.

## Access

Ask the maintainer for the PC's address and SSH user, which are kept out of this public repository. Check the login, then use the host in place of `ASSET_PC` below:

```bash
ssh -o BatchMode=yes ASSET_PC "hostname; whoami"
```

- The remote shell is Windows PowerShell 5, which doesn't support `&&`.
- Copy a script over and run it with `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`. Long inline commands are easy to break with bash and PowerShell quoting.
- The SSH user is not an administrator. Installing system software means asking the maintainer.
- Scripts skip finished items, so they can be rerun after a dropped connection or if the PC sleeps.

## Setting up

An administrator installs these once: Python 3.12 for all users, Visual Studio 2022 Build Tools with C++, CMake, Blender, and Git. Long file paths must be turned on, and the SSH service restarted so it picks up the new PATH. The current PC already has all of this. The work folder is `D:\erlenfall-assets`.

Then, from the SSH user, copy the scripts and install ComfyUI and its models:

```bash
scp -r tools/asset_pipeline/* ASSET_PC:D:/erlenfall-assets/
ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\setup_comfy.ps1"
```

It should report that the GPU is available. The models take about 15 GB. ComfyUI is pinned to v0.43.0, with PyTorch 2.14 for ROCm 10.1 from AMD's wheel index. `setup_pc.ps1` installs the TripoSR fallback and the SDXL environment.

## Asset PC versions

Read on 2026-11-17 over SSH, without changing anything on the PC. The PC is not on the setup that ROCm 10.1 lists, and the HIP DLL in the virtual environments differs from the system one, which may play a part in the startup crashes in [#59](https://github.com/Gamperle/Erlenfall/issues/59). Whether it does isn't known.

| Item | Value |
| --- | --- |
| GPU | AMD Radeon RX 7900 XT |
| Display driver | 32.0.32015.7029, dated 2026-10-18 |
| Radeon software | AMD Software: Adrenalin Edition, version value 26.10.1 (the release string 26.20.15.07-261015a is from [#71](https://github.com/Gamperle/Erlenfall/issues/71)) |
| Listed for ROCm 10.1 | Adrenalin 26.10.41.05, Windows 11 25H2 |
| Windows | 26H2 (`DisplayVersion`), build 26300.9974 (`UBR`); [#71](https://github.com/Gamperle/Erlenfall/issues/71) recorded 26300.9711 on 2 November, so Windows has updated since |
| `amdhip64_7.dll`, `C:\Windows\System32` | 10.0.3683.0, SHA-256 `7E50A36172DACA1A4C321DC3CE3FCC3898EF1B4C3107923BE5D5AC87E9113D83` |
| `amdhip64_7.dll`, `venv`, `venv-bakeoff`, `venv-comfy`, `venv-images` (each under `Lib\site-packages\_rocm_sdk_core\bin`) | 10.0.3684.0, identical SHA-256 `F20E2065CEE5889789BF73DF0C2D1F4EFB481E74ADE30488C352FD65AD80AC83` |
| `amdhip64_7.dll`, `trellis2\venv` (`_rocm_sdk_core` and `_rocm_sdk_devel`) | 10.0.3581.0, SHA-256 `3D72E1AC453D58C55C1F94CC7958A13CB42233D6F711AC363E5FA2B0DFAE43A8`. An older ROCm SDK, no longer used for batches |

So the four current environments agree with each other and differ from the system DLL by one build (3684 against 3683). The older `trellis2\venv` is 100 builds behind.

How to read them again (read-only, PowerShell 5): the driver from the registry key `HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}` (`DriverVersion`, `DriverDate`, `RadeonSoftwareVersion`), because `Get-CimInstance Win32_VideoController` is denied to the SSH user; Windows from `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion` (`DisplayVersion`, `CurrentBuildNumber`, `UBR`); the DLLs with `Get-FileHash <path> -Algorithm SHA256` and `(Get-Item <path>).VersionInfo.FileVersion`.

**Rollback note.** Before any driver or Windows update, the working state is the driver 32.0.32015.7029 (Adrenalin 26.10.1), Windows build 26300.9974, and the DLL hashes above. If a newer driver breaks generation, reinstall that driver version from AMD's archive, which needs the maintainer because the SSH user is not an administrator. Don't copy the system DLL over the one in a venv, or the other way round, to test the mismatch, without first keeping a copy of the original and noting its hash here.

## Making a batch

1. Write `tools/asset_pipeline/batches/my_batch.json` with each object's subject, face budget, and real size in meters, and a first seed no other batch uses. Copy it to `D:\erlenfall-assets\batches\`.
2. Draw candidates:

   ```bash
   ssh ASSET_PC "Set-Location D:\erlenfall-assets; \$env:HF_HOME='D:\erlenfall-assets\hf-cache-bakeoff'; venv-bakeoff\Scripts\python.exe draw_klein.py my_batch"
   ```

3. Look at the candidates and copy the best ones to `D:\erlenfall-assets\my_batch\input\`. `contact_sheet.py` puts them on one page.
4. Make the models. Add `-Names a_1,b_2` to make only some:

   ```bash
   ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\run_trellis.ps1 -Batch my_batch"
   ```

5. Scale them, then copy `my_batch\props` into `assets/props`:

   ```bash
   ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\size_models.ps1 -Batch my_batch"
   ```

The ComfyUI server only listens on the PC itself. To use its web interface, open a tunnel with `ssh -L 8188:127.0.0.1:8188 ASSET_PC` while it runs, then visit `http://127.0.0.1:8188`.

## Choosing the models

**Pictures.** FLUX.2 klein 4B is the default, under Apache 2.0, with no account needed. In testing it got objects right far more often than SDXL, with cleaner backgrounds. It needs `enable_model_cpu_offload`, because keeping every part on the GPU exceeds its memory, and its own environment with current `diffusers`. Z-Image Turbo also works, at 18 s and 12.1 GB. Don't use FLUX.2 klein 9B, whose license is non-commercial.

**Models.** TRELLIS.2 replaced TripoSR in November 2026 ([#70](https://github.com/Gamperle/Erlenfall/issues/70)). On the same pictures it gave much sharper detail, a real back instead of a guessed one, and correct thin parts such as spoked wheels and ropes. It made a clean crate where TripoSR's model failed cleanup ([#150](https://github.com/Gamperle/Erlenfall/issues/150)). It's about 3 times slower, but needs no cleanup, and it hasn't crashed. Pixal3D, which the same ComfyUI template offers, kept closer to the picture's colors, but flattened a well's roof into one slope. Hunyuan3D can't be used, because its license excludes the EU.

**Comparison with SDXL and Z-Image Turbo** ([#69](https://github.com/Gamperle/Erlenfall/issues/69)). The same eight objects, three seeds each, at 1024 px on the RX 7900 XT with `enable_model_cpu_offload`, scored by eye, were run through each model:

| Model | License | Time per picture | Peak VRAM | Result |
| --- | --- | --- | --- | --- |
| FLUX.2 klein 4B | Apache 2.0 | 9.3 s | 7.9 GB | Real anvils, closed cupboards, white backgrounds, timber walls with a clear outline. Hammers and flasks right. Plain "bellows" wrong |
| Z-Image Turbo | Apache 2.0 | 17.9 s | 12.1 GB (25.2 GB and 258 s without offload) | About as accurate as klein, but slower and heavier. Same failure on bellows |
| SDXL (reference) | CreativeML Open RAIL++-M | About 8 s | Not measured | Drew an axe for a hammer, and does not know bellows |

Both newer models clearly beat SDXL on object accuracy. Through TripoSR, anvil, hammer and cupboard came out clearly better and flasks looked more like glass. Timber walls failed with both (Z-Image lost the white plaster as background, klein made a wrong box), which is why walls are built in code. klein was chosen for its speed and memory, and it is the model every later batch used (`klein1` to `klein3`).

Bellows were fixed by the prompt, not by another model. The plain word failed, but `klein3` describes the shape (a flat pear-shaped accordion of dark folded leather between two wooden boards, a handle at the wide end, an iron nozzle at the narrow end, seen from the side), and `bellows_1` and `bellows_3` made from it are in the game. So the depth ControlNet fallback from the issue hasn't been needed, and wasn't tried.

**License and access, checked on 2026-11-17** from the Hugging Face model pages and API: [FLUX.2-klein-4B](https://huggingface.co/black-forest-labs/FLUX.2-klein-4B) and [Z-Image-Turbo](https://huggingface.co/Tongyi-MAI/Z-Image-Turbo) both declare `apache-2.0`, neither is gated or private (`gated: false`), and an anonymous request for each one's `model_index.json` returns 200. This is a reading of the cards, not legal advice, and the pages could change. The larger FLUX.2 klein 9B is non-commercial, see above.

**The pictures.** The klein and Z-Image pictures still exist on the asset PC (`bakeoff\pictures`: 8 objects, seeds 5000 to 5002, 48 in all) and are saved as a contact sheet, one row per object with klein on the left and Z-Image on the right: [`6_klein_zimage_pictures.jpg`](../tools/asset_pipeline/examples/6_klein_zimage_pictures.jpg). The 14 TripoSR models made from the first choices are in [`7_klein_zimage_models.jpg`](../tools/asset_pipeline/examples/7_klein_zimage_models.jpg) (top row klein, bottom row Z-Image; no bellows model was made). The prompts are in `image_bakeoff.py` on the PC.

![Eight objects, three seeds each, klein left and Z-Image right](../tools/asset_pipeline/examples/6_klein_zimage_pictures.jpg)

**The scores.** The by-eye scores were never written to a file, on the PC or in the repository, so the original per-picture scores are gone. What the logs do hold is the time per picture (1024 px, `enable_model_cpu_offload`):

| Model | Pictures logged | Fastest | Median | Slowest | Peak VRAM |
| --- | --- | --- | --- | --- | --- |
| klein 4B | 24 of 24 | 9.2 s | 9.4 s | 52.8 s (first picture, includes warm-up) | 7.9 GB |
| Z-Image Turbo | 19 of 24 (5 lines missing from the log) | 17.8 s | 17.9 s | 34.4 s (a bellows picture) | 12.1 GB |

Re-reading the contact sheet (a later reading, not the original scores), per object across the three seeds:

| Object | klein 4B | Z-Image Turbo |
| --- | --- | --- |
| Anvil | Right on a stump in 2 of 3. Seed 5000 is a flat star shape | Right in 3 of 3, with a horn |
| Barrel | Right in 3 of 3 | Right in 3 of 3, with shinier hoops |
| Bellows (plain word) | Wrong in 3 of 3: a barrel-like drum with folds | Wrong in 3 of 3: a box with vertical pleats and a rod |
| Cupboard | Closed doors in 3 of 3 | Closed doors in 3 of 3, taller |
| Flask | Right in 3 of 3, darker liquid | Right in 3 of 3, paler liquid, a longer neck |
| Hammer | A block head like a mallet in 3 of 3 | A steel head closer to a smith's hammer in 3 of 3 |
| Short sword | Broad blade, dagger-like | Slimmer, longer blade |
| Timber wall | Clear outline in 3 of 3 | Clear outline in 2 of 3. Seed 5000 has a gabled top |

This reading differs a little from the summary above ("about as accurate as klein"): on the sheet Z-Image's hammers look more like a smith's hammer, and klein's anvil seed 5000 is a miss.

**SDXL.** The SDXL pictures of this comparison are not on the PC, only the earlier SDXL sample sets (`samples`, `samples2`, `samples3`), which used different prompts. The SDXL row above rests on the issue comment alone.

What the comparison doesn't cover: the original per-picture scores (see above), the SDXL pictures, and the full prop list. The test used 8 objects.

The template's upsample stage is set to 1024 instead of 1536. At 1536 a step took 282 s instead of 23 s, probably because it no longer fits in the card's 20 GB.

## Getting good pictures

The look to aim for, and the subject wording that works, are in [the art style guide](ART_STYLE.md#image-prompt-template).

The picture matters more than anything else, because the model sees only that one image. Drawing six candidates and keeping the best two costs very little.

- **Reject** pictures that show several objects, a room or scenery, a cropped object, or a flat pattern that fills the frame.
- **Use a straight-on view at eye level.**
- **Check it's the right object.** SDXL has drawn an axe when asked for a hammer, and it doesn't reliably know bellows.
- **Describe the shape, not only the name.** "Pointed horn" and "square steel head" helped the anvil and hammer.
- **Prefer solid shapes.** Glass and hidden sides are the weakest.
- **Walls are unreliable.** A stone wall works when the picture shows a clear outline. Every timber wall picture ran off the frame or showed a room. Walls are code-built instead, see [WALLS_AND_BUILDINGS.md](WALLS_AND_BUILDINGS.md) and [#61](https://github.com/Gamperle/Erlenfall/issues/61).

## TripoSR texture baking speed

Baking the texture of a TripoSR model (`--bake-texture`) took 10 s to 400 s per model, most of the time per model ([#62](https://github.com/Gamperle/Erlenfall/issues/62)). `bench_bake.py` times its parts on the PC (with the GPU synchronized, one run per cell, on six first-batch pictures, mesh from marching cubes at resolution 256, default 2048 px texture). The three parts of `bake_texture` are the `xatlas` UV unwrap, the OpenGL rasterize of the positions, and the triplane color query:

| Picture | Faces | Unwrap (`xatlas`) | Rasterize | Color query | Share of bake in unwrap |
| --- | --- | --- | --- | --- | --- |
| `hammer_0` | 45,408 | 12.9 s | 0.13 s | 1.0 s | 92% |
| `forge_1` | 92,030 | 30.9 s | 0.05 s | 1.0 s | 97% |
| `barrel_1` | 154,124 | 62.3 s | 0.05 s | 1.0 s | 98% |
| `anvil_1` | 160,926 | 66.2 s | 0.05 s | 1.0 s | 98% |
| `chest_2` | 239,208 | 229.1 s | 0.05 s | 1.0 s | 99.6% |
| `cupboard_4` | 248,572 | 391.6 s | 0.05 s | 1.0 s | 99.7% |

The unwrap is the bottleneck, and it grows faster than the face count. Texture size doesn't matter (1024 px instead of 2048 px: the query drops from 1.0 s to 0.3 s and the unwrap stays the same). Mesh extraction takes a steady 4.1 to 4.3 s and the model step 3 s (the first convolution is no longer slow with cuDNN off).

Reducing the mesh before unwrapping is the cheap speedup. The cleanup (`cleanup_mesh.py`) reduces the model to 1,500 to 8,000 faces afterwards, and the colors are queried from the triplane at each surface point, so the unwrapped mesh doesn't need all its faces. Bake time in seconds after reducing the mesh with `fast_simplification` (the reduction itself takes 0.02 to 0.24 s), and with a lower marching-cubes resolution for comparison:

| Picture | No reduction | 30,000 faces | 15,000 faces | 8,000 faces | `--mc-resolution 192` | `--mc-resolution 128` |
| --- | --- | --- | --- | --- | --- | --- |
| `hammer_0` | 14.0 | 7.2 | 2.6 | 1.0 | 4.8 | 1.5 |
| `forge_1` | 31.9 | 6.4 | 2.1 | 1.1 | 14.2 | 4.0 |
| `barrel_1` | 63.3 | 6.1 | 2.2 | 1.3 | 35.3 | 16.9 |
| `anvil_1` | 67.3 | 4.1 | 1.7 | 0.9 | 30.1 | 9.3 |
| `chest_2` | 230.1 | 6.4 | 2.5 | 1.3 | 70.3 | 27.8 |
| `cupboard_4` | 392.7 | 8.8 | 3.0 | 1.3 | 152.2 | 35.3 |

A lower marching-cubes resolution helps much less than reducing the faces, and changes the model. `run_triposr.py` now reduces the extracted mesh to `BAKE_FACES` faces (default 30,000, `0` turns it off) before baking, which needs `fast_simplification` in the TripoSR venv (`setup_pc.ps1` installs it; without it the script warns and bakes the whole mesh). A whole TripoSR run of `cupboard_4` (model, mesh, bake, export) fell from about 410 s to 35 s, `anvil_1` and `hammer_0` ran in 26 s and 29 s.

**Quality.** I ran `cleanup_mesh.py` on every variant of the six pictures and compared the cleaned models' front and back renders with the unreduced ones. With 30,000 faces they look the same to my eye, and the three through the real script (`cupboard_4`, `anvil_1`, `hammer_0`) look the same as the shipped models. Measured as PSNR against the unreduced result they are 30.7 to 41.4 dB at 30,000 faces (a rerun of the same model gives identical images, so this difference is real, but small: the cleanup decimates a slightly different mesh). At 15,000 faces `forge_1` and `anvil_1` fell by another 2 to 3 dB and at 8,000 the anvil's stump looked softer, so 30,000 is the setting that kept the output. The speedup is for models made from now on: the TripoSR props that are in the game were not remade.

## Known problems

| Problem | Current handling | Issue |
| --- | --- | --- |
| ComfyUI's UV unwrap fails with `HIPBLAS_STATUS_ALLOC_FAILED` on meshes of 10 million faces or more on Windows ROCm | The workflow reduces the mesh to the face budget before unwrapping | [Comfy-Org/ComfyUI#16124](https://github.com/Comfy-Org/ComfyUI/issues/16124) |
| Some models take much longer, such as 25 minutes for a crate, in the upsample stage | None. 53 props took about 6 hours of GPU time | |
| TRELLIS.2 tears pictures of fine straw, thin staves, rope and small stones, whatever the shape seed | Redraw the object as thick, chunky shapes (batch `klein453`); the haystacks, `campfire_4` and `bucket_1` were remade that way. The cone-shaped hay rick and a hairy hay dome still came out as torn shells, and pails with thin staves and an iron handle came out ragged | [#453](https://github.com/Gamperle/Erlenfall/issues/453) |
| TRELLIS.2 models are centered on their middle, and a few face sideways | `size_glb.py` stands them on their base, and `turns` in the batch file turns odd ones. The smoke test checks every prop is within 10 cm of the ground | |
| Long SSH sessions to the PC drop, and the PC sleeps during work started over SSH | `make_trellis.py` keeps the PC awake while it runs. Run big batches a few names at a time | |
| TRELLIS.2 sometimes changes a shape it can't read, such as turning an A-frame tent into a cone | Check the results, and redraw the picture if needed | |
| TripoSR: 34 of 77 first attempts crashed at startup in `MIOpen.dll` with `0xC0000005` | `make_models.ps1` retries | [#59](https://github.com/Gamperle/Erlenfall/issues/59) |
| TripoSR: models are soft, backs are guessed, and meshes need cleanup | `cleanup_mesh.py` | [#55](https://github.com/Gamperle/Erlenfall/issues/55) |

## Licensing

- **FLUX.2 klein 4B:** Apache 2.0.
- **TRELLIS.2:** code and weights are MIT. ComfyUI (GPL-3.0) reimplements its rendering parts without NVIDIA's non-commercial `nvdiffrast`. The repackaged files on Comfy-Org's Hugging Face pages are marked MIT.
- **BiRefNet:** the code ([ZhengPeng7/BiRefNet](https://github.com/ZhengPeng7/BiRefNet)) is MIT, and the Hugging Face model card for the weights also declares MIT. See "Background removal licenses" below for what that does and doesn't cover.
- **DINOv3**, which TRELLIS.2 uses to read the picture, is under Meta's DINOv3 License. It allows commercial use but asks for "Built with DINOv3" attribution. [ASSETS.md](../ASSETS.md) carries it, and whether the game needs it too belongs with [#73](https://github.com/Gamperle/Erlenfall/issues/73).
- **Blender and the scripts that import `bpy`:** Blender is GPL (version 2 or later for its source), and its license page says published scripts using the Python API must be shared under a GPL-compliant license. The six `bpy` scripts in `tools/` were written for this project (the history shows no copied third-party code) and are under the repository's MIT license, which is generally regarded as GPL-compatible. Nobody has confirmed this with legal advice, so the maintainer still has to decide ([#67](https://github.com/Gamperle/Erlenfall/issues/67)). `build_character.py` also drives the MPFB add-on, whose own license wasn't checked here. The rule for new scripts is in [CONTRIBUTING.md](../CONTRIBUTING.md).
- **TripoSR:** MIT. **SDXL:** CreativeML Open RAIL++-M, not used for any shipped asset. See "SDXL license" below.

Every generated file added to the repository must go through Git LFS if it's a large binary, and be listed in [ASSETS.md](../ASSETS.md) with the tools and versions, the full prompt, the seed, and any manual edits. To reproduce a picture, use the same prompt, seed, and package versions.

### Background removal licenses

Checked on 2026-11-09 from the upstream pages. This is a reading of what those pages say, not legal advice, and the pages could change.

| Piece | What the upstream page says | Source |
| --- | --- | --- |
| `rembg` (the tool) | MIT License, copyright Daniel Gatis. Its README says model weights have their own licenses, independent of rembg's, and to check each model's source before commercial use | [danielgatis/rembg](https://github.com/danielgatis/rembg) |
| u2net (the weights rembg downloads by default) | rembg's README gives no license for the weights and points to the U-2-Net repository. That repository's code is under Apache License 2.0 (the LICENSE file is the unmodified template with no named copyright holder). Its README gives no separate license for the pretrained weights, which are on Google Drive and Baidu Pan, and none for the training datasets it names (DUTS-TR, and the Supervisely Person Dataset for the human-segmentation variant) | [xuebinqin/U-2-Net](https://github.com/xuebinqin/U-2-Net) |
| BiRefNet code | MIT | [ZhengPeng7/BiRefNet](https://github.com/ZhengPeng7/BiRefNet) |
| BiRefNet weights | The Hugging Face model card declares MIT. The card says the standard model was trained on DIS-TR (and validated on DIS-TE and DIS-VD) and gives no license for that data | [ZhengPeng7/BiRefNet](https://huggingface.co/ZhengPeng7/BiRefNet) |
| RMBG-2.0 (BRIA), trained with BiRefNet | BiRefNet's README says its weights are non-commercial only. Do not use it, nor RMBG-1.4 | BiRefNet README |

What this means for the game:

- **u2net:** the tool is MIT and the code is Apache 2.0, both permissive. The remaining gap is that no upstream page states a license for the weight files themselves or the datasets they were trained on. The game ships only the generated meshes and textures, never the weights, and the background mask is an intermediate step, so the practical exposure looks small. The maintainer decided on 2026-11-17 to accept this risk: the six props that used u2net stay, and u2net remains allowed in the TripoSR fallback. The question would go away if u2net were no longer used, and new props use BiRefNet anyway.
- **BiRefNet:** the same dataset caveat applies (training data licenses are not stated), but code and weights are both labeled MIT, which is the clearest labeling of the options. TRELLIS.2 already uses it internally, so the props made with it already depend on it.
- **Apache 2.0 and MIT** ask that the license text and copyright notice go with a redistributed copy of the code or weights. They place no condition on images or meshes made with the tool. Nothing here is redistributed in the game.
- **Which props are affected:** the TripoSR props in [ASSETS.md](../ASSETS.md) list "rembg u2net" in their tools column. The TRELLIS.2 props use BiRefNet.

The comparison that was still to do is in the next section.

### Background removal comparison (#218)

Run on 2026-11-19 on the asset PC, in `D:\erlenfall-assets\bgcompare218` (nothing outside that folder was changed; `ASSET_PC` below is that PC). The scripts are in [`tools/asset_pipeline/bg_compare`](../tools/asset_pipeline/bg_compare). Twelve existing FLUX.2 klein pictures with thin parts were run through three models: tongs, crosscut saw, hand saw, cant hook, pickaxe, short bow (a bow seen edge-on, 2% of the picture), spoked wheel, a hanging rack, a lantern and a mine lantern (loop, wire cage, glass), a windlass well, and a forge tool rack (hammers, tongs, chisels on boards). No picture of a chain exists in the klein batches, so chains were **not** tested.

| Model | Weights used | Source and license | sha256 |
| --- | --- | --- | --- |
| rembg u2net (rembg 2.0.69, default settings as TripoSR's `run.py` uses them) | `u2net.onnx`, 175,997,641 bytes, already on the PC since 2026-11-01 | rembg's default download; license gap as described above | `8D10D2F3BB75AE3B6D527C77944FC5E7DCD94B29809D47A739A7A728A912B491` |
| BiRefNet, as TRELLIS.2 uses it (ComfyUI's `RemoveBackground` node) | `comfyui/models/background_removal/birefnet.safetensors`, 444,473,596 bytes | the file the pipeline already uses (listed in the batch `models.json` records); MIT per the model card | `9ab37426bf4de0567af6b5d21b16151357149139362e6e8992021b8ce356a154` |
| BEN2 Base | `model.safetensors`, 380,577,976 bytes, and the model code `BEN2.py` (53,513 bytes), both from [PramaLLC/BEN2](https://huggingface.co/PramaLLC/BEN2) at revision `e48a20765fb421d19dcdb0bf3cc61e802ca5ec8f`, downloaded with the maintainer's approval | MIT (model card metadata). Trained on DIS5k and a proprietary 22K segmentation set owned by the publisher, so the training-data caveat is the same kind as for the others. The larger BEN2 model is only offered through a web demo and API and was not used | `model.safetensors` `EA8B7907176A09667C86343DC7D00DE6A6D871076CB90BB5F753618FD6FB3EBB` (matches the hash Hugging Face lists); `BEN2.py` `16E6132FAEFC112EA97072B93DF40C847A33AAD7C04A2E578B417E9EBB6094A7` |

BEN2 ran from its own `BEN2.py` in a new venv (`bgcompare218\venv-ben2`: torch 2.15 CPU, timm 1.0.31, einops, kornia, opencv-headless), loading the safetensors file, not the pickled `.pth`. It needs about 8.5 s per 1024 px picture on the CPU. BiRefNet and BEN2 are not RMBG-1.4 or 2.0; those were not touched.

**Masks (threshold 0.5, all 12 pictures).** Intersection over union between models was 0.95 to 0.99 for most pictures, and the three masks look the same for tongs, saws, pickaxe, cant hook, both lanterns, hanging rack and well. Differences:

| Picture | u2net | BiRefNet | BEN2 |
| --- | --- | --- | --- |
| spoked wheel | **Fills the gaps between all 16 spokes** (44% of the picture is foreground, against 27%) | 16 gaps open | 16 gaps open (IoU with BiRefNet 0.985) |
| forge tool rack | complete | **bites 3 holes out of the board** (24% against 26%) | complete |
| short bow (a 2% sliver) | IoU only 0.82 to 0.91 between every pair of models; no clear winner | same | same |
| lantern, mine lantern | glass area partly cut away (fewer holes, 6 and 8 against 10 and 12) | keeps the wire cage openings | keeps them, IoU with BiRefNet 0.99 |

So u2net fails on thin parts that are separated by gaps (the wheel), BiRefNet showed one bad failure (the rack), BEN2 showed none and agrees with BiRefNet everywhere else.

**Meshes.** For tongs, wheel, tool rack and mine lantern, the same pictures were turned into models with the masks swapped:

- *TRELLIS.2* (the default): the real workflow with 12,000 faces and the in-workflow BiRefNet mask replaced by each model's mask file (a control run with the unchanged workflow gave a near identical tongs model: 12,000 faces, 0.447 by 1.0 by 0.092, against 0.447 by 1.0 by 0.094 with the BiRefNet mask file, so the file route is faithful). TRELLIS.2 only uses the mask to crop and center the picture, so mask errors hardly matter: the wheel kept all 16 spokes with all three masks, tongs and mine lantern looked the same. The one visible effect was the tool rack, where the BiRefNet mask's bite shows up as a hole in the boards, and BEN2 gave a model without it.
- *TripoSR* (the fallback, 256 resolution, baked): the u2net wheel has a membrane across the spoke gaps. The BiRefNet and BEN2 wheels have open spokes. Tongs and mine lantern are alike with all three, and the rack came out a little different with each mask, with no clear winner.

**Recommendation.**

1. **Keep BiRefNet as the default.** It is already what TRELLIS.2 uses inside ComfyUI, BEN2 is not a ComfyUI node (using it there would need a custom node), and the evidence is one picture per prop, 12 pictures, with BEN2 ahead in one case (rack) and equal elsewhere, so it is not clear enough to change the pipeline. The pipeline default is not changed in this PR.
2. **Stop using u2net for new TripoSR props.** The wheel shows its weakness on thin gaps, and moving to BiRefNet or BEN2 also removes the unstated weight license. Done in [#492](https://github.com/Gamperle/Erlenfall/issues/492): `make_models.ps1` now starts ComfyUI, `make_masks.py` writes a BiRefNet mask for each picture to `<batch>\masks`, and `run_triposr.py --mask` prepares the picture from it (gray background, foreground at 85%, as `run.py` does after rembg) and passes it with `--no-remove-bg`. `make_models.ps1 -Mask u2net` keeps the old rembg route. BEN2 was not added, because it is not a ComfyUI node (see 1). Tested on the wheel and the tongs on the PC: the wheel's 16 spokes stay open. `run.py` creates `<output>\0` only when it removes the background, so `run_triposr.py` now makes it itself ([#493](https://github.com/Gamperle/Erlenfall/issues/493)). The six existing u2net props stay as decided on 2026-11-17.
3. **BEN2 Base is a good second opinion** when a BiRefNet mask looks wrong (the rack). A cheap check for a new batch is `bg_compare/mask_birefnet.py` and `bg_compare/mask_ben2.py`, then comparing the masks.

Not verified: whether BEN2 inside TRELLIS.2 itself changes meshes (only its mask was substituted, and TRELLIS.2 uses it just for the crop), BEN2's GPU speed, and the training-data licenses of all three models. Chains, nets, cages and a bigger sample were added afterwards, below.

#### Second round: chains and other thin parts ([#494](https://github.com/Gamperle/Erlenfall/issues/494))

The first round had no chain picture and one picture per prop. This round drew 30 new FLUX.2 klein 4B pictures with `draw_klein.py klein494` (batch [`klein494.json`](../tools/asset_pipeline/batches/klein494.json), seed 14000 plus 10 per object plus the picture number, 3 pictures for each of 10 objects, `CANDIDATES=3`): a hanging chain, a heap of chain, a wooden ladder, a rope ladder, a split-rail fence, a garden rake, a pitchfork, a scythe, a wire cage and a fishing net on a frame. They were run on the asset PC through the same three models, with the same weights and the same scripts as above (`bg_compare/run_masks.ps1`, in the new folder `D:\erlenfall-assets\bgcompare494`; the pictures are in `D:\erlenfall-assets\run494\klein494\candidates`). `bg_compare/compare_masks.py` gives the table and the sheets. With the first round, that makes 42 pictures. Pictures: [pictures.jpg](bg_compare_494/pictures.jpg); masks (picture, u2net, BiRefNet, BEN2 per row): [masks_0](bg_compare_494/masks_0.jpg), [masks_1](bg_compare_494/masks_1.jpg), [masks_2](bg_compare_494/masks_2.jpg), [masks_3](bg_compare_494/masks_3.jpg); the numbers for every picture: [table.txt](bg_compare_494/table.txt). "Holes" in the table are background areas that the mask closes off, counted at 256 px.

| Group (pictures) | u2net | BiRefNet | BEN2 |
| --- | --- | --- | --- |
| fishing net (3), wire cage (3) | **Fills the whole frame solid** (cage: 21 to 40% of the picture is foreground, against 8 to 15%; net 35 to 43% against 17 to 23%). 0 holes | Every mesh cell stays open (85 to 269 holes). Door, latch and cords visible | Same as BiRefNet (IoU with BiRefNet 0.82 to 0.93; the differences are single wires) |
| chain pile (3) | Links merged to a blob, 2 to 9 holes against 23 to 32 | Links separate, with the centre hole | Same, IoU with BiRefNet 0.98 |
| hanging chain (3) | Right in two pictures; in `hanging_chain_1` the middle links are half transparent | Clean | Right shape, but dark link interiors get gray patches (all three); IoU with BiRefNet 0.83 to 0.94 |
| wooden ladder (3) | Rungs partly faded in 2 of 3 | Clean, every rung | Clean, every rung, a few gray specks on a rail |
| rope ladder (3), split-rail fence (3) | Right, apart from `split_rail_fence_1`, where it differs from the other two (IoU 0.75, not looked at closely) | Right | Right, IoU with BiRefNet 0.95 to 0.99 |
| rake (3), pitchfork (3), scythe (3) | Right; one rake lost part of its handle (IoU 0.62) | Right | Right, gray patches inside two pitchfork handles |

So the first round's finding holds and is much stronger: **u2net closes every area with fine gaps** (net, cage, a heap of chain), which is exactly what a TripoSR fallback mesh would copy. BiRefNet and BEN2 both keep the gaps and agree closely (IoU 0.93 to 0.99 for most pictures). BEN2 was not better anywhere in this sample, and was a little worse in one way: gray, semi-transparent patches inside dark chain links and pitchfork handles, where BiRefNet's mask is a clean white.

**Updated recommendation:** unchanged. BiRefNet stays the default (it is also the TRELLIS.2 default and the TripoSR route since #492) and u2net stays out of new props. BEN2 is still a second opinion only: across 42 pictures it was ahead once (the rack) and slightly behind on dark chain links, so there is no evidence to prefer it. The pipeline default is not changed. These are masks only: whether the meshes keep chain links, net cells and cage gaps open is answered in the third round below ([#501](https://github.com/Gamperle/Erlenfall/issues/501)).

**Pictures that would make good props** (not added to the game, which is out of scope here): `hanging_chain_0` and `hanging_chain_2`, `wooden_ladder_0`, `rope_ladder_1`, `split_rail_fence_0`, `pitchfork_0` and `pitchfork_2`, `garden_rake_0`, `wire_cage_0` and `wire_cage_2` (a cage with a door), and `chain_pile_1`. The scythe pictures came out as pick-like tools (double curved blades on a straight shaft) and are not scythes. The fishing net frames are drawn as open boxes, so they are no good as nets.

Not verified in this round: meshes (done in the next round), and the training-data licenses.

#### Third round: meshes from chains, a net, a cage and a ladder ([#501](https://github.com/Gamperle/Erlenfall/issues/501))

Run on 2026-11-20 in the new folder `D:\erlenfall-assets\bgcompare501` (nothing else on the PC was changed). Five of the #494 pictures were turned into meshes with each of the three masks, by both generators: `hanging_chain_0`, `chain_pile_0`, `fishing_net_frame_1`, `wire_cage_0` and `wooden_ladder_2` (the ladder with the weakest u2net mask, IoU 0.76). The pictures and masks are copies from `run494` and `bgcompare494`. Same method as the first round: *TRELLIS.2* with the pipeline's workflow at 12,000 faces and the in-workflow BiRefNet mask replaced by the mask file (`bg_compare/trellis_masks.py`, `BGCOMPARE_RUN` names the folder), *TripoSR* at marching-cubes resolution 256 with texture baking and the picture prepared from the mask (`bg_compare/prep_triposr.py`). Renders were made in Blender 5.2 and looked at one by one. One mesh per cell, no repeats, so single-seed differences between the masks are partly luck. Pictures: [pictures.jpg](bg_compare_501/pictures.jpg) (chain, heap, net, cage, ladder); TRELLIS.2, front and side per mask (u2net, BiRefNet, BEN2): [trellis2.jpg](bg_compare_501/trellis2.jpg); TripoSR, front and back per mask: [triposr.jpg](bg_compare_501/triposr.jpg).

**TRELLIS.2 (uses the mask only to crop).** The mask hardly matters, as in the first round: even the solid u2net masks of the net and the cage gave open meshes, with the cells open.

| Picture | u2net | BiRefNet | BEN2 |
| --- | --- | --- | --- |
| hanging chain | links open, hook at the top wrong | links open, **top is cut off and a piece floats above the chain** | links open, a ring at the top instead of the hook, paler color |
| chain heap | open links, low heap | the same | the same, more orange |
| net | cell grid the most regular of the three | cells open, more torn | cells open, more torn |
| cage | 3 sides of dark wire with many triangular film shards inside the cells | the same | thinnest wires, open top like the picture, fewest shards |
| ladder | all rungs, clean | clean | clean |

So **no mask kept a chain, net or cage from coming out open in TRELLIS.2**. What it gets wrong is the same for all three masks: the hook of the hanging chain is lost or changed, the net comes out as a bell or sack and not as the flat hammock in the picture, and the cage and the net are full of small triangular shards (film across cells that should be empty). These are not the mask's fault, and the cage is not usable as a prop without cleanup.

**TripoSR (uses the mask fully).** Here the mask decides.

| Picture | u2net | BiRefNet | BEN2 |
| --- | --- | --- | --- |
| hanging chain | hook and thin chain, links mostly solid | the same | the same, one link opened |
| chain heap | ball of loops | ball of loops | ball of loops |
| net | **a closed box: the net is a textured wall and the top is closed** | open net, but speckled and torn at the edges | open net, one corner loose; the cleanest |
| cage | **a closed box with a grid printed on the wall** | frame left, most wires gone, a wall missing | frame and corners kept, wires mostly gone |
| ladder | fine, a fragment floats | fine, a fragment floats | fine, no fragment |

u2net's mask does what it did in the mask comparison: it closes the net and the cage into a solid box, and TripoSR copies that. BiRefNet and BEN2 keep the gaps open, but TripoSR cannot build thin wires or net cords: what remains is a frame with holes where the wires were, in the cage's case worse with BiRefNet. The heap became a ball in all three, because TripoSR makes a round object from any heap. No TripoSR chain looks like a chain with open links.

**Recommendation.**

1. **Chains, nets, cages and other lattices: use TRELLIS.2, with the BiRefNet default.** The mask is not what decides, so there is no reason to change it. The chain, the heap and the ladder are usable meshes (the ladder and the heap are the best). The net and the cage need the shards cleaned away, or they should stay out of the game. Pick pictures where the hook or end piece is not at the edge.
2. **Do not use TripoSR for them, with any mask.** If it is used anyway, never with u2net (closed box). BiRefNet and BEN2 gave similar open results with no clear winner, BEN2 a little cleaner on the net and cage, BiRefNet is the pipeline default.
3. The pipeline defaults are unchanged. No props were added to the game.

Found on the way and not fixed: the copy of `run_triposr.py` on the PC (`D:\erlenfall-assets\run_triposr.py`, 2026-11-18) is older than the repository's, so it lacks the `0` folder fix of [#493](https://github.com/Gamperle/Erlenfall/issues/493) and `--mask`, and `bg_compare218\run_triposr_masks.ps1` failed five times per picture on it until the folders were created by hand ([#512](https://github.com/Gamperle/Erlenfall/issues/512)). TRELLIS.2 turns cage and net cells into shards ([#513](https://github.com/Gamperle/Erlenfall/issues/513)).

Not verified: more than one seed per cell, TripoSR with higher marching-cubes resolution or a bigger texture (which might keep more wire), BEN2 inside TRELLIS.2 itself, and the training-data licenses.

### SDXL license

Checked on 2026-11-14 for [#60](https://github.com/Gamperle/Erlenfall/issues/60), from the text of the [CreativeML Open RAIL++-M License](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md) (26 July 2023, Stability AI) that ships with SDXL base 1.0. This is a reading of the text, not legal advice, and a court or a lawyer could read it differently.

**Is SDXL still used?** No. Every prop in [ASSETS.md](../ASSETS.md) lists FLUX.2 klein 4B as its picture source, and none lists SDXL. The SDXL environment (`setup_pc.ps1`) and the old `draw_pictures.py` remain only for reference. Nothing generated with SDXL is in the repository, so the license does not currently touch any shipped file.

**What the license says about output:**

- "Output" is "the results of operating a Model", and "Derivatives of the Model" covers modified versions, works based on the Model, and models created by transferring patterns from it (for example by distillation). The text does not name Output as a Derivative.
- "Licensor claims no rights in the Output You generate using the Model." You are accountable for the Output and its later uses, and "no use of the output can contravene any provision as stated in the License."
- The conditions on redistribution (pass on the use restrictions as an enforceable term, give recipients the license, mark changes) apply to distributing the Model or Derivatives of it, meaning weights, fine-tunes, and the like. This repository distributes none of them.
- Nothing in the text forbids putting Output under another license, and nothing requires the license to travel with Output.

**Use restrictions (Attachment A).** You agree not to use the Model or its Derivatives:

1. in any way that violates applicable law or regulation;
2. to exploit or harm minors;
3. to generate or disseminate verifiably false information meant to harm others;
4. to generate or disseminate personal identifiable information that can be used to harm an individual;
5. to defame, disparage, or harass others;
6. for fully automated decisions that adversely affect a person's legal rights or create a binding obligation;
7. to discriminate against or harm people based on social behavior or known or predicted personal characteristics;
8. to exploit the vulnerabilities of a group (age, social, physical, or mental) to materially distort behavior in a harmful way;
9. to discriminate based on legally protected characteristics;
10. to give medical advice or interpret medical results;
11. to generate or disseminate information for justice, law enforcement, immigration, or asylum processes, such as predicting that someone will commit fraud or crime.

**Conclusion.** Props, textures, and pictures made with SDXL could be released under CC BY-SA 4.0. The only restrictions are use-based and don't conflict with CC BY-SA's terms, and a fantasy game's props don't fall under any of the eleven items. CC BY-SA 4.0 lets anyone reuse the files for any purpose, including a restricted one, but the license puts that duty on the person doing the use, and the repository does not redistribute the model. This follows the maintainer's decision on #60 that assets need not be defensible, only that others' rights and licenses are respected.

**Rule for the repository:**

- Prefer the tools in "Choosing the models". SDXL is not needed.
- If SDXL is used anyway, name it and its version in the Source column of [ASSETS.md](../ASSETS.md), and use only for content that stays clear of Attachment A.
- Never commit SDXL weights, LoRAs, or checkpoints fine-tuned from it, and never train a model on its output and publish that model. Those are Derivatives, and the use restrictions would have to travel with them as an enforceable term.
- Keep the license link above with any SDXL use.

**Open question for the maintainer.** The text does not say whether Output is a Derivative, nor whether the use restrictions bind later users of Output ("no use of the output can contravene any provision"). The reading above, that they don't and the game is fine, is the common one but is untested in court. The maintainer decides whether to accept it if SDXL is ever used again, or to get legal advice together with [#73](https://github.com/Gamperle/Erlenfall/issues/73). Until then the safe rule is not to use SDXL.
