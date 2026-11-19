"""Runs TripoSR's run.py with cuDNN off and a smaller mesh for the texture bake. Run it from the TripoSR folder, with run.py's arguments.

Extra option: --mask MASK.png takes the foreground mask from a file (white = foreground, made by make_masks.py with
BiRefNet) instead of letting run.py call rembg with u2net, which fills the gaps between thin parts such as the spokes
of a wheel (#492, comparison in docs/ASSET_PIPELINE.md). The picture is prepared the way run.py does it after rembg
(foreground resized to --foreground-ratio, gray background) and passed on with --no-remove-bg. Without --mask,
run.py removes the background itself, as before.

run.py only creates <output-dir>/0 in the branch that removes the background, so with --no-remove-bg xatlas.export
failed with "Cannot open path ...\\0\\mesh.obj" after a full run (#493). This creates the folder first.

When run.py has made <output-dir>/0/mesh.obj, this adds a "mesh" stage to <batch>\\provenance\\<name>.json (see
provenance.py, #398) that names the mask model and its weight file. The output folder is <batch>\\models\\<name>,
as make_models.ps1 sets it.

With cuDNN off, a large MIOpen DLL no longer loads, the first convolution takes 0.16 s rather than 10.9 s,
and the output is practically unchanged. Whether this prevents the startup crash isn't known (issue #59).

Baking (--bake-texture) spent 97 to 99% of its time in xatlas, which unwraps the whole marching-cubes mesh:
390 s for 250,000 faces (#62). The unwrap grows faster than the face count, and the later cleanup reduces
the mesh to 1,500 to 8,000 faces anyway, so the mesh is reduced to BAKE_FACES faces (30,000 by default, 0 to
keep it whole) before unwrapping. The colors are queried from the triplane at each surface point, so the
texture loses nothing, and the cleaned models look the same (see docs/ASSET_PIPELINE.md). The reduction needs
fast_simplification in the TripoSR venv; without it a warning is printed and the mesh stays whole.
"""
import faulthandler
import json
import os
import runpy
import subprocess
import sys

import torch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance

faulthandler.enable()
torch.backends.cudnn.enabled = False
sys.path.insert(0, ".")

BAKE_FACES = int(os.environ.get("BAKE_FACES", "30000"))


def option(name, default=None):
    """The value after --name in run.py's arguments, or default."""
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv[1:-1] else default


def take_option(name):
    """Removes --name and its value from the arguments (run.py doesn't know it) and returns the value, or None."""
    value = option(name)
    if value is not None:
        i = sys.argv.index(name)
        del sys.argv[i:i + 2]
    return value


def prepare_masked_picture(picture, mask_path, output_dir, ratio):
    """Cuts the picture out with the mask and puts it on gray, as run.py does after rembg. Saves it as <output-dir>/0/input.png."""
    import numpy as np
    from PIL import Image
    from tsr.utils import resize_foreground

    rgba = Image.open(picture).convert("RGB")
    mask = Image.open(mask_path).convert("L")
    if mask.size != rgba.size:
        raise SystemExit(f"the mask is {mask.size} but the picture is {rgba.size}: {mask_path}")
    rgba.putalpha(mask)
    image = np.array(resize_foreground(rgba, ratio)).astype(np.float32) / 255.0
    image = image[:, :, :3] * image[:, :, 3:4] + (1 - image[:, :, 3:4]) * 0.5
    target = os.path.join(output_dir, "0", "input.png")
    Image.fromarray((image * 255.0).astype(np.uint8)).save(target)
    return target


