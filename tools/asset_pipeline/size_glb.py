"""Scales a GLB so its largest size matches the real object in meters, and turns it to face Godot's front.

Usage: blender -b -P size_glb.py -- in.glb out.glb meters [turn_degrees]

The turn is around the vertical axis and defaults to -90, for TripoSR models, which face +X. TRELLIS.2
models usually already face +Z, as Godot expects, so they use 0.
"""
import math
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
# their middle instead.
corners = [Vector(c) for c in obj.bound_box]
low = Vector(min(c[i] for c in corners) for i in range(3))
high = Vector(max(c[i] for c in corners) for i in range(3))
obj.data.transform(Matrix.Translation(Vector(((low.x + high.x) / -2, (low.y + high.y) / -2, -low.z))))
obj.data.update()
bpy.ops.export_scene.gltf(filepath=target, export_format="GLB", use_selection=True)
print(f"SIZED {len(obj.data.polygons)} faces, {meters} m, turned {turn:g} degrees", flush=True)
