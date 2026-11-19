"""Checks polyhaven_prop.py on a small made-up glTF (no download). Run: python3 tools/asset_pipeline/test_polyhaven_prop.py

The model is a sphere of 1,440 triangles with a textured material and a mirrored box with a flat-colored one, in
two nodes, so the run has to bake node transforms, pack two materials into an atlas, reduce the faces and write one
mesh with one material. Needs numpy and Pillow; the tests are skipped without them.
"""
import argparse
import io
import json
import math
import os
import struct
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance
import shrink_textures

try:
    import numpy as np
    from PIL import Image
    import polyhaven_prop
except ImportError:
    np = None


def sphere(rings=25, segments=30, radius=1.0):
    """Positions, normals, uvs and triangle indices of a UV sphere."""
    positions, uvs, triangles = [], [], []
    for r in range(rings + 1):
        theta = math.pi * r / rings
        for s in range(segments + 1):
            phi = 2 * math.pi * s / segments
            positions.append((radius * math.sin(theta) * math.cos(phi), radius * math.cos(theta), radius * math.sin(theta) * math.sin(phi)))
            uvs.append((s / segments, r / rings))
    for r in range(rings):
        for s in range(segments):
            a = r * (segments + 1) + s
            b = a + segments + 1
            if r > 0:
                triangles.append((a, a + 1, b))
            if r < rings - 1:
                triangles.append((a + 1, b + 1, b))
    return np.array(positions, np.float32), np.array(uvs, np.float32), np.array(triangles, np.uint16)


def box():
    corners = np.array([(x, y, z) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)], np.float32)
    faces = [(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)]
    return corners, np.zeros((8, 2), np.float32), np.array(faces, np.uint16)


def png(size, color):
    out = io.BytesIO()
    image = Image.new("RGB", size, color)
    for x in range(0, size[0], 8):
        for y in range(0, size[1], 8):
            image.putpixel((x, y), (255, 255, 255))
    image.save(out, "PNG")
    return out.getvalue()


def write_gltf(folder):
    """Writes model.gltf, model.bin and texture.png under folder. Returns the .gltf path."""
    blob = b""
    views, accessors = [], []

    def add(array, target, component, kind, minmax=False):
        nonlocal blob
        data = array.tobytes()
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob += data + b"\0" * (-len(data) % 4)
        accessor = {"bufferView": len(views) - 1, "componentType": component, "count": len(array), "type": kind}
        if minmax:
            accessor["min"], accessor["max"] = array.min(axis=0).tolist(), array.max(axis=0).tolist()
        accessors.append(accessor)
        return len(accessors) - 1

    primitives = []
    for (positions, uvs, triangles), material in ((sphere(), 0), (box(), 1)):
        normals = positions / np.maximum(np.linalg.norm(positions, axis=1, keepdims=True), 1e-9)
        primitives.append({"attributes": {"POSITION": add(positions, 34962, 5126, "VEC3", True), "NORMAL": add(normals.astype(np.float32), 34962, 5126, "VEC3"),
                                          "TEXCOORD_0": add(uvs, 34962, 5126, "VEC2")},
                           "indices": add(triangles.reshape(-1), 34963, 5123, "SCALAR"), "material": material})
    with open(os.path.join(folder, "model.bin"), "wb") as file:
        file.write(blob)
    with open(os.path.join(folder, "texture.png"), "wb") as file:
        file.write(png((300, 200), (160, 90, 40)))
    document = {
        "asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0, 1]}],
        "nodes": [{"mesh": 0, "translation": [0, 3, 0], "scale": [2, 2, 2]}, {"mesh": 1, "translation": [5, 0, 0], "scale": [-1, 1, 1]}],
        "meshes": [{"primitives": [primitives[0]]}, {"primitives": [primitives[1]]}],
        "materials": [{"name": "wood", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "roughnessFactor": 0.6, "metallicFactor": 0.0}},
                      {"name": "iron", "pbrMetallicRoughness": {"baseColorFactor": [0.2, 0.2, 0.25, 1], "metallicFactor": 1.0, "roughnessFactor": 0.4}},
                      ],
        "textures": [{"source": 0}], "images": [{"uri": "texture.png"}],
        "accessors": accessors, "bufferViews": views, "buffers": [{"uri": "model.bin", "byteLength": len(blob)}],
    }
    path = os.path.join(folder, "model.gltf")
    with open(path, "w") as file:
        json.dump(document, file)
    return path