def mask_record(mask_path):
    """The provenance fields that name the mask model: from mask_model.json next to the mask (make_masks.py), or rembg's u2net."""
    if mask_path:
        info_path = os.path.join(os.path.dirname(os.path.abspath(mask_path)), "mask_model.json")
        info = json.load(open(info_path)) if os.path.exists(info_path) else {}
        return {"helpers": ["BiRefNet"], "mask_tool": info.get("tool"), "models": info.get("models"),
                "mask_versions": info.get("versions"), "mask_sha256": provenance.sha256(mask_path)}
    # rembg's default model, as run.py uses it. It is hashed if the weight file is where U2NET_HOME says.
    weights = os.path.join(os.environ.get("U2NET_HOME", os.path.expanduser("~/.u2net")), "u2net.onnx")
    models = [{"file": "u2net.onnx", "size": os.path.getsize(weights), "sha256": provenance.sha256(weights).lower()}] if os.path.exists(weights) else None
    return {"helpers": ["rembg u2net"], "models": models}


def write_provenance(picture, mask_path):
    output = os.path.abspath(option("--output-dir", "output"))
    if not os.path.exists(os.path.join(output, "0", "mesh.obj")):
        return
    name = os.path.basename(output)
    base = os.path.dirname(os.path.dirname(output))
    try:
        commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        commit = None
    provenance.add_stage(
        os.path.join(base, "provenance", name + ".json"),
        {"step": "mesh", "tool": "TripoSR", "versions": {"TripoSR": commit or None, "torch": torch.__version__, "python": sys.version.split()[0]},
         "date": provenance.today(), **mask_record(mask_path), "mc_resolution": int(option("--mc-resolution", 256)),
         "bake_texture": "--bake-texture" in sys.argv, "cudnn": False, "script": "run_triposr.py",
         "picture_sha256": provenance.sha256(picture) if picture and os.path.exists(picture) else None},
        kind="ai_prop", asset=f"assets/props/{name}.glb", batch=os.path.basename(base), name=name,
        # Who picked the picture, worded the way ASSETS.md words it. The records need it, so set CHOSEN_BY for a manual run.
        **({"chosen_by": os.environ["CHOSEN_BY"]} if os.environ.get("CHOSEN_BY") else {}),
    )


def reduce_for_baking():
    """Makes TSR.extract_mesh return at most BAKE_FACES faces when it is asked for a mesh without vertex colors (a bake)."""
    if BAKE_FACES <= 0:
        return
    try:
        import fast_simplification
    except ImportError:
        print("WARNING: fast_simplification is not installed, so the mesh is not reduced before baking (slow, see #62)", flush=True)
        return
    import numpy as np
    import trimesh
    from tsr.system import TSR

    extract_mesh = TSR.extract_mesh

    def reduced(self, scene_codes, has_vertex_color, *args, **kwargs):
        meshes = extract_mesh(self, scene_codes, has_vertex_color, *args, **kwargs)
        if has_vertex_color:
            return meshes
        out = []
        for mesh in meshes:
            if len(mesh.faces) > BAKE_FACES:
                vertices, faces = fast_simplification.simplify(
                    np.asarray(mesh.vertices, dtype=np.float32), np.asarray(mesh.faces, dtype=np.int32), target_count=BAKE_FACES
                )
                print(f"reduced the mesh from {len(mesh.faces)} to {len(faces)} faces before baking", flush=True)
                mesh = trimesh.Trimesh(vertices, faces, process=False)
            out.append(mesh)
        return out

    TSR.extract_mesh = reduced


reduce_for_baking()
sys.argv = ["run.py"] + sys.argv[1:]
MASK = take_option("--mask")
PICTURE = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else None
OUTPUT_DIR = option("--output-dir", "output/")
os.makedirs(os.path.join(OUTPUT_DIR, "0"), exist_ok=True)
if MASK:
    if not PICTURE:
        raise SystemExit("--mask needs the picture as the first argument")
    sys.argv[1] = prepare_masked_picture(PICTURE, MASK, OUTPUT_DIR, float(option("--foreground-ratio", 0.85)))
    sys.argv.append("--no-remove-bg")
runpy.run_path("run.py", run_name="__main__")
write_provenance(PICTURE, MASK)
