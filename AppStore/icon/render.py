#!/usr/bin/env python3
"""
Deterministic Hummingbird app-icon renderer.

One geometry source (HUMMINGBIRD_PATH, an SVG path in a 1024x1024 box) drives
BOTH the committed SVG master (AppIcon.svg) and every PNG raster, so the vector
master and the shipped bitmaps can never drift apart.

No third-party SVG rasteriser is required: the path is flattened to polygons and
filled with Pillow at 4x supersampling, then downsampled (Lanczos) for clean
edges. `render.sh` will prefer a real SVG rasteriser (rsvg-convert / cairosvg)
when one is installed, since the SVG it emits is faithful to this same path.

Usage:  python3 render.py            # regenerate SVG + all rasters
        python3 render.py --svg-only # just rewrite AppIcon.svg
"""
from __future__ import annotations
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

BOX = 1024
SS = 4  # supersampling factor

# --- Brand palette -----------------------------------------------------------
# Greens in the Theme.accent family. The mark reads as a single flat silhouette
# (modelled on the "Mono" alt icon), never a photoreal bird.
GREEN_DEEP   = (23, 110, 78)     # #176E4E  primary mark on light ground
MINT_PALE_A  = (255, 255, 255)   # ground gradient top
MINT_PALE_B  = (233, 244, 238)   # #E9F4EE  ground gradient bottom (barely there)
NIGHT        = (11, 15, 13)      # #0B0F0D  dark-appearance / Midnight ground
MINT_LIGHT   = (209, 236, 223)   # #D1ECDF  mark on dark ground
MONO_MARK    = (58, 58, 60)      # #3A3A3C  Mono mark
MONO_GROUND  = (242, 242, 242)   # #F2F2F2  Mono ground
TINT_MARK    = (232, 236, 234)   # near-white mark for the iOS "tinted" slot

# --- Geometry ---------------------------------------------------------------
# One closed outline in a 1024x1024 box. Derived by tracing the silhouette of
# the previous "Mono" alt icon (the strongest of the three existing marks),
# simplified (Douglas-Peucker) and corner-rounded (Chaikin), then centred with
# a small diagonal lift. It keeps the interior negative-space feather slashes,
# so the icon bird and the in-app BrandMark are finally the same bird.
# Regeneration of the trace lives in AppStore/icon/trace_source.py; day to day
# just edit the coordinates below and re-run render.py.
HUMMINGBIRD_PATH = (
    'M 233.0 222.9 L 321.4 270.3 L 397.2 315.3 L 460.4 357.9 L 510.9 398.2 L 548.8 436.1 L 577.7 463.3 L 597.4 479.9 L 608.1 485.8 L 609.6 481.1 L 609.3 474.4 L 606.9 465.7 L 602.5 455.0 L 596.2 442.4 L 593.1 430.2 L 593.1 418.3 L 596.2 406.9 L 602.5 395.8 L 610.4 385.2 L 619.9 374.9 L 631.0 365.0 L 643.6 355.5 L 656.6 348.4 L 670.1 343.7 L 683.9 341.3 L 698.1 341.3 L 711.5 342.9 L 724.2 346.1 L 736.0 350.8 L 747.1 357.1 L 766.0 361.1 L 792.9 362.7 L 827.6 361.9 L 870.2 358.7 L 892.8 358.7 L 895.1 361.9 L 877.4 368.2 L 839.4 377.7 L 808.6 387.1 L 785.0 396.6 L 768.4 406.1 L 758.9 415.6 L 748.6 433.7 L 737.6 460.6 L 725.7 496.1 L 713.1 540.3 L 700.1 578.2 L 686.6 609.8 L 672.8 635.1 L 658.6 654.0 L 644.0 670.6 L 629.0 684.8 L 613.6 696.7 L 597.8 706.2 L 579.2 715.3 L 557.9 723.9 L 533.8 732.2 L 507.0 740.1 L 479.7 753.9 L 452.1 773.7 L 424.1 799.4 L 395.6 830.9 L 375.5 850.7 L 363.7 858.6 L 360.1 854.6 L 364.8 838.8 L 365.2 828.6 L 361.3 823.8 L 353.0 824.6 L 340.4 830.9 L 327.7 837.3 L 315.1 843.6 L 302.5 849.9 L 289.8 856.2 L 289.0 850.7 L 300.1 833.3 L 323.0 804.1 L 357.7 763.0 L 386.6 726.3 L 409.5 693.9 L 426.4 665.9 L 437.5 642.2 L 440.7 622.5 L 435.9 606.7 L 423.3 594.8 L 402.7 586.9 L 382.2 576.3 L 361.7 562.8 L 341.2 546.7 L 320.6 527.7 L 314.7 515.1 L 323.4 508.7 L 346.7 508.7 L 384.6 515.1 L 403.1 515.9 L 402.4 511.1 L 382.2 500.9 L 342.7 485.1 L 308.4 467.3 L 279.2 447.5 L 255.1 425.8 L 236.1 402.1 L 237.7 391.1 L 259.8 392.7 L 302.5 406.9 L 365.6 433.7 L 416.6 456.6 L 455.3 475.6 L 481.7 490.6 L 495.9 501.6 L 508.2 513.5 L 518.4 526.1 L 526.7 539.5 L 533.0 553.8 L 538.2 562.8 L 542.1 566.8 L 544.9 565.6 L 546.5 559.3 L 543.3 549.4 L 535.4 536.0 L 522.8 519.0 L 505.4 498.5 L 476.2 474.4 L 435.1 446.8 L 382.2 415.6 L 317.5 380.8 L 264.2 349.6 L 222.3 322.0 L 191.9 297.9 L 172.9 277.4 L 156.0 256.0 L 141.0 233.9 L 127.9 211.0 L 116.9 187.3 L 130.7 181.4 L 169.4 193.3 Z'
)


