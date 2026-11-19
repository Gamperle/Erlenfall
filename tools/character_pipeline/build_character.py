"""Builds one rigged character from a recipe, using MPFB and CC0 MakeHuman assets.

Run with:
blender --background --python build_character.py -- <recipes.json> <id> <asset folders, comma-separated> <output.glb> [full]

With "full", it skips removing hidden parts and all reduction, for telling whether a flaw comes
from those steps or from the assets.
"""
import json
import math
import os
import struct
import sys

import addon_utils
import bmesh
import bpy
import mathutils
import mathutils.bvhtree
import mathutils.kdtree
import numpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "asset_pipeline"))
import provenance

MPFB = "bl_ext.blender_org.mpfb"
TEXTURE_SIZE = 1024
ALPHA_CUTOFF = 0.25
FINE_HAIR_CUTOFF = 0.2
COVERED_DISTANCE = 0.035
EDGE_MARGIN = 0.03
EDGE_SINK = 0.012
# Triangle budgets per kind of part.
PART_BUDGETS = {"clothes": 5000, "hair": 1800, "beard": 800, "brows": 400, "eyes": 180}
BODY_BUDGETS = {"rest": 2000, "hands": 2500, "head": 3500}
HAND_GROUPS = ("hand_", "index_", "middle_", "ring_", "pinky_", "thumb_")
HEAD_GROUPS = ("head", "neck_")
REGION_GROUPS = HAND_GROUPS + HEAD_GROUPS
TUCK_DEPTH = 0.07
LAYER_DISTANCE = 0.04
LAYER_PULL = 0.86
WAIST_BAND = 0.1
WAIST_PULL = 0.7
PULL_MARGIN = 0.03
CHEST_GROUPS = ("spine_03", "spine_02")
CHEST_SMOOTHING = 12
HEM_WIDTH = 0.2
HEM_OVERLAP = 0.1


def find_asset(folders, name):
    for folder in folders:
        for root, _dirs, files in os.walk(folder):
            if name + ".mhclo" in files:
                return os.path.join(root, name + ".mhclo")
    raise FileNotFoundError(name)


def find_skin(folders, name):
    for folder in folders:
        for root, _dirs, files in os.walk(folder):
            if name + ".mhmat" in files:
                return os.path.join(root, name + ".mhmat")
    raise FileNotFoundError(name)


def as_list(names):
    return names if isinstance(names, list) else [names]


def triangles(mesh_object):
    return sum(len(polygon.vertices) - 2 for polygon in mesh_object.data.polygons)


def bake_modifiers(mesh_object):
    bpy.context.view_layer.objects.active = mesh_object
    if mesh_object.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for modifier in list(mesh_object.modifiers):
        if modifier.type in ("MASK", "SUBSURF"):
            bpy.ops.object.modifier_apply(modifier=modifier.name)


def reduce_mesh(mesh_object, budget):
    count = triangles(mesh_object)
    if count <= budget:
        return
    bpy.context.view_layer.objects.active = mesh_object
    modifier = mesh_object.modifiers.new("reduce", "DECIMATE")
    modifier.ratio = budget / count
    bpy.ops.object.modifier_apply(modifier="reduce")


def vertices_in_groups(mesh_object, names):
    indexes = {group.index for group in mesh_object.vertex_groups if any(group.name.startswith(name) for name in names)}
    return {
        vertex.index for vertex in mesh_object.data.vertices
        if any(element.group in indexes and element.weight > 0.3 for element in vertex.groups)
    }


def reduce_region(mesh_object, names, budget):
    """Reduces only the faces of the named bones' vertex groups, or everything else if names is None."""
    region = vertices_in_groups(mesh_object, REGION_GROUPS)
    if names is not None:
        region = vertices_in_groups(mesh_object, names)
    bpy.context.view_layer.objects.active = mesh_object
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    mesh = bmesh.from_edit_mesh(mesh_object.data)
    count = 0
    for face in mesh.faces:
        inside = all(vertex.index in region for vertex in face.verts)
        face.select_set(inside if names is not None else not inside)
        if face.select:
            count += len(face.verts) - 2
    mesh.select_flush_mode()
    bmesh.update_edit_mesh(mesh_object.data)
    if count > budget:
        bpy.ops.mesh.decimate(ratio=budget / count)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("REGION", names, count, "->", triangles(mesh_object))


def reduce_body(body):
    """Keeps more detail in the face and hands, where reduction shows most."""
    reduce_region(body, None, BODY_BUDGETS["rest"])
    reduce_region(body, HAND_GROUPS, BODY_BUDGETS["hands"])
    reduce_region(body, HEAD_GROUPS, BODY_BUDGETS["head"])


