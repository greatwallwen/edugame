from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[4] / "assets" / "games" / "ch11-band-defense"
BG_DIR = ROOT / "backgrounds"
SRC = BG_DIR / "band-defense-map-v2-screen.png"
OUT = BG_DIR / "band-defense-map-level1-watch-debug.png"


def _overlay(base: Image.Image, layer: Image.Image) -> None:
    base.alpha_composite(layer)


def _line_grid(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    for x in range(left + 18, right - 18, 32):
        alpha = 30 if x % 64 else 48
        draw.line((x, top + 22, x, bottom - 28), fill=(58, 196, 215, alpha), width=1)
    for y in range(top + 34, bottom - 28, 30):
        alpha = 24 if y % 60 else 42
        draw.line((left + 18, y, right - 18, y), fill=(74, 220, 185, alpha), width=1)


def _draw_panel_detail(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    draw.rounded_rectangle(box, radius=28, fill=(3, 18, 25, 72), outline=(72, 214, 224, 178), width=2)
    draw.rounded_rectangle(
        (left + 12, top + 14, right - 12, bottom - 14),
        radius=20,
        outline=(29, 112, 128, 126),
        width=1,
    )
    _line_grid(draw, (left + 12, top + 14, right - 12, bottom - 14))

    for y in (top + 74, top + 236, top + 438):
        draw.rounded_rectangle((left + 28, y, right - 28, y + 112), radius=12, outline=(36, 183, 200, 96), width=1)
        for i in range(6):
            x0 = left + 46 + i * 30
            draw.line((x0, y + 78, x0 + 18, y + 52 + (i % 3) * 11), fill=(62, 206, 222, 78), width=2)

    cx, cy = right - 78, top + 298
    for radius, alpha in ((58, 72), (40, 98), (22, 130)):
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=(65, 211, 224, alpha), width=2)
    draw.arc((cx - 54, cy - 54, cx + 54, cy + 54), 18, 122, fill=(116, 230, 174, 158), width=5)
    draw.arc((cx - 42, cy - 42, cx + 42, cy + 42), 198, 312, fill=(52, 154, 214, 122), width=3)

    for i, color in enumerate(((86, 214, 176, 210), (86, 214, 176, 180), (212, 160, 52, 188))):
        x = right - 82 + i * 18
        draw.ellipse((x, top + 34, x + 9, top + 43), fill=color)

    draw.rounded_rectangle((left + 34, bottom - 96, right - 34, bottom - 40), radius=10, outline=(56, 196, 212, 86), width=1)
    for i in range(16):
        x = left + 52 + i * 13
        height = 10 + (i * 7) % 36
        draw.rounded_rectangle((x, bottom - 52 - height, x + 4, bottom - 52), radius=2, fill=(65, 196, 220, 66))


def _draw_watch_hardware(base: Image.Image) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    panel = (948, 10, 1268, 710)
    draw.rounded_rectangle((932, 0, 1279, 719), radius=38, fill=(8, 18, 24, 108))
    draw.rounded_rectangle((940, 6, 1274, 714), radius=32, outline=(144, 170, 174, 116), width=3)
    draw.rounded_rectangle((946, 14, 1266, 706), radius=26, outline=(16, 45, 58, 210), width=5)
    draw.rounded_rectangle((1270, 250, 1279, 352), radius=5, fill=(16, 34, 42, 190))
    draw.rounded_rectangle((1270, 394, 1279, 462), radius=5, fill=(16, 34, 42, 170))

    _draw_panel_detail(draw, panel)

    shine = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.polygon(
        [(974, 18), (1110, 18), (1000, 708), (934, 708)],
        fill=(255, 255, 255, 28),
    )
    shine = shine.filter(ImageFilter.GaussianBlur(4))
    _overlay(layer, shine)

    draw.rounded_rectangle((18, 10, 928, 710), radius=24, outline=(104, 132, 144, 64), width=2)
    draw.line((40, 704, 910, 704), fill=(0, 0, 0, 42), width=3)
    draw.line((42, 16, 914, 16), fill=(255, 255, 255, 52), width=2)

    _overlay(base, layer.filter(ImageFilter.GaussianBlur(0.3)))


def main() -> None:
    base = Image.open(SRC).convert("RGBA")
    _draw_watch_hardware(base)
    base.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
