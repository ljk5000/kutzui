"""Generates Kutz UI's own cast bar textures and the rounded-corner masks (pure Python, no packages).

    python -I make_textures.py ..\\KutzUI\\Media\\Textures

* kutz_<name>.tga   256x32 grayscale bar textures. The cast bar colour tints them, so they stay
                    fairly bright (0.55 - 1.0) and only vary in brightness.
* kutz_mask_<shape>_<aspect>.tga   white RGBA masks whose ALPHA is a rounded rectangle. The cast bar
                    uses one as a mask texture; the file is picked by the bar's width/height ratio so
                    the corners keep a roundish shape (round = corner radius 28% of the height,
                    pill = fully rounded ends).

Everything here is original (formulas, a fixed random seed): no third-party artwork.
New files need a FULL game restart before the game can see them.
"""
import math
import os
import random
import struct
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
W, H = 256, 32


def write_tga(name, w, h, rows):
    """rows: h lists of w (r, g, b, a) tuples, top row first. 32-bit uncompressed, top-left origin."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x28)
    data = bytearray()
    for row in rows:
        for r, g, b, a in row:
            data += bytes((b, g, r, a))
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(header + bytes(data))


def gray(v):
    g = max(0, min(255, int(round(v * 255))))
    return (g, g, g, 255)


def make(name, fn):
    write_tga(name, W, H, [[gray(fn(x, y)) for x in range(W)] for y in range(H)])


rnd = random.Random(20261105)
row_noise = [rnd.random() for _ in range(H)]
pix_noise = [[rnd.random() for _ in range(W)] for _ in range(H)]


def smooth_line(seed, n, step):
    r = random.Random(seed)
    pts = [r.random() for _ in range(n // step + 2)]
    out = []
    for x in range(n):
        i, f = divmod(x, step)
        t = f / step
        t = t * t * (3 - 2 * t)
        out.append(pts[i] * (1 - t) + pts[i + 1] * t)
    return out


streaks = [smooth_line(100 + y, W, 24) for y in range(H)]


def glaze(x, y):
    t = (y + 0.5) / H
    return 0.95 + 0.05 * (1 - t * 2) if t < 0.5 else 0.72 - 0.10 * (t - 0.5) * 2


def carbon(x, y):
    cell = (((x + y) // 2) % 2) ^ (((x - y) // 2) % 2)
    return 0.66 + 0.22 * cell + 0.06 * (1 - (y + 0.5) / H)


def brushed(x, y):
    return 0.80 + 0.10 * row_noise[y] + 0.12 * (streaks[y][x] - 0.5) + 0.03 * pix_noise[y][x]


def segments(x, y):
    t = (y + 0.5) / H
    v = 0.98 - 0.12 * t
    if x % 8 == 0:
        v = 0.45
    elif x % 8 == 1:
        v = 1.0
    return v


def chrome(x, y):
    t = (y + 0.5) / H
    stops = [(0.0, 0.98), (0.42, 0.62), (0.5, 0.38), (0.58, 0.64), (1.0, 0.88)]
    for (t0, v0), (t1, v1) in zip(stops, stops[1:]):
        if t0 <= t <= t1:
            return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return 0.9


def dots(x, y):
    dx, dy = (x % 4) - 1.5, (y % 4) - 1.5
    d = math.sqrt(dx * dx + dy * dy)
    return 0.92 - 0.34 * max(0.0, 1 - d / 1.9)


def grain(x, y):
    return 0.80 + 0.14 * pix_noise[y][x] + 0.04 * (1 - (y + 0.5) / H)


def wave(x, y):
    return 0.76 + 0.20 * (0.5 + 0.5 * math.sin(x / W * 2 * math.pi * 3 + y * 0.35))


for name, fn in [("glaze", glaze), ("carbon", carbon), ("brushed", brushed), ("segments", segments),
                 ("chrome", chrome), ("dots", dots), ("grain", grain), ("wave", wave)]:
    make("kutz_%s.tga" % name, fn)


# ---- masks ------------------------------------------------------------------------------------------
def coverage(px, py, w, h, r):
    dx = max(r - px, 0.0, px - (w - r))
    dy = max(r - py, 0.0, py - (h - r))
    return 1.0 if dx * dx + dy * dy <= r * r else 0.0


def make_mask(name, w, h, radius):
    rows = []
    n = 4                                              # 4 x 4 samples per pixel for smooth edges
    for y in range(h):
        row = []
        for x in range(w):
            hit = 0
            for sy in range(n):
                for sx in range(n):
                    hit += coverage(x + (sx + 0.5) / n, y + (sy + 0.5) / n, w, h, radius)
            row.append((255, 255, 255, int(round(255 * hit / (n * n)))))
        rows.append(row)
    write_tga(name, w, h, rows)


# width / height ratio -> texture size (power of two sizes)
for aspect, (mw, mh) in {4: (256, 64), 8: (256, 32), 16: (512, 32), 32: (512, 16)}.items():
    make_mask("kutz_mask_round_%d.tga" % aspect, mw, mh, 0.28 * mh)
    make_mask("kutz_mask_pill_%d.tga" % aspect, mw, mh, 0.5 * mh)

print("wrote textures and masks to", os.path.abspath(OUT))