def pull_in(mesh, vertices):
    """Pulls vertices toward the body's center, so a lower layer stays hidden under the one over it."""
    if not vertices:
        return
    center_y = sum(vertex.co.y for vertex in vertices) / len(vertices)
    for vertex in vertices:
        vertex.co.x *= LAYER_PULL
        vertex.co.y = center_y + (vertex.co.y - center_y) * LAYER_PULL


def tuck_in(under, over):
    """Cuts a layer off below the top of the one over it, and pulls in what overlaps."""
    top = max(vertex.co.z for vertex in over.data.vertices)
    mesh = bmesh.new()
    mesh.from_mesh(under.data)
    pull_in(mesh, [vertex for vertex in mesh.verts if vertex.co.z < top + PULL_MARGIN and abs(vertex.co.x) < HEM_WIDTH])
    bmesh.ops.delete(mesh, geom=[vertex for vertex in mesh.verts if vertex.co.z < top - TUCK_DEPTH], context="VERTS")
    mesh.to_mesh(under.data)
    mesh.free()


def sink_waist(body, height):
    """Pulls the body in around where two layers of clothes meet, so no skin shows between them."""
    mesh = bmesh.new()
    mesh.from_mesh(body.data)
    band = [vertex for vertex in mesh.verts if abs(vertex.co.z - height) < WAIST_BAND and abs(vertex.co.x) < HEM_WIDTH]
    if band:
        center_y = sum(vertex.co.y for vertex in band) / len(band)
        for vertex in band:
            vertex.co.x *= WAIST_PULL
            vertex.co.y = center_y + (vertex.co.y - center_y) * WAIST_PULL
    mesh.to_mesh(body.data)
    mesh.free()


def trim_above(mesh_object, height):
    """Cuts off everything above a height over the ground, such as a shoe's shaft inside pants."""
    ground = min(vertex.co.z for vertex in mesh_object.data.vertices)
    mesh = bmesh.new()
    mesh.from_mesh(mesh_object.data)
    bmesh.ops.delete(mesh, geom=[vertex for vertex in mesh.verts if vertex.co.z > ground + height], context="VERTS")
    mesh.to_mesh(mesh_object.data)
    mesh.free()


def hide_under_hem(under, over):
    """Cuts a layer off above the lower edge of the top over it, and pulls in what overlaps."""
    hem = min(vertex.co.z for vertex in over.data.vertices if abs(vertex.co.x) < HEM_WIDTH)
    mesh = bmesh.new()
    mesh.from_mesh(under.data)
    pull_in(mesh, [vertex for vertex in mesh.verts if vertex.co.z > hem - PULL_MARGIN])
    bmesh.ops.delete(mesh, geom=[vertex for vertex in mesh.verts if vertex.co.z > hem + HEM_OVERLAP], context="VERTS")
    mesh.to_mesh(under.data)
    mesh.free()


def smooth_chest(mesh_object):
    """Rounds the cloth over the chest, because tight clothes copy the body's shape too closely."""
    region = vertices_in_groups(mesh_object, CHEST_GROUPS)
    mesh = bmesh.new()
    mesh.from_mesh(mesh_object.data)
    mesh.verts.ensure_lookup_table()
    verts = [mesh.verts[index] for index in region]
    for _step in range(CHEST_SMOOTHING):
        bmesh.ops.smooth_vert(mesh, verts=verts, factor=0.5, use_axis_x=False, use_axis_y=True, use_axis_z=True)
    mesh.to_mesh(mesh_object.data)
    mesh.free()


def recolor_image(image, color):
    """Repaints a texture in one color, keeping its light and dark strands and its alpha."""
    pixels = numpy.array(image.pixels[:]).reshape(-1, image.channels)
    brightness = pixels[:, :3].mean(axis=1, keepdims=True)
    strands = brightness / max(brightness.max(), 0.01)
    pixels[:, :3] = numpy.array([channel ** 2.2 for channel in color]) * (0.7 + strands * 0.6)
    image.pixels = pixels.ravel().tolist()


def stand_on_ground(rig, meshes, ground):
    """Puts the feet at 0. The rig is fitted to the body, so its bones move with the mesh, Root included."""
    for mesh_object in meshes:
        for vertex in mesh_object.data.vertices:
            vertex.co.z -= ground
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for edit_bone in rig.data.edit_bones:
        edit_bone.head.z -= ground
        edit_bone.tail.z -= ground
    bpy.ops.object.mode_set(mode="OBJECT")


