"""Compares the u2net, BiRefNet and BEN2 masks of a run folder and writes a table and a contact sheet.

Usage: compare_masks.py run_dir [sheet_prefix]
run_dir holds input\\*.png and masks\\{u2net,birefnet,ben2}\\*.png (white = foreground), as run_masks.ps1 writes them.
Prints, per picture: the foreground share and the number of holes (background areas that do not touch the border, at 256 px) of
each model, and the intersection over union of each pair (threshold 0.5). Writes <sheet_prefix>_<n>.jpg with the picture and the
three masks side by side, 8 rows per sheet. Needs numpy and Pillow.
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

MODELS = ["u2net", "birefnet", "ben2"]
SMALL = 256


def load(path):
    return np.asarray(Image.open(path).convert("L")) > 127


def holes(mask):
    """Counts background areas, at SMALL px, that are not connected to the border (gaps between thin parts)."""
    small = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).resize((SMALL, SMALL), Image.BILINEAR)) > 127
    seen = np.zeros_like(small, dtype=bool)
    count = 0
    for y in range(SMALL):
        for x in range(SMALL):
            if small[y, x] or seen[y, x]:
                continue
            queue = deque([(y, x)])
            seen[y, x] = True
            border = False
            size = 0
            while queue:
                cy, cx = queue.popleft()
                size += 1
                if cy in (0, SMALL - 1) or cx in (0, SMALL - 1):
                    border = True
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < SMALL and 0 <= nx < SMALL and not small[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((ny, nx))
            if not border and size >= 4:
                count += 1
    return count


def iou(a, b):
    union = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / union) if union else 1.0


def main():
    run = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 else os.path.join(run, "sheet")
    names = sorted(f for f in os.listdir(os.path.join(run, "input")) if f.endswith(".png"))
    print("picture | fg% u2net/birefnet/ben2 | holes u2net/birefnet/ben2 | IoU u2-bi, u2-ben, bi-ben")
    rows = []
    for name in names:
        masks = {m: load(os.path.join(run, "masks", m, name)) for m in MODELS}
        fg = [100.0 * masks[m].mean() for m in MODELS]
        hl = [holes(masks[m]) for m in MODELS]
        io = [iou(masks["u2net"], masks["birefnet"]), iou(masks["u2net"], masks["ben2"]), iou(masks["birefnet"], masks["ben2"])]
        print(f"{name[:-4]} | {fg[0]:.1f}/{fg[1]:.1f}/{fg[2]:.1f} | {hl[0]}/{hl[1]}/{hl[2]} | {io[0]:.3f}, {io[1]:.3f}, {io[2]:.3f}")
        rows.append(name)
    cell = 256
    for sheet, start in enumerate(range(0, len(rows), 8)):
        chunk = rows[start:start + 8]
        image = Image.new("RGB", (4 * cell, len(chunk) * (cell + 14)), "white")
        draw = ImageDraw.Draw(image)
        for r, name in enumerate(chunk):
            y = r * (cell + 14)
            draw.text((2, y + 1), name[:-4] + "   (picture, u2net, birefnet, ben2)", fill="black")
            image.paste(Image.open(os.path.join(run, "input", name)).convert("RGB").resize((cell, cell)), (0, y + 14))
            for c, m in enumerate(MODELS):
                image.paste(Image.open(os.path.join(run, "masks", m, name)).convert("RGB").resize((cell, cell)), ((c + 1) * cell, y + 14))
        image.save(f"{prefix}_{sheet}.jpg", quality=85)


main()
