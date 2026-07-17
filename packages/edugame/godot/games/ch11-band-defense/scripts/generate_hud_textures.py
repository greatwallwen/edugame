from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


GAME_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = GAME_ROOT / "assets" / "staged-production" / "hud"
LIVE_DIR = GAME_ROOT / "assets" / "generated"
AA_SCALE = 4

CYAN = (42, 188, 203, 255)
GREEN = (78, 202, 132, 255)
AMBER = (231, 168, 50, 255)
RED = (220, 72, 72, 255)
INK = (9, 15, 22, 255)
GLASS = (248, 252, 255, 255)
GLASS_SOFT = (255, 255, 255, 252)
STROKE = (188, 215, 222, 118)
STROKE_MUTED = (206, 224, 230, 76)
INNER_LINE = (78, 132, 146, 58)
INNER_SHADOW = (24, 52, 64, 40)
IOS_SURFACE_TOP = (255, 255, 255, 255)
IOS_SURFACE_BOTTOM = (236, 244, 249, 255)
IOS_CANVAS_TOP = (249, 252, 255, 255)
IOS_CANVAS_BOTTOM = (229, 239, 246, 255)


def _scaled_size(size: tuple[int, int]) -> tuple[int, int]:
    return (size[0] * AA_SCALE, size[1] * AA_SCALE)


def _scaled_box(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    return tuple(int(round(value * AA_SCALE)) for value in box)


def _scaled_point(point: tuple[int, int]) -> tuple[int, int]:
    return (int(round(point[0] * AA_SCALE)), int(round(point[1] * AA_SCALE)))


def _scaled_value(value: float) -> int:
    return max(1, int(round(value * AA_SCALE)))


def _finish_antialias(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return image.resize(size, Image.Resampling.LANCZOS)


def _rounded_rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill, outline=None, width: int = 1) -> None:
    draw.rounded_rectangle(
        _scaled_box(box),
        radius=_scaled_value(radius),
        fill=fill,
        outline=outline,
        width=_scaled_value(width),
    )


def _soft_glow(size: tuple[int, int], draw_fn, blur: float = 8.0) -> Image.Image:
    layer = Image.new("RGBA", _scaled_size(size), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer, "RGBA"))
    return layer.filter(ImageFilter.GaussianBlur(blur * AA_SCALE))


def _add_watch_noise(image: Image.Image, box: tuple[int, int, int, int], alpha: int = 18) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    x0, y0, x1, y1 = box
    for x in range(x0 + 18, x1 - 18, 24):
        for y in range(y0 + 18, y1 - 18, 22):
            if (x // 24 + y // 22) % 4 == 0:
                sx, sy = _scaled_point((x, y))
                draw.rectangle((sx, sy, sx + _scaled_value(1), sy + _scaled_value(1)), fill=(100, 225, 220, alpha))


def _add_glass_highlight(image: Image.Image, box: tuple[int, int, int, int]) -> None:
    shine = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shine, "RGBA")
    x0, y0, x1, y1 = box
    draw.polygon(
        [
            _scaled_point((x0 + 20, y0 + 6)),
            _scaled_point((x1 - 80, y0 + 6)),
            _scaled_point((x1 - 190, y1 - 12)),
            _scaled_point((x0 - 20, y1 - 12)),
        ],
        fill=(255, 255, 255, 18),
    )
    image.alpha_composite(shine.filter(ImageFilter.GaussianBlur(2 * AA_SCALE)))


def _add_ios_sheen(image: Image.Image, box: tuple[int, int, int, int], max_alpha: int = 58) -> None:
    sheen = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheen, "RGBA")
    x0, y0, x1, y1 = _scaled_box(box)
    height = max(1, y1 - y0)
    for y in range(y0, y1):
        t = (y - y0) / height
        alpha = int(max_alpha * (1.0 - t) ** 1.8)
        if alpha > 0:
            draw.line((x0, y, x1, y), fill=(255, 255, 255, alpha), width=1)
    image.alpha_composite(sheen.filter(ImageFilter.GaussianBlur(1.2 * AA_SCALE)))