def remove_covered(hidden, clothes, distance=COVERED_DISTANCE):
    """Deletes vertices well under clothes, so they can't poke through once reduced.

    Keeps those near a garment's open edges, so nothing is missing at cuffs, collars, and hems.
    """
    trees = []
    edge_points = []
    for mesh_object in clothes:
        mesh = bmesh.new()
        mesh.from_mesh(mesh_object.data)
        vertices = [vertex.co.copy() for vertex in mesh.verts]
        polygons = [tuple(vertex.index for vertex in face.verts) for face in mesh.faces]
        trees.append(mathutils.bvhtree.BVHTree.FromPolygons(vertices, polygons))
        edge_points += [vertex.co.copy() for vertex in mesh.verts if vertex.is_boundary]
        mesh.free()
    edges = mathutils.kdtree.KDTree(len(edge_points))
    for index, point in enumerate(edge_points):
        edges.insert(point, index)
    edges.balance()
    # A hole in the head or neck would show the inside of the mouth.
    protected = vertices_in_groups(hidden, HEAD_GROUPS)
    mesh = bmesh.new()
    mesh.from_mesh(hidden.data)
    covered = []
    kept = []
    for vertex in mesh.verts:
        if vertex.index in protected or (edge_points and edges.find(vertex.co)[2] < EDGE_MARGIN):
            kept.append(vertex)
            continue
        if any(tree.find_nearest(vertex.co, distance)[0] is not None for tree in trees):
            covered.append(vertex)
    # What stays near an edge sits a little deeper, so it stays under the cloth.
    for vertex in kept:
        if any(tree.find_nearest(vertex.co, distance)[0] is not None for tree in trees):
            vertex.co -= vertex.normal * EDGE_SINK
    bmesh.ops.delete(mesh, geom=covered, context="VERTS")
    mesh.to_mesh(hidden.data)
    mesh.free()


def finish_materials(path, cutout_names, colors):
    """Makes solid parts opaque and hair cut out, since blended layers sort wrongly in Godot.

    A part listed in colors loses its printed pattern and takes that plain color instead.
    """
    with open(path, "rb") as file:
        data = file.read()
    json_length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + json_length])
    for material in document.get("materials", []):
        material.pop("alphaCutoff", None)
        if any(name in material["name"] for name in cutout_names):
            material["alphaMode"] = "MASK"
            material["alphaCutoff"] = FINE_HAIR_CUTOFF if "eyebrow" in material["name"] or "beard" in material["name"] else ALPHA_CUTOFF
        else:
            material["alphaMode"] = "OPAQUE"
        for name, color in colors.items():
            if name in material["name"]:
                shading = material["pbrMetallicRoughness"]
                shading.pop("baseColorTexture", None)
                # Recipes use the sRGB values a color picker shows, and glTF stores linear ones.
                shading["baseColorFactor"] = [*(channel ** 2.2 for channel in color), 1.0]
    chunk = json.dumps(document, separators=(",", ":")).encode()
    chunk += b" " * (-len(chunk) % 4)
    rest = data[20 + json_length:]
    with open(path, "wb") as file:
        file.write(struct.pack("<III", 0x46546C67, 2, 20 + len(chunk) + len(rest)))
        file.write(struct.pack("<II", len(chunk), 0x4E4F534A))
        file.write(chunk)
        file.write(rest)


ACCESSORY_OFFSET = 0.014


class Solids:
    """The body and its clothes as points and a ray-casting tree, for fitting accessories to them."""

    def __init__(self, objects):
        vertices = []
        polygons = []
        self.body = numpy.array([tuple(vertex.co) for vertex in objects[0].data.vertices])
        for mesh_object in objects:
            start = len(vertices)
            vertices += [vertex.co.copy() for vertex in mesh_object.data.vertices]
            polygons += [tuple(start + index for index in polygon.vertices) for polygon in mesh_object.data.polygons]
        self.points = numpy.array([tuple(vertex) for vertex in vertices])
        self.tree = mathutils.bvhtree.BVHTree.FromPolygons(vertices, polygons)

    def near(self, x, z, reach=0.03):
        """The points around a spot."""
        mask = (abs(self.points[:, 0] - x) < reach) & (abs(self.points[:, 2] - z) < reach)
        return self.points[mask]

    def front(self, x, z, reach=0.03):
        found = self.near(x, z, reach)
        return float(found[:, 1].min()) if len(found) else None

    def back(self, x, z, reach=0.03):
        found = self.near(x, z, reach)
        return float(found[:, 1].max()) if len(found) else None

    def row(self, z, half_width=0.15, thickness=0.02):
        mask = (abs(self.points[:, 0]) < half_width) & (abs(self.points[:, 2] - z) < thickness)
        return self.points[mask]

    def row_front(self, z, half_width=0.15, thickness=0.02):
        return float(self.row(z, half_width, thickness)[:, 1].min())

    def row_back(self, z, half_width=0.15, thickness=0.02):
        return float(self.row(z, half_width, thickness)[:, 1].max())

    def shoulder(self, x, limit):
        """The height of the top of the shoulder at a sideways position, ignoring anything above the limit."""
        found = self.points[(abs(self.points[:, 0] - x) < 0.03) & (abs(self.points[:, 1] + 0.02) < 0.06) & (self.points[:, 2] < limit)]
        return float(found[:, 2].max()) if len(found) else limit

    def drop(self, x, y, top):
        """The height where a ray from above, at a spot, first meets the body or clothes."""
        hit = self.tree.ray_cast(mathutils.Vector((x, y, top)), mathutils.Vector((0, 0, -1)), 2.0)
        return None if hit[0] is None else hit[0].z


