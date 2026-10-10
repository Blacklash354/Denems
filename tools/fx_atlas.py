#!/usr/bin/env python3
"""Builds the particle sprite atlases in assets/fx/ from Kenney's CC0 packs.

    python3 tools/fx_atlas.py <kenney smoke particles dir> <kenney particle pack dir> assets/fx

smoke.png (6 x 5 cells of 64 px, alpha blended, tinted per particle):
    0-24  "White puff" 00-24 - a puff of smoke growing and thinning out, played over a particle's life
    25-27 dirt 01-03       - clods of earth and snow thrown up by a blast
    28-29 smoke 01-02      - soft round smoke
fire.png (4 x 4 cells of 64 px, additive):
    0-8   "Explosion" 00-08 - a fireball, played over its life
    9-12  muzzle 01, 02, 03, 05 - star-shaped muzzle flashes (white, tinted per particle)
    13-14 "Flash" 00, 04   - bright fiery cores for cannon blasts and flames
    15    a soft round glow (sparks, tracers, lamps)
Every sprite is shrunk to 48 px inside its 64 px cell: blocky like the console, and the margin stops
neighbouring cells bleeding into each other.
"""
import math
import os
import sys

from PIL import Image

CELL, FIT = 64, 48


def fit(path, mode="rgba"):
    im = Image.open(path).convert("RGBA")
    if mode == "grey":
        # particle pack: grey brightness in the colour, coverage in alpha -> white sprite with alpha
        r, g, b, a = im.split()
        lum = Image.merge("RGB", (r, g, b)).convert("L")
        a = Image.composite(a, Image.new("L", im.size, 0), lum)
        top = a.getextrema()[1] or 1
        a = a.point(lambda v: min(255, int(v * 255 / top)))           # the pack's sprites are dim: use the full range
        im = Image.merge("RGBA", (Image.new("L", im.size, 255),) * 3 + (a,))
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    w, h = im.size
    s = FIT / max(w, h)
    im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.paste(im, ((CELL - im.size[0]) // 2, (CELL - im.size[1]) // 2), im)
    return cell


def glow():
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = cell.load()
    for y in range(CELL):
        for x in range(CELL):
            d = math.hypot(x + 0.5 - CELL / 2, y + 0.5 - CELL / 2) / (FIT / 2)
            a = max(0.0, 1 - d) ** 2
            px[x, y] = (255, 255, 255, int(a * 255))
    return cell


def atlas(cells, cols, rows):
    out = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        out.paste(c, ((i % cols) * CELL, (i // cols) * CELL))
    return out


def main():
    smoke_dir, pack_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out_dir, exist_ok=True)
    P = lambda *p: os.path.join(smoke_dir, "PNG", *p)
    K = lambda n: os.path.join(pack_dir, n)
    smoke = [fit(P("White puff", "whitePuff%02d.png" % i)) for i in range(25)]
    smoke += [fit(K("dirt_%02d.png" % i), "grey") for i in (1, 2, 3)]
    smoke += [fit(K("smoke_%02d.png" % i), "grey") for i in (1, 2)]
    atlas(smoke, 6, 5).save(os.path.join(out_dir, "smoke.png"))
    fire = [fit(P("Explosion", "explosion%02d.png" % i)) for i in range(9)]
    fire += [fit(K("muzzle_%02d.png" % i), "grey") for i in (1, 2, 3, 5)]
    fire += [fit(P("Flash", "flash%02d.png" % i)) for i in (0, 4)]
    fire.append(glow())
    atlas(fire, 4, 4).save(os.path.join(out_dir, "fire.png"))
    print("wrote", os.path.join(out_dir, "smoke.png"), os.path.join(out_dir, "fire.png"))


if __name__ == "__main__":
    main()
