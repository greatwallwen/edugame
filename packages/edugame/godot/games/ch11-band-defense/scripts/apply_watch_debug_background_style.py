from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[4] / "assets" / "games" / "ch11-band-defense"
BG_DIR = ROOT / "backgrounds"
OUT = BG_DIR / "band-defense-map-level1-watch-debug.png"

CANVAS = (1280, 720)
PLAY_RECT = (0, 0, 940, 720)
HUD_RECT = (948, 10, 1268, 710)

LEVEL_ONE_PATH = [
    (68, 360),
    (165, 190),
    (365, 190),
    (475, 190),
    (640, 360),
    (690, 445),
    (815, 320),
    (884, 360),
]

LEVEL_ONE_SLOTS = [(256, 263), (439, 264), (531, 436), (739, 294)]


def _fit_to_canvas(image: Image.Image) -> Image.Image:
    width, height = image.size
    target_w, target_h = CANVAS
    scale = max(target_w / width, target_h / height)
    resized = image.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h)).convert("RGBA")


def _quiet_play_area(base: Image.Image) -> None:
    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    play = base.crop(PLAY_RECT).filter(ImageFilter.GaussianBlur(0.8)).convert("RGBA")
    veil = Image.new("RGBA", play.size, (232, 244, 248, 132))
    play.alpha_composite(veil)
    layer.paste(play, PLAY_RECT[:2])
    base.alpha_composite(layer)


def _draw_route_and_slots(base: Image.Image) -> None:
    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    for width, color in (
        (19, (53, 224, 242, 48)),
        (13, (49, 208, 232, 104)),
        (7, (116, 245, 255, 220)),
        (3, (238, 255, 255, 230)),
    ):
        draw.line(LEVEL_ONE_PATH, fill=color, width=width, joint="curve")
    for i in range(len(LEVEL_ONE_PATH) - 1):
        ax, ay = LEVEL_ONE_PATH[i]
        bx, by = LEVEL_ONE_PATH[i + 1]
        mx = ax * 0.58 + bx * 0.42
        my = ay * 0.58 + by * 0.42
        draw.line((mx - 9, my - 5, mx, my, mx - 9, my + 5), fill=(245, 255, 255, 170), width=2)

    for x, y in LEVEL_ONE_SLOTS:
        for radius, color, width in (
            (45, (40, 126, 168, 78), 2),
            (37, (246, 252, 255, 220), 6),
            (29, (78, 103, 118, 170), 2),
        ):
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=color, width=width)
        draw.ellipse((x - 26, y - 26, x + 26, y + 26), fill=(217, 228, 233, 216), outline=(92, 110, 122, 190), width=2)
        draw.line((x - 13, y, x + 13, y), fill=(57, 177, 236, 186), width=3)
        draw.line((x, y - 13, x, y + 13), fill=(57, 177, 236, 186), width=3)

    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.15)))


def _protect_right_hud_readability(base: Image.Image) -> None:
    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    left, top, right, bottom = HUD_RECT
    draw.rounded_rectangle(HUD_RECT, radius=30, fill=(2, 19, 28, 56), outline=(65, 219, 226, 180), width=2)
    draw.rounded_rectangle((left + 16, top + 22, right - 16, bottom - 20), radius=20, outline=(70, 204, 216, 92), width=1)

    for y in (top + 58, top + 214, top + 430):
        draw.rounded_rectangle((left + 30, y, right - 30, y + 104), radius=12, outline=(70, 204, 216, 72), width=1)

    cx, cy = right - 78, top + 294
    for radius, alpha in ((55, 78), (38, 118), (21, 150)):
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=(72, 224, 228, alpha), width=2)
    draw.arc((cx - 50, cy - 50, cx + 50, cy + 50), 20, 132, fill=(126, 230, 171, 162), width=5)

    for i in range(14):
        x = left + 48 + i * 13
        height = 12 + (i * 9) % 36
        draw.rounded_rectangle((x, bottom - 70 - height, x + 5, bottom - 70), radius=2, fill=(70, 202, 222, 78))

    shine = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.polygon([(972, 18), (1106, 18), (1000, 708), (936, 708)], fill=(255, 255, 255, 28))
    layer.alpha_composite(shine.filter(ImageFilter.GaussianBlur(4)))
    base.alpha_composite(layer)


def apply_style(source: Path, out: Path = OUT) -> None:
    image = _fit_to_canvas(Image.open(source).convert("RGBA"))
    _quiet_play_area(image)
    _protect_right_hud_readability(image)
    _draw_route_and_slots(image)
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out)
    print(f"wrote {out}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--out", default=OUT, type=Path)
    args = parser.parse_args()
    apply_style(args.source, args.out)


if __name__ == "__main__":
    main()
