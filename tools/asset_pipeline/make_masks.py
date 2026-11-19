"""Writes a foreground mask for each of a batch's pictures with BiRefNet, through a running ComfyUI server (#492).

Usage: make_masks.py batch_name [name ...]
Without names it uses every picture in <batch>/input. Each mask is saved as <batch>/masks/<name>.png (white = foreground),
and <batch>/masks/mask_model.json names the weight file and the ComfyUI that made them, for the provenance record that
run_triposr.py --mask writes. This is the same BiRefNet (ComfyUI's RemoveBackground node) that TRELLIS.2 runs inside its
workflow. It is for the TripoSR fallback, whose own rembg u2net fills the gaps between thin parts such as spokes
(see "Background removal comparison" in docs/ASSET_PIPELINE.md). Finished masks are skipped.
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
WEIGHTS = "birefnet.safetensors"


def call(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(SERVER + path, data=data, headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(request))


def mask_workflow(upload):
    return {
        "1": {"class_type": "LoadImage", "inputs": {"image": upload}},
        "2": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": WEIGHTS}},
        "3": {"class_type": "RemoveBackground", "inputs": {"bg_removal_model": ["2", 0], "image": ["1", 0]}},
        "4": {"class_type": "MaskToImage", "inputs": {"mask": ["3", 0]}},
        "5": {"class_type": "SaveImage", "inputs": {"images": ["4", 0], "filename_prefix": "masks/" + upload[:-4]}},
    }


def make_mask(upload, target):
    """Runs the workflow on a picture already in ComfyUI's input folder and copies the mask to target. Returns an error text or None."""
    prompt_id = call("/prompt", {"prompt": mask_workflow(upload)})["prompt_id"]
    while True:
        time.sleep(2)
        history = call("/history/" + prompt_id).get(prompt_id)
        if history and history["status"].get("completed") is not None and history["status"]["status_str"] in ("success", "error"):
            break
    if history["status"]["status_str"] != "success":
        error = next((m[1] for m in history["status"]["messages"] if m[0] == "execution_error"), {})
        return f"FAILED in {error.get('node_type')}: {error.get('exception_message', '')[:200]}"
    saved = history["outputs"]["5"]["images"][0]
    shutil.copy(os.path.join(COMFY, "output", saved["subfolder"], saved["filename"]), target)
    return None


def main(batch, names):
    base = os.path.join(ROOT, batch)
    out_dir = os.path.join(base, "masks")
    os.makedirs(out_dir, exist_ok=True)
    names = [n for arg in names for n in arg.split(",") if n] or sorted(f[:-4] for f in os.listdir(os.path.join(base, "input")) if f.endswith(".png"))
    try:
        system = call("/system_stats")["system"]
    except Exception as error:
        print("ComfyUI is not running on", SERVER, error, flush=True)
        return 1
    # "models" has the same shape as in TRELLIS.2's mesh stage: the weight file, its size and SHA-256.
    models = provenance.workflow_models(mask_workflow("x.png"), os.path.join(COMFY, "models"))
    with open(os.path.join(out_dir, "mask_model.json"), "w") as f:
        json.dump({"tool": "BiRefNet (ComfyUI RemoveBackground node)", "models": models,
                   "versions": {"ComfyUI": system.get("comfyui_version"), "pytorch": system.get("pytorch_version")}}, f, indent=2)
    failed = 0
    for name in names:
        target = os.path.join(out_dir, name + ".png")
        if os.path.exists(target):
            continue
        upload = f"{batch}_{name}_mask.png"
        shutil.copy(os.path.join(base, "input", name + ".png"), os.path.join(COMFY, "input", upload))
        error = make_mask(upload, target)
        failed += bool(error)
        print(name, error or "ok", flush=True)
    print("finished", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2:]))
