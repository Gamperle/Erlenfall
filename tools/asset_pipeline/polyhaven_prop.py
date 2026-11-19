#!/usr/bin/env python3
"""Turns a Poly Haven glTF model into a single-surface prop for assets/props (#220).

The smoke test wants every prop to be one mesh with one textured surface, and shrink_textures.py wants its
textures at the size tier. Poly Haven models come as glTF with several meshes and materials, separate diffuse,
normal and packed AO/roughness/metal (ARM) maps, and up to 20,000 faces. This script:

  1. downloads the model from Poly Haven's public API (or reads a local .gltf/.glb), checking each file's MD5
  2. bakes every node's transform into the vertices and merges all meshes into one
  3. merges the materials into one: a single material keeps its UVs, several are packed side by side into one
     atlas per map (base color, normal, and an ORM map with occlusion in red, roughness in green, metal in blue)
  4. reduces it to at most --faces triangles (default 3000, the top of the props' face budget) by quadric edge
     collapse, which keeps the silhouette, the UV islands and the open edges
  5. resizes the textures to the size tier (512 px up to 1.25 m, else 1024 px) as PNG, like shrink_textures.py
  6. stands it on the origin, centered, as size_glb.py does, scaled to --meters if given (Poly Haven's are
     in meters already, so the default keeps the real size), and writes the .glb
  7. with --provenance, writes provenance/props/<name>.json (kind polyhaven_prop) with the source URLs, the
     author, the CC0 license, the files' SHA-256 and the settings

It needs numpy and Pillow and the standard library only: no Blender, so it runs on any machine. The .glb has
one node, one mesh, one primitive with POSITION, NORMAL and TEXCOORD_0, and one material (base color, normal
and ORM maps; occlusion and metallicRoughness share the ORM image), which `size_glb.py` and the prop tuner
read like any other prop. size_glb.py would only be needed to change the size or turn the model.

Usage, from the repository root:
  polyhaven_prop.py NAME_OR_FILE [--res 1k] [--faces 3000] [--meters M] [--out assets/props/NAME.glb]
                    [--work DIR] [--provenance] [--author "A, B"]

  NAME_OR_FILE  a Poly Haven asset name such as painted_wooden_stool, or a path to a .gltf or .glb
  --res         the glTF resolution to download: 1k (default), 2k, 4k
  --faces       the most triangles to keep (0 keeps all of them)
  --meters      scale the longest side to this many meters
  --out         where to write the .glb (default assets/props/<name>.glb). A name that is not a Poly Haven
                asset needs --name.
  --work        folder for the downloaded files (default: a new temporary folder)
  --provenance  write the provenance record. A local file also needs --name, --author and --source-url
  --texture-edge  force the texture size in pixels instead of the size tier
  --keep-blend  keep parts whose material is see-through (glass, alphaMode BLEND), drawn opaque. A prop has one
                opaque surface, so by default they are left out (a lantern without its panes beats black panes)

The decimation measures cost by quadric error and moves a vertex onto its neighbor, never to a new place, so
the UV of every corner stays one the model already had. A collapse that would flip a face, pinch two UV
islands together or break a neighboring triangle is skipped.
"""
import argparse
import hashlib
import heapq
import io
import json
import math
import os
import struct
import sys
import tempfile
import urllib.request

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import provenance  # noqa: E402
import shrink_textures  # noqa: E402

API = "https://api.polyhaven.com"
LICENSE = "CC0 1.0"
LICENSE_URL = "https://polyhaven.com/license"
DEFAULT_FACES = 3000
COMPONENTS = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
SIZES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
TYPES = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4"}


class Warnings(list):
    def __call__(self, text):
        if text in self:
            return
        self.append(text)
        print("warning: " + text, file=sys.stderr)


# --- Download ----------------------------------------------------------------------------------


