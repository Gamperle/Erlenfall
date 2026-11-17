#!/usr/bin/env python3
"""Shrinks the embedded textures of prop GLBs by the prop's size (#426).

TRELLIS.2 and TripoSR bake every prop's textures (color, normal, roughness/occlusion) at 1024 x 1024, even for
a bowl that is never seen larger than a few hundred pixels. This is the size rule, run after sizing:

    longest side of the model's bounding box <= SMALL_MAX_METERS (1.25 m)  ->  textures at SMALL_EDGE (512 px)
    larger                                                                 ->  textures at LARGE_EDGE (1024 px)

The bounding box is the sized model's, in meters, so the rule needs size_glb.py to have run first. A texture
is only ever shrunk, never enlarged, so running the script again changes nothing. The mesh, its single
material, and its placement on the ground are not touched: only the PNG bytes inside the GLB and the buffer
offsets that follow them are rewritten. Normal maps are renormalized after shrinking.

Needs Pillow and the standard library only (no Blender), so it runs on any machine.

Usage, from the repository root:
  shrink_textures.py [--apply] [--ledger] [--records] [--provenance FOLDER] [--check] [FILE.glb ...]

  Without --apply it only reports what would change. Without files it takes every assets/props/*.glb.
  --apply     rewrites the GLBs
  --records   also adds a "textures" stage to each changed prop's provenance record (provenance.py)
  --provenance FOLDER  adds that stage to FOLDER/<name>.json instead, like size_glb.py (the asset PC's batch folder)
  --ledger    also adds a note to each changed prop's ASSETS.md row
  --check     changes nothing and exits 1 if a prop's textures are larger than its size tier (#445). Needs no
              Pillow. `provenance.py validate` runs the same check.
"""
import glob
import io
import json
import math
import os
import struct
import sys

try:
    from PIL import Image
except ImportError:  # --check and provenance.py validate read PNG headers only
    Image = None

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import provenance  # noqa: E402

ROOT = provenance.ROOT
SMALL_MAX_METERS = 1.25
SMALL_EDGE = 512
LARGE_EDGE = 1024
LEDGER_NOTE = "textures downscaled to %d px by `shrink_textures.py` (#426)"


def texture_edge(longest_meters):
    """The texture edge in pixels for a model whose longest side is this many meters."""
    return SMALL_EDGE if longest_meters <= SMALL_MAX_METERS + 1e-6 else LARGE_EDGE


def read_glb(path):
    with open(path, "rb") as file:
        data = file.read()
    if data[:4] != b"glTF":
        raise ValueError("%s is not a GLB (a Git LFS pointer? run git lfs pull)" % path)
    json_length = struct.unpack("<I", data[12:16])[0]
    document = json.loads(data[20:20 + json_length])
    bin_start = 20 + json_length + 8
    bin_length = struct.unpack("<I", data[20 + json_length:24 + json_length])[0]
    return document, data[bin_start:bin_start + bin_length]


