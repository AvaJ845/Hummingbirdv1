#!/usr/bin/env python3
"""
PROVENANCE ONLY - how HUMMINGBIRD_PATH in render.py was first derived.

Boundary-trace the Mono alt icon silhouette -> Douglas-Peucker simplify ->
Chaikin smooth -> centre/scale -> print an SVG path. This was run ONCE against
the original hand-made Mono mark; render.py now owns the path. You normally
edit render.py directly. Re-running this against the current (regenerated) Mono
is near-circular and only useful as a check.
"""
import os
import sys
from PIL import Image

SRC = os.path.join(os.path.dirname(__file__), "..", "..",
                   "Hummingbird", "Resources", "AltIcons", "AltIcon-Mono@3x.png")
im = Image.open(SRC).convert("L")
W, H = im.size
px = im.load()

def solid(x, y):
    return 0 <= x < W and 0 <= y < H and px[x, y] < 150

start = next((x, y) for y in range(H) for x in range(W) if solid(x, y))
dirs = [(-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1)]
contour = [start]
cx, cy = start
b = 0
for _ in range(200000):
    for k in range(8):
        d = (b + 1 + k) % 8
        nx, ny = cx + dirs[d][0], cy + dirs[d][1]
        if solid(nx, ny):
            b = (d + 4) % 8
            cx, cy = nx, ny
            contour.append((cx, cy))
            break
    else:
        break
    if (cx, cy) == start and len(contour) > 3:
        break
if contour[0] == contour[-1]:
    contour = contour[:-1]

def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    x1, y1 = pts[0]; x2, y2 = pts[-1]
    dmax, idx = 0.0, 0
    for i in range(1, len(pts) - 1):
        x0, y0 = pts[i]
        num = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        den = ((y2 - y1) ** 2 + (x2 - x1) ** 2) ** 0.5 or 1e-9
        dd = num / den
        if dd > dmax:
            dmax, idx = dd, i
    if dmax > eps:
        return rdp(pts[: idx + 1], eps)[:-1] + rdp(pts[idx:], eps)
    return [pts[0], pts[-1]]

n = len(contour)
poly = rdp(contour[: n // 2 + 1], 1.7)[:-1] + rdp(contour[n // 2:] + [contour[0]], 1.7)[:-1]

def chaikin(pts, iters=2):
    for _ in range(iters):
        out = []
        m = len(pts)
        for i in range(m):
            p, q = pts[i], pts[(i + 1) % m]
            out.append((p[0] * 0.75 + q[0] * 0.25, p[1] * 0.75 + q[1] * 0.25))
            out.append((p[0] * 0.25 + q[0] * 0.75, p[1] * 0.25 + q[1] * 0.75))
        pts = out
    return pts

poly = chaikin(poly, 2)

# scale 180 -> 1024 space, then fit: target 74% coverage of the larger axis, centered
xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
bw, bh = max(xs) - min(xs), max(ys) - min(ys)
scale = 0.76 * 1024 / max(bw, bh)
cx0 = (min(xs) + max(xs)) / 2
cy0 = (min(ys) + max(ys)) / 2
# nudge: sit a hair high and left of dead-centre for diagonal lift
tx, ty = 512 - 6, 512 + 8
final = [(round((x - cx0) * scale + tx, 1), round((y - cy0) * scale + ty, 1)) for x, y in poly]

# de-dupe consecutive
ded = [final[0]]
for p in final[1:]:
    if abs(p[0] - ded[-1][0]) > 0.15 or abs(p[1] - ded[-1][1]) > 0.15:
        ded.append(p)
final = ded

d = "M " + " ".join(f"{x} {y}" + (" L" if i < len(final) - 1 else "") for i, (x, y) in enumerate(final)) + " Z"
print(f"points: {len(final)}", file=sys.stderr)
print(d)
