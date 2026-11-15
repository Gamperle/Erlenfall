"""Draws candidate pictures with FLUX.2 klein 4B, skipping existing ones. Usage: draw_klein.py batch_name

The objects and the first seed come from batches/<batch_name>.json.
"""
import json
import os
import sys
import time

import torch
from diffusers import DiffusionPipeline
from diffusers.models.attention_processor import AttnProcessor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance

ROOT = os.environ.get("ASSET_ROOT", r"D:\erlenfall-assets")
OUT = os.path.join(ROOT, sys.argv[1], "candidates")
MODEL = "black-forest-labs/FLUX.2-klein-4B"
CANDIDATES = 6
STYLE = (
    "A single {}, 3d game prop, straight-on front view at eye level, centered, the entire object visible "
    "with empty space around it, isolated on a plain white background, realistic proportions, "
    "worn handmade materials, soft even studio lighting. No text, no people, no other objects."
)
BATCH = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "batches", sys.argv[1] + ".json")))

os.makedirs(OUT, exist_ok=True)
PROVENANCE = os.path.join(ROOT, sys.argv[1], "provenance")


def model_revision():
    """The commit of the downloaded model, which names its exact weights. None if it can't be found."""
    try:
        from huggingface_hub import snapshot_download

        return os.path.basename(snapshot_download(MODEL, local_files_only=True))
    except Exception:
        return None


VERSIONS = {
    "python": sys.version.split()[0],
    "torch": torch.__version__,
    "diffusers": provenance.module_version("diffusers"),
    "model": MODEL,
    "model_revision": model_revision(),
}
pipe = DiffusionPipeline.from_pretrained(MODEL, torch_dtype=torch.bfloat16)
# Keeping every part on the GPU exceeds its memory and makes each picture take minutes.
pipe.enable_model_cpu_offload(device="cuda:0")
pipe.set_progress_bar_config(disable=True)
# The default VAE attention fails with hipErrorProfilerNotInitialized on this GPU.
pipe.vae.set_attn_processor(AttnProcessor())
pipe.vae.enable_tiling()
for index, (name, item) in enumerate(BATCH["objects"].items()):
    for candidate in range(CANDIDATES):
        path = os.path.join(OUT, f"{name}_{candidate}.png")
        if os.path.exists(path):
            continue
        start = time.time()
        seed = BATCH["seed"] + index * 10 + candidate
        prompt = STYLE.format(item["subject"])
        image = pipe(
            prompt=prompt,
            width=1024,
            height=1024,
            num_inference_steps=4,
            guidance_scale=1.0,
            generator=torch.Generator("cuda:0").manual_seed(seed),
        ).images[0]
        image.save(path)
        # The record's name is the candidate's, so it matches the prop's name if this picture is chosen.
        provenance.add_stage(
            os.path.join(PROVENANCE, f"{name}_{candidate}.json"),
            {"step": "image", "tool": "FLUX.2 klein 4B", "versions": VERSIONS, "date": provenance.today(), "width": 1024,
             "height": 1024, "steps": 4, "guidance": 1.0, "candidate": candidate, "picture_sha256": provenance.sha256(path)},
            kind="ai_prop", asset=f"assets/props/{name}_{candidate}.glb", batch=sys.argv[1], object=name, name=f"{name}_{candidate}",
            subject=item["subject"], prompt=prompt, seed=seed,
        )
        print(f"{name}_{candidate}: {time.time() - start:.1f}s", flush=True)
print("done", flush=True)
