"""Turns a raw TripoSR model into a game-ready GLB: straighten, reduce faces, re-bake, export.

Usage: blender -b -P cleanup_mesh.py -- mesh.obj texture.png out_prefix max_faces [long|upright]

"long" stands thin objects like swords on end. Writes <out_prefix>.glb and <out_prefix>_front.png and _back.png.
"""
import math
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

TEXTURE_SIZE = 1024
SMALLEST_PIECE = 0.02  # Loose pieces under this share of the faces are noise.


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def remove_loose_pieces(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    # The baked OBJ splits vertices along UV seams, so every island would look like a loose piece.
    bmesh.ops.remove_doubles(mesh, verts=mesh.verts, dist=1e-5)
    remaining = set(mesh.faces)
    total = len(remaining)
    removed = 0
    while remaining:
        seed = remaining.pop()
        piece, stack = [seed], [seed]
        while stack:
            for edge in stack.pop().edges:
                for face in edge.link_faces:
                    if face in remaining:
                        remaining.remove(face)
                        piece.append(face)
                        stack.append(face)
        if len(piece) < total * SMALLEST_PIECE:
            bmesh.ops.delete(mesh, geom=piece, context="FACES")
            removed += len(piece)
    mesh.to_mesh(obj.data)
    mesh.free()
    return removed


def tilt_matrix(rx, ry):
    return Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(ry, 3, "Y")


def upright_rotation(obj):
    """Finds the small tilt that lines the most surface up with vertical and horizontal."""
    count = len(obj.data.polygons)
    normals = np.empty(count * 3)
    areas = np.empty(count)
    obj.data.polygons.foreach_get("normal", normals)
    obj.data.polygons.foreach_get("area", areas)
    normals = normals.reshape(-1, 3)

    def score(rx, ry):
        row = np.array(tilt_matrix(rx, ry)[2])
        z = normals @ row
        return float(np.sum(areas * (z**4 + (1.0 - z**2) ** 4)))

    best = (0.0, 0.0)
    for span, step in ((35.0, 2.5), (3.0, 0.5)):
        cx, cy = best
        candidates = [
            (cx + math.radians(a), cy + math.radians(b))
            for a in np.arange(-span, span + step, step)
            for b in np.arange(-span, span + step, step)
        ]
        best = max(candidates, key=lambda c: score(*c))
    return tilt_matrix(*best).to_4x4()


def long_axis_rotation(obj):
    """Stands a long thin object on end, keeping whichever end is already higher on top."""
    count = len(obj.data.vertices)
    points = np.empty(count * 3)
    obj.data.vertices.foreach_get("co", points)
    points = points.reshape(-1, 3)
    points -= points.mean(axis=0)
    _, vectors = np.linalg.eigh(np.cov(points.T))
    axis = Vector(vectors[:, -1])
    if axis.z < 0:
        axis = -axis
    return axis.rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()


def normalize(obj):
    """Puts the base on the ground at the origin, with the largest size at 1 unit."""
    corners = [Vector(c) for c in obj.bound_box]
    low = Vector((min(c[i] for c in corners) for i in range(3)))
    high = Vector((max(c[i] for c in corners) for i in range(3)))
    scale = 1.0 / max(high - low)
    center = (low + high) / 2.0
    center.z = low.z
    obj.data.transform(Matrix.Scale(scale, 4) @ Matrix.Translation(-center))
    obj.data.update()


def bake_image(name, colorspace):
    image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    image.colorspace_settings.name = colorspace
    return image


def make_low_poly(high, max_faces):
    low = high.copy()
    low.data = high.data.copy()
    low.name = "prop"
    bpy.context.collection.objects.link(low)
    select_only(low)
    if len(low.data.polygons) > max_faces:
        modifier = low.modifiers.new("reduce", "DECIMATE")
        modifier.ratio = max_faces / len(low.data.polygons)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.shade_smooth()
    # Decimating leaves the old UVs stretched, so unwrap again.
    while low.data.uv_layers:
        low.data.uv_layers.remove(low.data.uv_layers[0])
    low.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    return low


def bake(high, low):
    color = bake_image("color", "sRGB")
    normal = bake_image("normal", "Non-Color")

    material = bpy.data.materials.new("prop")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes["Principled BSDF"]
    shader.inputs["Roughness"].default_value = 0.8
    shader.inputs["Metallic"].default_value = 0.0
    color_node = nodes.new("ShaderNodeTexImage")
    color_node.image = color
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    low.data.materials.clear()
    low.data.materials.append(material)

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    bake_settings = scene.render.bake
    bake_settings.use_selected_to_active = True
    bake_settings.cage_extrusion = 0.02
    bake_settings.max_ray_distance = 0.08
    bake_settings.margin = 8

    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low

    nodes.active = color_node
    bake_settings.use_pass_direct = False
    bake_settings.use_pass_indirect = False
    bake_settings.use_pass_color = True
    bpy.ops.object.bake(type="DIFFUSE")
    nodes.active = normal_node
    bpy.ops.object.bake(type="NORMAL")
    color.pack()
    normal.pack()

    links.new(color_node.outputs["Color"], shader.inputs["Base Color"])
    map_node = nodes.new("ShaderNodeNormalMap")
    links.new(normal_node.outputs["Color"], map_node.inputs["Color"])
    links.new(map_node.outputs["Normal"], shader.inputs["Normal"])


def render_previews(low, prefix):
    corners = [low.matrix_world @ Vector(c) for c in low.bound_box]
    center = sum(corners, Vector()) / 8
    radius = max((c - center).length for c in corners)
    scene = bpy.context.scene
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


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    mesh_path, texture_path, prefix, max_faces = args[0], args[1], args[2], int(args[3])
    mode = args[4] if len(args) > 4 else "upright"
    start = time.time()

    bpy.ops.wm.read_factory_settings(use_empty=True)
    # TripoSR meshes are Z-up, unlike the importer's Y-up default.
    bpy.ops.wm.obj_import(filepath=mesh_path, forward_axis="Y", up_axis="Z")
    high = bpy.context.selected_objects[0]
    select_only(high)
    bpy.ops.object.shade_smooth()
    material = bpy.data.materials.new("source")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(texture_path)
    material.node_tree.links.new(texture.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    high.data.materials.clear()
    high.data.materials.append(material)

    raw_faces = len(high.data.polygons)
    removed = remove_loose_pieces(high)
    rotation = long_axis_rotation(high) if mode == "long" else upright_rotation(high)
    tilt = math.degrees(rotation.to_quaternion().angle)
    high.data.transform(rotation)
    high.data.update()
    normalize(high)

    low = make_low_poly(high, max_faces)
    bake(high, low)
    select_only(low)
    bpy.ops.export_scene.gltf(filepath=prefix + ".glb", export_format="GLB", use_selection=True)
    bpy.data.objects.remove(high)
    render_previews(low, prefix)
    print(
        f"RESULT faces {raw_faces} -> {len(low.data.polygons)}, removed {removed}, "
        f"tilt {tilt:.1f} deg, {time.time() - start:.0f}s",
        flush=True,
    )


main()
