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
  AppStore/promo/SubscriptionPromo-Plans.png  - the actual plans + pricing,
                                                styled like the in-app paywall

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

# Light "paywall" palette (matches the in-app Pro screen).
GREEN_DEEP  = (23, 110, 78)   # #176E4E  brand mark
ACCENT      = (15, 128, 97)   # #0F8061  contrast-tuned Theme.accent (prices)
GROUPED_BG  = (242, 242, 247) # #F2F2F7  systemGroupedBackground (light)
CARD_BG     = (255, 255, 255)
INK         = (28, 28, 30)    # #1C1C1E  primary label
INK_2ND     = (142, 142, 147) # #8E8E93  secondary label

FONT_BOLD = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
]
FONT_REG = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
]


def _load_font(px: int, bold: bool = True):
    for path in (FONT_BOLD if bold else FONT_REG):
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


def _rounded(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def render_plans() -> Image.Image:
    """1024x1024: the actual Pro plans + pricing, styled like the in-app paywall."""
    S = BOX * SS
    img = Image.new("RGB", (S, S), GROUPED_BG)
    d = ImageDraw.Draw(img)

    def center_text(y, text, font, fill):
        b = d.textbbox((0, 0), text, font=font)
        d.text(((S - (b[2] - b[0])) / 2 - b[0], y - b[1]), text, font=font, fill=fill)

    # Brand mark (green hummingbird), small, top.
    mark_px = int(150 * SS)
    scale = mark_px / S
    poly = [
        (x / BOX * S * scale + (S - mark_px) / 2,
         y / BOX * S * scale + int(70 * SS))
        for (x, y) in icon.flatten(icon.HUMMINGBIRD_PATH)
    ]
    d.polygon(poly, fill=GREEN_DEEP)

    center_text(int(258 * SS), "Hummingbird Pro", _load_font(int(60 * SS)), INK)
    center_text(int(340 * SS), "Compare every method  ·  90-day horizons",
                _load_font(int(30 * SS), bold=False), INK_2ND)

    # Plan card.
    m = int(70 * SS)
    card_top, card_bot = int(410 * SS), int(880 * SS)
    _rounded(d, (m, card_top, S - m, card_bot), radius=int(34 * SS), fill=CARD_BG)

    rows = [
        ("Pro Yearly",   "7-day free trial  ·  best value",     "$19.99/year"),
        ("Pro Monthly",  "Lower commitment  ·  cancel anytime",  "$2.99/month"),
        ("Pro Lifetime", "Pay once  ·  yours forever",           "$49.99"),
    ]
    name_f  = _load_font(int(38 * SS))
    sub_f   = _load_font(int(26 * SS), bold=False)
    price_f = _load_font(int(38 * SS))

    pad_x = m + int(44 * SS)
    row_h = (card_bot - card_top) / len(rows)
    for i, (name, sub, price) in enumerate(rows):
        cy = card_top + row_h * (i + 0.5)
        nb = d.textbbox((0, 0), name, font=name_f)
        d.text((pad_x, cy - (nb[3] - nb[1]) - int(6 * SS) - nb[1]), name, font=name_f, fill=INK)
        d.text((pad_x, cy + int(6 * SS)), sub, font=sub_f, fill=INK_2ND)
        pb = d.textbbox((0, 0), price, font=price_f)
        d.text((S - pad_x - (pb[2] - pb[0]) - pb[0], cy - (pb[3] - pb[1]) / 2 - pb[1]),
               price, font=price_f, fill=ACCENT)
        if i < len(rows) - 1:
            ly = int(card_top + row_h * (i + 1))
            d.line((pad_x, ly, S - pad_x, ly), fill=GROUPED_BG, width=int(2 * SS))

    center_text(int(930 * SS), "Educational comparison tools — never advice",
                _load_font(int(25 * SS), bold=False), INK_2ND)

    return img.resize((BOX, BOX), Image.LANCZOS)


def _save(img: Image.Image, name: str):
    path = os.path.join(HERE, name)
    img.save(path)
    print(f"  AppStore/promo/{name}  ({img.size[0]}x{img.size[1]}, {img.mode})")


def main():
    print("subscription promo images:")
    _save(render_mark_only(), "SubscriptionPromo.png")
    _save(render_with_wordmark(), "SubscriptionPromo-Pro.png")
    _save(render_plans(), "SubscriptionPromo-Plans.png")


if __name__ == "__main__":
    main()
