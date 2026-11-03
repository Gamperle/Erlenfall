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
        image = pipe(
            prompt=STYLE.format(item["subject"]),
            width=1024,
            height=1024,
            num_inference_steps=4,
            guidance_scale=1.0,
            generator=torch.Generator("cuda:0").manual_seed(BATCH["seed"] + index * 10 + candidate),
        ).images[0]
        image.save(path)
        print(f"{name}_{candidate}: {time.time() - start:.1f}s", flush=True)
print("done", flush=True)
