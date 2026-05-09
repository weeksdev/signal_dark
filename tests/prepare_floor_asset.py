from __future__ import annotations

from collections import Counter, deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "tests" / "generated_transparent_assets"
SOURCE_NAMES = ["floor.png", "floor_2.png", "hideout.png", "enemy_4.png"]

LUMA_MIN = 232
CHROMA_MAX = 18
COLOR_TOLERANCE = 28
QUANTIZE_STEP = 6
NEIGHBORS = ((1, 0), (-1, 0), (0, 1), (0, -1))
ALL_NEIGHBORS = (
	(1, 0), (-1, 0), (0, 1), (0, -1),
	(1, 1), (1, -1), (-1, 1), (-1, -1),
)


def main() -> None:
	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	for source_name in SOURCE_NAMES:
		source_path = ROOT / "assets" / source_name
		if not source_path.exists():
			continue
		cleaned = clean_and_crop_floor(source_path)
		output_path = OUTPUT_DIR / source_name
		preview_path = OUTPUT_DIR / source_name.replace(".png", "_preview_dark.png")
		cleaned.save(output_path)
		build_dark_preview(cleaned).save(preview_path)
		print(f"wrote {output_path.relative_to(ROOT)}")
		print(f"wrote {preview_path.relative_to(ROOT)}")


def clean_and_crop_floor(path: Path) -> Image.Image:
	image = Image.open(path).convert("RGBA")
	pixels = image.load()
	width, height = image.size
	background_colors = estimate_background_colors(image)
	background_mask = edge_connected_background_mask(pixels, width, height, background_colors)
	background_mask = contract_bright_edge(pixels, background_mask, background_colors, passes=16)

	output = image.copy()
	out_pixels = output.load()
	for y in range(height):
		for x in range(width):
			r, g, b, a = out_pixels[x, y]
			if background_mask[y][x]:
				out_pixels[x, y] = (r, g, b, 0)
				continue
			if is_soft_background_fringe((r, g, b), background_colors, background_mask, x, y):
				alpha = fringe_alpha((r, g, b), background_colors)
				if alpha < a:
					out_pixels[x, y] = (r, g, b, alpha)

	output = remove_bright_outer_edge(output, passes=8)
	bbox = output.getbbox()
	if bbox is None:
		return output
	return output.crop(bbox)


def estimate_background_colors(image: Image.Image) -> list[tuple[int, int, int]]:
	pixels = image.load()
	width, height = image.size
	border: list[tuple[int, int, int]] = []
	for x in range(width):
		border.append(quantize_rgb(pixels[x, 0][:3]))
		border.append(quantize_rgb(pixels[x, height - 1][:3]))
	for y in range(height):
		border.append(quantize_rgb(pixels[0, y][:3]))
		border.append(quantize_rgb(pixels[width - 1, y][:3]))
	counts = Counter(rgb for rgb in border if looks_like_background(rgb))
	return [rgb for rgb, _count in counts.most_common(4)] or [(248, 248, 248), (242, 242, 242)]


def edge_connected_background_mask(
	pixels,
	width: int,
	height: int,
	background_colors: list[tuple[int, int, int]],
) -> list[list[bool]]:
	mask = [[False] * width for _ in range(height)]
	queue: deque[tuple[int, int]] = deque()

	def try_seed(x: int, y: int) -> None:
		if mask[y][x]:
			return
		if not pixel_matches_background(pixels[x, y][:3], background_colors):
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
			nx = x + dx
			ny = y + dy
			if nx < 0 or ny < 0 or nx >= width or ny >= height or mask[ny][nx]:
				continue
			if not pixel_matches_background(pixels[nx, ny][:3], background_colors):
				continue
			mask[ny][nx] = True
			queue.append((nx, ny))
	return mask


