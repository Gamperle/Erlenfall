"""Smooths the shading of the goblin and matches its material to the villagers', without Blender.

The OpenGameArt goblin exports with one flat normal per triangle corner, so it looks faceted next to the
villagers' smooth bodies. This averages the normals of triangles that meet at a point and bend by less than
the angle limit, keeps harder edges (belt, teeth, nails) sharp, and sets a matte, non-metal material as in
docs/ART_STYLE.md. It only rewrites the NORMAL data and two material numbers, so the mesh, skin and
palette texture stay as they were. Run it on the output of build_goblin.py, with plain Python:

python3 smooth_goblin.py <goblin.glb> [angle in degrees, default 60]
"""
import json
import math
import struct
import sys
from collections import defaultdict

ROUGHNESS = 0.85


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def unit(a):
    length = math.sqrt(dot(a, a))
    return (a[0] / length, a[1] / length, a[2] / length) if length > 1e-12 else (0.0, 1.0, 0.0)


def main():
    path = sys.argv[1]
    limit = math.cos(math.radians(float(sys.argv[2]) if len(sys.argv) > 2 else 60.0))
    data = bytearray(open(path, "rb").read())
    json_length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + json_length])
    binary_start = 20 + json_length + 8
    primitive = document["meshes"][0]["primitives"][0]

    def view(index):
        accessor = document["accessors"][index]
        buffer_view = document["bufferViews"][accessor["bufferView"]]
        return binary_start + buffer_view.get("byteOffset", 0) + accessor.get("byteOffset", 0), accessor["count"]

    position_start, count = view(primitive["attributes"]["POSITION"])
    normal_start, _ = view(primitive["attributes"]["NORMAL"])
    index_start, index_count = view(primitive["indices"])
    positions = [struct.unpack_from("<3f", data, position_start + 12 * i) for i in range(count)]
    code = document["accessors"][primitive["indices"]]["componentType"]
    letter, size = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}[code]
    indices = [struct.unpack_from("<" + letter, data, index_start + size * i)[0] for i in range(index_count)]

    # Area-weighted face normals, grouped by the point they touch.
    at_point = defaultdict(list)
    face_of_corner = {}
    for face in range(index_count // 3):
        a, b, c = indices[3 * face:3 * face + 3]
        normal = cross(sub(positions[b], positions[a]), sub(positions[c], positions[a]))
        for corner in (a, b, c):
            at_point[tuple(round(x, 4) for x in positions[corner])].append((unit(normal), normal))
            face_of_corner[corner] = unit(normal)

    smoothed = 0
    for vertex in range(count):
        own = face_of_corner.get(vertex)
        if own is None:
            continue
        total = (0.0, 0.0, 0.0)
        for direction, weighted in at_point[tuple(round(x, 4) for x in positions[vertex])]:
            if dot(direction, own) >= limit:
                total = (total[0] + weighted[0], total[1] + weighted[1], total[2] + weighted[2])
        result = unit(total)
        if dot(result, own) < 0.9999:
            smoothed += 1
        struct.pack_into("<3f", data, normal_start + 12 * vertex, *result)

    # The binary chunk keeps its size, so only the JSON chunk's text changes (padded with spaces to the same length).
    for material in document["materials"]:
        material["pbrMetallicRoughness"]["roughnessFactor"] = ROUGHNESS
    text = json.dumps(document, separators=(",", ":")).encode()
    if len(text) > json_length:
        raise SystemExit("The JSON grew; rewrite the file with a new chunk length instead")
    data[20:20 + json_length] = text.ljust(json_length, b" ")
    open(path, "wb").write(data)
    print("smoothed %d of %d vertices at %s degrees, roughness %s" % (smoothed, count, sys.argv[2] if len(sys.argv) > 2 else "60", ROUGHNESS))


main()
