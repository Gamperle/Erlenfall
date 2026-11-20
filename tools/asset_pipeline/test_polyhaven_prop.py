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


def write_gltf(folder, tile=1.0):
    """Writes model.gltf, model.bin and texture.png under folder. Returns the .gltf path. With tile other than 1 the textured
    material goes on the box, whose large triangles get UVs of 0 to tile, and the sphere gets the flat-colored one."""
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
    tiled = tile != 1.0
    box_parts = box()
    box_parts = (box_parts[0], ((box_parts[0][:, :2] + 0.5) * tile).astype(np.float32), box_parts[2])
    for (positions, uvs, triangles), material in ((sphere(), 1 if tiled else 0), (box_parts, 0 if tiled else 1)):
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

    def convert_gltf(self, edit, **options):
        folder = tempfile.mkdtemp()
        source = write_gltf(folder, options.pop("tile", 1.0))
        with open(source) as file:
            document = json.load(file)
        edit(document)
        with open(source, "w") as file:
            json.dump(document, file)
        args = argparse.Namespace(faces=0, meters=None, texture_edge=None, keep_blend=False, out=os.path.join(folder, "prop.glb"), name="prop")
        for key, value in options.items():
            setattr(args, key, value)
        warnings = polyhaven_prop.Warnings()
        stats = polyhaven_prop.convert(source, args, warnings)
        return args, stats, warnings

    def test_tiling_texture_is_repeated_in_its_atlas_cell(self):
        args, _, warnings = self.convert_gltf(lambda d: None, tile=3.0)
        self.assertTrue(any("tiles its texture" in w for w in warnings), warnings)
        self.assertFalse(any("clamped" in w for w in warnings), warnings)
        document, binary, accessor = read_glb(args.out)
        uvs = accessor(document["meshes"][0]["primitives"][0]["attributes"]["TEXCOORD_0"])
        self.assertTrue(((uvs >= 0) & (uvs <= 1)).all())
        # the wood (material 0) has the left half of the atlas
        view = document["bufferViews"][document["images"][0]["bufferView"]]
        image = np.asarray(Image.open(io.BytesIO(binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])).convert("RGB"), np.float32)
        left = image[:, : image.shape[1] // 2]
        sub = image.shape[1] // 2 // 3
        self.assertTrue(np.allclose(left[:sub, :sub], left[:sub, sub:2 * sub]))  # three repeats side by side
        self.assertTrue(np.allclose(left[:sub, :sub], left[sub:2 * sub, :sub]))

    def test_more_repeats_than_the_cell_holds_are_clamped_and_warned(self):
        _, _, warnings = self.convert_gltf(lambda d: None, tile=12.0)
        self.assertTrue(any("clamped" in w for w in warnings), warnings)

    def test_emissive_glow_is_added_to_the_base_color(self):
        def edit(document):
            document["materials"][1]["emissiveFactor"] = [1.0, 0.0, 0.0]
        args, _, warnings = self.convert_gltf(edit)
        self.assertTrue(any("emissive" in w for w in warnings), warnings)
        document, binary, _ = read_glb(args.out)
        view = document["bufferViews"][document["images"][0]["bufferView"]]
        image = np.asarray(Image.open(io.BytesIO(binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])).convert("RGB"), np.float32)
        right = image[:, image.shape[1] // 2:]
        self.assertGreater(float(right[:, :, 0].mean()), 250)
        self.assertLess(float(right[:, :, 1].mean()), 80)

    def base_image(self, args):
        document, binary, _ = read_glb(args.out)
        view = document["bufferViews"][document["images"][0]["bufferView"]]
        return np.asarray(Image.open(io.BytesIO(binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])).convert("RGB"), np.float32)

    def test_glass_tint_darkens_the_see_through_part_and_opaque_keeps_its_color(self):
        def edit(document):
            document["materials"][1]["alphaMode"] = "BLEND"
            document["materials"][1]["pbrMetallicRoughness"]["baseColorFactor"] = [1.0, 1.0, 1.0, 0.2]
        _, stats, _ = self.convert_gltf(edit, glass="drop")
        self.assertEqual(stats["source_meshes"], 1)
        tinted, stats, warnings = self.convert_gltf(edit, glass="tint")
        self.assertEqual(stats["source_meshes"], 2)
        self.assertTrue(any("tinted dark" in w for w in warnings), warnings)
        opaque, _, _ = self.convert_gltf(edit, glass="opaque")
        dark = self.base_image(tinted)
        white = self.base_image(opaque)
        self.assertLess(float(dark[:, dark.shape[1] // 2:].mean()), 110)  # 0.2 + 0.25 * 0.8 = 0.4 of 255
        self.assertGreater(float(white[:, white.shape[1] // 2:].mean()), 250)
        _, stats, _ = self.convert_gltf(edit, keep_blend=True)
        self.assertEqual(stats["source_meshes"], 2)

    def test_transmission_is_tinted_and_volume_is_warned(self):
        def edit(document):
            document["materials"][1]["extensions"] = {"KHR_materials_transmission": {"transmissionFactor": 0.9}, "KHR_materials_volume": {"thicknessFactor": 1.0}}
            document["materials"][1]["pbrMetallicRoughness"]["metallicFactor"] = 0.0
            document["materials"][1]["pbrMetallicRoughness"]["baseColorFactor"] = [1.0, 1.0, 1.0, 1.0]
        args, _, warnings = self.convert_gltf(edit, glass="tint")
        self.assertTrue(any("transmission" in w for w in warnings), warnings)
        self.assertTrue(any("volume" in w for w in warnings), warnings)
        image = self.base_image(args)
        self.assertLess(float(image[:, image.shape[1] // 2:].mean()), 100)

    def test_transmission_on_a_metal_is_ignored(self):
        def edit(document):  # the iron has metallicFactor 1: Poly Haven's brass and steel carry a transmission of 1 and are not glass
            document["materials"][1]["extensions"] = {"KHR_materials_transmission": {"transmissionFactor": 1.0}}
            document["materials"][1]["pbrMetallicRoughness"]["baseColorFactor"] = [1.0, 1.0, 1.0, 1.0]
        args, _, warnings = self.convert_gltf(edit, glass="tint")
        self.assertTrue(any("is metal" in w for w in warnings), warnings)
        image = self.base_image(args)
        self.assertGreater(float(image[:, image.shape[1] // 2:].mean()), 250)  # still white, not tinted

    def test_clearcoat_lowers_roughness(self):
        def roughness(args):
            document, binary, _ = read_glb(args.out)
            view = document["bufferViews"][document["images"][2]["bufferView"]]
            image = np.asarray(Image.open(io.BytesIO(binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])).convert("RGB"), np.float32)
            return float(image[:, image.shape[1] // 2:, 1].mean()) / 255.0  # the iron's, 0.4 without a coat
        plain, _, _ = self.convert_gltf(lambda d: None)

        def edit(document):
            document["materials"][1]["extensions"] = {"KHR_materials_clearcoat": {"clearcoatFactor": 1.0, "clearcoatRoughnessFactor": 0.1}}
        coated, _, warnings = self.convert_gltf(edit)
        self.assertTrue(any("clearcoat" in w for w in warnings), warnings)
        self.assertAlmostEqual(roughness(plain), 0.4, delta=0.02)
        self.assertAlmostEqual(roughness(coated), 0.1, delta=0.02)

    def test_skins_and_animations_are_dropped_with_a_warning(self):
        def edit(document):
            document["skins"] = [{"joints": [0]}]
            document["animations"] = [{"channels": [], "samplers": []}, {"channels": [], "samplers": []}]
            document["nodes"][0]["skin"] = 0  # a skinned mesh ignores its node's scale and translation
        _, stats, warnings = self.convert_gltf(edit, meters=1.0)
        self.assertTrue(any("1 skins and 2 animations" in w for w in warnings), warnings)
        self.assertEqual(stats["source_meshes"], 2)

    def occlusion_model(self, uv0_scale=1.0):
        """A quad whose UV1 runs from 0.25 to 0.75 across it, on an occlusion map that is black left of 0.5 and white right of it."""
        folder = tempfile.mkdtemp()
        source = write_gltf(folder)
        with open(source) as file:
            document = json.load(file)
        positions = np.array([(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], np.float32)
        uv0 = np.array([(0, 0), (1, 0), (1, 1), (0, 1)], np.float32) * uv0_scale
        uv1 = np.array([(0.25, 0), (0.75, 0), (0.75, 1), (0.25, 1)], np.float32)
        blob = b""
        views, accessors = [], []
        for array, component, kind in ((positions, 5126, "VEC3"), (uv0, 5126, "VEC2"), (uv1, 5126, "VEC2"), (np.array([0, 1, 2, 0, 2, 3], np.uint16), 5123, "SCALAR")):
            data = array.tobytes()
            views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
            blob += data + b"\0" * (-len(data) % 4)
            accessor = {"bufferView": len(views) - 1, "componentType": component, "count": len(array), "type": kind}
            if kind == "VEC3":
                accessor["min"], accessor["max"] = array.min(axis=0).tolist(), array.max(axis=0).tolist()
            accessors.append(accessor)
        with open(os.path.join(folder, "model.bin"), "wb") as file:
            file.write(blob)
        occlusion = Image.new("L", (64, 64), 255)
        occlusion.paste(0, (0, 0, 32, 64))
        occlusion.save(os.path.join(folder, "ao.png"))
        document.update({"nodes": [{"mesh": 0}], "scenes": [{"nodes": [0]}], "accessors": accessors, "bufferViews": views,
                         "buffers": [{"uri": "model.bin", "byteLength": len(blob)}],
                         "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "TEXCOORD_0": 1, "TEXCOORD_1": 2}, "indices": 3, "material": 1}]}]})
        document["materials"][1]["occlusionTexture"] = {"index": 1, "texCoord": 1}
        document["textures"].append({"source": 1})
        document["images"].append({"uri": "ao.png"})
        with open(source, "w") as file:
            json.dump(document, file)
        args = argparse.Namespace(faces=0, meters=None, texture_edge=64, keep_blend=False, out=os.path.join(folder, "prop.glb"), name="prop")
        warnings = polyhaven_prop.Warnings()
        polyhaven_prop.convert(source, args, warnings)
        glb, binary, _ = read_glb(args.out)
        view = glb["bufferViews"][glb["images"][2]["bufferView"]]
        orm = np.asarray(Image.open(io.BytesIO(binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])).convert("RGB"), np.float32)
        return orm, warnings

    def test_occlusion_on_the_second_uv_set_is_rasterized_into_the_first(self):
        orm, warnings = self.occlusion_model()
        self.assertTrue(any("rasterized" in w for w in warnings), warnings)
        height, width = orm.shape[:2]
        self.assertLess(float(orm[height // 2, width // 10, 0]), 20)  # UV0 0.1 reads UV1 0.30: the black half
        self.assertGreater(float(orm[height // 2, width * 9 // 10, 0]), 235)  # UV0 0.9 reads UV1 0.70: the white half

    def test_occlusion_on_the_second_uv_set_is_dropped_when_the_first_tiles(self):
        orm, warnings = self.occlusion_model(uv0_scale=2.0)
        self.assertTrue(any("TEXCOORD_0 tiles" in w for w in warnings), warnings)
        self.assertGreater(float(orm[:, :, 0].min()), 235)  # no occlusion rather than a wrong one

    def test_texture_transform_matrix(self):
        class Fake:
            doc = {"materials": [{"pbrMetallicRoughness": {"baseColorTexture": {"index": 0, "extensions": {"KHR_texture_transform": {"offset": [0.5, 0.25], "scale": [2, 3]}}}}},
                                 {"pbrMetallicRoughness": {"baseColorTexture": {"index": 0, "extensions": {"KHR_texture_transform": {"rotation": math.pi / 2}}}}},
                                 {"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}}}]}
        warnings = polyhaven_prop.Warnings()
        matrix = polyhaven_prop.uv_matrix(Fake, 0, warnings)
        self.assertTrue(np.allclose(matrix @ [1, 1, 1], [2.5, 3.25, 1]))
        self.assertTrue(np.allclose(polyhaven_prop.uv_matrix(Fake, 1, warnings) @ [1, 0, 1], [0, -1, 1], atol=1e-9))
        self.assertIsNone(polyhaven_prop.uv_matrix(Fake, 2, warnings))
        self.assertIsNone(polyhaven_prop.uv_matrix(Fake, None, warnings))
        self.assertEqual(warnings, [])


class DecimationTest(unittest.TestCase):
    def grid(self, n=24):
        """A flat n x n grid of quads in the plane z = 0 whose UVs follow x on the left half and wobble on the right half."""
        xs = np.linspace(0, 1, n + 1)
        positions, uvs = [], []
        for y in xs:
            for x in xs:
                positions.append((x, y, 0.0))
                uvs.append((x + (0.04 * math.sin(10 * math.pi * x) if x > 0.5 else 0.0), y))
        triangles = []
        for j in range(n):
            for i in range(n):
                a = j * (n + 1) + i
                triangles += [(a, a + 1, a + n + 1), (a + 1, a + n + 2, a + n + 1)]
        normals = np.tile([0.0, 0.0, 1.0], (len(positions), 1))
        return np.array(positions), normals, np.array(uvs), np.array(triangles)

    def test_the_reduction_keeps_triangles_where_the_texture_bends(self):
        positions, normals, uvs, triangles = self.grid()
        out_positions, _, _, out = polyhaven_prop.decimate(positions, normals, uvs, triangles, len(triangles) // 3)
        centers = out_positions[out].mean(axis=1)[:, 0]
        self.assertLessEqual(len(out), len(triangles) // 3 + 2)
        # the flat-textured half is cheap to reduce, the wobbling half must keep most of what it has
        self.assertGreater(int((centers > 0.5).sum()), 2 * int((centers < 0.5).sum()))

    def test_uv_slide_is_zero_on_an_affine_mapping_and_grows_when_it_bends(self):
        pos = [np.array(p, float) for p in ((0, 0, 0), (1, 0, 0), (0, 1, 0))]
        uv = [np.array(p, float) for p in ((0, 0), (1, 0), (0, 1))]
        target = np.array([1.0, 1.0, 0.0])
        self.assertAlmostEqual(polyhaven_prop.uv_slide(pos, uv, target, np.array([1.0, 1.0]))[0], 0.0)
        self.assertAlmostEqual(polyhaven_prop.uv_slide(pos, uv, target, np.array([1.0, 1.5]))[0], 0.5)


if __name__ == "__main__":
    unittest.main()
