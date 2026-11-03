"""Lays pictures out in a labeled grid, for choosing candidates and reviewing previews.

Usage: python3 contact_sheet.py out.jpg columns tile_px image...
Each tile is labeled with the file name, without its extension.
"""
import os
import sys

from PIL import Image, ImageDraw

target, columns, tile = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
paths = sys.argv[4:]
LABEL = 22
rows = (len(paths) + columns - 1) // columns
# Cells take the first picture's shape, so wide screenshots don't leave gaps.
first = Image.open(paths[0])
height = tile * first.height // first.width
sheet = Image.new("RGB", (columns * tile, rows * (height + LABEL)), "white")
draw = ImageDraw.Draw(sheet)
for i, path in enumerate(paths):
    x, y = i % columns * tile, i // columns * (height + LABEL)
    image = Image.open(path).convert("RGB")
    image.thumbnail((tile, height))
    sheet.paste(image, (x + (tile - image.width) // 2, y + LABEL))
    draw.text((x + 6, y + 5), os.path.splitext(os.path.basename(path))[0], fill="black")
sheet.save(target, quality=85)
