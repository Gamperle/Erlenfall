#!/usr/bin/env python3
"""Builds a relief map for each surface photo in assets/textures from its Poly Haven maps.

Run from the repository root: python3 tools/texture_pipeline/build_relief_maps.py
Needs numpy and Pillow. The downloads are kept in tools/texture_pipeline/downloads, which
git ignores, so a second run works offline.

Each relief map packs four of the photo's maps into one image, so a shader reads them with
one texture sample:
  red and green: the OpenGL normal map's x and y. The shader works out z.
  blue: roughness.
  alpha: ambient occlusion. The terrain shader also uses it as a rough height.
"""

import io
import json
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

OUTPUT = Path("assets/textures")
DOWNLOADS = Path("tools/texture_pipeline/downloads")
RESOLUTION = "1k"
# Poly Haven asks each tool that uses its API to name itself.
USER_AGENT = "Erlenfall texture pipeline (github.com/Gamperle/Erlenfall)"

# Each photo in assets/textures and the Poly Haven texture it came from, as listed in ASSETS.md.
SOURCES = {
    "grass": "sparse_grass",
    "rock": "rock_face",
    "snow": "snow_02",
    "rubble": "rocks_ground_02",
    "road": "stony_dirt_path",
    "plaster": "clay_plaster",
    "wood": "brown_planks_05",
    "shingles": "roof_planks",
    "stone": "rustic_stone_wall",
    "grass_lush": "leafy_grass",
    "grass_dry": "grass_path_2",
    "soil": "brown_mud_leaves_01",
    "rock_2": "rock_face_03",
    "rubble_2": "rocky_gravel",
    "snow_2": "snow_03",
    "plaster_2": "worn_mossy_plasterwall",
    "wood_2": "weathered_planks",
    "shingles_2": "roof_slates_02",
    "stone_2": "stone_wall_04",
    "road_2": "muddy_tracks",
    "iron_ore": "rock_06",
    "iron_ore_2": "rust_coarse_01",
    "iron_ore_3": "red_mud_stones",
    "coal": "dark_rock_02",
    "rock_3": "rock_05",
    "boulder": "rock_boulder_dry",
    "boulder_2": "rock_boulder_cracked",
    "plaster_3": "grey_plaster_02",
    "stone_3": "old_stone_wall",
}


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response:
        return response.read()


def download(asset, kind):
    """Returns one of an asset's maps as an image, downloading it the first time."""
    path = DOWNLOADS / asset / f"{kind}.jpg"
    if not path.exists():
        files = json.loads(fetch(f"https://api.polyhaven.com/files/{asset}"))
        data = fetch(files[kind][RESOLUTION]["jpg"]["url"])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return Image.open(io.BytesIO(path.read_bytes()))


def build(name, asset):
    size = Image.open(OUTPUT / f"{name}.jpg").size
    normal = np.asarray(download(asset, "nor_gl").convert("RGB").resize(size, Image.LANCZOS))
    # The arm map holds ambient occlusion, roughness, and metalness in red, green, and blue.
    arm = np.asarray(download(asset, "arm").convert("RGB").resize(size, Image.LANCZOS))
    packed = np.dstack([normal[:, :, 0], normal[:, :, 1], arm[:, :, 1], arm[:, :, 0]])
    Image.fromarray(packed, "RGBA").save(OUTPUT / f"{name}_relief.png", optimize=True)
    print(f"{name}_relief.png from {asset}")


def main():
    for name, asset in SOURCES.items():
        build(name, asset)


if __name__ == "__main__":
    main()
