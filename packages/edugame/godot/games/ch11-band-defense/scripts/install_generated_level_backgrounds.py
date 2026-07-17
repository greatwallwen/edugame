from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
AUDIT_DIR = ROOT / "visual-audit"
BACKGROUND_DIR = ROOT / "assets" / "backgrounds"
CANVAS = (1280, 720)
MAP_SIZE = (960, 720)

LEVEL_ONE_MAP = BACKGROUND_DIR / "band-defense-map-level1-watch-debug-map-layer.png"
LEVELS = {
    2: {
        "source": AUDIT_DIR / "image2-level2-clean-source.png",
        "output": BACKGROUND_DIR / "band-defense-map-level2-watch-debug-map-layer.png",
        "slots": [(214, 207), (476, 142), (332, 354), (550, 405), (762, 257), (806, 487)],
    },
    3: {
        "source": AUDIT_DIR / "image2-level3-clean-source.png",
        "output": BACKGROUND_DIR / "band-defense-map-level3-watch-debug-map-layer.png",
        "slots": [(212, 227), (362, 398), (476, 240), (562, 432), (644, 212), (772, 288), (826, 472)],
    },
}


def _is_red_divider(pixel: tuple[int, ...]) -> bool:
    red, green, blue = pixel[:3]
    return red >= 180 and red >= green * 1.45 and red >= blue * 1.25


def _detect_map_split(source: Image.Image) -> int:
    rgb = source.convert("RGB")
    threshold = int(rgb.height * 0.72)
    candidates = []
    for x in range(rgb.width):
        red_pixels = sum(1 for y in range(rgb.height) if _is_red_divider(rgb.getpixel((x, y))))
        if red_pixels >= threshold:
            candidates.append(x)
    if candidates:
        return min(candidates)
    return round(rgb.width * 0.75)


def normalize_source(source: Image.Image) -> Image.Image:
    split_x = _detect_map_split(source)
    map_crop = source.convert("RGBA").crop((0, 0, split_x, source.height))
    map_crop = map_crop.resize(MAP_SIZE, Image.Resampling.LANCZOS)
    normalized = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    normalized.alpha_composite(map_crop, (0, 0))
    return normalized


def extract_level_one_pad_stamp() -> Image.Image:
    level_one = Image.open(LEVEL_ONE_MAP).convert("RGBA")
    center_x, center_y = (214, 207)
    size = 96
    half = size // 2
    stamp = level_one.crop((center_x - half, center_y - half, center_x + half, center_y + half))

    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((5, 5, size - 6, size - 6), fill=255)
    draw.ellipse((21, 21, size - 22, size - 22), fill=0)

    amber_mask = Image.new("L", (size, size), 0)
    amber_pixels = amber_mask.load()
    stamp_pixels = stamp.convert("RGB").load()
    for y in range(size):
        for x in range(size):
            red, green, blue = stamp_pixels[x, y]
            if red >= 150 and 80 <= green <= 195 and blue <= 105 and red - green >= 35:
                amber_pixels[x, y] = 255
    amber_mask = amber_mask.filter(ImageFilter.MaxFilter(5))
    mask = ImageChops.lighter(mask, amber_mask)
    mask = mask.filter(ImageFilter.GaussianBlur(0.5))
    stamp.putalpha(mask)
    return stamp


def _mean_corner_color(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[float, float, float]:
    crop = image.crop(box).convert("RGB")
    pixels = list(crop.getdata())
    return tuple(sum(pixel[channel] for pixel in pixels) / len(pixels) for channel in range(3))


def _interpolated_surface_patch(target: Image.Image, variant_index: int) -> Image.Image:
    size = target.width
    corner = 16
    top_left = _mean_corner_color(target, (0, 0, corner, corner))
    top_right = _mean_corner_color(target, (size - corner, 0, size, corner))
    bottom_left = _mean_corner_color(target, (0, size - corner, corner, size))
    bottom_right = _mean_corner_color(target, (size - corner, size - corner, size, size))

    patch = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    pixels = patch.load()
    for y in range(size):
        vertical = y / max(1, size - 1)
        for x in range(size):
            horizontal = x / max(1, size - 1)
            noise = ((x * 19 + y * 23 + variant_index * 29) % 5) - 2
            color = []
            for channel in range(3):
                top = top_left[channel] * (1.0 - horizontal) + top_right[channel] * horizontal
                bottom = bottom_left[channel] * (1.0 - horizontal) + bottom_right[channel] * horizontal
                value = round(top * (1.0 - vertical) + bottom * vertical + noise)
                color.append(max(0, min(255, value)))
            pixels[x, y] = (color[0], color[1], color[2], 255)
    return patch


def restore_slot_surfaces(
    map_layer: Image.Image,
    centers: list[tuple[int, int]],
    source_box: tuple[int, int, int, int] = (400, 500, 528, 628),
) -> None:
    size = source_box[2] - source_box[0]
    if size != source_box[3] - source_box[1]:
        raise ValueError("surface source box must be square")
    blend_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(blend_mask).ellipse((6, 6, size - 7, size - 7), fill=255)
    blend_mask = blend_mask.filter(ImageFilter.GaussianBlur(4.0))

    half = size // 2
    for index, (center_x, center_y) in enumerate(centers):
        box = (center_x - half, center_y - half, center_x + half, center_y + half)
        target = map_layer.crop(box)
        variant = _interpolated_surface_patch(target, index)
        variant.putalpha(blend_mask)
        map_layer.alpha_composite(variant, (center_x - half, center_y - half))


def stamp_tower_pads(map_layer: Image.Image, stamp: Image.Image, centers: list[tuple[int, int]]) -> None:
    half_x = stamp.width // 2
    half_y = stamp.height // 2
    for center_x, center_y in centers:
        target_box = (center_x - half_x, center_y - half_y, center_x + half_x, center_y + half_y)
        target = map_layer.crop(target_box)
        source_mean = _mean_corner_color(stamp, (34, 34, 62, 62))
        target_mean = _mean_corner_color(target, (34, 34, 62, 62))
        adapted = stamp
        if max(source_mean) >= 30:
            shifted_channels = []
            for channel, source_value, target_value in zip(stamp.convert("RGB").split(), source_mean, target_mean):
                delta = round(target_value - source_value)
                shifted_channels.append(
                    channel.point(lambda value, offset=delta: max(0, min(255, value + offset)))
                )
            adapted = Image.merge("RGB", tuple(shifted_channels)).convert("RGBA")
            adapted.putalpha(stamp.getchannel("A"))
        map_layer.alpha_composite(adapted, (center_x - half_x, center_y - half_y))


def install_level(level_number: int, pad_stamp: Image.Image) -> Path:
    level = LEVELS[level_number]
    source_path = level["source"]
    output_path = level["output"]
    if not source_path.exists():
        raise FileNotFoundError(f"missing Image 2 source: {source_path}")

    normalized = normalize_source(Image.open(source_path))
    restore_slot_surfaces(normalized, level["slots"])
    stamp_tower_pads(normalized, pad_stamp, level["slots"])
    normalized.save(output_path)
    return output_path


def main() -> None:
    pad_stamp = extract_level_one_pad_stamp()
    for level_number in sorted(LEVELS):
        output = install_level(level_number, pad_stamp)
        print(f"installed {output}")


if __name__ == "__main__":
    main()
