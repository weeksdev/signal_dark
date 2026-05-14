"""
Generate a preview image showing all enemy sprites on a dark background.
Verifies each asset is RGBA, has visible content, and displays at correct size.

Run: uv run --with pillow python3 tests/screenshot_enemy_sprites.py
Output: tests/generated_transparent_assets/enemy_sprite_sheet.png
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT   = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
OUT    = ROOT / "tests" / "generated_transparent_assets" / "enemy_sprite_sheet.png"

# (filename, enemy_name, game_scale)
ENEMIES = [
    ("enemy_1.png",            "Wisp",    0.0265),
    ("enemy_2.png",            "Hunter",  0.0265),
    ("enemy_3.png",            "Prism",   0.0265),
    ("enemy_4.png",            "Sweeper", 0.0255),
    ("star_enemy.png",         "Pulsar",  0.029),
    ("enemy_stationary_1.png", "Sentry",     0.032),
    ("triangle_enemy.png",     "WallSensor", 0.028),
]

CARD_W, CARD_H = 200, 220
COLS         = 3
BG           = (8, 18, 12, 255)
LABEL_COLOR  = (120, 220, 150, 255)
WARN_COLOR   = (255, 80, 60, 255)
GAME_PREVIEW_SIZE = 80  # pixels — sprites rendered at ~30–40px in game; use 80 for visibility


def main() -> None:
    rows = (len(ENEMIES) + COLS - 1) // COLS
    sheet_w = COLS * CARD_W
    sheet_h = rows * CARD_H + 40
    sheet = Image.new("RGBA", (sheet_w, sheet_h), BG)
    draw  = ImageDraw.Draw(sheet)

    # Title
    draw.text((10, 10), "SIGNAL DARK — Enemy Sprite Verification", fill=(80, 200, 120, 220))

    issues: list[str] = []

    for idx, (fname, name, scale) in enumerate(ENEMIES):
        col = idx % COLS
        row = idx // COLS
        x0  = col * CARD_W
        y0  = row * CARD_H + 40

        path = ASSETS / fname
        ok   = True
        note = ""

        if not path.exists():
            issues.append(f"{name}: {fname} MISSING")
            draw.rectangle([x0+4, y0+4, x0+CARD_W-4, y0+CARD_H-4],
                           outline=WARN_COLOR[:3], width=2)
            draw.text((x0+10, y0+CARD_H//2), f"{name}\nMISSING", fill=WARN_COLOR)
            continue

        img = Image.open(path).convert("RGBA")

        # Check mode
        if img.mode != "RGBA":
            note = "⚠ not RGBA"
            ok = False

        # Check content (non-transparent pixels)
        px      = img.load()
        nonzero = sum(1 for y in range(0, img.height, 4)
                      for x in range(0, img.width, 4) if px[x, y][3] > 10)
        if nonzero == 0:
            note = "⚠ fully transparent"
            ok = False

        # Compute game-size render (approximate)
        game_w = int(img.width  * scale)
        game_h = int(img.height * scale)

        # Thumbnail at GAME_PREVIEW_SIZE for display
        thumb = img.copy()
        thumb.thumbnail((GAME_PREVIEW_SIZE, GAME_PREVIEW_SIZE), Image.LANCZOS)

        # Dark card background
        card_bg = (14, 28, 20, 255) if ok else (40, 14, 14, 255)
        draw.rectangle([x0, y0, x0+CARD_W, y0+CARD_H], fill=card_bg)
        draw.rectangle([x0+2, y0+2, x0+CARD_W-2, y0+CARD_H-2],
                       outline=(40, 120, 60, 180) if ok else WARN_COLOR[:3], width=1)

        # Center thumb
        tx = x0 + (CARD_W - thumb.width)  // 2
        ty = y0 + 10 + (CARD_H - 10 - 50 - thumb.height) // 2
        sheet.alpha_composite(thumb, (tx, ty))

        # Labels
        label_y = y0 + CARD_H - 50
        draw.text((x0+8, label_y),      name,  fill=LABEL_COLOR if ok else WARN_COLOR)
        draw.text((x0+8, label_y+16),   fname, fill=(80, 140, 100, 180))
        draw.text((x0+8, label_y+30),
                  f"{img.width}×{img.height}  →  {game_w}×{game_h}px",
                  fill=(60, 120, 80, 180))
        if note:
            draw.text((x0+8, label_y+44), note, fill=WARN_COLOR)
            issues.append(f"{name}: {note}")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"Saved → {OUT.relative_to(ROOT)}")

    if issues:
        print("\nISSUES FOUND:")
        for iss in issues:
            print(f"  ✗ {iss}")
    else:
        print(f"\nAll {len(ENEMIES)} enemy sprites OK.")


if __name__ == "__main__":
    main()
