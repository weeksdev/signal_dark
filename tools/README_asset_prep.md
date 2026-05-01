# Asset Prep CLI

`tools/asset_prep.py` turns messy AI-generated PNGs into reusable game-ready parts.

It is designed for this repo's current workflow:
- AI output often arrives as one big sheet
- "transparent" backgrounds are often fake or partially baked in
- exported pieces need repeatable names, crops, and previews

## Dependencies

Minimum:

```bash
uv run --with pillow tools/asset_prep.py --help
```

To enable ML background removal:

```bash
uv run --with pillow --with rembg --with onnxruntime tools/asset_prep.py --help
```

`rembg` uses an ONNX model such as `u2net` for foreground extraction. The CLI also includes a non-ML edge flood cleanup pass for AI images with fake flat backgrounds.

## Commands

Inspect an image:

```bash
uv run --with pillow tools/asset_prep.py inspect assets/walls.png
```

Clean background with hybrid cleanup:

```bash
uv run --with pillow --with rembg --with onnxruntime tools/asset_prep.py \
  clean-bg assets/walls.png assets/derived/walls_clean.png \
  --mode hybrid \
  --trim
```

Suggest slices from connected alpha regions:

```bash
uv run --with pillow tools/asset_prep.py \
  suggest-slices assets/derived/walls_clean.png tools/manifests/walls.json \
  --prefix wall \
  --min-area 2500
```

Export the named slices and a preview sheet:

```bash
uv run --with pillow tools/asset_prep.py \
  slice tools/manifests/walls.json assets/derived/walls \
  --preview assets/derived/walls_preview.png
```

The preview sheet defaults to a checkerboard background so dark sprites remain visible.

If your cleaned derivative is only useful as a mask, keep the original art for RGB and use the cleaned image only for alpha/crop guidance:

```bash
uv run --with pillow tools/asset_prep.py \
  slice tools/manifests/walls.json assets/derived/walls \
  --rgb-source assets/walls.png \
  --preview assets/derived/walls_preview.png
```

## Recommended Wall Workflow

1. Run `inspect` on the raw wall sheet.
2. Run `clean-bg --mode hybrid` if the AI baked in a fake background.
3. Run `suggest-slices` to get initial rectangles.
4. Rename the generated slice names in the manifest to `wall_top`, `wall_middle`, `wall_bottom`, etc.
5. Adjust rectangle coordinates if needed.
6. Run `slice --preview` and verify the exported pieces.

## Manifest Format

Example:

```json
{
  "source": "assets/derived/walls_clean.png",
  "preprocess": {
    "alpha_threshold": 8,
    "trim_exports": true,
    "padding": 8
  },
  "slices": [
    {
      "name": "wall_top",
      "rect": [120, 60, 180, 620],
      "pivot": [0.5, 0.5],
      "notes": "Vertical top cap"
    },
    {
      "name": "wall_middle",
      "rect": [410, 60, 160, 620],
      "pivot": [0.5, 0.5],
      "notes": "Straight repeatable segment"
    }
  ]
}
```

`rect` is `[x, y, width, height]`.

## Notes

- `clean-bg --mode edge` is fast and useful for flat or nearly-flat fake backgrounds.
- `clean-bg --mode ml` is useful when the background is irregular.
- `clean-bg --mode hybrid` runs edge cleanup first, then ML removal.
- `suggest-slices` uses connected opaque regions, so text labels or background junk can create extra boxes if cleanup was incomplete.
