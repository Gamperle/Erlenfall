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
| `shoot_props.gd` | Photographs placed props in the game |
| [`tools/prop_tuner`](../tools/prop_tuner) | A scene for correcting each prop's size and height against the player, saved to `data/prop_tuning.json` |
| `setup_pc.ps1` | Installs the TripoSR and SDXL environments |
| `bench_bake.py` | Times the parts of TripoSR texture baking and writes variants for comparison |
| `make_models.ps1`, `run_triposr.py`, `render_preview.py`, `watchdog.ps1`, `torchmcubes.py` | Make models with TripoSR, the fallback |
| `clean_models.ps1`, `cleanup_mesh.py`, `adjust_glb.py` | Clean TripoSR models, and reshape ones it gets out of proportion |
| `check_mesh.py` | Prints a raw model's face count and whether it's watertight |
| `draw_pictures.py` | The older SDXL drawing script, kept for reference |

## Provenance records

Each generated asset has a small JSON record in [`provenance/`](../provenance) at the repository root, named after the asset: `provenance/props/anvil_2.json`, `provenance/characters/hedda.json`, `provenance/textures/grass_relief.json`, `provenance/ui/panel.json`. It sits outside `assets/` so that [ASSETS.md](../ASSETS.md) doesn't need a row for it. ASSETS.md stays the human-readable list, with the license. The record is the same facts as data, so a script can check them and an asset can be remade or replaced.

A prop's record holds the subject, the full prompt, the seed, the chosen candidate, and one stage for each step with its tool, tool versions, date, and settings:

| Stage | Written by | Records |
| --- | --- | --- |
| `image` | `draw_klein.py` | FLUX.2 klein model, model revision, Python, PyTorch, and diffusers versions, size, steps, guidance, candidate number, the picture's SHA-256 |
| `mesh` | `make_trellis.py` (TRELLIS.2), `run_triposr.py` (TripoSR) | TRELLIS.2 build, ComfyUI and PyTorch versions from the running server, face budget, SHA-256 of `trellis2_api.json` (which fixes the other settings), the picture's SHA-256, and `models`: every weight file the workflow loads (TRELLIS.2 and PIXAL3D diffusion models, both TRELLIS.2 VAEs, BiRefNet, DINOv3, MoGe) with its node, file name, path under `comfyui\models`, size, and SHA-256, so a swapped file shows in the record (#450). The writer hashes about 13 GB once per run (20 seconds on the PC); a file it can't find gets null, which fails validation. Records backfilled from ASSETS.md have `models: null`, because the files used then weren't recorded and aren't guessed. The files on the PC on 2026-11-28 (all dated 2026-11-04) have SHA-256 `birefnet.safetensors` `9ab37426...a154`, `dino_v3_L_naf_fp32.safetensors` `4ad2ec4e...290f`, `trellis_2_int8_convrot.safetensors` `d01952ad...3a31`. For TripoSR: its commit, PyTorch version, marching-cubes resolution |
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

Still to do: compare BiRefNet (and BEN2 Base, MIT) with u2net on thin parts such as tongs, chains, and handles. That needs the asset PC, so it is tracked in [#218](https://github.com/Gamperle/Erlenfall/issues/218).

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