def plain_material(name, color, metallic=0.0, roughness=0.9):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.use_backface_culling = False
    shader = material.node_tree.nodes["Principled BSDF"]
    # Recipes use the sRGB values a color picker shows, and Blender's colors are linear.
    shader.inputs["Base Color"].default_value = (*(channel ** 2.2 for channel in color), 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return material


def add_part(name, geometry, color, metallic=0.0, roughness=0.9):
    """Makes an object with a plain colored material from lists of vertices and faces."""
    vertices, faces = geometry
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(vertex) for vertex in vertices], [], faces)
    mesh.update()
    mesh_object = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(mesh_object)
    material = plain_material(name, color, metallic, roughness)
    mesh.materials.append(material)
    return mesh_object


def bmesh_geometry(mesh):
    vertices = [vertex.co.copy() for vertex in mesh.verts]
    faces = [tuple(vertex.index for vertex in face.verts) for face in mesh.faces]
    mesh.free()
    return vertices, faces


def grid_geometry(rows):
    """Joins rows of points (all of one length) into a sheet of quads."""
    width = len(rows[0])
    vertices = [point for row in rows for point in row]
    faces = [(r * width + c, r * width + c + 1, (r + 1) * width + c + 1, (r + 1) * width + c)
             for r in range(len(rows) - 1) for c in range(width - 1)]
    return vertices, faces


def strip_geometry(path, width, up):
    """A flat band along a path of points, as wide as `width` across the path and the up direction."""
    rows = []
    for index, point in enumerate(path):
        before = mathutils.Vector(path[max(index - 1, 0)])
        after = mathutils.Vector(path[min(index + 1, len(path) - 1)])
        side = (after - before).cross(mathutils.Vector(up)).normalized() * (width / 2)
        rows.append([mathutils.Vector(point) - side, mathutils.Vector(point) + side])
    return grid_geometry(rows)


def box_geometry(center, size, tilt=0.0):
    """A box, optionally tilted around the front-to-back axis."""
    mesh = bmesh.new()
    bmesh.ops.create_cube(mesh, size=1.0)
    bmesh.ops.scale(mesh, vec=mathutils.Vector(size), verts=mesh.verts)
    bmesh.ops.rotate(mesh, cent=(0, 0, 0), matrix=mathutils.Matrix.Rotation(tilt, 3, "Y"), verts=mesh.verts)
    bmesh.ops.translate(mesh, vec=mathutils.Vector(center), verts=mesh.verts)
    return bmesh_geometry(mesh)


def tube_geometry(start, end, radius, sides=8, taper=1.0):
    """A closed cylinder between two points, whose far end can be narrower."""
    start = mathutils.Vector(start)
    end = mathutils.Vector(end)
    axis = end - start
    mesh = bmesh.new()
    bmesh.ops.create_cone(mesh, cap_ends=True, cap_tris=False, segments=sides, radius1=radius, radius2=radius * taper, depth=axis.length)
    bmesh.ops.rotate(mesh, cent=(0, 0, 0), matrix=axis.to_track_quat("Z", "Y").to_matrix(), verts=mesh.verts)
    bmesh.ops.translate(mesh, vec=(start + end) / 2, verts=mesh.verts)
    return bmesh_geometry(mesh)


