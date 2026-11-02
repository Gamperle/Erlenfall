#!/usr/bin/env python3
"""Builds the interface textures in assets/ui from the game's CC0 surface photos.

Run from the repository root: python3 tools/ui_pipeline/build_ui_textures.py
Needs numpy and Pillow. The output is the same on every run.

Each surface repeats, and the frames are built so that the middle and the edges of a
nine-patch tile without seams. assets/ui/erlenfall_theme.tres sets those margins, so
change both together.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SOURCE = Path("assets/textures")
OUTPUT = Path("assets/ui")

CREAM = (235, 222, 190)
AMBER = (240, 170, 70)


def tile(name, size, brightness=1.0, rotate=False):
    """Loads a repeating photo as an RGB array of floats from 0 to 1."""
    image = Image.open(SOURCE / name).convert("RGB").resize((size, size), Image.LANCZOS)
    if rotate:
        image = image.rotate(90)
    return np.asarray(image, dtype=np.float32) / 255.0 * brightness


def wrap(surface, width, height, margin):
    """Repeats a surface so that a nine-patch's middle starts on a whole tile."""
    size = surface.shape[0]
    ys = (np.arange(height) - margin) % size
    xs = (np.arange(width) - margin) % size
    return surface[np.ix_(ys, xs)]


def edge_distance(width, height):
    """Returns each pixel's distance from the nearest edge of the image."""
    ys, xs = np.mgrid[0:height, 0:width]
    return np.minimum.reduce([xs, ys, width - 1 - xs, height - 1 - ys]).astype(np.float32)


def rounded_alpha(width, height, radius):
    """Returns a mask with rounded outer corners, smoothed by drawing it at 4x."""
    mask = Image.new("L", (width * 4, height * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width * 4 - 1, height * 4 - 1), radius * 4, fill=255)
    return np.asarray(mask.resize((width, height), Image.LANCZOS), dtype=np.float32) / 255.0


