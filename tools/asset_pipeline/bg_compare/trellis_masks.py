"""Runs the pipeline's TRELLIS.2 workflow with the foreground mask taken from a file (u2net, birefnet or ben2) instead of from the
in-workflow BiRefNet. 'pipeline' keeps the workflow as it is (the control). Needs ComfyUI on 127.0.0.1:8188.
Usage: trellis_masks.py FACES name:model [name:model ...]   (every step writes bgcompare218\\trellis\\<name>__<model>.glb)"""
import json
import os
import shutil
import sys
import time
import urllib.request

from PIL import Image

R = r"D:\erlenfall-assets\bgcompare218"
COMFY = r"D:\erlenfall-assets\comfyui"
SERVER = "http://127.0.0.1:8188"
faces = int(sys.argv[1])
out = os.path.join(R, "trellis")
os.makedirs(out, exist_ok=True)


def call(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(SERVER + path, data=data, headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(request))


for job in sys.argv[2:]:
    name, model = job.split(":")
    target = os.path.join(out, f"{name}__{model}_{faces}.glb")
    if os.path.exists(target):
        continue
    pic = f"bgcmp218_{name}.png"
    shutil.copy(os.path.join(R, "input", name + ".png"), os.path.join(COMFY, "input", pic))
    w = json.load(open(r"D:\erlenfall-assets\trellis2_api.json"))
    w["122"]["inputs"]["image"] = pic
    w["186"]["inputs"]["target_face_count"] = faces
    w["save"]["inputs"]["filename_prefix"] = f"trellis/bgcmp218_{name}__{model}"
    if model != "pipeline":
        maskfile = f"bgcmp218_mask_{model}_{name}.png"
        Image.open(os.path.join(R, "masks", model, name + ".png")).convert("RGB").save(os.path.join(COMFY, "input", maskfile))
        w["900"] = {"class_type": "LoadImageMask", "inputs": {"image": maskfile, "channel": "red"}}
        w["303"]["inputs"]["mask"] = ["900", 0]
    t = time.time()
    pid = call("/prompt", {"prompt": w})["prompt_id"]
    while True:
        time.sleep(10)
        h = call("/history/" + pid).get(pid)
        if h and h["status"].get("completed") is not None and h["status"]["status_str"] in ("success", "error"):
            break
    if h["status"]["status_str"] != "success":
        err = next((m[1] for m in h["status"]["messages"] if m[0] == "execution_error"), {})
        print(job, "FAILED", err.get("node_type"), str(err.get("exception_message"))[:200], flush=True)
        continue
    saved = h["outputs"]["save"]["3d"][0]
    shutil.copy(os.path.join(COMFY, "output", saved["subfolder"], saved["filename"]), target)
    print(job, "ok", f"{time.time() - t:.0f}s", flush=True)
print("finished", flush=True)
