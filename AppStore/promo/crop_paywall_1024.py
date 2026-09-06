#!/usr/bin/env python3
"""
Square 1024x1024 subscription promotional image cropped straight from the real
paywall screenshot (AppStore/raw-screens/08_paywall_plans.png, 1320x2868).

App Store Connect's per-product Promotional Image slot requires exactly
1024x1024. This takes the actual on-device pixels of the "Choose your plan"
card (Yearly / Monthly / Lifetime + prices) rather than a redrawn mockup,
scales them to fit, and centres them on the same grouped-background grey so
the square has no letterbox seam.

Usage:  python3 AppStore/promo/crop_paywall_1024.py
Output: AppStore/promo/SubscriptionPromo-Screenshot.png
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(REPO, "AppStore", "raw-screens", "08_paywall_plans.png")

OUT = 1024
BG = (242, 242, 247)  # systemGroupedBackground (sampled from the screenshot)

# Crop box in the 1320x2868 source: from just above "Choose your plan"
# through the plan card and into the start of the subscription-terms text,
# full content width. Tuned against the committed screenshot.
CROP = (24, 650, 1296, 1876)  # (left, top, right, bottom)


def main():
    src = Image.open(SRC).convert("RGB")
    region = src.crop(CROP)

    # Scale to fit the 1024 square (fit width; height will be <= 1024).
    w, h = region.size
    scale = OUT / w
    region = region.resize((OUT, round(h * scale)), Image.LANCZOS)

    canvas = Image.new("RGB", (OUT, OUT), BG)
    y = (OUT - region.height) // 2
    canvas.paste(region, (0, max(0, y)))
    if region.height > OUT:  # safety: crop overflow instead of squashing
        canvas = region.crop((0, (region.height - OUT) // 2,
                              OUT, (region.height - OUT) // 2 + OUT))

    path = os.path.join(HERE, "SubscriptionPromo-Screenshot.png")
    canvas.save(path)
    print(f"AppStore/promo/SubscriptionPromo-Screenshot.png  "
          f"({canvas.size[0]}x{canvas.size[1]}, {canvas.mode})")


if __name__ == "__main__":
    main()
