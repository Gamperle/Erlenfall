# Asset generation pipeline

This pipeline makes 3D props from text. FLUX.2 klein 4B draws a picture, TRELLIS.2 turns it into a textured, game-ready mesh through ComfyUI, and Blender scales it to real size. It runs on a Windows PC with an AMD Radeon RX 7900 XT, controlled over SSH. TripoSR, the earlier image-to-3D model, remains as a fallback.

**Status: in use for props.** Every generated prop in the game is listed in [ASSETS.md](../ASSETS.md). SDXL output is not used ([#60](https://github.com/Gamperle/Erlenfall/issues/60)). [The pipeline's README](../tools/asset_pipeline/README.md) walks through a batch with pictures.

## Workflow

| Step | Tool | Runs on | Time per item | Output |
| --- | --- | --- | --- | --- |
| Draw candidates | FLUX.2 klein 4B (`draw_klein.py`) | GPU | About 9 s, 7.9 GB | `<batch>\candidates\<object>_<n>.png` |
| Choose pictures | A person or agent | | | `<batch>\input\` |
| Make the model | TRELLIS.2 in ComfyUI (`run_trellis.ps1`, `make_trellis.py`) | GPU | 1 to 25 minutes, usually 3 to 9 | `<batch>\trellis\<name>.glb` |
| Set real size | Blender (`size_models.ps1`, `size_glb.py`) | CPU | Seconds | `<batch>\props\<name>.glb` |

TRELLIS.2 removes the background with BiRefNet, builds the shape in three stages, remeshes it into one closed surface, reduces it to the object's face budget, unwraps it, and bakes base color, roughness, metallic, normal, and ambient occlusion maps at 1024 px. No separate cleanup is needed.

The scripts are in [tools/asset_pipeline](../tools/asset_pipeline):

| File | Purpose |
| --- | --- |
| `batches/*.json` | Each batch's objects, with subject, face budget, real size, and first seed |
| `draw_klein.py` | Draws candidates for a batch with FLUX.2 klein |
| `contact_sheet.py` | Puts candidates or previews on one labeled page |
| `setup_comfy.ps1` | Installs ComfyUI with ROCm PyTorch and downloads the TRELLIS.2 models |
| `run_trellis.ps1`, `make_trellis.py`, `trellis2_api.json` | Start ComfyUI, make a batch's models, and stop it again |
| `size_models.ps1`, `size_glb.py` | Scale models to real size and turn them to face Godot's front |
| `shoot_props.gd` | Photographs placed props in the game |
| [`tools/prop_tuner`](../tools/prop_tuner) | A scene for correcting each prop's size and height against the player, saved to `data/prop_tuning.json` |
| `setup_pc.ps1` | Installs the TripoSR and SDXL environments |
| `make_models.ps1`, `run_triposr.py`, `render_preview.py`, `watchdog.ps1`, `torchmcubes.py` | Make models with TripoSR, the fallback |
| `clean_models.ps1`, `cleanup_mesh.py`, `adjust_glb.py` | Clean TripoSR models, and reshape ones it gets out of proportion |
| `check_mesh.py` | Prints a raw model's face count and whether it's watertight |
| `draw_pictures.py` | The older SDXL drawing script, kept for reference |

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

The template's upsample stage is set to 1024 instead of 1536. At 1536 a step took 282 s instead of 23 s, probably because it no longer fits in the card's 20 GB.

## Getting good pictures

The picture matters more than anything else, because the model sees only that one image. Drawing six candidates and keeping the best two costs very little.

- **Reject** pictures that show several objects, a room or scenery, a cropped object, or a flat pattern that fills the frame.
- **Use a straight-on view at eye level.**
- **Check it's the right object.** SDXL has drawn an axe when asked for a hammer, and it doesn't reliably know bellows.
- **Describe the shape, not only the name.** "Pointed horn" and "square steel head" helped the anvil and hammer.
- **Prefer solid shapes.** Glass and hidden sides are the weakest.
- **Walls are unreliable.** A stone wall works when the picture shows a clear outline. Every timber wall picture ran off the frame or showed a room. Walls are code-built instead, see [WALLS_AND_BUILDINGS.md](WALLS_AND_BUILDINGS.md) and [#61](https://github.com/Gamperle/Erlenfall/issues/61).

## Known problems

| Problem | Current handling | Issue |
| --- | --- | --- |
| ComfyUI's UV unwrap fails with `HIPBLAS_STATUS_ALLOC_FAILED` on meshes of 10 million faces or more on Windows ROCm | The workflow reduces the mesh to the face budget before unwrapping | [Comfy-Org/ComfyUI#16124](https://github.com/Comfy-Org/ComfyUI/issues/16124) |
| Some models take much longer, such as 25 minutes for a crate, in the upsample stage | None. 53 props took about 6 hours of GPU time | |
| TRELLIS.2 does worse than TripoSR on hay, burlap, and a campfire | Those props still use TripoSR models | [#154](https://github.com/Gamperle/Erlenfall/issues/154) |
| TRELLIS.2 models are centered on their middle, and a few face sideways | `size_glb.py` stands them on their base, and `turns` in the batch file turns odd ones. The smoke test checks every prop is within 10 cm of the ground | |
| Long SSH sessions to the PC drop, and the PC sleeps during work started over SSH | `make_trellis.py` keeps the PC awake while it runs. Run big batches a few names at a time | |
| TRELLIS.2 sometimes changes a shape it can't read, such as turning an A-frame tent into a cone | Check the results, and redraw the picture if needed | |
| TripoSR: 34 of 77 first attempts crashed at startup in `MIOpen.dll` with `0xC0000005` | `make_models.ps1` retries | [#59](https://github.com/Gamperle/Erlenfall/issues/59) |
| TripoSR: models are soft, backs are guessed, and meshes need cleanup | `cleanup_mesh.py` | [#55](https://github.com/Gamperle/Erlenfall/issues/55) |

## Licensing

- **FLUX.2 klein 4B:** Apache 2.0.
- **TRELLIS.2:** code and weights are MIT. ComfyUI (GPL-3.0) reimplements its rendering parts without NVIDIA's non-commercial `nvdiffrast`. The repackaged files on Comfy-Org's Hugging Face pages are marked MIT.
- **BiRefNet:** MIT.
- **DINOv3**, which TRELLIS.2 uses to read the picture, is under Meta's DINOv3 License. It allows commercial use but asks for "Built with DINOv3" attribution. [ASSETS.md](../ASSETS.md) carries it, and whether the game needs it too belongs with [#73](https://github.com/Gamperle/Erlenfall/issues/73).
- **TripoSR:** MIT. **SDXL:** CreativeML Open RAIL++-M, still being checked ([#60](https://github.com/Gamperle/Erlenfall/issues/60)).

Every generated file added to the repository must go through Git LFS if it's a large binary, and be listed in [ASSETS.md](../ASSETS.md) with the tools and versions, the full prompt, the seed, and any manual edits. To reproduce a picture, use the same prompt, seed, and package versions.
