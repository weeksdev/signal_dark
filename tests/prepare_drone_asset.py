"""
Remove background from drone.png, crop tight, write RGBA to assets/.
Run: uv run --with pillow python3 tests/prepare_drone_asset.py
"""
from __future__ import annotations
from collections import Counter, deque
from pathlib import Path
from PIL import Image

ROOT    = Path(__file__).resolve().parents[1]
INPUT   = ROOT / "assets" / "drone.png"
OUTPUT  = ROOT / "assets" / "drone.png"
PREVIEW = ROOT / "tests" / "generated_transparent_assets" / "drone_preview_dark.png"

LUMA_MIN        = 228
CHROMA_MAX      = 22
COLOR_TOLERANCE = 30
QUANTIZE_STEP   = 6
CROP_PADDING    = 4

NEIGHBORS     = ((1,0),(-1,0),(0,1),(0,-1))
ALL_NEIGHBORS = ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1))


def main() -> None:
    print(f"Processing {INPUT.relative_to(ROOT)} …")
    result = clean_asset(INPUT)
    result = tight_crop(result, CROP_PADDING)
    result.save(OUTPUT)
    print(f"Saved {OUTPUT.relative_to(ROOT)}  ({result.size[0]}×{result.size[1]} RGBA)")
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    make_preview(result).save(PREVIEW)
    print(f"Preview → {PREVIEW.relative_to(ROOT)}")


def clean_asset(path: Path) -> Image.Image:
    image  = Image.open(path).convert("RGBA")
    pixels = image.load()
    w, h   = image.size
    bg     = estimate_background_colors(image)
    mask   = edge_connected_background_mask(pixels, w, h, bg)
    mask   = contract_bright_edge(pixels, mask, bg, passes=16)
    output = image.copy()
    out_px = output.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = out_px[x, y]
            if mask[y][x]:
                out_px[x, y] = (r, g, b, 0)
            elif is_soft_fringe((r, g, b), bg, mask, x, y):
                alpha = fringe_alpha((r, g, b), bg)
                if alpha < a:
                    out_px[x, y] = (r, g, b, alpha)
    return remove_bright_outer_edge(output, passes=6)


def tight_crop(image: Image.Image, padding: int = 4) -> Image.Image:
    px = image.load()
    w, h = image.size
    min_x, min_y, max_x, max_y = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                min_x = min(min_x, x); min_y = min(min_y, y)
                max_x = max(max_x, x); max_y = max(max_y, y)
    if max_x < min_x:
        return image
    return image.crop((max(0, min_x-padding), max(0, min_y-padding),
                       min(w, max_x+padding+1), min(h, max_y+padding+1)))


def estimate_background_colors(image: Image.Image) -> list:
    px = image.load()
    w, h = image.size
    border = []
    for x in range(w):
        border.append(quantize_rgb(px[x,0][:3])); border.append(quantize_rgb(px[x,h-1][:3]))
    for y in range(h):
        border.append(quantize_rgb(px[0,y][:3])); border.append(quantize_rgb(px[w-1,y][:3]))
    counts = Counter(rgb for rgb in border if looks_like_background(rgb))
    return [rgb for rgb,_ in counts.most_common(4)] or [(248,248,248),(242,242,242)]


def edge_connected_background_mask(pixels, width, height, bg_colors):
    mask = [[False]*width for _ in range(height)]
    queue: deque = deque()
    def try_seed(x, y):
        if mask[y][x] or not pixel_matches_background(pixels[x,y][:3], bg_colors): return
        mask[y][x] = True; queue.append((x,y))
    for x in range(width):  try_seed(x,0); try_seed(x,height-1)
    for y in range(height): try_seed(0,y); try_seed(width-1,y)
    while queue:
        x,y = queue.popleft()
        for dx,dy in NEIGHBORS:
            nx,ny = x+dx,y+dy
            if 0<=nx<width and 0<=ny<height and not mask[ny][nx] and pixel_matches_background(pixels[nx,ny][:3], bg_colors):
                mask[ny][nx] = True; queue.append((nx,ny))
    return mask


def contract_bright_edge(pixels, bg_mask, bg_colors, passes=1):
    h, w = len(bg_mask), len(bg_mask[0])
    mask = [row[:] for row in bg_mask]
    for _ in range(passes):
        next_mask = [row[:] for row in mask]
        for y in range(h):
            for x in range(w):
                if mask[y][x]: continue
                rgb = pixels[x,y][:3]
                if not looks_like_background(rgb): continue
                if nearest_dist(rgb, bg_colors) > COLOR_TOLERANCE+36: continue
                for dx,dy in ALL_NEIGHBORS:
                    nx,ny = x+dx,y+dy
                    if 0<=nx<w and 0<=ny<h and mask[ny][nx]:
                        next_mask[y][x] = True; break
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
                r,g,b,a = pixels[x,y]
                if a<=0 or not touches_transparent(pixels,w,h,x,y): continue
                luma = (r+g+b)//3; chroma = max(r,g,b)-min(r,g,b)
                if luma>=72 or (luma>=54 and chroma<=20): to_clear.append((x,y))
        if not to_clear: break
        for x,y in to_clear:
            r,g,b,_ = pixels[x,y]; pixels[x,y] = (r,g,b,0)
    return output


def touches_transparent(pixels, w, h, x, y):
    for dx,dy in ALL_NEIGHBORS:
        nx,ny = x+dx,y+dy
        if nx<0 or ny<0 or nx>=w or ny>=h or pixels[nx,ny][3]==0: return True
    return False


def is_soft_fringe(rgb, bg_colors, bg_mask, x, y):
    if not looks_like_background(rgb) or nearest_dist(rgb,bg_colors)>COLOR_TOLERANCE+16: return False
    h,w = len(bg_mask),len(bg_mask[0])
    for dx,dy in ALL_NEIGHBORS:
        nx,ny = x+dx,y+dy
        if 0<=nx<w and 0<=ny<h and bg_mask[ny][nx]: return True
    return False


def fringe_alpha(rgb, bg_colors):
    d = nearest_dist(rgb, bg_colors)
    if d<=10: return 0
    if d>=COLOR_TOLERANCE+16: return 255
    return int(255*(d-10)/(COLOR_TOLERANCE+6))


def pixel_matches_background(rgb, bg_colors):
    return looks_like_background(rgb) and nearest_dist(rgb,bg_colors)<=COLOR_TOLERANCE

def looks_like_background(rgb):
    r,g,b = rgb; luma=(r+g+b)//3; chroma=max(rgb)-min(rgb)
    return luma>=LUMA_MIN and chroma<=CHROMA_MAX

def nearest_dist(rgb, colors):
    return min(abs(rgb[0]-c[0])+abs(rgb[1]-c[1])+abs(rgb[2]-c[2]) for c in colors)

def quantize_rgb(rgb):
    return tuple((ch//QUANTIZE_STEP)*QUANTIZE_STEP for ch in rgb)


def make_preview(image: Image.Image) -> Image.Image:
    size = 320
    card = Image.new("RGBA", (size,size), (10,18,14,255))
    checker = Image.new("RGBA", (size-16,size-16))
    cpx = checker.load()
    cell = 24
    for y in range(size-16):
        for x in range(size-16):
            v = 232 if ((x//cell)+(y//cell))%2==0 else 196
            cpx[x,y] = (v,v,v,255)
    card.alpha_composite(checker, (8,8))
    thumb = image.copy(); thumb.thumbnail((size-24,size-24))
    card.alpha_composite(thumb, ((size-thumb.width)//2,(size-thumb.height)//2))
    return card


if __name__ == "__main__":
    main()
