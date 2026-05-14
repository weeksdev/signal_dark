"""
Remove checkerboard/white background from debris_2.png, crop tight to content,
and write the cleaned RGBA result directly to assets/debris_2.png.
"""
from __future__ import annotations

from collections import Counter, deque
from pathlib import Path
from typing import Iterable

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
INPUT  = ROOT / "assets" / "debris_2.png"
OUTPUT = ROOT / "assets" / "debris_2.png"
PREVIEW = ROOT / "tests" / "generated_transparent_assets" / "debris_2_preview_dark.png"

LUMA_MIN      = 228
CHROMA_MAX    = 22
COLOR_TOLERANCE = 30
QUANTIZE_STEP = 6
CROP_PADDING  = 4

NEIGHBORS = ((1, 0), (-1, 0), (0, 1), (0, -1))
ALL_NEIGHBORS = (
    (1, 0), (-1, 0), (0, 1), (0, -1),
    (1, 1), (1, -1), (-1, 1), (-1, -1),
)


def main() -> None:
    print(f"Processing {INPUT.relative_to(ROOT)} …")
    result = clean_asset(INPUT)
    result = tight_crop(result, CROP_PADDING)
    result.save(OUTPUT)
    print(f"Saved {OUTPUT.relative_to(ROOT)}  ({result.size[0]}×{result.size[1]} RGBA)")

    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview = make_preview(result)
    preview.save(PREVIEW)
    print(f"Preview → {PREVIEW.relative_to(ROOT)}")


# ── background removal ────────────────────────────────────────────────────────

