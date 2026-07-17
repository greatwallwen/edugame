from __future__ import annotations

import math
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
BG_DIR = ROOT / "assets" / "backgrounds"
VISUAL_AUDIT_DIR = ROOT / "visual-audit"
LEVEL_ONE_STYLE_SOURCE = VISUAL_AUDIT_DIR / "level1-map-stylized-2d-edge-sharp-grille-candidate-layer.png"
LEVEL_ONE_MAP_LAYER = BG_DIR / "band-defense-map-level1-watch-debug-map-layer.png"
LEVEL_ONE_HUD_LAYER = BG_DIR / "band-defense-hud-level1-watch-debug-layer.png"
LEVEL_ONE_COMPOSITE = BG_DIR / "band-defense-map-level1-watch-debug.png"

CANVAS = (1280, 720)
MAP_W = 960
BOARD_PANEL = (8, 16, 940, 678)
BOARD_INNER = (58, 54, 900, 642)
ETCH = (86, 92, 90, 118)
ETCH_LIGHT = (244, 246, 240, 112)

LEVEL_ONE_CONNECTED_PATH = [
    (76, 350),
    (112, 321),
    (185, 260),
    (340, 260),
    (520, 260),
    (639, 322),
    (639, 385),
    (695, 440),
    (734, 440),
    (815, 350),
    (878, 350),
]

LEVELS = {
    2: {
        "out": "band-defense-map-level2-watch-debug-map-layer.png",
        "seed": 20260709,
        "accent": (34, 204, 218),
        "warm": (235, 184, 60),
        "path": [
            (76, 332),
            (132, 332),
            (190, 332),
            (262, 278),
            (250, 440),
            (410, 440),
            (410, 278),
            (434, 210),
            (552, 210),
            (622, 286),
            (622, 372),
            (690, 426),
            (816, 426),
            (850, 382),
            (878, 354),
        ],
        "ports": [(76, 332), (878, 354)],
        "slots": [(214, 207), (476, 142), (332, 354), (550, 405), (762, 257), (806, 487)],
        "modules": [
            (66, 64, 320, 134),
            (676, 74, 878, 150),
            (84, 548, 330, 638),
            (690, 548, 858, 632),
        ],
        "chips": [
            (48, 248, 86, 316),
            (340, 52, 418, 78),
            (566, 442, 612, 488),
            (830, 190, 894, 240),
            (372, 604, 428, 654),
        ],
    },
    3: {
        "out": "band-defense-map-level3-watch-debug-map-layer.png",
        "seed": 20260710,
        "accent": (26, 190, 225),
        "warm": (236, 176, 56),
        "path": [
            (76, 342),
            (124, 342),
            (178, 342),
            (256, 292),
            (256, 470),
            (454, 470),
            (454, 350),
            (506, 350),
            (578, 270),
            (656, 270),
            (712, 342),
            (712, 410),
            (792, 410),
            (843, 372),
            (878, 350),
        ],
        "ports": [(76, 342), (878, 350)],
        "slots": [(212, 227), (362, 398), (476, 240), (562, 432), (644, 212), (772, 288), (826, 472)],
        "modules": [
            (70, 62, 302, 132),
            (360, 52, 582, 102),
            (690, 70, 878, 146),
            (84, 534, 300, 644),
            (438, 568, 626, 646),
            (704, 542, 870, 632),
        ],
        "chips": [
            (44, 244, 90, 318),
            (330, 152, 390, 202),
            (524, 126, 594, 178),
            (822, 188, 894, 238),
            (332, 596, 392, 646),
            (620, 498, 664, 544),
        ],
    },
}


def _jitter(value: int, delta: int, rng: random.Random) -> int:
    return value + rng.randint(-delta, delta)


def _draw_rounded(draw: ImageDraw.ImageDraw, box, radius: int, fill, outline=None, width: int = 1) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def _chamfered_rect(box: tuple[int, int, int, int], cut: int) -> list[tuple[int, int]]:
    x1, y1, x2, y2 = box
    return [
        (x1 + cut, y1),
        (x2 - cut, y1),
        (x2, y1 + cut),
        (x2, y2 - cut),
        (x2 - cut, y2),
        (x1 + cut, y2),
        (x1, y2 - cut),
        (x1, y1 + cut),
    ]


