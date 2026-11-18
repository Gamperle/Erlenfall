"""blender -b -P render_glb.py -- model.glb out_prefix : renders front (+Z), side and back-ish views with Godot's facing (front = +Z in gltf)."""
import math
import os
import sys

import bpy
from mathutils import Vector

# RENDER_ELEVATION raises the camera (0.25 by default, about 14 degrees; 1.0 looks down at 45 degrees).
ELEVATION = float(os.environ.get("RENDER_ELEVATION", "0.25"))
path, prefix = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
low = Vector(min(p[i] for p in pts) for i in range(3))
high = Vector(max(p[i] for p in pts) for i in range(3))
center = (low + high) / 2
radius = (high - low).length / 2
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.device = "CPU"
scene.render.resolution_x = scene.render.resolution_y = 512
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.85, 0.85, 1)
scene.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
# Blender is Z-up, the importer maps glTF +Z (Godot's front) to Blender -Y.
for name, yaw in (("front", 0), ("side", 90), ("back", 180)):
    a = math.radians(yaw)
    direction = Vector((math.sin(a), -math.cos(a), ELEVATION)).normalized()
    cam.location = center + direction * radius * 2.6
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{prefix}_{name}.png"
    bpy.ops.render.render(write_still=True)
