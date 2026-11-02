"""Reshapes a cleaned GLB. Usage: blender -b -P adjust_glb.py -- in.glb out_prefix depth|blade factor

"depth" squashes the front-to-back axis, for walls. "blade" stretches everything below a sword's crossguard.
Writes <out_prefix>.glb and <out_prefix>_front.png and _back.png.
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Vector

source, prefix, mode, factor = sys.argv[sys.argv.index("--") + 1:]
factor = float(factor)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

count = len(obj.data.vertices)
points = np.empty(count * 3)
obj.data.vertices.foreach_get("co", points)
points = points.reshape(-1, 3)
if mode == "depth":
    points[:, 0] = (points[:, 0] - points[:, 0].mean()) * factor
else:
    # The crossguard is the height where the sword is widest. The blade is everything below it.
    bins = np.linspace(points[:, 2].min(), points[:, 2].max(), 41)
    widths = [
        np.ptp(np.hypot(points[mask, 0], points[mask, 1])) + np.hypot(points[mask, 0], points[mask, 1]).max() if mask.any() else 0
        for mask in ((points[:, 2] >= a) & (points[:, 2] < b) for a, b in zip(bins, bins[1:]))
    ]
    guard = bins[int(np.argmax(widths))]
    below = points[:, 2] < guard
    points[below, 2] = guard + (points[below, 2] - guard) * factor
    points[:, 2] -= points[:, 2].min()
    print(f"RESULT guard at {guard:.3f}", flush=True)
obj.data.vertices.foreach_set("co", points.ravel())
obj.data.update()

bpy.ops.export_scene.gltf(filepath=prefix + ".glb", export_format="GLB", use_selection=True)

corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
center = sum(corners, Vector()) / 8
radius = max((c - center).length for c in corners)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.render.resolution_x = scene.render.resolution_y = 1024
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.8, 0.8, 1)
scene.world = world
camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
scene.collection.objects.link(camera)
scene.camera = camera
for name, angle in (("front", 35), ("back", 215)):
    a = math.radians(angle)
    camera.location = center + Vector((math.cos(a), math.sin(a), 0.5)).normalized() * radius * 3.2
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{prefix}_{name}.png"
    bpy.ops.render.render(write_still=True)