def clean_asset(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    bg_colors = estimate_background_colors(image)
    bg_mask = edge_connected_background_mask(pixels, width, height, bg_colors)
    bg_mask = contract_bright_edge(pixels, bg_mask, bg_colors, passes=16)
    output = image.copy()
    out_px = output.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = out_px[x, y]
            if bg_mask[y][x]:
                out_px[x, y] = (r, g, b, 0)
            elif is_soft_fringe((r, g, b), bg_colors, bg_mask, x, y):
                alpha = fringe_alpha((r, g, b), bg_colors)
                if alpha < a:
                    out_px[x, y] = (r, g, b, alpha)
    output = remove_bright_outer_edge(output, passes=6)
    return output


def tight_crop(image: Image.Image, padding: int = 4) -> Image.Image:
    px = image.load()
    w, h = image.size
    min_x, min_y, max_x, max_y = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if max_x < min_x:
        return image
    left   = max(0, min_x - padding)
    top    = max(0, min_y - padding)
    right  = min(w, max_x + padding + 1)
    bottom = min(h, max_y + padding + 1)
    return image.crop((left, top, right, bottom))


# ── helpers (adapted from remove_asset_checkerboard.py) ──────────────────────

def estimate_background_colors(image: Image.Image) -> list[tuple[int, int, int]]:
    pixels = image.load()
    w, h = image.size
    border: list[tuple[int, int, int]] = []
    for x in range(w):
        border.append(quantize_rgb(pixels[x, 0][:3]))
        border.append(quantize_rgb(pixels[x, h - 1][:3]))
    for y in range(h):
        border.append(quantize_rgb(pixels[0, y][:3]))
        border.append(quantize_rgb(pixels[w - 1, y][:3]))
    counts = Counter(rgb for rgb in border if looks_like_background(rgb))
    return [rgb for rgb, _ in counts.most_common(4)] or [(248, 248, 248), (242, 242, 242)]


def edge_connected_background_mask(pixels, width, height, bg_colors):
    mask = [[False] * width for _ in range(height)]
    queue: deque[tuple[int, int]] = deque()

    def try_seed(x: int, y: int) -> None:
        if mask[y][x]:
            return
        if not pixel_matches_background(pixels[x, y][:3], bg_colors):
            return
        mask[y][x] = True
        queue.append((x, y))

    for x in range(width):
        try_seed(x, 0)
        try_seed(x, height - 1)
    for y in range(height):
        try_seed(0, y)
        try_seed(width - 1, y)
    while queue:
        x, y = queue.popleft()
        for dx, dy in NEIGHBORS:
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= width or ny >= height or mask[ny][nx]:
                continue
            if not pixel_matches_background(pixels[nx, ny][:3], bg_colors):
                continue
            mask[ny][nx] = True
            queue.append((nx, ny))
    return mask


def contract_bright_edge(pixels, bg_mask, bg_colors, passes=1):
    height = len(bg_mask)
    width  = len(bg_mask[0])
    mask = [row[:] for row in bg_mask]
    for _ in range(passes):
        next_mask = [row[:] for row in mask]
        for y in range(height):
            for x in range(width):
                if mask[y][x]:
                    continue
                rgb = pixels[x, y][:3]
                if not looks_like_background(rgb):
                    continue
                if nearest_dist(rgb, bg_colors) > COLOR_TOLERANCE + 36:
                    continue
                for dx, dy in ALL_NEIGHBORS:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and mask[ny][nx]:
                        next_mask[y][x] = True
                        break
        mask = next_mask
    return mask


def remove_bright_outer_edge(image: Image.Image, passes=1) -> Image.Image:
    output = image.copy()
    for _ in range(passes):
        pixels = output.load()
        w, h = output.size
        to_clear = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = pixels[x, y]
                if a <= 0:
                    continue
                if not touches_transparent(pixels, w, h, x, y):
                    continue
                luma = (r + g + b) // 3
                chroma = max(r, g, b) - min(r, g, b)
                if luma >= 72 or (luma >= 54 and chroma <= 20):
                    to_clear.append((x, y))
        if not to_clear:
            break
        for x, y in to_clear:
            r, g, b, _ = pixels[x, y]
            pixels[x, y] = (r, g, b, 0)
    return output


def touches_transparent(pixels, w, h, x, y) -> bool:
    for dx, dy in ALL_NEIGHBORS:
        nx, ny = x + dx, y + dy
        if nx < 0 or ny < 0 or nx >= w or ny >= h:
            return True
        if pixels[nx, ny][3] == 0:
            return True
    return False


def is_soft_fringe(rgb, bg_colors, bg_mask, x, y) -> bool:
    if not looks_like_background(rgb):
        return False
    if nearest_dist(rgb, bg_colors) > COLOR_TOLERANCE + 16:
        return False
    h = len(bg_mask)
    w = len(bg_mask[0])
    for dx, dy in ALL_NEIGHBORS:
        nx, ny = x + dx, y + dy
        if 0 <= nx < w and 0 <= ny < h and bg_mask[ny][nx]:
            return True
    return False


def fringe_alpha(rgb, bg_colors) -> int:
    d = nearest_dist(rgb, bg_colors)
    if d <= 10:
        return 0
    if d >= COLOR_TOLERANCE + 16:
        return 255
    return int(255 * (d - 10) / (COLOR_TOLERANCE + 6))


def pixel_matches_background(rgb, bg_colors) -> bool:
    return looks_like_background(rgb) and nearest_dist(rgb, bg_colors) <= COLOR_TOLERANCE


def looks_like_background(rgb) -> bool:
    r, g, b = rgb
    luma = (r + g + b) // 3
    chroma = max(rgb) - min(rgb)
    return luma >= LUMA_MIN and chroma <= CHROMA_MAX


def nearest_dist(rgb, colors) -> int:
    return min(abs(rgb[0]-c[0]) + abs(rgb[1]-c[1]) + abs(rgb[2]-c[2]) for c in colors)


def quantize_rgb(rgb) -> tuple[int, int, int]:
    return tuple((ch // QUANTIZE_STEP) * QUANTIZE_STEP for ch in rgb)


# ── preview ───────────────────────────────────────────────────────────────────

def make_preview(image: Image.Image) -> Image.Image:
    size = 320
    card = Image.new("RGBA", (size, size), (10, 18, 14, 255))
    checker = make_checkerboard(size - 16, size - 16)
    card.alpha_composite(checker, (8, 8))
    thumb = image.copy()
    thumb.thumbnail((size - 24, size - 24))
    x = (size - thumb.width) // 2
    y = (size - thumb.height) // 2
    card.alpha_composite(thumb, (x, y))
    return card


def make_checkerboard(w, h, cell=24) -> Image.Image:
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            v = 232 if ((x // cell) + (y // cell)) % 2 == 0 else 196
            px[x, y] = (v, v, v, 255)
    return img


if __name__ == "__main__":
    main()
