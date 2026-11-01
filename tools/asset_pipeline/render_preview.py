"""Renders a textured OBJ from two angles. Usage: blender -b -P render_preview.py -- mesh.obj texture.png out_prefix"""
import math
import sys

import bpy
from mathutils import Vector

mesh_path, texture_path, prefix = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
# TripoSR meshes are Z-up, unlike the importer's Y-up default.
bpy.ops.wm.obj_import(filepath=mesh_path, forward_axis="Y", up_axis="Z")
obj = bpy.context.selected_objects[0]
bpy.ops.object.shade_smooth()

mat = bpy.data.materials.new("baked")
mat.use_nodes = True
nodes = mat.node_tree.nodes
tex = nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(texture_path)
mat.node_tree.links.new(tex.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
obj.data.materials.clear()
obj.data.materials.append(mat)

corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
center = sum(corners, Vector()) / 8
radius = max((c - center).length for c in corners)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.device = "CPU"
scene.render.resolution_x = scene.render.resolution_y = 640
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.8, 0.8, 1)
scene.world = world

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
for name, angle in (("front", 35), ("back", 215)):
    a = math.radians(angle)
    cam.location = center + Vector((math.cos(a), math.sin(a), 0.5)).normalized() * radius * 3.2
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{prefix}_{name}.png"
    bpy.ops.render.render(write_still=True)
