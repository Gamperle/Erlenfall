# Asset generation pipeline

This pipeline makes draft 3D props from text. FLUX.2 klein 4B draws a picture, TripoSR turns it into a textured mesh, and Blender renders previews for review. It runs on a Windows PC with an AMD Radeon RX 7900 XT, controlled over SSH.

**Status: experimental. No generated asset is in the game yet.** Before one can be added:

1. The maintainer accepts the art style ([#22](https://github.com/Gamperle/Erlenfall/issues/22)).
2. The SDXL license is cleared ([#60](https://github.com/Gamperle/Erlenfall/issues/60)).
3. A cleanup step exists for orientation, face count, and glTF export ([#55](https://github.com/Gamperle/Erlenfall/issues/55)).

## Workflow

| Step | Tool | Runs on | Time per item | Output |
| --- | --- | --- | --- | --- |
| Draw candidates | FLUX.2 klein 4B (`draw_klein.py`) | GPU | About 9 s, 7.9 GB | `<batch>\candidates\<object>_<n>.png` |
| Choose pictures | A person or agent | | | `<batch>\input\` |
| Make the model | TripoSR, `rembg` | GPU and CPU | About 2 minutes, including the preview and crash retries | `<batch>\models\<name>\0\mesh.obj`, `texture.png` |
| Render previews | Blender | CPU | Included above | `<batch>\previews\<name>_front.png`, `_back.png` |
| Clean up for the game | Blender (`clean_models.ps1`, `cleanup_mesh.py`) | CPU | 10 to 35 s | `cleaned\<name>.glb` |
| Reshape and set real size | Blender (`adjust_glb.py`, `size_glb.py`, `size_models.ps1`) | CPU | Seconds | `props\<name>.glb` |

Texture baking takes most of the model time, at 30 to 177 s, and it grows with mesh complexity. The GPU model step is a steady 12 s, so the card sits mostly idle during a batch. The batch uses about 3 of the CPU's 16 threads and 2.5 GB of RAM while baking, so the PC has spare capacity. Previews are not the bottleneck: one render takes 2.5 s on the CPU and 1.4 s on the GPU with Blender's HIP backend ([#62](https://github.com/Gamperle/Erlenfall/issues/62)).

The scripts are in [tools/asset_pipeline](../tools/asset_pipeline):

| File | Purpose |
| --- | --- |
| `setup_pc.ps1` | Installs everything into one folder |
| `draw_pictures.py` | Holds the object list and prompts, and draws candidates |
| `make_models.ps1` | Makes models and previews, with crash retries |
| `render_preview.py` | Renders a model from the front and back |
| `check_mesh.py` | Prints face count, watertightness, and volume |
| `watchdog.ps1` | Stops hung runs during a batch |
| `torchmcubes.py` | Replaces the `torchmcubes` package, which doesn't build here |

`setup_pc.ps1` and `make_models.ps1` combine steps that were first run separately. They have not been run in this exact form, so expect to adjust them on first use.

## Access

Ask the maintainer for the PC's address and SSH user, which are kept out of this public repository. Check the login, then use the host in place of `ASSET_PC` below:

```bash
ssh -o BatchMode=yes ASSET_PC "hostname; whoami"
```

- The remote shell is Windows PowerShell 5, which doesn't support `&&`.
- Copy a script over and run it with `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`. Long inline commands are easy to break with bash and PowerShell quoting.
- The SSH user is not an administrator. Installing system software means asking the maintainer.
- Start long jobs in the background. Scripts skip finished items, so they can be rerun after a dropped connection or if the PC sleeps.

## Setting up

An administrator installs these once: Python 3.12 for all users, Visual Studio 2022 Build Tools with C++, CMake, Blender, and Git. Long file paths must be turned on, and the SSH service restarted so it picks up the new PATH. The current PC already has all of this. The work folder is `D:\erlenfall-assets`.

Then, from the SSH user:

```bash
scp -r tools/asset_pipeline ASSET_PC:D:/erlenfall-assets-setup
ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets-setup\setup_pc.ps1"
```

Both environments should report that the GPU is available. The first runs also download about 7 GB for SDXL, plus TripoSR's model and the 176 MB background remover. These are cached in the work folder.

## Making a batch

1. Edit `OBJECTS` in `draw_pictures.py`, copy it to the work folder, and draw candidates:

   ```bash
   ssh ASSET_PC "Set-Location D:\erlenfall-assets; \$env:HF_HOME='D:\erlenfall-assets\hf-cache-sdxl'; venv-images\Scripts\python.exe draw_pictures.py my_batch"
   ```

2. Look at the candidates and copy the best ones to `D:\erlenfall-assets\my_batch\input\`.
3. Make the models:

   ```bash
   ssh ASSET_PC "powershell -NoProfile -ExecutionPolicy Bypass -File D:\erlenfall-assets\make_models.ps1 -Batch my_batch"
   ```

4. Copy the previews back with `scp` and check them against the picture. Use `check_mesh.py`'s output to spot failed models. The failed stone wall in the first batch had just 222 faces.

## Choosing the image model

FLUX.2 klein 4B is the default, under Apache 2.0, with no account needed. In testing it got objects right far more often than SDXL, with cleaner backgrounds. It needs `enable_model_cpu_offload`, because keeping every part on the GPU exceeds its memory. It needs its own environment with current `diffusers`, not `setup_pc.ps1`'s `venv-images`. Z-Image Turbo also works, at 18 s and 12.1 GB. TRELLIS.2 has not produced a model on this PC ([#70](https://github.com/Gamperle/Erlenfall/issues/70)), and two TripoSR processes at once make the startup crash much worse ([#59](https://github.com/Gamperle/Erlenfall/issues/59)).

## Getting good pictures

The picture matters more than anything else, because TripoSR sees only that one image. Drawing six candidates and keeping the best three costs very little.

- **Reject** pictures that show several objects, a room or scenery, a cropped object, or a flat pattern that fills the frame.
- **Use a straight-on view at eye level.** It gave cleaner pictures in the second batch, but barrels, bowls, and doors still lean, so expect to straighten models during cleanup.
- **Check it's the right object.** SDXL has drawn an axe when asked for a hammer, and it doesn't reliably know bellows.
- **Describe the shape, not only the name.** "Pointed horn" and "square steel head" helped the anvil and hammer. Asking for closed cupboard doors or three stool legs often still failed.
- **Prefer solid shapes.** Forges, jugs, lanterns, and doors worked best. Glass, thin parts, and hidden sides are the weakest.
- **Walls are unreliable.** A stone wall works when the picture shows a clear outline, in 3 of 6 candidates. Every timber wall picture ran off the frame or showed a room. See [#61](https://github.com/Gamperle/Erlenfall/issues/61).
- **Some objects need another source.** SDXL drew machines for bellows in all six candidates, and glass flasks still come out poorly.

## Known problems

| Problem | Current handling | Issue |
| --- | --- | --- |
| 34 of 77 first attempts across two batches crashed at startup in `MIOpen.dll` with `0xC0000005`. Crashes come in runs, and 5 models failed all 8 attempts before working in a later rerun | `make_models.ps1` retries, and running it again picks up failed models | [#59](https://github.com/Gamperle/Erlenfall/issues/59) |
| A run can also hang at "Initializing model" with no CPU use, which stops the batch | Run `watchdog.ps1` beside the batch. It stops a run after 5 idle minutes, and `make_models.ps1` retries it | [#59](https://github.com/Gamperle/Erlenfall/issues/59) |
| The SDXL VAE crashes on the GPU with `hipErrorProfilerNotInitialized` | `AttnProcessor()` and `vae.enable_tiling()`. Check larger pictures for seams, because only small previews have been checked | [#47](https://github.com/Gamperle/Erlenfall/issues/47) |
| `torchmcubes` can't build, because PyTorch's CMake files use an undefined `hip::host` target on Windows | Stand-in using scikit-image on the CPU | [#47](https://github.com/Gamperle/Erlenfall/issues/47) |
| TripoSR's texture baking mixes CPU and GPU tensors | `setup_pc.ps1` patches `tsr/bake_texture.py` | [#47](https://github.com/Gamperle/Erlenfall/issues/47) |
| Models are soft, backs are guessed, and meshes have too many faces and aren't watertight | Needs cleanup | [#55](https://github.com/Gamperle/Erlenfall/issues/55) |

TripoSR meshes are Z-up, while Blender's OBJ importer assumes Y-up by default. A chair that looks like it's lying down usually means the wrong import setting, not a bad model.

## Licensing

Tools: TripoSR is MIT-licensed, and SDXL uses CreativeML Open RAIL++-M, which is still being checked ([#60](https://github.com/Gamperle/Erlenfall/issues/60)).

Every generated file added to the repository must go through Git LFS if it's a large binary, and be listed in [ASSETS.md](../ASSETS.md) with the tools and versions, the full prompt, the seed, and any manual edits. To reproduce a picture, use the same prompt, seed, and package versions.
