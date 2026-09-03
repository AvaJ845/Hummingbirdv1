# Hummingbird icon

One geometry source → every raster. Nothing here is hand-painted.

## Files
- `AppIcon.svg` — vector master (generated; do not hand-edit).
- `render.py` — source of truth. Holds `HUMMINGBIRD_PATH` (a 1024×1024 outline)
  and the per-slot colourways, emits `AppIcon.svg` and every PNG.
- `render.sh` — wrapper: runs `render.py`, and cross-checks against a real SVG
  rasteriser if one is installed.
- `trace_source.py` — how `HUMMINGBIRD_PATH` was first derived: a boundary trace
  of the previous **Mono** alt icon (`AltIcon-Mono@3x.png`), Douglas–Peucker
  simplified, Chaikin-smoothed, centred. Kept for provenance; you don't need to
  re-run it — edit the coordinates in `render.py` directly.

## Regenerate

```sh
sh AppStore/icon/render.sh
xcodegen generate      # if any file paths changed (they don't by default)
```

Outputs (all filenames unchanged, so no asset-catalog / Info.plist edits):

| File | Slot |
|---|---|
| `AppStore/AppIcon-1024.png` | App Store listing |
| `Hummingbird/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | primary (light) |
| `…/AppIcon-Dark.png` | primary (dark appearance) |
| `…/AppIcon-Tinted.png` | primary (tinted appearance) |
| `Hummingbird/Resources/AltIcons/AltIcon-Midnight@2x,@3x.png` | alt icon "Midnight" |
| `Hummingbird/Resources/AltIcons/AltIcon-Mono@2x,@3x.png` | alt icon "Mono" |
| `Hummingbird/Resources/Assets.xcassets/BrandMark.imageset/BrandMark.png` | in-app header + Settings swatch |
| `HummingbirdWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | watch app |

## Status

This is a deterministic, artifact-free **floor** — one clean flat silhouette,
one family across all five colourways, the in-app bird finally identical to the
icon bird. A professional icon designer pass (true bézier master, optical
centring, size-specific tuning) is still worthwhile before a marquee launch.
