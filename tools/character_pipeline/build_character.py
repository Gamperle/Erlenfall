"""Builds one rigged character from a recipe, using MPFB and CC0 MakeHuman assets.

Run with:
blender --background --python build_character.py -- <recipes.json> <id> <asset folders, comma-separated> <output.glb>
"""
import json
import os
import struct
import sys

import addon_utils
import bpy

MPFB = "bl_ext.blender_org.mpfb"
TEXTURE_SIZE = 512
ALPHA_CUTOFF = 0.25
# Triangle budgets per kind of part.
PART_BUDGETS = {"clothes": 2200, "hair": 700, "beard": 300, "brows": 400, "eyes": 180}
BODY_BUDGET = 2800


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


def calf_height(body):
    group = body.vertex_groups["calf_l"].index
    heights = [
        vertex.co.z for vertex in body.data.vertices
        if any(element.group == group and element.weight > 0.5 for element in vertex.groups)
    ]
    return sum(heights) / len(heights)


def stand_on_ground(rig, meshes, body_calf, ground):
    """Puts the feet at 0 and lines the bones up with the mesh. Root stays at the origin."""
    bone = rig.data.bones["calf_l"]
    bone_lift = body_calf - (bone.head_local.z + bone.tail_local.z) / 2.0 - ground
    for mesh_object in meshes:
        for vertex in mesh_object.data.vertices:
            vertex.co.z -= ground
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for edit_bone in rig.data.edit_bones:
        if edit_bone.name != "Root":
            edit_bone.use_connect = False
    for edit_bone in rig.data.edit_bones:
        if edit_bone.name != "Root":
            edit_bone.head.z += bone_lift
            edit_bone.tail.z += bone_lift
    bpy.ops.object.mode_set(mode="OBJECT")


def tint_material(mesh_object, color):
    """Tints a part's base color, for telling villagers apart with the same clothes."""
    for slot in mesh_object.material_slots:
        if slot.material is None or not slot.material.use_nodes:
            continue
        nodes = slot.material.node_tree
        shader = next((node for node in nodes.nodes if node.type == "BSDF_PRINCIPLED"), None)
        base = shader.inputs["Base Color"] if shader else None
        if base is None or not base.is_linked:
            continue
        source = base.links[0].from_socket
        mix = nodes.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        nodes.links.new(source, mix.inputs["A"])
        mix.inputs["B"].default_value = (*color, 1.0)
        nodes.links.new(mix.outputs["Result"], base)


def fix_transparency(path, cutout_names):
    """Makes solid parts opaque and hair cut out, since blended layers sort wrongly in Godot."""
    with open(path, "rb") as file:
        data = file.read()
    json_length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + json_length])
    for material in document.get("materials", []):
        material.pop("alphaCutoff", None)
        if any(name in material["name"] for name in cutout_names):
            material["alphaMode"] = "MASK"
            material["alphaCutoff"] = ALPHA_CUTOFF
        else:
            material["alphaMode"] = "OPAQUE"
    chunk = json.dumps(document, separators=(",", ":")).encode()
    chunk += b" " * (-len(chunk) % 4)
    rest = data[20 + json_length:]
    with open(path, "wb") as file:
        file.write(struct.pack("<III", 0x46546C67, 2, 20 + len(chunk) + len(rest)))
        file.write(struct.pack("<II", len(chunk), 0x4E4F534A))
        file.write(chunk)
        file.write(rest)


def build(recipe, folders, output):
    from bl_ext.blender_org.mpfb.entities.objectproperties import HumanObjectProperties
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService
    from bl_ext.blender_org.mpfb.services.targetservice import TargetService

    body = HumanService.create_human(mask_helpers=True, detailed_helpers=False, extra_vertex_groups=True, feet_on_ground=False, scale=0.1)
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
    body_calf = calf_height(body)
    reduce_mesh(body, BODY_BUDGET)
    tints = recipe.get("tints", {})
    for asset, _kind, _name in meshes.values():
        bake_modifiers(asset)
    # Parts of one kind share their budget in proportion to their detail.
    kind_totals = {}
    for asset, kind, _name in meshes.values():
        kind_totals[kind] = kind_totals.get(kind, 0) + triangles(asset)
    for asset, kind, name in meshes.values():
        reduce_mesh(asset, PART_BUDGETS[kind] * triangles(asset) // kind_totals[kind])
        if name in tints:
            tint_material(asset, tints[name])

    all_meshes = [body] + [item[0] for item in meshes.values()]
    feet = [item[0] for item in meshes.values() if item[2] in recipe.get("footwear", [])]
    ground = min(vertex.co.z for mesh_object in (feet or all_meshes) for vertex in mesh_object.data.vertices)
    stand_on_ground(rig, all_meshes, body_calf, ground)

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
    fix_transparency(output, cutouts)
    print("PARTS", {mesh_object.name: triangles(mesh_object) for mesh_object in all_meshes})
    print("BUILT", recipe["id"], sum(triangles(mesh_object) for mesh_object in all_meshes), "triangles", os.path.getsize(output) // 1024, "KB")


def main():
    arguments = sys.argv[sys.argv.index("--") + 1:]
    recipes_path, character_id, folders, output = arguments
    with open(recipes_path, encoding="utf-8") as file:
        recipes = json.load(file)
    recipe = next(item for item in recipes if item["id"] == character_id)
    addon_utils.enable(MPFB, default_set=False)
    build(recipe, folders.split(","), output)


main()