def bead_geometry(center, size, direction):
    """A small stretched blob along a direction, one link of a chain."""
    mesh = bmesh.new()
    bmesh.ops.create_icosphere(mesh, subdivisions=1, radius=1.0)
    for vertex in mesh.verts:
        vertex.co = mathutils.Vector((vertex.co.x * size * 0.8, vertex.co.y * size * 1.6, vertex.co.z * size * 0.8))
    bmesh.ops.rotate(mesh, cent=(0, 0, 0), matrix=mathutils.Vector(direction).to_track_quat("Y", "Z").to_matrix(), verts=mesh.verts)
    bmesh.ops.translate(mesh, vec=mathutils.Vector(center), verts=mesh.verts)
    return bmesh_geometry(mesh)


def merge_geometry(*parts):
    vertices = []
    faces = []
    for part_vertices, part_faces in parts:
        start = len(vertices)
        vertices += part_vertices
        faces += [tuple(start + index for index in face) for face in part_faces]
    return vertices, faces


def bone_height(rig, name):
    return rig.data.bones[name].head_local.z


def torso_ellipse(solids, z, margin):
    """The centre and half sizes of an ellipse around the torso at a height, without the arms."""
    ring = solids.row(z, 0.23)
    front, back = ring[:, 1].min(), ring[:, 1].max()
    return (front + back) / 2, float(ring[:, 0].max()) + margin, (back - front) / 2 + margin


def make_apron(rig, solids, ground, options):
    """A bib apron with a skirt panel fitted to the front, neck straps over the shoulders, and a waist tie."""
    top = bone_height(rig, "clavicle_l") - 0.06
    waist = bone_height(rig, "spine_01") + 0.01
    hem = ground + options.get("hem", 0.5)
    hips = bone_height(rig, "pelvis") - 0.04
    bib_end = waist + 0.04
    levels = [top, top - 0.06, top - 0.12, bib_end, waist - 0.04]
    steps = 6
    levels += [waist - 0.04 - (waist - 0.04 - hem) * (step + 1) / steps for step in range(steps)]
    rows = []
    for z in levels:
        # A narrow bib that widens to the waist, then a skirt that flares a little.
        if z > bib_end:
            half = 0.085 + 0.075 * (top - z) / (top - bib_end)
        else:
            half = 0.16 + 0.04 * (bib_end - z) / max(bib_end - hem, 0.01)
        flat = solids.row_front(z, thickness=0.08)
        row = []
        for column in range(7):
            x = half * (column / 3 - 1)
            y = flat + 0.03 * (x / half) ** 2
            seen = solids.front(x, z)
            if seen is not None and z > hips:
                y = min(y, seen)
            row.append(mathutils.Vector((x, y - ACCESSORY_OFFSET - 0.012, z)))
        rows.append(row)
    parts = [grid_geometry(rows)]
    # The straps run from the bib's top corners over the shoulders and down the back.
    for side in (-1, 1):
        x = 0.075 * side
        shoulder = solids.shoulder(x, bone_height(rig, "clavicle_l") + 0.07)
        front_y = rows[0][3 + side * 2].y
        back_y = solids.back(x, top - 0.02) or solids.row_back(top)
        centre_y = (front_y + back_y) / 2
        path = [(x, front_y, top), (x, front_y + (centre_y - front_y) * 0.5, shoulder + 0.012), (x, centre_y + (back_y - centre_y) * 0.5, shoulder + 0.012),
                (x, back_y + ACCESSORY_OFFSET, shoulder - 0.08), (x, back_y + ACCESSORY_OFFSET, top - 0.06)]
        parts.append(strip_geometry(path, 0.03, (0, 1, 0)))
    # The waist tie runs all the way around.
    centre, reach_x, reach_y = torso_ellipse(solids, waist, ACCESSORY_OFFSET)
    around = [(reach_x * math.sin(step * math.tau / 20), centre - reach_y * math.cos(step * math.tau / 20), waist + 0.01) for step in range(21)]
    parts.append(strip_geometry(around, 0.045, (0, 0, 1)))
    return merge_geometry(*parts)


def make_chain(rig, solids, ground, options):
    """A chain of links resting on the shoulders and hanging in a V on the chest, with a medallion."""
    top = bone_height(rig, "neck_01") - 0.02
    mid_y = (solids.row_front(top - 0.1) + solids.row_back(top - 0.1)) / 2
    beads = []
    for step in range(36):
        angle = step * math.tau / 36
        # Angle 0 is the front. The ring is drawn out at the front, so the chain hangs there in a V.
        sway = math.cos(angle)
        x = (0.115 + 0.012 * max(sway, 0)) * math.sin(angle)
        y = mid_y - (0.1 + 0.05 * max(sway, 0)) * sway
        z = solids.drop(x, y, top)
        if z is not None:
            beads.append(mathutils.Vector((x, y, z + 0.012)))
    parts = [bead_geometry(point, 0.014, beads[(index + 1) % len(beads)] - beads[index - 1]) for index, point in enumerate(beads)]
    lowest = min(beads, key=lambda point: point.z)
    parts.append(box_geometry((lowest.x, lowest.y - 0.012, lowest.z - 0.03), (0.05, 0.012, 0.05), 0.785))
    return merge_geometry(*parts)