def _polyline_frame(draw: ImageDraw.ImageDraw, points, color, width: int = 1) -> None:
    draw.line(points + [points[0]], fill=color, width=width, joint="curve")


def _draw_pin_row(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    count: int,
    step: tuple[int, int],
    color=(228, 198, 74, 205),
    size: int = 6,
) -> None:
    x, y = start
    dx, dy = step
    for i in range(count):
        px = x + dx * i
        py = y + dy * i
        draw.rounded_rectangle((px, py, px + size, py + size), radius=1, fill=color, outline=(132, 120, 92, 120))


def _clear_of_features(point: tuple[int, int], level, clearance: float = 70.0) -> bool:
    x, y = point
    for sx, sy in level["slots"]:
        if math.hypot(x - sx, y - sy) < clearance:
            return False
    path = level["path"]
    for start, end in zip(path, path[1:]):
        ax, ay = start
        bx, by = end
        abx = bx - ax
        aby = by - ay
        denom = abx * abx + aby * aby
        if denom <= 0.001:
            distance = math.hypot(x - ax, y - ay)
        else:
            t = max(0.0, min(1.0, ((x - ax) * abx + (y - ay) * aby) / denom))
            distance = math.hypot(x - (ax + abx * t), y - (ay + aby * t))
        if distance < clearance:
            return False
    return True


def _draw_board_base(image: Image.Image, rng: random.Random) -> ImageDraw.ImageDraw:
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle((0, 0, MAP_W, 720), fill=(52, 60, 60, 255))

    noise = Image.new("L", (MAP_W, 720), 0)
    noise_px = noise.load()
    for y in range(720):
        for x in range(MAP_W):
            grain = rng.randint(0, 14)
            if 36 < x < 910 and 36 < y < 646:
                grain += rng.randint(0, 22)
            noise_px[x, y] = min(255, grain)
    noise = noise.filter(ImageFilter.GaussianBlur(0.45))
    tint = Image.new("RGBA", (MAP_W, 720), (190, 194, 190, 0))
    tint.putalpha(noise)
    image.alpha_composite(tint, (0, 0))

    rim = _chamfered_rect(BOARD_PANEL, 34)
    draw.polygon(rim, fill=(78, 88, 88, 255))
    _polyline_frame(draw, rim, (24, 30, 30, 215), 2)
    _polyline_frame(draw, _chamfered_rect((18, 25, 930, 668), 28), (206, 210, 204, 108), 1)
    _polyline_frame(draw, _chamfered_rect((26, 34, 922, 660), 24), (28, 34, 34, 118), 1)

    plate = _chamfered_rect((36, 32, 916, 654), 24)
    draw.polygon(plate, fill=(152, 158, 156, 248))
    _polyline_frame(draw, plate, (46, 54, 54, 150), 1)
    _polyline_frame(draw, _chamfered_rect((48, 42, 904, 642), 18), (214, 220, 214, 86), 1)

    inner = _chamfered_rect(BOARD_INNER, 18)
    draw.polygon(inner, fill=(150, 158, 155, 255))
    _polyline_frame(draw, inner, (112, 124, 122, 116), 1)
    _polyline_frame(draw, _chamfered_rect((70, 68, 884, 628), 12), (210, 218, 212, 58), 1)

    seam_paths = [
        [(66, 102), (144, 102), (172, 130), (244, 130), (270, 158)],
        [(646, 76), (690, 76), (724, 110), (838, 110), (878, 150)],
        [(72, 542), (214, 542), (252, 584), (402, 584), (438, 620)],
        [(620, 584), (712, 584), (744, 552), (872, 552)],
        [(588, 88), (536, 140), (536, 182), (492, 220)],
        [(706, 470), (648, 470), (610, 506), (558, 506)],
        [(760, 206), (824, 206), (858, 242), (858, 316), (828, 350)],
        [(318, 598), (384, 598), (418, 626), (520, 626)],
    ]
    for points in seam_paths:
        draw.line(points, fill=ETCH, width=1)
        draw.line([(x, y + 2) for x, y in points], fill=ETCH_LIGHT, width=1)

    for x in range(94, 862, 118):
        draw.line((x, 84, x + 44, 84), fill=(80, 88, 86, 42), width=1)
    for y in range(136, 582, 104):
        draw.line((70, y, 114, y), fill=(80, 88, 86, 42), width=1)
    return draw


