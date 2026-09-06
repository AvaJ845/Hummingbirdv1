#!/usr/bin/env python3
"""
Subscription promotional image for App Store Connect.

App Store Connect asks for a 1024x1024 image that "best represents this
subscription." It's shown in win-back offers, offer-code redemption sheets,
and — if App Store Promotion is enabled — on the app's product page.

This reuses the exact hummingbird geometry from AppStore/icon/render.py so the
promo art can never drift from the app icon. The treatment is deliberately the
dark "Midnight" colourway (mint mark on near-black) — premium-tier reading, and
instantly distinct from the free app's green-on-white Home Screen icon.

Outputs (1024x1024, RGB, no alpha):
  AppStore/promo/SubscriptionPromo.png        - mark only, full bleed
  AppStore/promo/SubscriptionPromo-Pro.png    - mark + small "PRO" wordmark

Usage:  python3 AppStore/promo/render_promo.py
"""
from __future__ import annotations
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

# Reuse the icon renderer's geometry + flattener so the bird is identical.
sys.path.insert(0, os.path.join(REPO, "AppStore", "icon"))
import render as icon  # noqa: E402

BOX = 1024
SS = 4

NIGHT = (11, 15, 13)        # #0B0F0D  ground (matches AltIcon-Midnight)
NIGHT_LIFT = (18, 26, 22)   # #121A16  barely-there gradient bottom
MINT = (209, 236, 223)      # #D1ECDF  mark + wordmark (matches AltIcon-Midnight)

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/SFNS.ttf",
]


def _load_font(px: int):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, px)
            except Exception:
                continue
    return ImageFont.load_default()


def _bird_layer(canvas_px: int, scale: float, dy: float):
    """Mint hummingbird polygon on a transparent layer, scaled + shifted."""
    poly = [
        (x / BOX * canvas_px * scale + canvas_px * (1 - scale) / 2,
         y / BOX * canvas_px * scale + canvas_px * (1 - scale) / 2 + dy * canvas_px)
        for (x, y) in icon.flatten(icon.HUMMINGBIRD_PATH)
    ]
    layer = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(poly, fill=MINT + (255,))
    return layer


def _ground(canvas_px: int):
    g = icon._vertical_gradient(canvas_px, NIGHT, NIGHT_LIFT)
    return g.convert("RGBA")


def render_mark_only() -> Image.Image:
    S = BOX * SS
    base = _ground(S)
    base = Image.alpha_composite(base, _bird_layer(S, scale=1.0, dy=0.0))
    return base.resize((BOX, BOX), Image.LANCZOS).convert("RGB")


def render_with_wordmark() -> Image.Image:
    S = BOX * SS
    base = _ground(S)
    # Shrink + lift the bird to open a band for the wordmark.
    base = Image.alpha_composite(base, _bird_layer(S, scale=0.78, dy=-0.075))

    draw = ImageDraw.Draw(base)
    text = "P R O"                      # letter-spaced for a calm, editorial feel
    font = _load_font(int(92 * SS))
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (S - tw) / 2 - bbox[0]
    y = S * 0.77 - bbox[1]
    draw.text((x, y), text, font=font, fill=MINT + (255,))

    return base.resize((BOX, BOX), Image.LANCZOS).convert("RGB")


def _save(img: Image.Image, name: str):
    path = os.path.join(HERE, name)
    img.save(path)
    print(f"  AppStore/promo/{name}  ({img.size[0]}x{img.size[1]}, {img.mode})")


def main():
    print("subscription promo images:")
    _save(render_mark_only(), "SubscriptionPromo.png")
    _save(render_with_wordmark(), "SubscriptionPromo-Pro.png")


if __name__ == "__main__":
    main()
