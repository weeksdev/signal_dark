#!/usr/bin/env python3
"""
Prepare noisy AI-generated image sheets for game use.

Features:
- Inspect image dimensions and border color
- Remove fake backgrounds with edge flood-fill color cleanup
- Optionally run ML-backed background removal via rembg
- Suggest slice bounds from alpha-connected components
- Export manifest-driven slices and preview sheets

Typical wall-sheet workflow:
1. Inspect the source image
2. Run `clean-bg --mode hybrid`
3. Run `suggest-slices`
4. Adjust the manifest rectangles if needed
5. Run `slice --preview`
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(message)


def require_pillow():
    try:
        from PIL import Image, ImageColor, ImageDraw, ImageOps
    except ModuleNotFoundError:
        fail(
            "Missing dependency: Pillow. "
            "Run with `uv run --with pillow tools/asset_prep.py ...` "
            "or install Pillow in your Python environment."
        )
    return Image, ImageColor, ImageDraw, ImageOps


def require_rembg():
    try:
        from rembg import new_session, remove
    except ModuleNotFoundError:
        fail(
            "Missing dependency: rembg. "
            "Run with `uv run --with pillow --with rembg --with onnxruntime tools/asset_prep.py ...` "
            "to enable ML background removal."
        )
    return new_session, remove


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def rel_to_root(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def parse_path(value: str) -> Path:
    return Path(value).expanduser()


@dataclass
class Bounds:
    left: int
    top: int
    right: int
    bottom: int

    @property
    def width(self) -> int:
        return self.right - self.left

    @property
    def height(self) -> int:
        return self.bottom - self.top

    @property
    def rect(self) -> list[int]:
        return [self.left, self.top, self.width, self.height]

    def padded(self, amount: int, limit_w: int, limit_h: int) -> "Bounds":
        return Bounds(
            max(0, self.left - amount),
            max(0, self.top - amount),
            min(limit_w, self.right + amount),
            min(limit_h, self.bottom + amount),
        )


def image_open(path: Path):
    Image, _, _, _ = require_pillow()
    return Image.open(path).convert("RGBA")


def rgba_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt(
        ((a[0] - b[0]) ** 2) +
        ((a[1] - b[1]) ** 2) +
        ((a[2] - b[2]) ** 2)
    )


def median_color(samples: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    if not samples:
        return (0, 0, 0)
    return tuple(int(statistics.median(channel)) for channel in zip(*samples))


def collect_border_samples(image, inset: int = 0) -> list[tuple[int, int, int]]:
    width, height = image.size
    pixels = image.load()
    samples: list[tuple[int, int, int]] = []
    x0 = max(0, min(width - 1, int(inset)))
    y0 = max(0, min(height - 1, int(inset)))
    x1 = max(0, min(width - 1, int(width - 1 - inset)))
    y1 = max(0, min(height - 1, int(height - 1 - inset)))

    for x in range(width):
        samples.append(pixels[x, y0][:3])
        samples.append(pixels[x, y1][:3])
    for y in range(height):
        samples.append(pixels[x0, y][:3])
        samples.append(pixels[x1, y][:3])
    return samples


def trim_to_alpha(image, padding: int):
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image.copy(), Bounds(0, 0, image.width, image.height)
    bounds = Bounds(*bbox).padded(padding, image.width, image.height)
    return image.crop((bounds.left, bounds.top, bounds.right, bounds.bottom)), bounds


def remove_background_edge_flood(
    image,
    threshold: float,
    alpha_threshold: int,
    inset: int,
    keep_existing_alpha: bool,
):
    width, height = image.size
    src = image.copy().convert("RGBA")
    pixels = src.load()
    bg = median_color(collect_border_samples(src, inset=inset))
    visited = set()
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited:
            continue
        visited.add((x, y))

        r, g, b, a = pixels[x, y]
        if keep_existing_alpha and a <= alpha_threshold:
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in visited:
                    queue.append((nx, ny))
            continue

        if rgba_distance((r, g, b), bg) > threshold:
            continue

        pixels[x, y] = (r, g, b, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in visited:
                queue.append((nx, ny))

    return src, bg


def apply_alpha_threshold(image, alpha_threshold: int):
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a <= alpha_threshold:
                pixels[x, y] = (r, g, b, 0)
    return image


def extract_line_art_alpha(image, threshold: int, softness: int, invert: bool):
    src = image.copy().convert("RGBA")
    pixels = src.load()
    softness = max(1, softness)
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = pixels[x, y]
            luminance = max(r, g, b)
            if invert:
                luminance = 255 - luminance
            if luminance <= threshold:
                out_alpha = 0
            else:
                out_alpha = int(clamp((luminance - threshold) / softness, 0.0, 1.0) * 255.0)
            pixels[x, y] = (255, 255, 255, out_alpha)
    return src


def ml_remove_background(image, model: str):
    new_session, remove = require_rembg()
    session = new_session(model)
    return remove(image, session=session)


def connected_alpha_bounds(image, alpha_threshold: int, min_area: int) -> list[Bounds]:
    alpha = image.getchannel("A")
    width, height = image.size
    pixels = alpha.load()
    visited = [[False for _ in range(width)] for _ in range(height)]
    bounds: list[Bounds] = []

    for y0 in range(height):
        for x0 in range(width):
            if visited[y0][x0] or pixels[x0, y0] <= alpha_threshold:
                continue
            queue: deque[tuple[int, int]] = deque([(x0, y0)])
            visited[y0][x0] = True
            left = right = x0
            top = bottom = y0
            count = 0
            while queue:
                x, y = queue.popleft()
                count += 1
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    if visited[ny][nx] or pixels[nx, ny] <= alpha_threshold:
                        continue
                    visited[ny][nx] = True
                    queue.append((nx, ny))
            if count >= min_area:
                bounds.append(Bounds(left, top, right + 1, bottom + 1))
    bounds.sort(key=lambda item: (item.top, item.left))
    return bounds


def parse_manifest(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        fail(f"Invalid manifest JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"Manifest root must be an object: {path}")
    return data


def rect_from_manifest(item: dict[str, Any]) -> Bounds:
    rect = item.get("rect")
    if not isinstance(rect, list) or len(rect) != 4:
        fail(f"Slice `{item.get('name', '<unnamed>')}` missing `rect: [x, y, w, h]`")
    x, y, w, h = rect
    return Bounds(int(x), int(y), int(x + w), int(y + h))


def manifest_source_path(manifest_path: Path, manifest: dict[str, Any]) -> Path | None:
    source = manifest.get("source")
    if not source:
        return None
    source_path = Path(source)
    if source_path.is_absolute():
        return source_path
    root_candidate = (ROOT / source_path).resolve()
    if root_candidate.exists():
        return root_candidate
    source_path = (manifest_path.parent / source_path).resolve()
    return source_path


def write_image(image, path: Path) -> None:
    ensure_parent(path)
    image.save(path)


def load_manifest_image(manifest_path: Path, fallback_image: Path | None):
    manifest = parse_manifest(manifest_path)
    source = fallback_image or manifest_source_path(manifest_path, manifest)
    if source is None:
        fail("No image path provided and manifest has no `source` field.")
    return image_open(source), manifest, source


def checkerboard_background(width: int, height: int, tile: int = 24):
    Image, _, ImageDraw, _ = require_pillow()
    image = Image.new("RGBA", (width, height), (186, 186, 186, 255))
    draw = ImageDraw.Draw(image)
    dark = (138, 138, 138, 255)
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            if ((x // tile) + (y // tile)) % 2 == 0:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=dark)
    return image


def build_preview_sheet(slices: list[tuple[str, Any]], cell_padding: int, bg_color: str):
    Image, ImageColor, ImageDraw, ImageOps = require_pillow()
    if not slices:
        fail("No slices available for preview.")
    swatches = []
    max_w = 0
    max_h = 0
    for name, image in slices:
        framed = ImageOps.expand(image, border=2, fill=(255, 255, 255, 80))
        swatches.append((name, framed))
        max_w = max(max_w, framed.width)
        max_h = max(max_h, framed.height)

    cols = max(1, math.ceil(math.sqrt(len(swatches))))
    rows = math.ceil(len(swatches) / cols)
    label_h = 28
    cell_w = max_w + cell_padding * 2
    cell_h = max_h + cell_padding * 2 + label_h
    if bg_color.lower() == "checkerboard":
        sheet = checkerboard_background(cols * cell_w, rows * cell_h)
    else:
        sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), ImageColor.getrgb(bg_color))
    draw = ImageDraw.Draw(sheet)

    for idx, (name, image) in enumerate(swatches):
        col = idx % cols
        row = idx // cols
        x = col * cell_w + cell_padding + (max_w - image.width) // 2
        y = row * cell_h + cell_padding
        sheet.alpha_composite(image, (x, y))
        label_fill = (18, 18, 18, 255) if bg_color.lower() == "checkerboard" else (255, 255, 255, 255)
        draw.text((col * cell_w + 8, row * cell_h + max_h + cell_padding + 6), name, fill=label_fill)
    return sheet


def cmd_inspect(args: argparse.Namespace) -> int:
    image = image_open(args.image)
    alpha = image.getchannel("A")
    border = median_color(collect_border_samples(image, inset=args.border_inset))
    bbox = alpha.getbbox()
    payload = {
        "path": rel_to_root(args.image),
        "size": [image.width, image.height],
        "alpha_bbox": list(bbox) if bbox else None,
        "border_median_rgb": list(border),
        "suggested_bg_hex": "#%02x%02x%02x" % border,
    }
    print(json.dumps(payload, indent=2))
    return 0


def cmd_clean_bg(args: argparse.Namespace) -> int:
    image = image_open(args.image)
    result = image.copy()
    detected_bg = None

    if args.mode in {"edge", "hybrid"}:
        result, detected_bg = remove_background_edge_flood(
            result,
            threshold=args.edge_threshold,
            alpha_threshold=args.alpha_threshold,
            inset=args.border_inset,
            keep_existing_alpha=args.keep_existing_alpha,
        )
        result = apply_alpha_threshold(result, args.alpha_threshold)

    if args.mode == "lineart":
        result = extract_line_art_alpha(
            result,
            threshold=args.luma_threshold,
            softness=args.luma_softness,
            invert=args.invert_lineart,
        )

    if args.mode in {"ml", "hybrid"}:
        result = ml_remove_background(result, args.model).convert("RGBA")
        result = apply_alpha_threshold(result, args.alpha_threshold)

    if args.trim:
        result, _ = trim_to_alpha(result, args.padding)

    write_image(result, args.output)
    payload = {
        "output": rel_to_root(args.output),
        "mode": args.mode,
        "model": args.model if args.mode in {"ml", "hybrid"} else None,
        "detected_bg_rgb": list(detected_bg) if detected_bg else None,
        "size": [result.width, result.height],
    }
    print(json.dumps(payload, indent=2))
    return 0


def cmd_suggest_slices(args: argparse.Namespace) -> int:
    image = image_open(args.image)
    bounds = connected_alpha_bounds(image, args.alpha_threshold, args.min_area)
    if not bounds:
        fail("No slice candidates found. Try lowering `--min-area` or `--alpha-threshold`.")
    slices = []
    for idx, bound in enumerate(bounds, start=1):
        padded = bound.padded(args.padding, image.width, image.height)
        slices.append(
            {
                "name": f"{args.prefix}_{idx:02d}",
                "rect": padded.rect,
                "pivot": [0.5, 0.5],
                "notes": "",
            }
        )
    manifest = {
        "source": rel_to_root(args.image),
        "preprocess": {
            "alpha_threshold": args.alpha_threshold,
            "trim_exports": True,
            "padding": args.padding,
        },
        "slices": slices,
    }
    ensure_parent(args.output)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {len(slices)} suggested slices to {rel_to_root(args.output)}")
    return 0


def cmd_init_manifest(args: argparse.Namespace) -> int:
    manifest = {
        "source": rel_to_root(args.image),
        "preprocess": {
            "alpha_threshold": 8,
            "trim_exports": True,
            "padding": 8,
        },
        "slices": [
            {
                "name": "rename_me",
                "rect": [0, 0, 64, 64],
                "pivot": [0.5, 0.5],
                "notes": "Replace with a real slice rectangle.",
            }
        ],
    }
    ensure_parent(args.output)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote template manifest to {rel_to_root(args.output)}")
    return 0


def trim_with_alpha_reference(image, alpha_image, padding: int):
    alpha = alpha_image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image.copy(), Bounds(0, 0, image.width, image.height)
    bounds = Bounds(*bbox).padded(padding, image.width, image.height)
    return image.crop((bounds.left, bounds.top, bounds.right, bounds.bottom)), bounds


def export_slices(
    mask_image,
    manifest: dict[str, Any],
    output_dir: Path,
    trim_exports: bool,
    default_padding: int,
    rgb_image=None,
):
    exported: list[tuple[str, Any]] = []
    for item in manifest.get("slices", []):
        if not isinstance(item, dict):
            continue
        name = item.get("name")
        if not name:
            fail("Every slice must have a `name`.")
        bounds = rect_from_manifest(item)
        mask_region = mask_image.crop((bounds.left, bounds.top, bounds.right, bounds.bottom))
        region = mask_region
        if rgb_image is not None:
            rgb_region = rgb_image.crop((bounds.left, bounds.top, bounds.right, bounds.bottom)).convert("RGBA")
            rgb_region.putalpha(mask_region.getchannel("A"))
            region = rgb_region
        if item.get("trim", trim_exports):
            pad = int(item.get("padding", default_padding))
            region, _ = trim_with_alpha_reference(region, mask_region, pad)
        out_path = output_dir / f"{name}.png"
        write_image(region, out_path)
        exported.append((name, region))
    return exported


def cmd_slice(args: argparse.Namespace) -> int:
    image, manifest, source = load_manifest_image(args.manifest, args.image)
    rgb_image = image_open(args.rgb_source) if args.rgb_source else None
    preprocess = manifest.get("preprocess", {})
    alpha_threshold = int(preprocess.get("alpha_threshold", args.alpha_threshold))
    trim_exports = bool(preprocess.get("trim_exports", True))
    default_padding = int(preprocess.get("padding", args.padding))

    if args.clean_mode in {"edge", "hybrid"}:
        image, _ = remove_background_edge_flood(
            image,
            threshold=args.edge_threshold,
            alpha_threshold=alpha_threshold,
            inset=args.border_inset,
            keep_existing_alpha=args.keep_existing_alpha,
        )
        image = apply_alpha_threshold(image, alpha_threshold)
    if args.clean_mode == "lineart":
        image = extract_line_art_alpha(
            image,
            threshold=args.luma_threshold,
            softness=args.luma_softness,
            invert=args.invert_lineart,
        )

    if args.clean_mode in {"ml", "hybrid"}:
        image = ml_remove_background(image, args.model).convert("RGBA")
        image = apply_alpha_threshold(image, alpha_threshold)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    exported = export_slices(
        image,
        manifest,
        args.output_dir,
        trim_exports,
        default_padding,
        rgb_image=rgb_image,
    )

    if args.preview:
        preview = build_preview_sheet(exported, args.preview_padding, args.preview_bg)
        write_image(preview, args.preview)

    summary = {
        "source": rel_to_root(source),
        "rgb_source": rel_to_root(args.rgb_source) if args.rgb_source else None,
        "output_dir": rel_to_root(args.output_dir),
        "slice_count": len(exported),
        "preview": rel_to_root(args.preview) if args.preview else None,
    }
    print(json.dumps(summary, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Prepare noisy AI-generated image assets for game use.")
    sub = parser.add_subparsers(dest="command", required=True)

    inspect_p = sub.add_parser("inspect", help="Report image dimensions, alpha bounds, and border color.")
    inspect_p.add_argument("image", type=parse_path)
    inspect_p.add_argument("--border-inset", type=int, default=0)
    inspect_p.set_defaults(func=cmd_inspect)

    clean_p = sub.add_parser("clean-bg", help="Remove fake or real backgrounds and optionally trim.")
    clean_p.add_argument("image", type=parse_path)
    clean_p.add_argument("output", type=parse_path)
    clean_p.add_argument("--mode", choices=["edge", "ml", "hybrid", "lineart"], default="hybrid")
    clean_p.add_argument("--model", default="u2net")
    clean_p.add_argument("--edge-threshold", type=float, default=28.0)
    clean_p.add_argument("--alpha-threshold", type=int, default=8)
    clean_p.add_argument("--luma-threshold", type=int, default=28)
    clean_p.add_argument("--luma-softness", type=int, default=72)
    clean_p.add_argument("--invert-lineart", action="store_true")
    clean_p.add_argument("--border-inset", type=int, default=0)
    clean_p.add_argument("--padding", type=int, default=8)
    clean_p.add_argument("--trim", action="store_true")
    clean_p.add_argument("--keep-existing-alpha", action="store_true")
    clean_p.set_defaults(func=cmd_clean_bg)

    suggest_p = sub.add_parser("suggest-slices", help="Suggest slice rectangles from alpha-connected components.")
    suggest_p.add_argument("image", type=parse_path)
    suggest_p.add_argument("output", type=parse_path)
    suggest_p.add_argument("--prefix", default="slice")
    suggest_p.add_argument("--alpha-threshold", type=int, default=8)
    suggest_p.add_argument("--min-area", type=int, default=2500)
    suggest_p.add_argument("--padding", type=int, default=8)
    suggest_p.set_defaults(func=cmd_suggest_slices)

    init_p = sub.add_parser("init-manifest", help="Create a manifest template.")
    init_p.add_argument("image", type=parse_path)
    init_p.add_argument("output", type=parse_path)
    init_p.set_defaults(func=cmd_init_manifest)

    slice_p = sub.add_parser("slice", help="Export manifest-driven slices and an optional preview sheet.")
    slice_p.add_argument("manifest", type=parse_path)
    slice_p.add_argument("output_dir", type=parse_path)
    slice_p.add_argument("--image", type=parse_path, help="Override manifest source image.")
    slice_p.add_argument("--rgb-source", type=parse_path, help="Use this image for final RGB while taking alpha/crop guidance from the manifest source image.")
    slice_p.add_argument("--clean-mode", choices=["none", "edge", "ml", "hybrid", "lineart"], default="none")
    slice_p.add_argument("--model", default="u2net")
    slice_p.add_argument("--edge-threshold", type=float, default=28.0)
    slice_p.add_argument("--alpha-threshold", type=int, default=8)
    slice_p.add_argument("--luma-threshold", type=int, default=28)
    slice_p.add_argument("--luma-softness", type=int, default=72)
    slice_p.add_argument("--invert-lineart", action="store_true")
    slice_p.add_argument("--border-inset", type=int, default=0)
    slice_p.add_argument("--padding", type=int, default=8)
    slice_p.add_argument("--keep-existing-alpha", action="store_true")
    slice_p.add_argument("--preview", type=parse_path)
    slice_p.add_argument("--preview-padding", type=int, default=16)
    slice_p.add_argument("--preview-bg", default="checkerboard")
    slice_p.set_defaults(func=cmd_slice)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
