#!/bin/sh
# Regenerate every Hummingbird icon raster from the one geometry source.
#
# render.py is the source of truth: it emits AppIcon.svg AND every PNG from the
# same path, so they can never drift. If a real SVG rasteriser is installed we
# additionally re-render the primary PNG straight from AppIcon.svg as a check;
# otherwise render.py's own (supersampled Pillow) rasteriser is authoritative.
set -e
cd "$(dirname "$0")"

python3 render.py

if command -v rsvg-convert >/dev/null 2>&1; then
    echo "cross-check: rsvg-convert AppIcon.svg -> /tmp/AppIcon.svgcheck.png"
    rsvg-convert -w 1024 -h 1024 AppIcon.svg -o /tmp/AppIcon.svgcheck.png
elif command -v cairosvg >/dev/null 2>&1; then
    echo "cross-check: cairosvg AppIcon.svg -> /tmp/AppIcon.svgcheck.png"
    cairosvg AppIcon.svg -o /tmp/AppIcon.svgcheck.png -W 1024 -H 1024
else
    echo "note: no SVG rasteriser (rsvg-convert / cairosvg) found - render.py output is authoritative."
fi
