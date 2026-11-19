"""Writes BEN2 Base alpha masks (white = foreground) for every png in an input folder. Usage: mask_ben2.py in_dir out_dir"""
import os
import sys
import time

sys.path.insert(0, r"D:\erlenfall-assets\bgcompare218\ben2")
import torch
from PIL import Image
from safetensors.torch import load_file

from BEN2 import BEN_Base

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
model = BEN_Base()
model.load_state_dict(load_file(r"D:\erlenfall-assets\bgcompare218\ben2\model.safetensors"), strict=True)
model.eval()
for f in sorted(os.listdir(src)):
    if not f.endswith(".png"):
        continue
    t = time.time()
    out = model.inference(Image.open(os.path.join(src, f)).convert("RGB"), refine_foreground=False)
    out.getchannel("A").save(os.path.join(dst, f))
    print(f, f"{time.time() - t:.1f}s", flush=True)