def make_quiver(rig, solids, ground, options):
    """A quiver on the back, hung from a strap across the chest, with arrow ends sticking out."""
    top = bone_height(rig, "spine_03") + 0.2
    low = bone_height(rig, "pelvis") + 0.02
    back_y = solids.row_back((top + low) / 2)
    base = (-0.05, back_y + 0.075, low)
    tip = (0.05, back_y + 0.075, top + 0.12)
    parts = [tube_geometry(base, tip, 0.06, 10, 1.1)]
    direction = (mathutils.Vector(tip) - mathutils.Vector(base)).normalized()
    for index, offset in enumerate(((-0.025, 0), (0.0, 0.02), (0.025, -0.005), (0.01, -0.02))):
        start = mathutils.Vector(tip) + mathutils.Vector((offset[0], offset[1], 0)) - direction * 0.05
        parts.append(tube_geometry(start, start + direction * (0.15 + 0.02 * index), 0.007, 5))
    # The strap goes from the right shoulder, across the chest, down to the left hip.
    shoulder_z = bone_height(rig, "clavicle_l") + 0.02
    path = []
    for step in range(11):
        t = step / 10
        z = shoulder_z - t * (shoulder_z - low - 0.06)
        x = 0.1 - 0.2 * t
        path.append((x, (solids.front(x, z) or solids.row_front(z)) - ACCESSORY_OFFSET, z))
    parts.append(strip_geometry(path, 0.04, (0, 1, 0)))
    return merge_geometry(*parts)


def make_pack(rig, solids, ground, options):
    """A pack on the back with a bedroll on top, and two shoulder straps."""
    top = bone_height(rig, "clavicle_l") - 0.04
    low = bone_height(rig, "spine_01") - 0.06
    back_y = solids.row_back((top + low) / 2)
    parts = [box_geometry((0, back_y + 0.1, (top + low) / 2 - 0.02), (0.34, 0.2, top - low - 0.04))]
    parts.append(tube_geometry((-0.2, back_y + 0.12, top + 0.04), (0.2, back_y + 0.12, top + 0.04), 0.075, 10))
    for side in (-1, 1):
        x = 0.1 * side
        front_y = solids.front(x, top - 0.02) or solids.row_front(top)
        shoulder = solids.shoulder(x, bone_height(rig, "clavicle_l") + 0.07)
        centre_y = (front_y + back_y) / 2
        path = [(x, back_y + 0.012, top - 0.03), (x, back_y + 0.012, top + 0.01),
                (x, centre_y + (back_y - centre_y) * 0.5, shoulder + 0.012), (x, centre_y - (centre_y - front_y) * 0.5, shoulder + 0.012),
                (x, front_y - ACCESSORY_OFFSET, top - 0.02), (x, front_y - ACCESSORY_OFFSET, top - 0.12)]
        parts.append(strip_geometry(path, 0.04, (0, 1, 0)))
    return merge_geometry(*parts)


def make_hat(rig, solids, ground, options):
    """A hat on the head: a crown that covers the hair and a brim around it, as wide and tall as the options say."""
    top = float(solids.body[:, 2].max())
    brow = top - options.get("sink", 0.075)
    height = options.get("crown", 0.1)
    brim = options.get("brim", 0.1)
    droop = options.get("droop", 0.02)
    margin = options.get("margin", 0.035)
    head = solids.body[(solids.body[:, 2] > top - 0.06) & (solids.body[:, 2] < top - 0.03)]
    centre = float((head[:, 1].min() + head[:, 1].max()) / 2)
    reach_x = float(head[:, 0].max()) + margin
    reach_y = float((head[:, 1].max() - head[:, 1].min()) / 2) + margin
    # Rings from the brim's edge in to the crown, up its side, and over the top: how far out, and how high.
    profile = [(brim, -droop), (brim * 0.5, -droop * 0.3), (0.0, 0.0), (0.0, height * 0.5), (-0.005, height * 0.85), (-0.03, height), (-0.06, height * 1.02), (-reach_x * 0.5, height * 1.03), (-reach_x + 0.001, height * 1.03)]
    rows = []
    for out, rise in profile:
        scale_x = max(reach_x + out, 0.001)
        scale_y = max(reach_y + out, 0.001)
        rows.append([mathutils.Vector((scale_x * math.sin(step * math.tau / 24), centre - scale_y * math.cos(step * math.tau / 24), brow + rise)) for step in range(24)] + [mathutils.Vector((0, centre - scale_y, brow + rise))])
    return grid_geometry(rows)