def _draw_trace(draw: ImageDraw.ImageDraw, points, color, width: int = 2, glow: bool = False) -> None:
    if glow:
        draw.line(points, fill=(color[0], color[1], color[2], 34), width=width + 8, joint="curve")
        draw.line(points, fill=(color[0], color[1], color[2], 50), width=width + 3, joint="curve")
    draw.line(points, fill=(color[0], color[1], color[2], 130), width=width, joint="curve")
    for x, y in points:
        draw.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(color[0], color[1], color[2], 120))


def _draw_modules(draw: ImageDraw.ImageDraw, modules, accent, rng: random.Random) -> None:
    for i, box in enumerate(modules):
        x1, y1, x2, y2 = box
        _draw_rounded(draw, box, 8, (158, 168, 164, 138), (112, 124, 122, 116), 1)
        _draw_rounded(draw, (x1 + 6, y1 + 6, x2 - 6, y2 - 6), 5, (184, 194, 188, 88), (222, 230, 222, 66), 1)
        _draw_rounded(draw, (x1 + 14, y1 + 14, x2 - 14, y2 - 14), 3, (164, 176, 172, 74), (104, 122, 122, 74), 1)
        for row in range(y1 + 18, y2 - 18, 12):
            draw.line((x1 + 22, row, x2 - 24, row), fill=(124, 142, 144, 72), width=1)
        for col in range(x1 + 26, x2 - 24, 20):
            draw.rectangle((col, y2 - 23, col + 9, y2 - 16), fill=(accent[0], accent[1], accent[2], 108))
        if i % 2 == 0:
            for col in range(x1 + 28, min(x1 + 112, x2 - 20), 12):
                draw.ellipse((col, y1 + 21, col + 5, y1 + 26), fill=(44, 50, 50, 108))
        else:
            _draw_pin_row(draw, (x1 + 20, y1 + 19), min(9, max(3, (x2 - x1 - 40) // 13)), (13, 0), (228, 198, 74, 150), 5)


def _draw_chips(draw: ImageDraw.ImageDraw, chips, accent, warm) -> None:
    for box in chips:
        x1, y1, x2, y2 = box
        _draw_rounded(draw, box, 5, (54, 58, 56, 232), (18, 22, 22, 210), 1)
        _draw_rounded(draw, (x1 + 5, y1 + 5, x2 - 5, y2 - 5), 3, (94, 100, 96, 188), (214, 220, 214, 58), 1)
        for px in range(x1 + 7, x2 - 6, 9):
            draw.rectangle((px, y1 - 5, px + 4, y1 - 1), fill=(warm[0], warm[1], warm[2], 190))
            draw.rectangle((px, y2 + 1, px + 4, y2 + 5), fill=(warm[0], warm[1], warm[2], 190))
        for py in range(y1 + 7, y2 - 6, 9):
            draw.rectangle((x1 - 5, py, x1 - 1, py + 4), fill=(warm[0], warm[1], warm[2], 170))
            draw.rectangle((x2 + 1, py, x2 + 5, py + 4), fill=(warm[0], warm[1], warm[2], 170))
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        draw.rectangle((cx - 4, cy - 4, cx + 4, cy + 4), fill=(accent[0], accent[1], accent[2], 180))


def _draw_tower_pad(draw: ImageDraw.ImageDraw, center, accent, warm) -> None:
    x, y = center
    draw.ellipse((x - 39, y - 39, x + 39, y + 39), fill=(142, 152, 150, 92), outline=(66, 76, 76, 118), width=1)
    draw.ellipse((x - 30, y - 30, x + 30, y + 30), fill=(174, 184, 180, 92), outline=(92, 104, 104, 128), width=1)
    draw.ellipse((x - 22, y - 22, x + 22, y + 22), fill=(144, 154, 152, 74), outline=(218, 226, 218, 90), width=1)
    for dx, dy in ((0, -25), (25, 0), (0, 25), (-25, 0)):
        draw.ellipse((x + dx - 3, y + dy - 3, x + dx + 3, y + dy + 3), fill=(warm[0], warm[1], warm[2], 116))


def _draw_route_ports(draw: ImageDraw.ImageDraw, ports, accent, warm) -> None:
    for idx, (x, y) in enumerate(ports):
        side = -1 if idx == 0 else 1
        outer = (x - 30, y - 20, x + 10, y + 20) if side < 0 else (x - 10, y - 20, x + 30, y + 20)
        inner = (x - 22, y - 12, x + 3, y + 12) if side < 0 else (x - 3, y - 12, x + 22, y + 12)
        draw.rounded_rectangle(outer, radius=5, fill=(62, 72, 72, 182), outline=(22, 28, 28, 150), width=1)
        draw.rounded_rectangle(inner, radius=3, fill=(116, 126, 122, 128), outline=(226, 232, 222, 66), width=1)
        slot = (x - 17, y - 5, x + 1, y + 5) if side < 0 else (x - 1, y - 5, x + 17, y + 5)
        draw.rounded_rectangle(slot, radius=2, fill=(accent[0], accent[1], accent[2], 164), outline=(230, 250, 246, 72))
        pin_x = x - 28 if side < 0 else x + 21
        _draw_pin_row(draw, (pin_x, y - 13), 3, (0, 10), warm, 3)


def _draw_background_traces(draw: ImageDraw.ImageDraw, level, rng: random.Random) -> None:
    accent = level["accent"]
    warm = level["warm"]
    for i in range(20):
        x = _jitter(110 + (i % 5) * 160, 22, rng)
        y = _jitter(120 + (i // 5) * 185, 34, rng)
        if not _clear_of_features((x, y), level, 78.0):
            continue
        points = [(x, y), (x + rng.randint(36, 82), y), (x + rng.randint(80, 140), y + rng.choice([-34, 34, 52]))]
        if any(px < 78 or px > 874 or py < 82 or py > 624 for px, py in points):
            continue
        _draw_trace(draw, points, accent if i % 3 else warm, width=1, glow=False)
    for x, y in [(72, 78), (908, 96), (70, 612), (906, 582), (506, 618), (520, 70), (790, 80)]:
        draw.rounded_rectangle((x - 12, y - 5, x + 12, y + 5), radius=3, fill=(accent[0], accent[1], accent[2], 150), outline=(20, 58, 62, 120))


def _draw_edge_hardware(draw: ImageDraw.ImageDraw, accent, warm, level_number: int) -> None:
    draw.rounded_rectangle((26, 252, 52, 360), radius=5, fill=(52, 58, 58, 218), outline=(18, 22, 22, 210), width=1)
    draw.rounded_rectangle((33, 278, 44, 338), radius=3, fill=(94, 104, 100, 170), outline=(220, 226, 216, 72), width=1)
    draw.rounded_rectangle((36, 294, 41, 324), radius=2, fill=(accent[0], accent[1], accent[2], 196))
    _draw_pin_row(draw, (56, 270), 5, (0, 10), warm, 5)

    draw.rounded_rectangle((270, 28, 360, 58), radius=5, fill=(54, 60, 58, 218), outline=(18, 22, 22, 210), width=1)
    draw.rounded_rectangle((284, 38, 346, 49), radius=2, fill=(108, 118, 114, 162), outline=(224, 228, 218, 78), width=1)
    _draw_pin_row(draw, (286, 34), 10, (6, 0), warm, 3)

    draw.rounded_rectangle((92, 590, 198, 638), radius=6, fill=(126, 134, 130, 172), outline=(42, 48, 48, 150), width=1)
    for row in range(0, 4):
        for col in range(0, 11):
            cx = 106 + col * 8
            cy = 602 + row * 8
            draw.ellipse((cx, cy, cx + 4, cy + 4), fill=(34, 38, 38, 168))
    _draw_pin_row(draw, (214, 616), 5, (11, 0), warm, 5)

    for offset in range(5):
        draw.line((214, 620 + offset, 318, 620 + offset), fill=(226, 170, 46, 184), width=1)

    if level_number == 3:
        draw.rounded_rectangle((820, 74, 874, 126), radius=6, fill=(48, 56, 56, 220), outline=(18, 22, 22, 210), width=1)
        for yy in (90, 108):
            for xx in (834, 852):
                draw.rounded_rectangle((xx, yy, xx + 10, yy + 10), radius=2, fill=(accent[0], accent[1], accent[2], 190))
        _draw_pin_row(draw, (812, 86), 5, (0, 8), warm, 4)
    else:
        draw.rounded_rectangle((828, 86, 886, 124), radius=5, fill=(56, 62, 62, 204), outline=(18, 22, 22, 190), width=1)
        draw.rounded_rectangle((842, 98, 872, 112), radius=2, fill=(accent[0], accent[1], accent[2], 142))

    draw.rounded_rectangle((888, 318, 916, 410), radius=5, fill=(58, 64, 64, 210), outline=(20, 24, 24, 196), width=1)
    draw.rounded_rectangle((901, 342, 908, 388), radius=2, fill=(accent[0], accent[1], accent[2], 180))
    _draw_pin_row(draw, (884, 342), 5, (0, 10), warm, 4)

    for x, y in [(60, 76), (784, 134), (870, 226), (60, 438), (898, 574), (506, 616)]:
        draw.rounded_rectangle((x, y, x + 22, y + 9), radius=2, fill=(accent[0], accent[1], accent[2], 162), outline=(28, 62, 64, 138))
    for x, y in [(38, 162), (144, 430), (474, 132), (548, 222), (690, 466), (772, 610)]:
        _draw_pin_row(draw, (x, y), 3, (12, 0), warm, 6)


def generate_level(level_number: int) -> None:
    level = LEVELS[level_number]
    rng = random.Random(level["seed"])
    image = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = _draw_board_base(image, rng)
    _draw_background_traces(draw, level, rng)
    _draw_edge_hardware(draw, level["accent"], level["warm"], level_number)
    _draw_chips(draw, level["chips"], level["accent"], level["warm"])
    for slot in level["slots"]:
        _draw_tower_pad(draw, slot, level["accent"], level["warm"])
    _draw_route_ports(draw, level.get("ports", [level["path"][0], level["path"][-1]]), level["accent"], level["warm"])
    draw.rectangle((MAP_W, 0, CANVAS[0], CANVAS[1]), fill=(0, 0, 0, 0))
    out = BG_DIR / level["out"]
    image.save(out)
    print(f"generated {out}")


def install_level_one_style_source() -> None:
    if not LEVEL_ONE_STYLE_SOURCE.exists():
        raise FileNotFoundError(f"missing style source: {LEVEL_ONE_STYLE_SOURCE}")
    shutil.copyfile(LEVEL_ONE_STYLE_SOURCE, LEVEL_ONE_MAP_LAYER)
    map_layer = Image.open(LEVEL_ONE_MAP_LAYER).convert("RGBA")
    draw = ImageDraw.Draw(map_layer, "RGBA")
    _draw_route_ports(draw, [LEVEL_ONE_CONNECTED_PATH[0], LEVEL_ONE_CONNECTED_PATH[-1]], (34, 204, 218), (235, 184, 60))
    hud_layer = Image.open(LEVEL_ONE_HUD_LAYER).convert("RGBA")
    Image.alpha_composite(map_layer, hud_layer).save(LEVEL_ONE_COMPOSITE)
    map_layer.save(LEVEL_ONE_MAP_LAYER)
    print(f"installed {LEVEL_ONE_MAP_LAYER}")
    print(f"composed {LEVEL_ONE_COMPOSITE}")


def main() -> None:
    install_level_one_style_source()
    for level_number in (2, 3):
        generate_level(level_number)


if __name__ == "__main__":
    main()