def write_glb(path, document, binary):
    text = json.dumps(document, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    with open(path, "wb") as file:
        file.write(b"glTF" + struct.pack("<II", 2, total))
        file.write(struct.pack("<I", len(text)) + b"JSON" + text)
        file.write(struct.pack("<I", len(binary)) + b"BIN\0" + binary)


def png_size(raw):
    """(width, height) from a PNG's header, without Pillow."""
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    return struct.unpack(">II", raw[16:24])


def check_file(path):
    """Problems for one GLB whose embedded textures are above its size tier (none when fine). A file that is
    not a real GLB (a Git LFS pointer in a checkout without LFS) is skipped."""
    try:
        document, binary = read_glb(path)
    except ValueError:
        return []
    edge = texture_edge(max(bounding_size(document)))
    problems = []
    for index, image in enumerate(document.get("images", [])):
        view = document["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        size = png_size(binary[start:start + 24])
        if max(size) > edge:
            problems.append("%s: texture %d is %d x %d px, above the %d px its size allows (run shrink_textures.py --apply)"
                            % (os.path.basename(path), index, size[0], size[1], edge))
    return problems


def check_props(root=ROOT):
    """Problems for every assets/props/*.glb under root."""
    problems = []
    for path in sorted(glob.glob(os.path.join(root, "assets", "props", "*.glb"))):
        problems += check_file(path)
    return problems


def _matrix(node):
    """A node's local transform as a row-major 4x4 list, from matrix or translation/rotation/scale."""
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    tx, ty, tz = node.get("translation", [0, 0, 0])
    rot = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    scales = (sx, sy, sz)
    return [[rot[r][c] * scales[c] for c in range(3)] + [t] for r, t in zip(range(3), (tx, ty, tz))] + [[0, 0, 0, 1]]


def _multiply(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def bounding_size(document):
    """The model's bounding box size in meters (x, y, z), from the mesh accessors and the node transforms."""
    nodes = document.get("nodes", [])
    low = [math.inf] * 3
    high = [-math.inf] * 3

    def visit(index, parent):
        node = nodes[index]
        world = _multiply(parent, _matrix(node))
        if "mesh" in node:
            for primitive in document["meshes"][node["mesh"]]["primitives"]:
                accessor = document["accessors"][primitive["attributes"]["POSITION"]]
                for corner in range(8):
                    point = [accessor["max"][i] if corner >> i & 1 else accessor["min"][i] for i in range(3)]
                    for axis in range(3):
                        value = sum(world[axis][i] * point[i] for i in range(3)) + world[axis][3]
                        low[axis] = min(low[axis], value)
                        high[axis] = max(high[axis], value)
        for child in node.get("children", []):
            visit(child, world)

    identity = [[1 if r == c else 0 for c in range(4)] for r in range(4)]
    scene = document["scenes"][document.get("scene", 0)]
    for root in scene["nodes"]:
        visit(root, identity)
    return [h - l for h, l in zip(high, low)]


def normal_images(document):
    """Indices of images used as a normal map."""
    found = set()
    for material in document.get("materials", []):
        texture = material.get("normalTexture")
        if texture is not None:
            source = document["textures"][texture["index"]].get("source")
            if source is not None:
                found.add(source)
    return found


def _shrink(image, edge, is_normal):
    resized = image.resize((edge, edge), Image.LANCZOS) if image.size[0] == image.size[1] else image.resize(
        (max(1, round(image.size[0] * edge / max(image.size))), max(1, round(image.size[1] * edge / max(image.size)))),
        Image.LANCZOS)
    if is_normal and resized.mode in ("RGB", "RGBA"):
        import numpy

        pixels = numpy.asarray(resized).astype("float32")
        vector = pixels[..., :3] / 127.5 - 1.0
        length = numpy.maximum(numpy.sqrt((vector ** 2).sum(axis=-1, keepdims=True)), 1e-6)
        pixels[..., :3] = numpy.clip((vector / length + 1.0) * 127.5 + 0.5, 0, 255)
        resized = Image.fromarray(pixels.astype("uint8"), resized.mode)
    return resized


def shrink_file(path, apply=False):
    """Returns a report dict for one GLB, rewriting it when apply is set and a texture is above the rule."""
    document, binary = read_glb(path)
    size = bounding_size(document)
    longest = max(size)
    edge = texture_edge(longest)
    views = document["bufferViews"]
    normals = normal_images(document)
    new_bytes = {}
    before = after = 0
    for index, image in enumerate(document.get("images", [])):
        view = views[image["bufferView"]]
        raw = binary[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        picture = Image.open(io.BytesIO(raw))
        picture.load()
        before += picture.size[0] * picture.size[1]
        if max(picture.size) > edge:
            picture = _shrink(picture, edge, index in normals)
            out = io.BytesIO()
            if apply:
                picture.save(out, "PNG", optimize=True)
            new_bytes[image["bufferView"]] = out.getvalue()
        after += picture.size[0] * picture.size[1]
    report = {"path": path, "longest": longest, "edge": edge, "textures": len(document.get("images", [])),
              "changed": bool(new_bytes), "pixels_before": before, "pixels_after": after,
              "bytes_before": os.path.getsize(path)}
    if new_bytes and apply:
        chunks = []
        position = 0
        for number in sorted(range(len(views)), key=lambda i: views[i].get("byteOffset", 0)):
            view = views[number]
            start = view.get("byteOffset", 0)
            data = new_bytes.get(number, binary[start:start + view["byteLength"]])
            chunks.append(b"\0" * (-position % 4))
            position += -position % 4
            view["byteOffset"] = position
            view["byteLength"] = len(data)
            chunks.append(data)
            position += len(data)
        merged = b"".join(chunks)
        document["buffers"][0]["byteLength"] = len(merged) + (-len(merged) % 4)
        write_glb(path, document, merged)
    report["bytes_after"] = os.path.getsize(path)
    return report


def vram_bytes(pixels):
    """Estimated video memory, assuming 1 byte per pixel block compression (BC7) and a full mipmap chain."""
    return pixels * 4 // 3


def add_record_stage(report, folder=None):
    name = os.path.splitext(os.path.basename(report["path"]))[0]
    record_file = os.path.join(folder, name + ".json") if folder else provenance.record_path(
        "ai_prop", "assets/props/%s.glb" % name)
    if not folder and not os.path.exists(record_file):
        print("no provenance record for %s" % name)
        return
    import PIL

    provenance.add_stage(record_file, {
        "step": "textures", "tool": "shrink_textures.py", "script": "shrink_textures.py",
        "versions": {"Pillow": PIL.__version__}, "date": provenance.today(),
        "longest_side_meters": round(report["longest"], 3), "texture_edge": report["edge"], "from_edge": 1024,
        "rule": "%d px up to %g m longest side, else %d px" % (SMALL_EDGE, SMALL_MAX_METERS, LARGE_EDGE),
        "note": "Downscaled with Lanczos; normal maps renormalized (#426)"})


def add_ledger_note(report, text):
    name = os.path.basename(report["path"])
    lines = text.split("\n")
    note = LEDGER_NOTE % report["edge"]
    for number, line in enumerate(lines):
        if line.startswith("| `assets/props/%s` |" % name):
            if "downscaled" not in line:
                lines[number] = line[:-2].rstrip() + "; " + note + " |" if line.endswith(" |") else line
            break
    else:
        print("no ASSETS.md row for %s" % name)
    return "\n".join(lines)


def main(argv):
    argv = list(argv)
    folder = None
    if "--provenance" in argv:
        at = argv.index("--provenance")
        folder = argv[at + 1]
        del argv[at:at + 2]
    flags = [a for a in argv if a.startswith("--")]
    if "--check" in flags:
        paths = [a for a in argv if not a.startswith("--")]
        problems = [p for path in paths for p in check_file(path)] if paths else check_props()
        for problem in problems:
            print(problem)
        print("textures: %d problems" % len(problems) if problems else "textures: ok")
        return 1 if problems else 0
    if Image is None:
        print("Pillow is needed: pip install pillow numpy")
        return 1
    files = [a for a in argv if not a.startswith("--")] or sorted(glob.glob(os.path.join(ROOT, "assets", "props", "*.glb")))
    apply = "--apply" in flags
    ledger_path = os.path.join(ROOT, "ASSETS.md")
    ledger = provenance.read_text(ledger_path) if "--ledger" in flags else ""
    totals = [0, 0, 0, 0]
    for path in files:
        report = shrink_file(path, apply)
        totals[0] += vram_bytes(report["pixels_before"])
        totals[1] += vram_bytes(report["pixels_after"])
        totals[2] += report["bytes_before"]
        totals[3] += report["bytes_after"]
        print("%-34s %.2f m  -> %4d px  %s" % (os.path.basename(path), report["longest"], report["edge"],
                                               "changed" if report["changed"] else "ok"))
        if apply and report["changed"]:
            if "--records" in flags or folder:
                add_record_stage(report, folder)
            if "--ledger" in flags:
                ledger = add_ledger_note(report, ledger)
    if apply and "--ledger" in flags:
        with open(ledger_path, "w", encoding="utf-8", newline="\n") as file:
            file.write(ledger)
    print("estimated texture memory (BC7 + mipmaps): %.1f MB -> %.1f MB" % (totals[0] / 1e6, totals[1] / 1e6))
    print("GLB files on disk: %.1f MB -> %.1f MB" % (totals[2] / 1e6, totals[3] / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