# --- Minimal SVG path -> polygon flattener ---------------------------------
def _tokenize(d: str):
    out, num = [], ""
    for ch in d:
        if ch.isalpha():
            if num:
                out.append(float(num)); num = ""
            out.append(ch)
        elif ch in "-+" and num and num[-1] not in "eE":
            out.append(float(num)); num = ch
        elif ch in " ,\t\n":
            if num:
                out.append(float(num)); num = ""
        else:
            num += ch
    if num:
        out.append(float(num))
    return out


def _cubic(p0, p1, p2, p3, steps=64):
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        x = (u**3) * p0[0] + 3 * (u**2) * t * p1[0] + 3 * u * (t**2) * p2[0] + (t**3) * p3[0]
        y = (u**3) * p0[1] + 3 * (u**2) * t * p1[1] + 3 * u * (t**2) * p2[1] + (t**3) * p3[1]
        yield (x, y)


def _quad(p0, p1, p2, steps=48):
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        x = (u**2) * p0[0] + 2 * u * t * p1[0] + (t**2) * p2[0]
        y = (u**2) * p0[1] + 2 * u * t * p1[1] + (t**2) * p2[1]
        yield (x, y)


def flatten(d: str):
    toks = _tokenize(d)
    pts, i, cur, start, cmd = [], 0, (0.0, 0.0), (0.0, 0.0), None
    while i < len(toks):
        t = toks[i]
        if isinstance(t, str):
            cmd = t; i += 1
        if cmd == "M":
            cur = (toks[i], toks[i + 1]); start = cur; pts.append(cur); i += 2
        elif cmd == "L":
            cur = (toks[i], toks[i + 1]); pts.append(cur); i += 2
        elif cmd == "C":
            p1 = (toks[i], toks[i + 1]); p2 = (toks[i + 2], toks[i + 3]); p3 = (toks[i + 4], toks[i + 5])
            pts.extend(_cubic(cur, p1, p2, p3)); cur = p3; i += 6
        elif cmd == "Q":
            p1 = (toks[i], toks[i + 1]); p2 = (toks[i + 2], toks[i + 3])
            pts.extend(_quad(cur, p1, p2)); cur = p2; i += 4
        elif cmd == "Z":
            pts.append(start); cur = start
        else:
            raise ValueError(f"unsupported path command: {cmd!r}")
    return pts


