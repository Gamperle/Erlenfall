"""Scales a GLB so its largest size matches the real object in meters, and turns it to face Godot's front.

Usage: blender -b -P size_glb.py -- in.glb out.glb meters [turn_degrees [provenance_folder]]

With a provenance folder it adds a "size" stage to <folder>/<name>.json (see provenance.py).

The turn is around the vertical axis and defaults to -90, for TripoSR models, which face +X. TRELLIS.2
models usually already face +Z, as Godot expects, so they use 0.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
source, target, meters = args[:3]
turn = float(args[3]) if len(args) > 3 else -90.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
corners = [Vector(c) for c in obj.bound_box]
size = Vector(max(c[i] for c in corners) - min(c[i] for c in corners) for i in range(3))
obj.data.transform(Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Scale(float(meters) / max(size), 4))
# Stand it on the origin, centered, because the game places props by their base. TRELLIS.2 centers models on
# their middle instead. The vertices are read directly, because obj.bound_box isn't updated by the transform.
points = [v.co for v in obj.data.vertices]
low = Vector(min(p[i] for p in points) for i in range(3))
high = Vector(max(p[i] for p in points) for i in range(3))
obj.data.transform(Matrix.Translation(Vector(((low.x + high.x) / -2, (low.y + high.y) / -2, -low.z))))
obj.data.update()
bpy.ops.export_scene.gltf(filepath=target, export_format="GLB", use_selection=True)
if len(args) > 4:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import provenance

    name = os.path.splitext(os.path.basename(target))[0]
    provenance.add_stage(
        os.path.join(args[4], name + ".json"),
        {"step": "size", "tool": "Blender", "versions": {"Blender": bpy.app.version_string}, "date": provenance.today(),
         "meters": float(meters), "turn_degrees": turn, "script": "size_glb.py"},
        kind="ai_prop", asset=f"assets/props/{name}.glb", name=name,
    )
print(f"SIZED {len(obj.data.polygons)} faces, {meters} m, turned {turn:g} degrees", flush=True)
