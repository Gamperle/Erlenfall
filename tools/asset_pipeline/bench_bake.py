"""Times the parts of TripoSR's texture baking and writes the variants' models for comparison (#62).

Usage, from the TripoSR folder on the asset PC, with the venv's Python:
    python bench_bake.py out_dir picture.png [picture.png ...]   (environment variables below)
For each picture it runs the model once, then extracts the mesh and bakes it in several ways, timing every part
of bake_texture (xatlas unwrap, OpenGL rasterize, triplane color query) with the GPU synchronized. Each variant is
written to out_dir/<picture>/<variant>/mesh.obj and texture.png, the layout run.py writes, so that
cleanup_mesh.py can turn it into a model whose renders can be compared (#62).

A variant is mc resolution, texture resolution, and a face budget for reducing the mesh before unwrapping
(0 = none). VARIANTS="256:2048:0,256:1024:0" overrides the list. The first one is the baseline.
"""
import json
import os
import sys
import time

import numpy as np
import rembg
import torch
import xatlas
from PIL import Image

sys.path.insert(0, ".")
torch.backends.cudnn.enabled = False
from tsr.bake_texture import make_atlas, positions_to_colors, rasterize_position_atlas  # noqa: E402
from tsr.system import TSR  # noqa: E402
from tsr.utils import remove_background, resize_foreground  # noqa: E402

DEFAULT_VARIANTS = "256:2048:0,256:1024:0,256:1024:30000,256:1024:15000,256:1024:8000,192:1024:0,128:1024:0"
variants = [tuple(int(x) for x in v.split(":")) for v in os.environ.get("VARIANTS", DEFAULT_VARIANTS).split(",")]
out_dir = sys.argv[1]
pictures = sys.argv[2:]
device = "cuda:0"


def sync():
    torch.cuda.synchronize()


def timed(fn, *args):
    sync()
    start = time.time()
    result = fn(*args)
    sync()
    return result, time.time() - start


def reduce_faces(mesh, faces):
    """Quadric decimation to about `faces` triangles, as the cleanup's decimate does later."""
    # fast_simplification is not in the TripoSR venv: pip install --target <dir> fast_simplification, and set EXTRA_LIBS to <dir>.
    if os.environ.get("EXTRA_LIBS"):
        sys.path.insert(0, os.environ["EXTRA_LIBS"])
    import fast_simplification

    vertices, triangles = fast_simplification.simplify(
        np.asarray(mesh.vertices, dtype=np.float32), np.asarray(mesh.faces, dtype=np.int32), target_count=faces
    )
    import trimesh

    return trimesh.Trimesh(vertices, triangles, process=False)


model = TSR.from_pretrained("stabilityai/TripoSR", config_name="config.yaml", weight_name="model.ckpt")
model.renderer.set_chunk_size(8192)
model.to(device)
session = rembg.new_session()
results = []
for picture in pictures:
    name = os.path.splitext(os.path.basename(picture))[0]
    image = remove_background(Image.open(picture), session)
    image = resize_foreground(image, 0.85)
    image = np.array(image).astype(np.float32) / 255.0
    image = Image.fromarray(((image[:, :, :3] * image[:, :, 3:4] + (1 - image[:, :, 3:4]) * 0.5) * 255.0).astype(np.uint8))
    with torch.no_grad():
        codes, t_model = timed(lambda: model([image], device=device))
    meshes = {}
    for mc, resolution, faces in variants:
        if mc not in meshes:
            meshes[mc] = timed(lambda: model.extract_mesh(codes, False, resolution=mc))
        mesh, t_extract = meshes[mc]
        mesh = mesh[0]
        full_faces = len(mesh.faces)
        t_reduce = 0.0
        if faces and faces < len(mesh.faces):
            mesh, t_reduce = timed(reduce_faces, mesh, faces)
        padding = round(max(2, resolution / 256))
        atlas, t_atlas = timed(make_atlas, mesh, resolution, padding)
        positions, t_raster = timed(
            rasterize_position_atlas, mesh, atlas["vmapping"], atlas["indices"], atlas["uvs"], resolution, padding
        )
        colors, t_query = timed(lambda: positions_to_colors(model, codes[0], positions, resolution))
        tag = f"mc{mc}_tex{resolution}_f{faces}"
        target = os.path.join(out_dir, name, tag)
        os.makedirs(target, exist_ok=True)
        xatlas.export(
            os.path.join(target, "mesh.obj"), mesh.vertices[atlas["vmapping"]], atlas["indices"], atlas["uvs"],
            mesh.vertex_normals[atlas["vmapping"]],
        )
        Image.fromarray((colors * 255.0).astype(np.uint8)).transpose(Image.FLIP_TOP_BOTTOM).save(os.path.join(target, "texture.png"))
        row = {"picture": name, "variant": tag, "mc": mc, "texture": resolution, "face_budget": faces, "faces_extracted": full_faces,
               "faces_baked": len(mesh.faces), "model_s": round(t_model, 2), "extract_s": round(t_extract, 2), "reduce_s": round(t_reduce, 2),
               "unwrap_s": round(t_atlas, 2), "rasterize_s": round(t_raster, 2), "query_s": round(t_query, 2)}
        row["bake_s"] = round(t_atlas + t_raster + t_query, 2)
        print(json.dumps(row), flush=True)
        results.append(row)
with open(os.path.join(out_dir, "timings.json"), "w", encoding="utf-8") as file:
    json.dump(results, file, indent=1)