# --- Rendering ------------------------------------------------------------
def _vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (1, size), top)
    px = img.load()
    for y in range(size):
        f = y / (size - 1)
        px[0, y] = tuple(round(top[c] + (bottom[c] - top[c]) * f) for c in range(3))
    return img.resize((size, size))


def compose(size, *, ground, mark, gradient_bottom=None, transparent=False):
    S = size * SS
    if transparent:
        base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    elif gradient_bottom is not None:
        base = _vertical_gradient(S, ground, gradient_bottom).convert("RGBA")
    else:
        base = Image.new("RGBA", (S, S), ground + (255,))

    poly = [(x / BOX * S, y / BOX * S) for (x, y) in flatten(HUMMINGBIRD_PATH)]
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(poly, fill=mark + (255,))
    base = Image.alpha_composite(base, layer)

    out = base.resize((size, size), Image.LANCZOS)
    return out if transparent else out.convert("RGB")


def save(img, rel):
    path = os.path.join(REPO, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"  {rel}  ({img.size[0]}x{img.size[1]}, {img.mode})")


def emit_svg():
    top = "#%02X%02X%02X" % MINT_PALE_A
    bot = "#%02X%02X%02X" % MINT_PALE_B
    mark = "#%02X%02X%02X" % GREEN_DEEP
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<!-- Hummingbird app icon master. Generated by AppStore/icon/render.py -
     edit the path there, not here. Full-bleed 1024x1024, no baked corner mask. -->
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{top}"/>
      <stop offset="1" stop-color="{bot}"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#ground)"/>
  <path fill="{mark}" d="{HUMMINGBIRD_PATH}"/>
</svg>
"""
    with open(os.path.join(HERE, "AppIcon.svg"), "w") as f:
        f.write(svg)
    print("  AppStore/icon/AppIcon.svg")


def main():
    emit_svg()
    if "--svg-only" in sys.argv:
        return

    print("rasters:")
    # Primary — green mark on a barely-there vertical mint gradient.
    primary = compose(BOX, ground=MINT_PALE_A, mark=GREEN_DEEP, gradient_bottom=MINT_PALE_B)
    for rel in (
        "AppStore/AppIcon-1024.png",
        "Hummingbird/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
        "Hummingbird/Resources/Assets.xcassets/BrandMark.imageset/BrandMark.png",
        "HummingbirdWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    ):
        save(primary, rel)

    # Dark appearance — light mint mark on night ground.
    dark = compose(BOX, ground=NIGHT, mark=MINT_LIGHT)
    save(dark, "Hummingbird/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png")

    # Tinted appearance — near-white mark on transparent; iOS applies the tint.
    tinted = compose(BOX, ground=(0, 0, 0), mark=TINT_MARK, transparent=True)
    save(tinted, "Hummingbird/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png")

    # Alternate icons — same master, different colourway. @2x = 120, @3x = 180.
    midnight = compose(180, ground=NIGHT, mark=MINT_LIGHT)
    mono = compose(180, ground=MONO_GROUND, mark=MONO_MARK)
    for img, name, px in ((midnight, "Midnight", 180), (mono, "Mono", 180)):
        save(img.resize((120, 120), Image.LANCZOS), f"Hummingbird/Resources/AltIcons/AltIcon-{name}@2x.png")
        save(img, f"Hummingbird/Resources/AltIcons/AltIcon-{name}@3x.png")


if __name__ == "__main__":
    main()