def fetch(url, timeout=60):
    request = urllib.request.Request(url, headers={"User-Agent": "erlenfall-asset-pipeline (polyhaven_prop.py)"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def fetch_json(url):
    return json.loads(fetch(url))


def download(name, resolution, folder):
    """Downloads the glTF of a Poly Haven model into folder. Returns (path of the .gltf, source dict).
    Every file's MD5 is checked against the API's. The source dict is what the provenance record keeps."""
    files = fetch_json("%s/files/%s" % (API, name))
    try:
        entry = files["gltf"][resolution]["gltf"]
    except KeyError:
        raise SystemExit("%s has no glTF at %s (Poly Haven lists: %s)" % (name, resolution, ", ".join(files.get("gltf", {})) or "no glTF"))
    info = fetch_json("%s/info/%s" % (API, name))
    sources = [("%s_%s.gltf" % (name, resolution), entry)] + list(entry["include"].items())
    saved = []
    for relative, item in sources:
        data = fetch(item["url"])
        if hashlib.md5(data).hexdigest() != item["md5"]:
            raise SystemExit("%s does not match the MD5 Poly Haven lists for it" % item["url"])
        path = os.path.join(folder, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as file:
            file.write(data)
        saved.append({"file": relative, "url": item["url"], "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    source = {"page": "https://polyhaven.com/a/" + name, "polyhaven_asset": name, "resolution": resolution,
              "license": LICENSE, "license_url": LICENSE_URL, "authors": sorted(info.get("authors", {})),
              "title": info.get("name"), "polycount": info.get("polycount"), "files": saved}
    return os.path.join(folder, sources[0][0]), source


# --- Reading glTF ------------------------------------------------------------------------------


class Gltf:
    """A glTF or GLB file with its buffers and images loaded."""

    def __init__(self, path):
        self.folder = os.path.dirname(os.path.abspath(path))
        with open(path, "rb") as file:
            data = file.read()
        self.glb_binary = None
        if data[:4] == b"glTF":
            length = struct.unpack("<I", data[12:16])[0]
            self.doc = json.loads(data[20:20 + length])
            offset = 20 + length
            if offset + 8 <= len(data):
                size = struct.unpack("<I", data[offset:offset + 4])[0]
                self.glb_binary = data[offset + 8:offset + 8 + size]
        else:
            self.doc = json.loads(data)
        self.buffers = [self._buffer(b) for b in self.doc.get("buffers", [])]

    def _uri(self, uri):
        if uri.startswith("data:"):
            import base64

            return base64.b64decode(uri.split(",", 1)[1])
        import urllib.parse

        with open(os.path.join(self.folder, urllib.parse.unquote(uri)), "rb") as file:
            return file.read()

    def _buffer(self, buffer):
        if "uri" in buffer:
            return self._uri(buffer["uri"])
        if self.glb_binary is None:
            raise SystemExit("a buffer has no uri and the file has no binary chunk")
        return self.glb_binary

    def view_bytes(self, index):
        view = self.doc["bufferViews"][index]
        start = view.get("byteOffset", 0)
        return self.buffers[view["buffer"]][start:start + view["byteLength"]]

    def accessor(self, index):
        """The accessor as a numpy array (count, components), converted to float32 if it is normalized."""
        acc = self.doc["accessors"][index]
        if "sparse" in acc:
            raise SystemExit("sparse accessors are not supported")
        dtype = np.dtype(COMPONENTS[acc["componentType"]])
        width = SIZES[acc["type"]]
        count = acc["count"]
        if "bufferView" not in acc:
            return np.zeros((count, width), dtype)
        view = self.doc["bufferViews"][acc["bufferView"]]
        start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride") or dtype.itemsize * width
        raw = self.buffers[view["buffer"]]
        if stride == dtype.itemsize * width:
            array = np.frombuffer(raw, dtype, count * width, start).reshape(count, width)
        else:
            array = np.empty((count, width), dtype)
            for i in range(count):
                array[i] = np.frombuffer(raw, dtype, width, start + i * stride)
        if acc.get("normalized"):
            scale = {np.int8: 127.0, np.uint8: 255.0, np.int16: 32767.0, np.uint16: 65535.0}[dtype.type]
            return np.maximum(array.astype(np.float32) / scale, -1.0)
        return array

    def image(self, index, warn):
        """A Pillow image of glTF image number index."""
        entry = self.doc["images"][index]
        data = self.view_bytes(entry["bufferView"]) if "bufferView" in entry else self._uri(entry["uri"])
        image = Image.open(io.BytesIO(data))
        image.load()
        return image


def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], np.float64).reshape(4, 4).T
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    rotation = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    matrix = np.eye(4)
    matrix[:3, :3] = rotation * np.array(node.get("scale", [1, 1, 1]))
    matrix[:3, 3] = node.get("translation", [0, 0, 0])
    return matrix


def load_parts(gltf, warn, keep_blend=False):
    """Every triangle primitive in the scene, with its node's transform baked in:
    a list of dicts with positions (n, 3), normals (n, 3), uvs (n, 2), triangles (m, 3) and material (index or None)."""
    doc = gltf.doc
    if doc.get("skins") or doc.get("animations"):
        warn("the model has skins or animations; they are dropped and the mesh stays in its bind pose")
    scene = doc["scenes"][doc.get("scene", 0)] if doc.get("scenes") else {"nodes": list(range(len(doc.get("nodes", []))))}
    parts = []

    def visit(index, parent):
        node = doc["nodes"][index]
        world = parent @ node_matrix(node)
        if "mesh" in node:
            for primitive in doc["meshes"][node["mesh"]]["primitives"]:
                material = doc["materials"][primitive["material"]] if primitive.get("material") is not None else {}
                if material.get("alphaMode") == "BLEND" and not keep_blend:
                    warn("%s is see-through (glass) and was left out; --keep-blend draws it opaque" % material.get("name", "a material"))
                    continue
                part = read_primitive(gltf, primitive, world, warn)
                if part:
                    parts.append(part)
        for child in node.get("children", []):
            visit(child, world)

    for root in scene["nodes"]:
        visit(root, np.eye(4))
    return parts


def read_primitive(gltf, primitive, world, warn):
    if primitive.get("mode", 4) != 4:
        warn("a primitive that is not a triangle list (mode %d) was skipped" % primitive.get("mode", 4))
        return None
    attributes = primitive["attributes"]
    positions = gltf.accessor(attributes["POSITION"]).astype(np.float64)
    count = len(positions)
    if "indices" in primitive:
        triangles = gltf.accessor(primitive["indices"]).reshape(-1, 3).astype(np.int64)
    else:
        triangles = np.arange(count).reshape(-1, 3)
    matrix = world[:3, :3]
    positions = positions @ matrix.T + world[:3, 3]
    if "NORMAL" in attributes:
        normals = gltf.accessor(attributes["NORMAL"]).astype(np.float64) @ np.linalg.inv(matrix)
    else:
        normals = None
    if np.linalg.det(matrix) < 0:  # a mirroring node turns the faces inside out
        triangles = triangles[:, ::-1]
    if normals is None:
        normals = vertex_normals(positions, triangles)
    length = np.linalg.norm(normals, axis=1, keepdims=True)
    normals = normals / np.where(length == 0, 1, length)
    if "TEXCOORD_0" in attributes:
        uvs = gltf.accessor(attributes["TEXCOORD_0"]).astype(np.float64)
    else:
        uvs = np.zeros((count, 2))
    return {"positions": positions, "normals": normals, "uvs": uvs, "triangles": triangles, "material": primitive.get("material")}


def vertex_normals(positions, triangles):
    a, b, c = (positions[triangles[:, i]] for i in range(3))
    face = np.cross(b - a, c - a)
    normals = np.zeros_like(positions)
    for i in range(3):
        np.add.at(normals, triangles[:, i], face)
    return normals


# --- Materials ---------------------------------------------------------------------------------


def texture_image(gltf, material_texture, warn, what):
    """(Pillow image, texcoord set) for a glTF textureInfo, or (None, 0)."""
    if not material_texture:
        return None, 0
    if "KHR_texture_transform" in material_texture.get("extensions", {}):
        warn("%s uses KHR_texture_transform, which is ignored" % what)
    texture = gltf.doc["textures"][material_texture["index"]]
    if "source" not in texture:
        return None, 0
    return gltf.image(texture["source"], warn), material_texture.get("texCoord", 0)


def channels(image, size):
    """The image as a float array (h, w, 4) in 0..1 at the given (w, h), resampled with Lanczos."""
    image = image.convert("RGBA")
    if image.size != size:
        image = image.resize(size, Image.LANCZOS)
    return np.asarray(image, np.float32) / 255.0


def bake_material(gltf, index, size, warn):
    """The three maps of one material at size (w, h): base color RGB, normal RGB and ORM RGB, as float arrays 0..1.
    Missing maps become the flat value that the material's factors say."""
    doc = gltf.doc
    material = doc["materials"][index] if index is not None else {}
    pbr = material.get("pbrMetallicRoughness", {})
    name = material.get("name", "material %s" % index)
    if material.get("alphaMode", "OPAQUE") != "OPAQUE":
        warn("%s has alphaMode %s; the prop is drawn opaque" % (name, material["alphaMode"]))
    if any(material.get("emissiveFactor", [0, 0, 0])):
        warn("%s is emissive, which a prop does not keep" % name)
    for key in ("KHR_materials_transmission", "KHR_materials_clearcoat", "KHR_materials_volume"):
        if key in material.get("extensions", {}):
            warn("%s uses %s, which is dropped" % (name, key))
    width, height = size
    factor = np.array(pbr.get("baseColorFactor", [1, 1, 1, 1]), np.float32)
    base_image, base_uv = texture_image(gltf, pbr.get("baseColorTexture"), warn, name + " base color")
    base = channels(base_image, size)[:, :, :3] if base_image else np.ones((height, width, 3), np.float32)
    base = base * factor[:3]
    normal_image, normal_uv = texture_image(gltf, material.get("normalTexture"), warn, name + " normal")
    normal = channels(normal_image, size)[:, :, :3] if normal_image else np.dstack([np.full((height, width), v, np.float32) for v in (0.5, 0.5, 1.0)])
    scale = material.get("normalTexture", {}).get("scale", 1.0)
    if normal_image is not None and abs(scale - 1.0) > 1e-6:
        flat = normal * 2 - 1
        flat[:, :, :2] *= scale
        normal = flat * 0.5 + 0.5
    if normal_image is not None:
        normal = renormalize(normal)
    metal_image, metal_uv = texture_image(gltf, pbr.get("metallicRoughnessTexture"), warn, name + " metallic roughness")
    occlusion_image, occlusion_uv = texture_image(gltf, material.get("occlusionTexture"), warn, name + " occlusion")
    rough_factor = pbr.get("roughnessFactor", 1.0)
    metal_factor = pbr.get("metallicFactor", 1.0)
    orm = np.ones((height, width, 3), np.float32)
    if occlusion_image is not None:
        orm[:, :, 0] = channels(occlusion_image, size)[:, :, 0]
    if metal_image is not None:
        packed = channels(metal_image, size)
        orm[:, :, 1] = packed[:, :, 1] * rough_factor
        orm[:, :, 2] = packed[:, :, 2] * metal_factor
    else:
        orm[:, :, 1] = rough_factor
        orm[:, :, 2] = metal_factor
    if any(uv not in (0, base_uv) for uv in (normal_uv, metal_uv, occlusion_uv) if uv):
        warn("%s reads a map through TEXCOORD_1; only TEXCOORD_0 is kept" % name)
    return base, normal, orm


def renormalize(normal):
    vector = normal * 2 - 1
    length = np.linalg.norm(vector, axis=2, keepdims=True)
    vector = vector / np.where(length < 1e-6, 1, length)
    return vector * 0.5 + 0.5


def to_png(array):
    image = Image.fromarray((np.clip(array, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    out = io.BytesIO()
    image.save(out, "PNG", optimize=True)
    return out.getvalue()


def merge_materials(gltf, parts, edge, warn):
    """Gives every part the one material's UVs. Returns (base, normal, orm) arrays (h, w, 3) at most edge px long.

    One material: its maps are resized and the UVs stay as they are. Several: a grid of cells, one per material in
    use, each edge/columns px, holds the material's maps, and each triangle's UVs are moved into its cell. A
    triangle whose UVs lie outside 0..1 (tiling) is shifted into the unit square by its own whole-number offset,
    and its vertices are split off so a neighbor keeps its own; UVs that still leave the square are clamped and
    counted in a warning."""
    used = sorted({p["material"] for p in parts}, key=lambda m: -1 if m is None else m)
    if len(used) == 1:
        source = largest_texture(gltf, used[0])
        if source is None:
            width = height = 16  # flat colors only
        elif max(source) > edge:
            width, height = (max(1, round(side * edge / max(source))) for side in source)
        else:
            width, height = source
        return bake_material(gltf, used[0], (width, height), warn)
    columns = math.ceil(math.sqrt(len(used)))
    rows = math.ceil(len(used) / columns)
    cell = edge // columns
    atlas = [np.zeros((cell * rows, cell * columns, 3), np.float32) for _ in range(3)]
    pad = 2.0 / cell
    clamped = 0
    split_parts = []
    for slot, material in enumerate(used):
        column, row = slot % columns, slot // columns
        maps = bake_material(gltf, material, (cell, cell), warn)
        for target, source in zip(atlas, maps):
            target[row * cell:(row + 1) * cell, column * cell:(column + 1) * cell] = source
        for part in parts:
            if part["material"] != material:
                continue
            part = unindex(part)
            uv = part["uvs"].reshape(-1, 3, 2)
            shift = np.floor(uv.mean(axis=1, keepdims=True) - 1e-6)
            uv = uv - shift
            clamped += int(((uv < -1e-4) | (uv > 1 + 1e-4)).any(axis=(1, 2)).sum())
            uv = np.clip(uv, 0, 1) * (1 - 2 * pad) + pad
            uv[:, :, 0] = (uv[:, :, 0] + column) / columns
            uv[:, :, 1] = (uv[:, :, 1] + row) / rows
            part["uvs"] = uv.reshape(-1, 2)
            split_parts.append(part)
    if clamped:
        warn("%d triangles tile a texture across more than one repeat; their UVs were clamped into the atlas cell" % clamped)
    parts[:] = split_parts
    return tuple(a[: cell * rows, : cell * columns] for a in atlas)


def largest_texture(gltf, index):
    """(width, height) of the largest map a material reads, or None if it has none."""
    doc = gltf.doc
    if index is None:
        return None
    material = doc["materials"][index]
    pbr = material.get("pbrMetallicRoughness", {})
    sizes = []
    for info in (pbr.get("baseColorTexture"), pbr.get("metallicRoughnessTexture"), material.get("normalTexture"), material.get("occlusionTexture")):
        if info and "source" in doc["textures"][info["index"]]:
            image = doc["images"][doc["textures"][info["index"]]["source"]]
            data = gltf.view_bytes(image["bufferView"]) if "bufferView" in image else gltf._uri(image["uri"])
            sizes.append(Image.open(io.BytesIO(data)).size)
    return max(sizes, key=lambda s: s[0] * s[1]) if sizes else None


def unindex(part):
    """The part with three vertices of its own for each triangle."""
    triangles = part["triangles"].reshape(-1)
    return {"positions": part["positions"][triangles], "normals": part["normals"][triangles], "uvs": part["uvs"][triangles],
            "triangles": np.arange(len(triangles)).reshape(-1, 3), "material": part["material"]}


# --- Merging -----------------------------------------------------------------------------------


def merge_parts(parts):
    """One mesh from all parts, welding vertices that agree in position, normal and UV. Returns positions, normals,
    uvs and triangles. Triangles with no area are dropped."""
    positions = np.concatenate([p["positions"] for p in parts])
    normals = np.concatenate([p["normals"] for p in parts])
    uvs = np.concatenate([p["uvs"] for p in parts])
    offsets = np.cumsum([0] + [len(p["positions"]) for p in parts[:-1]])
    triangles = np.concatenate([p["triangles"] + o for p, o in zip(parts, offsets)])
    key = np.concatenate([np.round(positions * 1e6), np.round(normals * 1e3), np.round(uvs * 1e5)], axis=1).astype(np.int64)
    _, first, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inverse = inverse.reshape(-1)
    positions, normals, uvs = positions[first], normals[first], uvs[first]
    triangles = inverse[triangles]
    a, b, c = (positions[triangles[:, i]] for i in range(3))
    area = np.linalg.norm(np.cross(b - a, c - a), axis=1)
    keep = (area > 1e-14) & (triangles[:, 0] != triangles[:, 1]) & (triangles[:, 1] != triangles[:, 2]) & (triangles[:, 0] != triangles[:, 2])
    return positions, normals, uvs, triangles[keep]


# --- Decimation --------------------------------------------------------------------------------


def plane_quadric(a, b, c):
    """The area-weighted quadric of the triangle's plane, as a 4 x 4 matrix, and the triangle's unit normal (zeros if flat)."""
    cross = np.cross(b - a, c - a)
    length = np.linalg.norm(cross)
    if length < 1e-20:
        return np.zeros((4, 4)), np.zeros(3)
    normal = cross / length
    plane = np.append(normal, -normal @ a)
    return np.outer(plane, plane) * (length / 2), normal


def decimate(positions, normals, uvs, triangles, target):
    """Reduces the mesh to about target triangles by edge collapse. See the module text.

    The mesh is handled by position ("pids": vertices welded by position), so a UV seam is not an edge of the mesh and
    cannot tear open, and each triangle corner keeps the index of its own vertex (position, normal, UV) as a corner
    vertex ("sv"). Collapsing pid a onto pid b moves a's corners onto the b vertex of the same UV island, found
    from the triangles that the collapse removes. A collapse that leaves some other island's corner at a with no
    such vertex is skipped. Returns (positions, normals, uvs, triangles) of the reduced mesh."""
    if target <= 0 or len(triangles) <= target:
        return positions, normals, uvs, triangles
    _, pid_first, pid_of = np.unique(np.round(positions * 1e6).astype(np.int64), axis=0, return_index=True, return_inverse=True)
    pid_of = pid_of.reshape(-1)
    pid_position = positions[pid_first].copy()
    corners = [list(map(int, t)) for t in triangles]                  # corner vertices of each face
    faces = [[int(pid_of[v]) for v in t] for t in corners]            # pids of each face
    alive = [True] * len(faces)
    around = [set() for _ in pid_position]
    for f, face in enumerate(faces):
        for p in face:
            around[p].add(f)
    quadric = np.zeros((len(pid_position), 4, 4))
    edge_faces = {}
    for f, face in enumerate(faces):
        q, _ = plane_quadric(*(pid_position[p] for p in face))
        for p in face:
            quadric[p] += q
        for i in range(3):
            edge_faces.setdefault(tuple(sorted((face[i], face[(i + 1) % 3]))), []).append(f)
    for (a, b), owners in edge_faces.items():  # an open edge gets a plane through it, standing on its face, to hold the silhouette
        if len(owners) == 1:
            face = faces[owners[0]]
            _, normal = plane_quadric(*(pid_position[p] for p in face))
            side = np.cross(pid_position[b] - pid_position[a], normal)
            length = np.linalg.norm(side)
            if length > 1e-20:
                side /= length
                plane = np.append(side, -side @ pid_position[a])
                q = np.outer(plane, plane) * length * length
                quadric[a] += q
                quadric[b] += q
    version = [0] * len(pid_position)
    heap = []

    def cost(a, b):
        v = np.append(pid_position[b], 1.0)
        return float(v @ (quadric[a] + quadric[b]) @ v)

    def push(a, b):
        heapq.heappush(heap, (cost(a, b), a, b, version[a], version[b]))

    for a, b in edge_faces:
        push(a, b)
        push(b, a)
    count = len(faces)

    def neighbors(p):
        found = set()
        for f in around[p]:
            found.update(faces[f])
        found.discard(p)
        return found

    while heap and count > target:
        _, a, b, va, vb = heapq.heappop(heap)
        if version[a] != va or version[b] != vb:
            continue
        shared = around[a] & around[b]
        if not shared or len(shared) > 2:
            continue
        opposite = {p for f in shared for p in faces[f] if p != a and p != b}
        if neighbors(a) & neighbors(b) != opposite:
            continue  # collapsing would join two parts of the surface that only touch at the edge
        mapping = {}
        ok = True
        for f in shared:
            corner_a = corners[f][faces[f].index(a)]
            corner_b = corners[f][faces[f].index(b)]
            if mapping.setdefault(corner_a, corner_b) != corner_b:
                ok = False
        if not ok:
            continue
        moving = around[a] - shared
        for f in moving:
            if corners[f][faces[f].index(a)] not in mapping:
                ok = False
                break
            old = faces[f]
            new = [b if p == a else p for p in old]
            _, before = plane_quadric(*(pid_position[p] for p in old))
            _, after = plane_quadric(*(pid_position[p] for p in new))
            if not after.any() or (before @ after) < 0.2:
                ok = False
                break
        if not ok:
            continue
        for f in shared:
            alive[f] = False
            for p in faces[f]:
                around[p].discard(f)
        for f in moving:
            index = faces[f].index(a)
            faces[f][index] = b
            corners[f][index] = mapping[corners[f][index]]
            around[b].add(f)
        around[a] = set()
        quadric[b] += quadric[a]
        version[a] += 1
        version[b] += 1
        count -= len(shared)
        for c in neighbors(b):
            push(b, c)
            push(c, b)
    keep = [f for f in range(len(faces)) if alive[f]]
    used = sorted({v for f in keep for v in corners[f]})
    renumber = {v: i for i, v in enumerate(used)}
    # a corner vertex sits on the position of the pid it was last collapsed to; track it through the faces
    owner = {}
    for f in keep:
        for p, v in zip(faces[f], corners[f]):
            owner[v] = p
    new_positions = np.array([pid_position[owner[v]] for v in used])
    new_triangles = np.array([[renumber[v] for v in corners[f]] for f in keep], np.int64)
    return new_positions, normals[used], uvs[used], new_triangles


# --- Output ------------------------------------------------------------------------------------


def stand_on_origin(positions, meters):
    """Scales so the longest side is meters (if given) and stands the model centered on x and z with its base at y = 0."""
    low, high = positions.min(axis=0), positions.max(axis=0)
    if meters:
        positions = positions * (meters / float((high - low).max()))
        low, high = positions.min(axis=0), positions.max(axis=0)
    return positions - np.array([(low[0] + high[0]) / 2, low[1], (low[2] + high[2]) / 2])


def write_glb(path, positions, normals, uvs, triangles, maps, name):
    base, normal, orm = (to_png(m) for m in maps)
    small = len(positions) < 65536
    index = triangles.astype(np.uint16 if small else np.uint32).reshape(-1)
    pieces = []

    def add(data):
        offset = sum(len(p) for p in pieces)
        pieces.append(data + b"\0" * (-len(data) % 4))
        return offset, len(data)

    views = []
    for data, target in ((positions.astype("<f4").tobytes(), 34962), (normals.astype("<f4").tobytes(), 34962),
                         (uvs.astype("<f4").tobytes(), 34962), (index.astype("<u2" if small else "<u4").tobytes(), 34963),
                         (base, None), (normal, None), (orm, None)):
        offset, length = add(data)
        view = {"buffer": 0, "byteOffset": offset, "byteLength": length}
        if target:
            view["target"] = target
        views.append(view)
    binary = b"".join(pieces)
    count = len(positions)
    document = {
        "asset": {"version": "2.0", "generator": "polyhaven_prop.py"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "materials": [{"name": name, "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 1.0, "roughnessFactor": 1.0,
                                                              "metallicRoughnessTexture": {"index": 2}},
                       "normalTexture": {"index": 1}, "occlusionTexture": {"index": 2}}],
        "textures": [{"source": i, "sampler": 0} for i in range(3)],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "images": [{"bufferView": 4 + i, "mimeType": "image/png"} for i in range(3)],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": count, "type": "VEC3", "min": positions.min(axis=0).tolist(), "max": positions.max(axis=0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": count, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": count, "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123 if small else 5125, "count": len(index), "type": "SCALAR"},
        ],
        "bufferViews": views, "buffers": [{"byteLength": len(binary)}],
    }
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    shrink_textures.write_glb(path, document, binary)


def convert(source, args, warn):
    """Runs the steps on a .gltf/.glb path. Returns (stats dict, output path)."""
    gltf = Gltf(source)
    parts = load_parts(gltf, warn, args.keep_blend)
    if not parts:
        raise SystemExit("%s has no triangle meshes" % source)
    materials = {p["material"] for p in parts}
    source_faces = int(sum(len(p["triangles"]) for p in parts))
    # The size tier needs the model's size, which the node transforms decide
    every = np.concatenate([p["positions"] for p in parts])
    size = every.max(axis=0) - every.min(axis=0)
    longest = float(size.max()) * ((args.meters / float(size.max())) if args.meters else 1.0)
    edge = args.texture_edge or shrink_textures.texture_edge(longest)
    maps = merge_materials(gltf, parts, edge, warn)
    positions, normals, uvs, triangles = merge_parts(parts)
    merged_faces = len(triangles)
    positions, normals, uvs, triangles = decimate(positions, normals, uvs, triangles, args.faces)
    if args.faces and len(triangles) > args.faces:
        warn("the reduction stopped at %d triangles, above the %d asked for (every remaining collapse would flip or tear a face)" % (len(triangles), args.faces))
    positions = stand_on_origin(positions, args.meters)
    normals = recompute_normals(positions, normals, triangles)
    write_glb(args.out, positions, normals, uvs, triangles, maps, args.name)
    stats = {"source_meshes": len(parts), "source_materials": len(materials), "source_faces": source_faces, "merged_faces": merged_faces,
             "faces": int(len(triangles)), "vertices": int(len(positions)), "texture_edge": edge,
             "texture_px": [int(maps[0].shape[1]), int(maps[0].shape[0])], "size_m": [round(float(v), 4) for v in positions.max(axis=0) - positions.min(axis=0)]}
    return stats


def recompute_normals(positions, normals, triangles):
    """Keeps the model's own normals, except where reduction left one facing away from its triangles (it is replaced by the area-weighted face average)."""
    smooth = vertex_normals(positions, triangles)
    length = np.linalg.norm(smooth, axis=1, keepdims=True)
    smooth = smooth / np.where(length == 0, 1, length)
    flipped = (normals * smooth).sum(axis=1) < 0
    normals = np.where(flipped[:, None], smooth, normals)
    length = np.linalg.norm(normals, axis=1, keepdims=True)
    return normals / np.where(length == 0, 1, length)


# --- Provenance --------------------------------------------------------------------------------


def write_record(args, source, stats, warnings, root=provenance.ROOT):
    asset = os.path.relpath(os.path.abspath(args.out), root).replace(os.sep, "/")
    if not asset.startswith("assets/"):
        print("provenance not written: %s is not under assets/" % args.out, file=sys.stderr)
        return None
    stage = {"step": "convert", "tool": "polyhaven_prop.py", "date": provenance.today(),
             "versions": {"python": sys.version.split()[0], "numpy": np.__version__, "Pillow": module_version("Pillow")},
             "script": "polyhaven_prop.py", "max_faces": args.faces, "meters": args.meters, "texture_edge": stats["texture_edge"],
             "source_meshes": stats["source_meshes"], "source_materials": stats["source_materials"], "source_faces": stats["source_faces"],
             "faces": stats["faces"], "vertices": stats["vertices"], "warnings": list(warnings),
             "output_sha256": provenance.sha256(args.out)}
    record = provenance.new_record("polyhaven_prop", asset, "pipeline", name=args.name, source=source, license=source["license"],
                                   authors=source["authors"], stages=[stage])
    path = provenance.record_path("polyhaven_prop", asset, root)
    provenance.save(path, record)
    return path


def module_version(name):
    return provenance.module_version(name)


def ledger_row(asset, source, stats, meters):
    """A suggested ASSETS.md row for the prop (the file is not edited)."""
    authors = ", ".join(source["authors"]) or "Poly Haven"
    notes = "%d to %d faces, one material, textures at %d px (`polyhaven_prop.py`)" % (stats["source_faces"], stats["faces"], stats["texture_edge"])
    return "| `%s` | [Poly Haven: %s](%s) | %s | CC0 | %s |" % (asset, source["polyhaven_asset"], source["page"], authors, notes)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("model", help="a Poly Haven asset name, or a .gltf/.glb file")
    parser.add_argument("--res", default="1k")
    parser.add_argument("--faces", type=int, default=DEFAULT_FACES)
    parser.add_argument("--meters", type=float)
    parser.add_argument("--out")
    parser.add_argument("--name")
    parser.add_argument("--work")
    parser.add_argument("--provenance", action="store_true")
    parser.add_argument("--author")
    parser.add_argument("--source-url")
    parser.add_argument("--texture-edge", type=int)
    parser.add_argument("--keep-blend", action="store_true")
    args = parser.parse_args(argv)
    warnings = Warnings()
    local = os.path.exists(args.model)
    if local:
        source_path = args.model
        args.name = args.name or os.path.splitext(os.path.basename(args.model))[0]
        authors = [a.strip() for a in (args.author or "").split(",") if a.strip()]
        source = {"page": args.source_url, "polyhaven_asset": args.name, "resolution": None, "license": LICENSE, "license_url": LICENSE_URL,
                  "authors": authors, "title": None, "polycount": None, "files": [{"file": os.path.basename(args.model), "url": args.source_url,
                                                                                  "bytes": os.path.getsize(args.model), "sha256": provenance.sha256(args.model)}]}
        if args.provenance and not (args.author and args.source_url):
            raise SystemExit("--provenance with a local file needs --author and --source-url, which a file does not say")
    else:
        args.name = args.name or args.model
        folder = args.work or tempfile.mkdtemp(prefix="polyhaven_")
        os.makedirs(folder, exist_ok=True)
        source_path, source = download(args.model, args.res, folder)
    args.out = args.out or os.path.join(provenance.ROOT, "assets", "props", args.name + ".glb")
    stats = convert(source_path, args, warnings)
    print("%s: %d meshes, %d materials, %d faces -> %d faces, %d vertices, textures %d px, %s m"
          % (args.name, stats["source_meshes"], stats["source_materials"], stats["source_faces"], stats["faces"], stats["vertices"],
             stats["texture_edge"], " x ".join("%.3f" % v for v in stats["size_m"])))
    if args.provenance:
        print("wrote " + write_record(args, source, stats, warnings))
    asset = os.path.relpath(os.path.abspath(args.out), provenance.ROOT).replace(os.sep, "/")
    print(ledger_row(asset, source, stats, args.meters))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
