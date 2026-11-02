"""Scales a cleaned GLB so its largest size matches the real object in meters.

Usage: blender -b -P size_glb.py -- in.glb out.glb meters
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

source, target, meters = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
corners = [Vector(c) for c in obj.bound_box]
size = Vector(max(c[i] for c in corners) - min(c[i] for c in corners) for i in range(3))
# TripoSR faces +X. This turns the front toward +Z once exported to glTF, as Godot expects.
obj.data.transform(Matrix.Rotation(math.radians(-90), 4, "Z") @ Matrix.Scale(float(meters) / max(size), 4))
obj.data.update()
bpy.ops.export_scene.gltf(filepath=target, export_format="GLB", use_selection=True)
print(f"RESULT {len(obj.data.polygons)} faces, {meters} m", flush=True)
