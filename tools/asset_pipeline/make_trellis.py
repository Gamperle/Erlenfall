"""Turns a batch's chosen pictures into textured models with TRELLIS.2, through a running ComfyUI server.

Usage: make_trellis.py batch_name [name ...]
Without names it uses every picture in <batch>/input. Each model is reduced to its face budget from
batches/<batch>.json and saved as <batch>/trellis/<name>.glb with base color, normal, roughness, and
ambient occlusion maps. Finished models are skipped, so it can be run again after a failure.
"""
import json
import os
import shutil
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance

ROOT = os.environ.get("ASSET_ROOT", r"D:\erlenfall-assets")
SERVER = "http://127.0.0.1:8188"
COMFY = os.path.join(ROOT, "comfyui")
HERE = os.path.dirname(os.path.abspath(__file__))
# The texture maps' size in pixels, the same as the cleaned TripoSR models.
TEXTURE_SIZE = 1024

batch = sys.argv[1]
base = os.path.join(ROOT, batch)
objects = json.load(open(os.path.join(HERE, "batches", batch + ".json")))["objects"]
# PowerShell passes a -File list as one comma-separated argument.
names = [n for arg in sys.argv[2:] for n in arg.split(",") if n] or sorted(f[:-4] for f in os.listdir(os.path.join(base, "input")) if f.endswith(".png"))
out_dir = os.path.join(base, "trellis")
os.makedirs(out_dir, exist_ok=True)
if os.name == "nt":
    import ctypes

    # Windows doesn't count work started over SSH as activity, so it would sleep in the middle of a batch.
    # ES_CONTINUOUS | ES_SYSTEM_REQUIRED keeps it awake until this process ends.
    ctypes.windll.kernel32.SetThreadExecutionState(0x80000000 | 0x00000001)


def call(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(SERVER + path, data=data, headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(request))


def comfy_versions():
    """ComfyUI's and its PyTorch's versions, as the running server reports them."""
    try:
        system = call("/system_stats")["system"]
        return {"ComfyUI": system.get("comfyui_version"), "pytorch": system.get("pytorch_version"), "python": system.get("python_version", "").split(" ")[0] or None}
    except Exception:
        return {"ComfyUI": None}


for name in names:
    target = os.path.join(out_dir, name + ".glb")
    if os.path.exists(target):
        continue
    item = objects[name.rsplit("_", 1)[0]]
    picture = os.path.join(base, "input", name + ".png")
    if not os.path.exists(picture):
        picture = os.path.join(base, "candidates", name + ".png")
    shutil.copy(picture, os.path.join(COMFY, "input", f"{batch}_{name}.png"))
    workflow = json.load(open(os.path.join(HERE, "trellis2_api.json")))
    workflow["122"]["inputs"]["image"] = f"{batch}_{name}.png"
    workflow["186"]["inputs"]["target_face_count"] = item["faces"]
    workflow["save"]["inputs"]["filename_prefix"] = f"trellis/{batch}_{name}"
    start = time.time()
    prompt_id = call("/prompt", {"prompt": workflow})["prompt_id"]
    while True:
        time.sleep(10)
        history = call("/history/" + prompt_id).get(prompt_id)
        if history and history["status"].get("completed") is not None and history["status"]["status_str"] in ("success", "error"):
            break
    status = history["status"]
    if status["status_str"] != "success":
        error = next((m[1] for m in status["messages"] if m[0] == "execution_error"), {})
        print(f"{name} FAILED in {error.get('node_type')}: {error.get('exception_message', '')[:200]}", flush=True)
        continue
    saved = history["outputs"]["save"]["3d"][0]
    shutil.copy(os.path.join(COMFY, "output", saved["subfolder"], saved["filename"]), target)
    # TRELLIS.2 also runs BiRefNet and DINOv3 inside this workflow, so the workflow file's hash names the set.
    provenance.add_stage(
        os.path.join(base, "provenance", name + ".json"),
        {"step": "mesh", "tool": "TRELLIS.2 (Comfy-Org int8 build)", "versions": comfy_versions(), "date": provenance.today(),
         "helpers": ["BiRefNet", "DINOv3"], "faces": item["faces"], "workflow": "trellis2_api.json",
         "workflow_sha256": provenance.sha256(os.path.join(HERE, "trellis2_api.json")), "picture_sha256": provenance.sha256(picture),
         "comfy_prompt_id": prompt_id},
        kind="ai_prop", asset=f"assets/props/{name}.glb", batch=batch, object=name.rsplit("_", 1)[0], name=name, subject=item["subject"],
    )
    print(f"{name} ok {item['faces']} faces {time.time() - start:.0f}s", flush=True)
print("finished", flush=True)