def contract_bright_edge(
	pixels,
	background_mask: list[list[bool]],
	background_colors: list[tuple[int, int, int]],
	passes: int,
) -> list[list[bool]]:
	height = len(background_mask)
	width = len(background_mask[0])
	mask = [row[:] for row in background_mask]
	for _pass in range(passes):
		next_mask = [row[:] for row in mask]
		for y in range(height):
			for x in range(width):
				if mask[y][x]:
					continue
				rgb = pixels[x, y][:3]
				if not looks_like_background(rgb):
					continue
				if nearest_color_distance(rgb, background_colors) > COLOR_TOLERANCE + 36:
					continue
				for dx, dy in ALL_NEIGHBORS:
					nx = x + dx
					ny = y + dy
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					if mask[ny][nx]:
						next_mask[y][x] = True
						break
		mask = next_mask
	return mask


def remove_bright_outer_edge(image: Image.Image, passes: int) -> Image.Image:
	output = image.copy()
	for _pass in range(passes):
		pixels = output.load()
		width, height = output.size
		to_clear: list[tuple[int, int]] = []
		for y in range(height):
			for x in range(width):
				r, g, b, a = pixels[x, y]
				if a <= 0:
					continue
				if not touches_transparent(pixels, width, height, x, y):
					continue
				luma = (r + g + b) // 3
				chroma = max(r, g, b) - min(r, g, b)
				if luma >= 72 or (luma >= 54 and chroma <= 20):
					to_clear.append((x, y))
		if not to_clear:
			break
		for x, y in to_clear:
			r, g, b, _a = pixels[x, y]
			pixels[x, y] = (r, g, b, 0)
	return output


def touches_transparent(pixels, width: int, height: int, x: int, y: int) -> bool:
	for dx, dy in ALL_NEIGHBORS:
		nx = x + dx
		ny = y + dy
		if nx < 0 or ny < 0 or nx >= width or ny >= height:
			return True
		if pixels[nx, ny][3] == 0:
			return True
	return False


def is_soft_background_fringe(
	rgb: tuple[int, int, int],
	background_colors: list[tuple[int, int, int]],
	background_mask: list[list[bool]],
	x: int,
	y: int,
) -> bool:
	if not looks_like_background(rgb):
		return False
	if nearest_color_distance(rgb, background_colors) > COLOR_TOLERANCE + 16:
		return False
	height = len(background_mask)
	width = len(background_mask[0])
	for dx, dy in ALL_NEIGHBORS:
		nx = x + dx
		ny = y + dy
		if nx < 0 or ny < 0 or nx >= width or ny >= height:
			continue
		if background_mask[ny][nx]:
			return True
	return False


def fringe_alpha(rgb: tuple[int, int, int], background_colors: list[tuple[int, int, int]]) -> int:
	distance = nearest_color_distance(rgb, background_colors)
	if distance <= 10:
		return 0
	if distance >= COLOR_TOLERANCE + 16:
		return 255
	return int(255 * (distance - 10) / (COLOR_TOLERANCE + 6))


def pixel_matches_background(rgb: tuple[int, int, int], background_colors: list[tuple[int, int, int]]) -> bool:
	return looks_like_background(rgb) and nearest_color_distance(rgb, background_colors) <= COLOR_TOLERANCE


def looks_like_background(rgb: tuple[int, int, int]) -> bool:
	r, g, b = rgb
	luma = (r + g + b) // 3
	chroma = max(rgb) - min(rgb)
	return luma >= LUMA_MIN and chroma <= CHROMA_MAX


def nearest_color_distance(rgb: tuple[int, int, int], colors: list[tuple[int, int, int]]) -> int:
	return min(manhattan_distance(rgb, color) for color in colors)


def manhattan_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
	return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def quantize_rgb(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
	return tuple((channel // QUANTIZE_STEP) * QUANTIZE_STEP for channel in rgb)


def build_dark_preview(image: Image.Image) -> Image.Image:
	card = Image.new("RGBA", image.size, (10, 18, 14, 255))
	card.alpha_composite(image)
	return card


if __name__ == "__main__":
	main()