def _add_rounded_vertical_gradient(
    image: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    top_color: tuple[int, int, int, int],
    bottom_color: tuple[int, int, int, int],
) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    layer_draw = ImageDraw.Draw(layer, "RGBA")
    x0, y0, x1, y1 = _scaled_box(box)
    height = max(1, y1 - y0)
    for y in range(y0, y1 + 1):
        t = (y - y0) / height
        color = tuple(int(round(top_color[i] * (1.0 - t) + bottom_color[i] * t)) for i in range(4))
        layer_draw.line((x0, y, x1, y), fill=color, width=1)
    mask = Image.new("L", image.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(_scaled_box(box), radius=_scaled_value(radius), fill=255)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))
    image.alpha_composite(layer)


def _add_card_shadow(
    image: Image.Image,
    size: tuple[int, int],
    box: tuple[int, int, int, int],
    radius: int,
    alpha: int = 54,
    y_offset: int = 7,
) -> None:
    x0, y0, x1, y1 = box
    shadow_box = (x0, y0 + y_offset, x1, y1 + y_offset)
    image.alpha_composite(
        _soft_glow(
            size,
            lambda draw: _rounded_rect(draw, shadow_box, radius, (48, 76, 96, alpha)),
            8.0,
        )
    )


def _add_inner_shadow(image: Image.Image, box: tuple[int, int, int, int], radius: int, alpha: int = 46) -> None:
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow, "RGBA")
    x0, y0, x1, y1 = box
    for offset, weight in [(0, alpha), (3, int(alpha * 0.52)), (7, int(alpha * 0.26))]:
        _rounded_rect(
            draw,
            (x0 + offset, y0 + offset, x1 - offset, y1 - offset),
            max(2, radius - offset),
            None,
            (12, 38, 46, weight),
            1,
        )
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(0.9 * AA_SCALE)))


def _add_micro_grid(image: Image.Image, box: tuple[int, int, int, int], alpha: int = 18) -> None:
    return


