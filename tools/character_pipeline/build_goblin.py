"""Exports the OpenGameArt goblin as glTF, with its helper bones and scale cleaned up.

Run with:
blender --background --python build_goblin.py -- <Goblin.blend> <palette.png> <output.glb>
"""
import sys

import bpy

HELPER_BONES = ("IKLegPole", "IKTarget")


def main():
    source, palette, output = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=source)
    # The file looks for its palette in a folder that isn't in the download.
    bpy.data.images["ImphenziaPalette01.png"].filepath = palette
    bpy.data.images["ImphenziaPalette01.png"].reload()
    rig = next(item for item in bpy.data.objects if item.type == "ARMATURE")
    mesh = next(item for item in bpy.data.objects if item.type == "MESH")
    for pose_bone in rig.pose.bones:
        for constraint in list(pose_bone.constraints):
            pose_bone.constraints.remove(constraint)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in list(rig.data.edit_bones):
        if bone.name.startswith(HELPER_BONES):
            rig.data.edit_bones.remove(bone)
    bpy.ops.object.mode_set(mode="OBJECT")
    # The model's origin is at its hips, and the game expects it at its feet.
    lowest = min(vertex.co.z for vertex in mesh.data.vertices)
    for vertex in mesh.data.vertices:
        vertex.co.z -= lowest
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in rig.data.edit_bones:
        bone.head.z -= lowest
        bone.tail.z -= lowest
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=output, use_selection=True, export_animations=False, export_image_format="JPEG", export_jpeg_quality=90)
    print("BUILT goblin", sum(len(polygon.vertices) - 2 for polygon in mesh.data.polygons), "triangles", tuple(round(size, 2) for size in mesh.dimensions))


main()