def read_glb(path):
    document, binary = shrink_textures.read_glb(path)

    def accessor(index):
        acc = document["accessors"][index]
        view = document["bufferViews"][acc["bufferView"]]
        dtype = {5126: "<f4", 5123: "<u2", 5125: "<u4"}[acc["componentType"]]
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[acc["type"]]
        return np.frombuffer(binary, dtype, acc["count"] * width, view["byteOffset"]).reshape(acc["count"], width)

    return document, binary, accessor


@unittest.skipIf(np is None, "numpy and Pillow are needed")
class ConvertTest(unittest.TestCase):
    def convert(self, **options):
        folder = tempfile.mkdtemp()
        source = write_gltf(folder)
        args = argparse.Namespace(faces=400, meters=None, texture_edge=None, keep_blend=False, out=os.path.join(folder, "prop.glb"), name="prop")
        for key, value in options.items():
            setattr(args, key, value)
        warnings = polyhaven_prop.Warnings()
        stats = polyhaven_prop.convert(source, args, warnings)
        return args, stats, warnings

    def test_one_mesh_one_material_at_the_face_budget(self):
        args, stats, _ = self.convert()
        document, binary, accessor = read_glb(args.out)
        self.assertEqual(len(document["meshes"]), 1)
        self.assertEqual(len(document["meshes"][0]["primitives"]), 1)
        self.assertEqual(len(document["materials"]), 1)
        self.assertEqual(len(document["nodes"]), 1)
        self.assertEqual(stats["source_meshes"], 2)
        self.assertEqual(stats["source_materials"], 2)
        self.assertEqual(stats["source_faces"], 1452)
        self.assertLessEqual(stats["faces"], 400)
        self.assertGreater(stats["faces"], 300)
        self.assertEqual(len(accessor(document["meshes"][0]["primitives"][0]["indices"])) // 3, stats["faces"])

    def test_textures_are_png_at_the_size_tier(self):
        args, stats, _ = self.convert()
        document, binary, _ = read_glb(args.out)
        self.assertEqual(len(document["images"]), 3)
        for image in document["images"]:
            view = document["bufferViews"][image["bufferView"]]
            size = shrink_textures.png_size(binary[view["byteOffset"]:view["byteOffset"] + 24])
            self.assertLessEqual(max(size), 1024)
        self.assertEqual(stats["texture_edge"], 1024)  # the model is 12 m across
        self.assertEqual(shrink_textures.check_file(args.out), [])

    def test_small_model_gets_small_textures(self):
        args, stats, _ = self.convert(meters=0.5)
        self.assertEqual(stats["texture_edge"], 512)
        self.assertEqual(shrink_textures.check_file(args.out), [])
        self.assertAlmostEqual(max(stats["size_m"]), 0.5, places=3)

    def test_stands_on_origin_and_keeps_uvs_in_the_atlas(self):
        args, _, _ = self.convert(meters=1.0)
        document, binary, accessor = read_glb(args.out)
        primitive = document["meshes"][0]["primitives"][0]["attributes"]
        positions = accessor(primitive["POSITION"])
        self.assertAlmostEqual(float(positions[:, 1].min()), 0.0, places=5)
        self.assertAlmostEqual(float((positions[:, 0].min() + positions[:, 0].max()) / 2), 0.0, places=5)
        uvs = accessor(primitive["TEXCOORD_0"])
        self.assertTrue(((uvs >= 0) & (uvs <= 1)).all())
        normals = accessor(primitive["NORMAL"])
        self.assertTrue(np.allclose(np.linalg.norm(normals, axis=1), 1.0, atol=1e-3))

    def test_reduction_keeps_the_shape_and_the_winding(self):
        args, _, _ = self.convert(faces=300, meters=1.0)
        document, binary, accessor = read_glb(args.out)
        primitive = document["meshes"][0]["primitives"][0]
        positions = accessor(primitive["attributes"]["POSITION"]).astype(np.float64)
        triangles = accessor(primitive["indices"]).reshape(-1, 3)
        a, b, c = (positions[triangles[:, i]] for i in range(3))
        volume = float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6)
        self.assertGreater(volume, 0)  # outward winding; the mirrored box was turned right side out
        self.assertAlmostEqual(float(np.ptp(positions, axis=0).max()), 1.0, places=5)

    def test_no_reduction_when_under_budget(self):
        _, stats, _ = self.convert(faces=0)
        self.assertEqual(stats["faces"], stats["merged_faces"])

    def test_see_through_parts_are_left_out(self):
        folder = tempfile.mkdtemp()
        source = write_gltf(folder)
        with open(source) as file:
            document = json.load(file)
        document["materials"][1]["alphaMode"] = "BLEND"
        with open(source, "w") as file:
            json.dump(document, file)
        args = argparse.Namespace(faces=0, meters=None, texture_edge=None, keep_blend=False, out=os.path.join(folder, "prop.glb"), name="prop")
        warnings = polyhaven_prop.Warnings()
        stats = polyhaven_prop.convert(source, args, warnings)
        self.assertEqual(stats["source_meshes"], 1)
        self.assertEqual(stats["source_materials"], 1)
        self.assertTrue(any("glass" in w for w in warnings))

    def test_provenance_record_validates(self):
        args, stats, warnings = self.convert()
        root = tempfile.mkdtemp()
        os.makedirs(os.path.join(root, "assets", "props"))
        os.makedirs(os.path.join(root, "tools", "asset_pipeline", "batches"))
        args.out = os.path.join(root, "assets", "props", "prop.glb")
        polyhaven_prop.write_glb(args.out, np.zeros((3, 3)), np.zeros((3, 3)), np.zeros((3, 2)), np.array([[0, 1, 2]]), [np.zeros((4, 4, 3))] * 3, "prop")
        source = {"page": "https://polyhaven.com/a/prop", "polyhaven_asset": "prop", "resolution": "1k", "license": "CC0 1.0",
                  "license_url": "https://polyhaven.com/license", "authors": ["Somebody"],
                  "files": [{"file": "prop_1k.gltf", "url": "https://dl.polyhaven.org/x/prop_1k.gltf", "bytes": 5, "sha256": "0" * 64}]}
        path = polyhaven_prop.write_record(args, source, stats, warnings, root)
        record = provenance.load(path)
        self.assertEqual(provenance.check_record(record, "prop"), [])
        self.assertEqual(record["kind"], "polyhaven_prop")
        self.assertEqual(path, os.path.join(root, "provenance", "props", "prop.json"))
        with open(os.path.join(root, "ASSETS.md"), "w") as file:
            file.write("| File | Source | Author | License | Notes |\n| --- | --- | --- | --- | --- |\n"
                       "| `assets/props/prop.glb` | [Poly Haven: prop](https://polyhaven.com/a/prop) | Somebody | CC0 | one material |\n")
        out = []
        self.assertEqual(provenance.validate(root, out=out.append), 0, out)
        record["license"] = "CC BY 4.0"
        del record["source"]["files"]
        problems = provenance.check_record(record, "prop")
        self.assertTrue(any("license" in p for p in problems))
        self.assertTrue(any("source.files" in p for p in problems))
        os.remove(path)
        self.assertEqual(provenance.validate(root, out=out.append), 1)
        self.assertTrue(any("has no provenance record" in line for line in out), out)


if __name__ == "__main__":
    unittest.main()
