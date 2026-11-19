"""Writes rembg u2net masks (white = foreground), as TripoSR's run.py gets them (rembg defaults). Usage: mask_u2net.py in_dir out_dir"""
import os
import sys

os.environ["U2NET_HOME"] = r"D:\erlenfall-assets\u2net"
os.environ["HOME"] = r"D:\erlenfall-assets\u2net"
from PIL import Image
from rembg import new_session, remove

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
session = new_session("u2net")
for f in sorted(os.listdir(src)):
    if not f.endswith(".png"):
        continue
    rgba = remove(Image.open(os.path.join(src, f)).convert("RGB"), session=session)
    rgba.getchannel("A").save(os.path.join(dst, f))
    print(f, flush=True)