def _force_opaque_region(image: Image.Image, box: tuple[int, int, int, int], radius: int) -> None:
    mask = Image.new("L", image.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(_scaled_box(box), radius=_scaled_value(radius), fill=255)
    alpha = image.getchannel("A")
    alpha = Image.composite(Image.new("L", image.size, 255), alpha, mask)
    image.putalpha(alpha)


def _draw_accent_rail(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color=CYAN, alpha: int = 170) -> None:
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(
        _scaled_box((x0, y0, x1, y1)),
        radius=_scaled_value(max(2, (y1 - y0) / 2)),
        fill=(*color[:3], alpha),
    )
    draw.rounded_rectangle(
        _scaled_box((x0 + 4, y0 + 1, x1 - 4, y1 - 1)),
        radius=_scaled_value(max(1, (y1 - y0 - 2) / 2)),
        fill=(255, 255, 255, 42),
    )


def _draw_status_dots(draw: ImageDraw.ImageDraw, origin: tuple[int, int], colors: list[tuple[int, int, int, int]]) -> None:
    x0, y0 = origin
    for i, color in enumerate(colors):
        x = x0 + i * 18
        draw.ellipse(_scaled_box((x, y0, x + 8, y0 + 8)), fill=color)


def _draw_tiny_wave(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color=CYAN) -> None:
    x0, y0, x1, y1 = box
    mid = (y0 + y1) // 2
    points = []
    width = x1 - x0
    heights = [0, -9, -4, 7, 3, -6, -10, 5, 8, -2, -7, 1, 10, 3, -4, 6]
    for i, h in enumerate(heights):
        x = x0 + int(width * i / (len(heights) - 1))
        points.append(_scaled_point((x, mid + h)))
    draw.line(points, fill=(*color[:3], 150), width=_scaled_value(2))


def make_panel_frame() -> Image.Image:
    size = (384, 384)
    image = Image.new("RGBA", _scaled_size(size), (0, 0, 0, 0))
    box = (10, 10, 374, 374)
    _add_card_shadow(image, size, box, 34, 14, 2)
    _add_rounded_vertical_gradient(image, box, 34, IOS_CANVAS_TOP, IOS_CANVAS_BOTTOM)
    _add_ios_sheen(image, (18, 18, 366, 116), 22)
    return _finish_antialias(image, size)


def make_dialog_frame() -> Image.Image:
    size = (512, 320)
    image = Image.new("RGBA", _scaled_size(size), (0, 0, 0, 0))
    box = (14, 14, 498, 306)
    _add_card_shadow(image, size, box, 30, 20, 4)
    _add_rounded_vertical_gradient(image, box, 30, IOS_CANVAS_TOP, IOS_CANVAS_BOTTOM)
    _add_ios_sheen(image, (24, 22, 488, 142), 24)
    return _finish_antialias(image, size)


def make_button_plate(primary: bool = False) -> Image.Image:
    size = (320, 96)
    image = Image.new("RGBA", _scaled_size(size), (0, 0, 0, 0))
    accent = GREEN if primary else CYAN
    if primary:
        fill = (230, 249, 240, 252)
    else:
        fill = (255, 255, 255, 252)
    box = (8, 12, 312, 84)
    _add_card_shadow(image, size, box, 30, 24 if primary else 18, 3)
    top = (248, 255, 251, 255) if primary else IOS_SURFACE_TOP
    bottom = (214, 241, 226, 255) if primary else IOS_SURFACE_BOTTOM
    _add_rounded_vertical_gradient(image, box, 30, top, bottom)
    _add_ios_sheen(image, (18, 16, 302, 44), 28 if primary else 18)
    return _finish_antialias(image, size)


def make_status_tray() -> Image.Image:
    size = (320, 96)
    image = Image.new("RGBA", _scaled_size(size), (0, 0, 0, 0))
    box = (8, 12, 312, 84)
    _add_card_shadow(image, size, box, 24, 16, 2)
    _add_rounded_vertical_gradient(image, box, 24, IOS_SURFACE_TOP, IOS_SURFACE_BOTTOM)
    _add_ios_sheen(image, (18, 18, 302, 44), 16)
    return _finish_antialias(image, size)


def make_section_card() -> Image.Image:
    size = (320, 240)
    image = Image.new("RGBA", _scaled_size(size), (0, 0, 0, 0))
    box = (10, 10, 310, 228)
    _add_card_shadow(image, size, box, 24, 24, 3)
    _add_rounded_vertical_gradient(image, box, 24, IOS_SURFACE_TOP, IOS_SURFACE_BOTTOM)
    _add_ios_sheen(image, (16, 16, 304, 74), 22)
    return _finish_antialias(image, size)


def make_text_plate() -> Image.Image:
    size = (320, 160)
    image = Image.new("RGBA", _scaled_size(size), (0, 0, 0, 0))
    box = (8, 10, 312, 150)
    _add_card_shadow(image, size, box, 20, 14, 2)
    _add_rounded_vertical_gradient(image, box, 20, IOS_SURFACE_TOP, IOS_SURFACE_BOTTOM)
    _add_ios_sheen(image, (14, 14, 306, 58), 18)
    return _finish_antialias(image, size)


def make_text_chip() -> Image.Image:
    size = (192, 72)
    image = Image.new("RGBA", _scaled_size(size), (0, 0, 0, 0))
    box = (8, 10, 184, 62)
    _add_rounded_vertical_gradient(image, box, 24, IOS_SURFACE_TOP, IOS_SURFACE_BOTTOM)
    _add_ios_sheen(image, (12, 12, 180, 34), 14)
    return _finish_antialias(image, size)


def write_manifest() -> None:
    payload = {
        "visual_cues": [
            "light smartwatch hidden debug mode",
            "real smartwatch glass system UI",
            "capsule controls",
            "ring progress and compact telemetry",
            "soft iOS card depth",
            "clean glass panels without background grid texture",
            "cyan green status with amber warnings",
        ],
        "assets": [
            "hud_panel_frame.png",
            "hud_button_plate.png",
            "hud_button_plate_primary.png",
            "hud_status_tray.png",
            "hud_dialog_frame.png",
            "hud_text_plate.png",
            "hud_text_chip.png",
            "hud_section_card.png",
        ],
    }
    (OUT_DIR / "hud-texture-manifest.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    LIVE_DIR.mkdir(parents=True, exist_ok=True)
    generated = {
        "hud_panel_frame.png": make_panel_frame(),
        "hud_button_plate.png": make_button_plate(False),
        "hud_button_plate_primary.png": make_button_plate(True),
        "hud_status_tray.png": make_status_tray(),
        "hud_dialog_frame.png": make_dialog_frame(),
        "hud_text_plate.png": make_text_plate(),
        "hud_text_chip.png": make_text_chip(),
        "hud_section_card.png": make_section_card(),
    }
    for filename, image in generated.items():
        image.save(OUT_DIR / filename)
        image.save(LIVE_DIR / filename)
    write_manifest()
    (LIVE_DIR / "hud-texture-manifest.json").write_text(
        (OUT_DIR / "hud-texture-manifest.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
