"""Runs TripoSR's run.py with cuDNN off and a smaller mesh for the texture bake. Run it from the TripoSR folder, with run.py's arguments.

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
import os
import runpy
import sys

import torch

faulthandler.enable()
torch.backends.cudnn.enabled = False
sys.path.insert(0, ".")

BAKE_FACES = int(os.environ.get("BAKE_FACES", "30000"))


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
runpy.run_path("run.py", run_name="__main__")
