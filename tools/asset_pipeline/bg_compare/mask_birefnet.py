"""Writes the masks of the pipeline's own BiRefNet (ComfyUI's RemoveBackground node, birefnet.safetensors), white = foreground.
Needs ComfyUI running on 127.0.0.1:8188. Usage: mask_birefnet.py in_dir out_dir"""
import json
import os
import shutil
import sys
import time
import urllib.request

COMFY = r"D:\erlenfall-assets\comfyui"
SERVER = "http://127.0.0.1:8188"
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)


def call(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(SERVER + path, data=data, headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(request))


for f in sorted(os.listdir(src)):
    if not f.endswith(".png"):
        continue
    name = "bgcmp218_" + f
    shutil.copy(os.path.join(src, f), os.path.join(COMFY, "input", name))
    workflow = {
        "1": {"class_type": "LoadImage", "inputs": {"image": name}},
        "2": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": "birefnet.safetensors"}},
        "3": {"class_type": "RemoveBackground", "inputs": {"bg_removal_model": ["2", 0], "image": ["1", 0]}},
        "4": {"class_type": "MaskToImage", "inputs": {"mask": ["3", 0]}},
        "5": {"class_type": "SaveImage", "inputs": {"images": ["4", 0], "filename_prefix": "bgcmp218/" + f[:-4]}},
    }
    pid = call("/prompt", {"prompt": workflow})["prompt_id"]
    while True:
        time.sleep(2)
        h = call("/history/" + pid).get(pid)
        if h and h["status"].get("completed") is not None and h["status"]["status_str"] in ("success", "error"):
            break
    if h["status"]["status_str"] != "success":
        print(f, "FAILED", h["status"]["messages"][-1], flush=True)
        continue
    saved = h["outputs"]["5"]["images"][0]
    shutil.copy(os.path.join(COMFY, "output", saved["subfolder"], saved["filename"]), os.path.join(dst, f))
    print(f, "ok", flush=True)
