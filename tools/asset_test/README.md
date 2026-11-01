# TripoSR test on an AMD GPU

**The RX 7900 XT runs Windows, so use [the asset pipeline](../../docs/ASSET_PIPELINE.md) instead.** This Linux kit remains for reference.

This kit checks whether [TripoSR](https://github.com/VAST-AI-Research/TripoSR) can generate 3D models for Erlenfall on an AMD Radeon RX 7900 XT through ROCm. **The kit itself is untested**, because the machine it was written on has no such GPU. Expect that a step may need adjusting.

## Before you start

- Linux with ROCm installed. Check [AMD's compatibility list](https://rocm.docs.amd.com/projects/radeon/en/latest/docs/compatibility/native_linux/native_linux_compatibility.html) for your distribution.
- Your user must be able to access the GPU, usually through the `render` and `video` groups.
- Python 3.10 or newer, git, and a C++ compiler with CMake, which `torchmcubes` needs to build.
- About 10 GB of free disk space for the Python packages and model download.

## Run it

Use a clear image of one object on a plain background:

```bash
./run_test.sh /path/to/object.png
```

The script installs everything into `work/` next to itself and doesn't change your system. It first prints whether PyTorch can see the GPU, then generates a model in `work/output/`.

## What to report back

1. Did it print `GPU available: True`? If not, generation falls back to the much slower CPU.
2. How long did generation take?
3. Does the resulting `work/output/0/mesh.obj` look usable when opened in Blender?

## Licensing

TripoSR is MIT-licensed, but check the terms of any tool used to create input images. List every generated asset in [ASSETS.md](../../ASSETS.md).