def blur(values, radius):
    image = Image.fromarray(np.uint8(np.clip(values, 0.0, 1.0) * 255.0), "L")
    return np.asarray(image.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255.0


def lit(height_map, strength):
    """Turns a height map into shading, lit from the top left."""
    grad_y, grad_x = np.gradient(height_map)
    return np.clip(1.0 - strength * (grad_x + grad_y), 0.35, 1.8)[..., None]


def dots(width, height, centers, radius):
    """Returns a domed mask with a rivet at each center."""
    ys, xs = np.mgrid[0:height, 0:width]
    result = np.zeros((height, width), dtype=np.float32)
    for cx, cy in centers:
        distance = np.hypot(xs - cx, ys - cy) / radius
        result = np.maximum(result, np.clip(1.0 - distance * distance, 0.0, 1.0))
    return result


def iron_surface(size):
    """Dark iron with some rust showing through."""
    rust = tile("iron_ore_2.jpg", size)
    rust_grey = rust.mean(axis=2, keepdims=True)
    return rust_grey * 0.42 * np.array([0.92, 0.95, 1.0]) + rust * 0.07


def save(name, rgb, alpha=None):
    alpha = np.ones(rgb.shape[:2], dtype=np.float32) if alpha is None else alpha
    rgba = np.dstack((np.clip(rgb, 0.0, 1.0), np.clip(alpha, 0.0, 1.0)))
    Image.fromarray(np.uint8(rgba * 255.0 + 0.5), "RGBA").save(OUTPUT / name, optimize=True)


def corner_brackets(size, length, arm):
    """Returns a mask of an iron bracket with a pointed end in each corner."""
    bracket = Image.new("L", (size * 4, size * 4), 0)
    draw = ImageDraw.Draw(bracket)
    scaled = [length * 4, arm * 4]
    draw.polygon([
        (0, 0), (scaled[0], 0), (scaled[0] - scaled[1] // 2, scaled[1] // 2), (scaled[0], scaled[1]),
        (scaled[1], scaled[1]), (scaled[1], scaled[0]), (scaled[1] // 2, scaled[0] - scaled[1] // 2), (0, scaled[0]),
    ], fill=255)
    return np.asarray(bracket.resize((size, size), Image.LANCZOS), dtype=np.float32) / 255.0


def build_panel():
    """Dark oak boards in an iron frame. Margin 40, then a 256 pixel tile."""
    margin, middle = 40, 256
    size = margin * 2 + middle
    wood = wrap(tile("wood_2.jpg", middle, 0.62, rotate=True), size, size, margin)
    iron = wrap(iron_surface(middle), size, size, margin)
    distance = edge_distance(size, size)

    band = np.clip(11.0 - distance, 0.0, 1.0)
    bracket = corner_brackets(margin, 38, 18)
    brackets = np.zeros((size, size), dtype=np.float32)
    brackets[:margin, :margin] = bracket
    brackets[:margin, -margin:] = bracket[:, ::-1]
    brackets[-margin:, :margin] = bracket[::-1, :]
    brackets[-margin:, -margin:] = bracket[::-1, ::-1]
    metal = np.maximum(band, brackets)

    # Rivets repeat with the tile along the frame, and two more hold each bracket.
    along = [margin + 32 + 64 * i for i in range(4)]
    rivets = [(x, 5.5) for x in along] + [(x, size - 6.5) for x in along]
    rivets += [(5.5, y) for y in along] + [(size - 6.5, y) for y in along]
    for x in (9, size - 10):
        for y in (9, size - 10):
            rivets.append((x, y))
    rivet = dots(size, size, rivets, 3.5)

    shadow = 1.0 - 0.6 * np.clip(1.0 - (distance - 11.0) / 18.0, 0.0, 1.0) ** 2
    shadow = np.where(distance >= margin, 1.0, shadow)[..., None]
    height = blur(metal, 1.0) * 5.0 + rivet * 3.0
    shading = lit(height, 0.5)
    mask = metal[..., None]
    rgb = wood * shadow * (1.0 - mask) + iron * mask * shading
    save("panel.png", rgb, rounded_alpha(size, size, 5))


def build_parchment():
    """Aged paper for written text, with darker edges. Margin 20, then a 256 pixel tile."""
    margin, middle = 20, 256
    size = margin * 2 + middle
    plaster = tile("plaster.jpg", middle)
    detail = plaster.mean(axis=2, keepdims=True)
    detail = 1.0 + (detail - detail.mean()) * 1.1
    paper = detail * np.array([0.86, 0.78, 0.60])
    rgb = wrap(paper, size, size, margin)
    distance = edge_distance(size, size)
    burn = np.clip(distance / margin, 0.0, 1.0) ** 0.6
    rgb = rgb * (0.45 + 0.55 * burn)[..., None]
    save("parchment.png", rgb, rounded_alpha(size, size, 3))


def build_buttons():
    """Worn planks with a bevel. Margin 10, then a 128 pixel tile."""
    margin, middle = 10, 128
    size = margin * 2 + middle
    wood = wrap(tile("wood_2.jpg", middle, 1.05, rotate=True), size, size, margin)
    wood = wood * np.array([1.08, 1.0, 0.9])
    distance = edge_distance(size, size)
    rim = np.clip(distance / 4.0, 0.0, 1.0)
    nails = dots(size, size, [(5.5, 5.5), (size - 6.5, 5.5), (5.5, size - 6.5), (size - 6.5, size - 6.5)], 2.5)
    alpha = rounded_alpha(size, size, 3)

    raised = lit(rim * 4.0, 0.25) * (0.55 + 0.45 * rim)[..., None] * lit(nails * 2.0, 0.6)
    sunken = lit(rim * -4.0, 0.25) * (0.5 + 0.5 * rim)[..., None]
    grey = wood.mean(axis=2, keepdims=True)
    save("button_normal.png", wood * raised, alpha)
    save("button_hover.png", (wood * 1.3 + np.array([0.05, 0.03, 0.0])) * raised, alpha)
    save("button_pressed.png", wood * 0.68 * sunken, alpha)
    save("button_disabled.png", (grey * 0.55 + wood * 0.15) * (0.6 + 0.4 * rim)[..., None], alpha * 0.8)

    ring = np.clip(1.0 - np.abs(distance - 2.0) / 2.0, 0.0, 1.0)
    glow = np.clip(1.0 - distance / 8.0, 0.0, 1.0) * 0.35
    color = np.ones((size, size, 3), dtype=np.float32) * np.array(AMBER) / 255.0
    save("button_focus.png", color, np.maximum(ring, glow) * alpha)


def build_bars():
    """An iron trough, and a pale fill that the theme tints. Margins 8 and 2, 64 pixel tiles."""
    margin, middle = 8, 64
    width, height = margin * 2 + middle, margin * 2 + 8
    iron = wrap(iron_surface(middle), width, height, margin) * 1.2
    distance = edge_distance(width, height)
    rim = np.clip(4.0 - distance, 0.0, 1.0)
    trough = np.array([0.06, 0.05, 0.045]) * np.ones((height, width, 3), dtype=np.float32)
    shading = lit(blur(rim, 0.8) * 3.0, 0.5)
    rgb = iron * rim[..., None] * shading + trough * (1.0 - rim[..., None])
    save("bar_trough.png", rgb, rounded_alpha(width, height, 3))

    fill_height = 20
    grain = wrap(tile("wood_2.jpg", 64, rotate=True), 64, fill_height, 0).mean(axis=2)
    grain = 1.0 + (grain - grain.mean()) * 0.5
    rows = np.linspace(0.0, 1.0, fill_height)[:, None]
    gradient = 0.68 + 0.32 * np.exp(-((rows - 0.3) / 0.28) ** 2)
    value = (grain * gradient)[..., None]
    save("bar_fill.png", value * np.ones((fill_height, 64, 3), dtype=np.float32))


def build_small_parts():
    """Slider stud, scrollbar, drop-down arrow, and the divider under titles."""
    size = 24
    iron = wrap(iron_surface(64), size, size, 0) * 1.3
    stud = dots(size, size, [(11.5, 11.5)], 11.5)
    shape = np.clip(stud * 12.0, 0.0, 1.0)
    shading = lit(stud * 9.0, 0.32)
    save("grabber.png", iron * shading, shape)
    save("grabber_hover.png", (iron * 1.35 + np.array([0.08, 0.05, 0.0])) * shading, shape)

    width, height = 16, 32
    iron = wrap(iron_surface(64), width, height, 0) * 1.5
    edge = np.clip(edge_distance(width, height) / 3.0, 0.0, 1.0)
    save("scroll_grabber.png", iron * lit(edge * 3.0, 0.3), rounded_alpha(width, height, 4))

    scale = 4
    arrow = Image.new("L", (16 * scale, 16 * scale), 0)
    ImageDraw.Draw(arrow).polygon([(2 * scale, 5 * scale), (14 * scale, 5 * scale), (8 * scale, 12 * scale)], fill=255)
    arrow_alpha = np.asarray(arrow.resize((16, 16), Image.LANCZOS), dtype=np.float32) / 255.0
    save("arrow_down.png", np.ones((16, 16, 3), dtype=np.float32) * np.array(CREAM) / 255.0, arrow_alpha)

    width, height = 256, 10
    xs = np.abs(np.linspace(-1.0, 1.0, width))
    line = np.clip((1.0 - xs) * 3.0, 0.0, 1.0)[None, :] * np.clip(1.5 - np.abs(np.arange(height)[:, None] - 4.5), 0.0, 1.0)
    ys, pixels = np.mgrid[0:height, 0:width]
    diamond = np.clip(5.0 - (np.abs(pixels - 127.5) + np.abs(ys - 4.5)), 0.0, 1.0)
    color = np.ones((height, width, 3), dtype=np.float32) * np.array(AMBER) / 255.0
    save("divider.png", color * 0.9, np.maximum(line * 0.8, diamond))


def build_hud_parts():
    """Dark leather: a strip for the compass (margins 12 and 6) and a soft plate behind HUD text."""
    middle = 128
    leather_tile = tile("iron_ore_2.jpg", middle)
    leather = leather_tile * np.array([0.34, 0.32, 0.3])
    margin_x, margin_y = 12, 6
    width, height = margin_x * 2 + middle, margin_y * 2 + middle
    ys = (np.arange(height) - margin_y) % middle
    xs = (np.arange(width) - margin_x) % middle
    rgb = leather[np.ix_(ys, xs)]
    iron = iron_surface(middle)[np.ix_(ys, xs)]

    caps = np.zeros((height, width), dtype=np.float32)
    caps[:, :9] = 1.0
    caps[:, -9:] = 1.0
    rows = np.minimum(np.arange(height), height - 1 - np.arange(height))
    edge = np.clip(2.0 - rows, 0.0, 1.0)[:, None] * np.ones((height, width), dtype=np.float32)
    metal = np.maximum(caps, edge)
    shading = lit(blur(metal, 0.7) * 3.0, 0.5)
    rgb = rgb * (1.0 - metal[..., None]) + iron * 1.2 * metal[..., None] * shading
    save("compass_strip.png", rgb, rounded_alpha(width, height, 3) * 0.94)

    margin, middle = 16, 32
    size = margin * 2 + middle
    alpha = np.clip(edge_distance(size, size) / margin, 0.0, 1.0) ** 0.8 * 0.62
    color = np.ones((size, size, 3), dtype=np.float32) * np.array([0.07, 0.055, 0.045])
    save("hud_plate.png", color, alpha)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    build_panel()
    build_parchment()
    build_buttons()
    build_bars()
    build_small_parts()
    build_hud_parts()


if __name__ == "__main__":
    main()
