"""Runs TripoSR's run.py with cuDNN off. Run it from the TripoSR folder, with run.py's arguments.

With cuDNN off, a large MIOpen DLL no longer loads, the first convolution takes 0.16 s rather than 10.9 s,
and the output is practically unchanged. Whether this prevents the startup crash isn't known (issue #59).

When run.py has made <output-dir>/0/mesh.obj, this adds a "mesh" stage to <batch>\\provenance\\<name>.json
(see provenance.py, #398). The output folder is <batch>\\models\\<name>, as make_models.ps1 sets it.
"""
import faulthandler
import os
import runpy
import subprocess
import sys

import torch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance


def option(name, default=None):
    """The value after --name in run.py's arguments, or default."""
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv[1:-1] else default


def write_provenance():
    output = os.path.abspath(option("--output-dir", "output"))
    if not os.path.exists(os.path.join(output, "0", "mesh.obj")):
        return
    name = os.path.basename(output)
    base = os.path.dirname(os.path.dirname(output))
    try:
        commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        commit = None
    picture = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else None
    provenance.add_stage(
        os.path.join(base, "provenance", name + ".json"),
        {"step": "mesh", "tool": "TripoSR", "versions": {"TripoSR": commit or None, "torch": torch.__version__, "python": sys.version.split()[0]},
         "date": provenance.today(), "helpers": ["rembg u2net"], "mc_resolution": int(option("--mc-resolution", 256)),
         "bake_texture": "--bake-texture" in sys.argv, "cudnn": False, "script": "run_triposr.py",
         "picture_sha256": provenance.sha256(picture) if picture and os.path.exists(picture) else None},
        kind="ai_prop", asset=f"assets/props/{name}.glb", batch=os.path.basename(base), name=name,
    )


faulthandler.enable()
torch.backends.cudnn.enabled = False
sys.path.insert(0, ".")
sys.argv = ["run.py"] + sys.argv[1:]
runpy.run_path("run.py", run_name="__main__")
write_provenance()