ACCESSORIES = {"apron": make_apron, "chain": make_chain, "quiver": make_quiver, "pack": make_pack, "hat": make_hat}
ACCESSORY_LOOKS = {"chain": {"metallic": 0.8, "roughness": 0.35}, "hat": {"roughness": 1.0}}


def copy_weights(accessory, body, rig):
    """Skins an accessory to the same bones as the body around it, vertex by vertex."""
    tree = mathutils.kdtree.KDTree(len(body.data.vertices))
    for vertex in body.data.vertices:
        tree.insert(vertex.co, vertex.index)
    tree.balance()
    bones = {bone.name for bone in rig.data.bones}
    groups = {}
    for vertex in accessory.data.vertices:
        nearest = body.data.vertices[tree.find(vertex.co)[1]]
        for element in nearest.groups:
            name = body.vertex_groups[element.group].name
            if name in bones and element.weight > 0:
                groups.setdefault(name, []).append((vertex.index, element.weight))
    for name, weights in groups.items():
        group = accessory.vertex_groups.new(name=name)
        for index, weight in weights:
            group.add([index], weight, "REPLACE")
    accessory.parent = rig
    modifier = accessory.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig


def add_accessories(recipe, body, rig, clothes):
    """Makes the recipe's accessories, fitted to the body and the clothes over it."""
    solids = Solids([body] + clothes)
    ground = min(vertex.co.z for vertex in body.data.vertices)
    made = []
    for options in recipe.get("accessories", []):
        kind = options["type"]
        accessory = add_part("accessory_" + kind, ACCESSORIES[kind](rig, solids, ground, options), options["color"], **ACCESSORY_LOOKS.get(kind, {}))
        copy_weights(accessory, body, rig)
        made.append(accessory)
    return made


VEST_GROUPS = ("upperarm", "lowerarm", "hand", "clavicle", "neck", "head")
VEST_LIFT = 0.012


def make_vest(source, color):
    """A sleeveless vest made from a copy of a top: no sleeves or collar, a little larger, in a plain color."""
    vest = source.copy()
    vest.data = source.data.copy()
    vest.name = "vest"
    bpy.context.scene.collection.objects.link(vest)
    mesh = bmesh.new()
    mesh.from_mesh(vest.data)
    mesh.verts.ensure_lookup_table()
    sleeves = vertices_in_groups(vest, VEST_GROUPS)
    bmesh.ops.delete(mesh, geom=[mesh.verts[index] for index in sleeves], context="VERTS")
    mesh.normal_update()
    for vertex in mesh.verts:
        vertex.co += vertex.normal * VEST_LIFT
    mesh.to_mesh(vest.data)
    mesh.free()
    vest.data.materials.clear()
    vest.data.materials.append(plain_material("vest", color))
    return vest


