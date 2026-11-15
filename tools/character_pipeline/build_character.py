"""Builds one rigged character from a recipe, using MPFB and CC0 MakeHuman assets.

Run with:
blender --background --python build_character.py -- <recipes.json> <id> <asset folders, comma-separated> <output.glb> [full]

With "full", it skips removing hidden parts and all reduction, for telling whether a flaw comes
from those steps or from the assets.
"""
import json
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
            meshes[asset.name] = (asset, kind, name)
    HumanService.set_character_skin(find_skin(folders, recipe["skin"]), body, skin_type="MAKESKIN")
    bpy.context.view_layer.update()

    bake_modifiers(body)
    for asset, _kind, _name in meshes.values():
        bake_modifiers(asset)
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

    all_meshes = [body] + [item[0] for item in meshes.values()]
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
