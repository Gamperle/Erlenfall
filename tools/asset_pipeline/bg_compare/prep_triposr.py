"""Builds TripoSR inputs (RGB on gray, foreground resized to 85%) from a picture and a mask, the way run.py does after rembg.
Usage: prep_triposr.py out_dir name model [name model ...]"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, r"D:\erlenfall-assets\TripoSR")
from tsr.utils import resize_foreground

R = os.environ.get("BGCOMPARE_RUN", r"D:\erlenfall-assets\bgcompare218")  # #501 ran it with bgcompare501
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
args = sys.argv[2:]
for name, model in zip(args[::2], args[1::2]):
    rgb = Image.open(os.path.join(R, "input", name + ".png")).convert("RGB")
    mask = Image.open(os.path.join(R, "masks", model, name + ".png")).convert("L")
    rgba = rgb.copy()
    rgba.putalpha(mask)
    image = resize_foreground(rgba, 0.85)
    image = np.array(image).astype(np.float32) / 255.0
    image = image[:, :, :3] * image[:, :, 3:4] + (1 - image[:, :, 3:4]) * 0.5
    Image.fromarray((image * 255.0).astype(np.uint8)).save(os.path.join(out, f"{name}__{model}.png"))
    print(name, model, flush=True)
