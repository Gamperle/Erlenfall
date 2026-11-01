"""Draws straight-on candidate pictures with SDXL, skipping existing ones. Usage: draw_pictures.py batch_name"""
import os
import sys
import time

import torch
from diffusers import StableDiffusionXLPipeline
from diffusers.models.attention_processor import AttnProcessor

ROOT = os.environ.get("ASSET_ROOT", r"D:\erlenfall-assets")
OUT = os.path.join(ROOT, sys.argv[1], "candidates")
MODEL = "stabilityai/stable-diffusion-xl-base-1.0"
CANDIDATES = 6
STYLE = (
    "single {}, 3d game prop, straight-on front view at eye level, camera level with the object, centered, "
    "entire object visible with empty space around it, isolated on a plain white background, "
    "realistic proportions, worn handmade materials, slightly stylized, soft even studio lighting"
)
NEGATIVE = (
    "text, watermark, logo, people, hands, multiple objects, room, floor, scenery, cropped, cut off, blurry, cartoon, "
    "pattern, texture, tiled, repeating, seamless, collection, many, top view, view from above, tilted, angled, perspective"
)
OBJECTS = {
    "desk": "old wooden writing desk with drawers, empty top",
    "stool": "simple wooden stool with exactly three legs",
    "cupboard": "rustic wooden kitchen cupboard with both doors fully closed",
    "chest": "wooden storage chest with iron bands, lid closed",
    "stone_wall": "small ruined fragment of dry stone wall standing alone, uneven top edge, clear outline against the background",
    "timber_wall": "small standalone half-timbered wall fragment, white plaster and dark oak beams, clear outline against the background",
    "door": "heavy arched wooden door with iron hinges in a stone frame",
    "cauldron": "cast iron cooking cauldron with thick stubby legs",
    "pan": "black iron frying pan seen from the side, with a long handle",
    "jug": "glazed brown clay jug with a handle",
    "bowl": "one lone turned wooden bowl seen from the side",
    "barrel": "one lone upright oak barrel with iron hoops",
    "kiln": "small domed brick kiln with an arched opening",
    "anvil": "classic black iron blacksmith anvil with a pointed horn, on a wooden stump",
    "forge": "stone blacksmith forge with a chimney hood",
    "bellows": "classic hand bellows with two wooden boards, pleated leather sides and a metal nozzle",
    "hammer": "blacksmith cross-peen hammer with a square steel head and a short wooden handle, standing upright",
    "sword": "plain steel longsword with a leather-wrapped grip, pointing straight down, vertical",
    "lantern": "iron oil lantern with glass panes and a carrying ring",
    "flask": "round glass alchemy flask with a cork, filled with opaque green liquid, no stand",
}

os.makedirs(OUT, exist_ok=True)
pipe = StableDiffusionXLPipeline.from_pretrained(MODEL, torch_dtype=torch.float16, variant="fp16", use_safetensors=True).to("cuda:0")
pipe.set_progress_bar_config(disable=True)
# The default attention in the VAE fails with hipErrorProfilerNotInitialized on this GPU.
pipe.vae.to(torch.float32)
pipe.vae.set_attn_processor(AttnProcessor())
pipe.vae.enable_tiling()
for index, (name, subject) in enumerate(OBJECTS.items()):
    for candidate in range(CANDIDATES):
        path = os.path.join(OUT, f"{name}_{candidate}.png")
        if os.path.exists(path):
            continue
        start = time.time()
        latents = pipe(
            STYLE.format(subject),
            negative_prompt=NEGATIVE,
            num_inference_steps=30,
            guidance_scale=7.0,
            generator=torch.Generator("cuda:0").manual_seed(3000 + index * 10 + candidate),
            output_type="latent",
        ).images
        with torch.no_grad():
            decoded = pipe.vae.decode(latents.to(torch.float32) / pipe.vae.config.scaling_factor).sample
        pipe.image_processor.postprocess(decoded.detach().cpu(), output_type="pil")[0].save(path)
        print(f"{name}_{candidate}: {time.time() - start:.1f}s", flush=True)
print("done", flush=True)
