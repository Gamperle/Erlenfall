"""Draws candidate pictures with FLUX.2 klein 4B, skipping existing ones. Usage: draw_klein.py batch_name"""
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
OBJECTS = {
    "anvil": "black iron blacksmith anvil with a pointed horn, on a wooden stump",
    "barrel": "upright oak barrel with iron hoops",
    "bowl": "turned wooden bowl seen from the side",
    "cauldron": "cast iron cooking cauldron with thick stubby legs and two handles",
    "chest": "wooden storage chest with iron bands, lid closed",
    "cupboard": "rustic wooden kitchen cupboard with both doors fully closed",
    "desk": "old wooden writing desk with drawers, empty top",
    "door": "heavy arched wooden door with iron hinges in a stone frame",
    "forge": "stone blacksmith forge with a chimney hood",
    "hammer": "blacksmith hammer with a square steel head and a short wooden handle",
    "jug": "glazed brown clay jug with a handle",
    "kiln": "small domed brick kiln with an arched opening",
    "lantern": "iron oil lantern with glass panes and a carrying ring",
    "pan": "black iron frying pan seen from the side, with a long handle",
    "stone_wall": "short section of dry stone wall standing alone, both ends and an uneven top visible",
    "stool": "simple wooden stool with three legs",
    "sword": "plain steel longsword with a leather-wrapped grip, pointing straight down",
    "short_sword": "plain steel short sword with a straight broad blade, pointing straight down",
}

os.makedirs(OUT, exist_ok=True)
pipe = DiffusionPipeline.from_pretrained(MODEL, torch_dtype=torch.bfloat16)
# Keeping every part on the GPU exceeds its memory and makes each picture take minutes.
pipe.enable_model_cpu_offload(device="cuda:0")
pipe.set_progress_bar_config(disable=True)
# The default VAE attention fails with hipErrorProfilerNotInitialized on this GPU.
pipe.vae.set_attn_processor(AttnProcessor())
pipe.vae.enable_tiling()
for index, (name, subject) in enumerate(OBJECTS.items()):
    for candidate in range(CANDIDATES):
        path = os.path.join(OUT, f"{name}_{candidate}.png")
        if os.path.exists(path):
            continue
        start = time.time()
        image = pipe(
            prompt=STYLE.format(subject),
            width=1024,
            height=1024,
            num_inference_steps=4,
            guidance_scale=1.0,
            generator=torch.Generator("cuda:0").manual_seed(6000 + index * 10 + candidate),
        ).images[0]
        image.save(path)
        print(f"{name}_{candidate}: {time.time() - start:.1f}s", flush=True)
print("done", flush=True)