def build(recipe, folders, output, full_detail=False):
    from bl_ext.blender_org.mpfb.entities.objectproperties import HumanObjectProperties
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService
    from bl_ext.blender_org.mpfb.services.targetservice import TargetService

    # The joint helpers place the rig's bones on this body. Without them, every body gets the default skeleton.
    body = HumanService.create_human(mask_helpers=True, detailed_helpers=True, extra_vertex_groups=True, feet_on_ground=False, scale=0.1)
    for key, value in recipe["shape"].items():
        HumanObjectProperties.set_value(key, value, entity_reference=body)
    TargetService.reapply_macro_details(body)
    bpy.context.view_layer.update()
    rig = HumanService.add_builtin_rig(body, "game_engine", import_weights=True)

    meshes = {}
    for kind, asset_type in (("clothes", "Clothes"), ("hair", "Hair"), ("beard", "Clothes"), ("brows", "Eyebrows"), ("eyes", "Eyes")):
        for name in as_list(recipe.get(kind, [])):
            asset = HumanService.add_mhclo_asset(find_asset(folders, name), body, asset_type=asset_type, subdiv_levels=0, material_type="MAKESKIN")
            if not asset.data.materials:
                # Some assets, such as the newsboy cap, come without a material. The recipe's colors paint it.
                asset.data.materials.append(plain_material(asset.name, (0.5, 0.5, 0.5)))
            meshes[asset.name] = (asset, kind, name)
    HumanService.set_character_skin(find_skin(folders, recipe["skin"]), body, skin_type="MAKESKIN")
    bpy.context.view_layer.update()

    bake_modifiers(body)
    for asset, _kind, _name in meshes.values():
        bake_modifiers(asset)
    extras = add_accessories(recipe, body, rig, [item[0] for item in meshes.values() if item[1] == "clothes"])
    if not full_detail:
        remove_covered(body, [item[0] for item in meshes.values() if item[1] == "clothes"])
        reduce_body(body)
    named_parts = {item[2]: item[0] for item in meshes.values()}
    if not full_detail:
        for under, over in recipe.get("tucked", {}).items():
            sink_waist(body, max(vertex.co.z for vertex in named_parts[over].data.vertices))
            tuck_in(named_parts[under], named_parts[over])
        for under, over in recipe.get("under_hem", {}).items():
            sink_waist(body, min(vertex.co.z for vertex in named_parts[over].data.vertices if abs(vertex.co.x) < HEM_WIDTH))
            hide_under_hem(named_parts[under], named_parts[over])
        for name, height in recipe.get("trim_above", {}).items():
            trim_above(named_parts[name], height)
        for hidden, over in recipe.get("covered_by", {}).items():
            remove_covered(named_parts[hidden], [named_parts[over]], LAYER_DISTANCE)
    for name in recipe.get("smooth_chest", []):
        smooth_chest(named_parts[name])
    for options in recipe.get("vests", []):
        vest = make_vest(named_parts[options["from"]], options["color"])
        meshes[vest.name] = (vest, "clothes", "vest")
        named_parts["vest"] = vest
    if "hair_color" in recipe:
        hair = named_parts[as_list(recipe["hair"])[0]]
        for slot in hair.material_slots:
            for node in slot.material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and "normal" not in node.image.name:
                    recolor_image(node.image, recipe["hair_color"])
    # Parts of one kind share their budget in proportion to their detail.
    kind_totals = {}
    for asset, kind, _name in meshes.values():
        kind_totals[kind] = kind_totals.get(kind, 0) + triangles(asset)
    for asset, kind, _name in meshes.values():
        if not full_detail:
            reduce_mesh(asset, PART_BUDGETS[kind] * triangles(asset) // kind_totals[kind])

    all_meshes = [body] + [item[0] for item in meshes.values()] + extras
    feet = [item[0] for item in meshes.values() if item[2] in recipe.get("footwear", [])]
    ground = min(vertex.co.z for mesh_object in (feet or all_meshes) for vertex in mesh_object.data.vertices)
    stand_on_ground(rig, all_meshes, ground)

    for image in bpy.data.images:
        if image.size[0] > TEXTURE_SIZE:
            image.scale(TEXTURE_SIZE, TEXTURE_SIZE)

    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for mesh_object in all_meshes:
        mesh_object.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=output, use_selection=True, export_animations=False, export_morph=False, export_image_format="JPEG", export_jpeg_quality=85)
    cutouts = [name for kind in ("hair", "beard", "brows") for name in as_list(recipe.get(kind, []))]
    finish_materials(output, cutouts, recipe.get("colors", {}))
    print("PARTS", {mesh_object.name: triangles(mesh_object) for mesh_object in all_meshes})
    print("BUILT", recipe["id"], sum(triangles(mesh_object) for mesh_object in all_meshes), "triangles", os.path.getsize(output) // 1024, "KB")


def main():
    arguments = sys.argv[sys.argv.index("--") + 1:]
    recipes_path, character_id, folders, output = arguments[:4]
    with open(recipes_path, encoding="utf-8") as file:
        recipes = json.load(file)
    recipe = next(item for item in recipes if item["id"] == character_id)
    addon_utils.enable(MPFB, default_set=False)
    full = arguments[4:] == ["full"]
    build(recipe, folders.split(","), output, full)
    mpfb = getattr(sys.modules.get(MPFB), "bl_info", {}).get("version")
    stage = {
        "step": "build", "tool": "build_character.py with MPFB", "date": provenance.today(),
        "versions": {"Blender": bpy.app.version_string, "MPFB": ".".join(map(str, mpfb)) if mpfb else None},
        "recipe": recipe, "recipes_file_sha256": provenance.sha256(recipes_path), "asset_folders": [os.path.basename(f.rstrip("/\\")) for f in folders.split(",")],
        "full_detail": full, "output_sha256": provenance.sha256(output),
    }
    asset = "assets/characters/" + os.path.basename(output)
    provenance.save(provenance.record_path("character", asset), provenance.new_record(
        "character", asset, name=recipe["id"], stages=[stage]))


main()
