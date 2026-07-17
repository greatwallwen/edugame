from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


GAME_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = GAME_ROOT / "assets" / "staged-production" / "refined-hardware"
SIZE = 256
SCALE = 3
WORK_SIZE = SIZE * SCALE
TOWER_IDS = ("i2c", "filter", "peak", "power")
TOWER_ANIM_COLUMNS = 8
TOWER_ANIM_ROWS = 2
ATTACK_EFFECT_FRAMES = 8
BEAM_FRAME_SIZE = (192, 64)
RANGE_FRAME_SIZE = (256, 256)
BOARD_BOUNDS = {
    "i2c": [65, 78, 191, 178],
    "filter": [60, 83, 196, 179],
    "peak": [60, 83, 196, 181],
    "power": [59, 83, 197, 181],
}
AMBIENT_EFFECT_CUES = [
    "orbiting data motes",
    "scan arc",
    "energy spark",
    "layered hologram rings",
    "data filament lattice",
    "micro telemetry ticks",
]
AMBIENT_SIGNATURE_CUES = {
    "i2c": "bus constellation links",
    "filter": "frequency comb field",
    "peak": "peak lock prism",
    "power": "wake pulse halo",
}
BOARD_PRESENTATION_CUES = [
    "angled board plane",
    "visible board thickness",
    "beveled edge highlight",
    "contact shadow",
]
COMPONENT_PRESENTATION_CUES = [
    "raised IC packages",
    "metal pin shadows",
    "connector housings",
    "machined fasteners",
]


MANIFEST = {
    "i2c": {
        "name": "I2C initialization hardware tower",
        "real_hardware_cues": [
            "sensor breakout board",
            "header pins",
            "pull-up resistors",
            "small IMU package",
            "SDA/SCL bus traces",
        ],
        "tower_concept_cues": [
            "raised chassis",
            "pedestal ring",
            "diagnostic mast",
            "layered tech pedestal",
            "holographic docking base",
            "glowing board socket",
            "side guide rail",
            "maglev base ring",
            "energy port",
        ],
        "hardware_accessory_cues": [
            "SDA probe",
            "SCL probe",
            "bus activity light",
        ],
        "circuit_layout_cues": [
            "non-overlapping component zones",
            "clear trace routing",
            "component clearance",
            "separate connector, sensor, and pull-up resistor areas",
        ],
    },
    "filter": {
        "name": "analog/digital signal filter hardware tower",
        "real_hardware_cues": [
            "op-amp",
            "resistors",
            "capacitors",
            "RC filter network",
            "small waveform monitor",
        ],
        "tower_concept_cues": [
            "raised chassis",
            "pedestal ring",
            "diagnostic mast",
            "layered tech pedestal",
            "holographic docking base",
            "glowing board socket",
            "side guide rail",
            "maglev base ring",
            "energy port",
        ],
        "hardware_accessory_cues": [
            "input terminal",
            "output terminal",
            "mini waveform window",
        ],
        "circuit_layout_cues": [
            "non-overlapping component zones",
            "clear trace routing",
            "component clearance",
            "separate op-amp, resistor, and capacitor areas",
        ],
    },
    "peak": {
        "name": "peak detector comparator hardware tower",
        "real_hardware_cues": [
            "comparator",
            "diode",
            "threshold reference",
            "sample capacitor",
            "oscilloscope-style signal trace",
        ],
        "tower_concept_cues": [
            "raised chassis",
            "pedestal ring",
            "diagnostic mast",
            "layered tech pedestal",
            "holographic docking base",
            "glowing board socket",
            "side guide rail",
            "maglev base ring",
            "energy port",
        ],
        "hardware_accessory_cues": [
            "threshold trim knob",
            "diode direction label",
            "peak latch bar",
        ],
        "circuit_layout_cues": [
            "non-overlapping component zones",
            "clear trace routing",
            "component clearance",
            "separate comparator, diode, threshold, and capacitor areas",
        ],
    },
    "power": {
        "name": "low-power wakeup hardware tower",
        "real_hardware_cues": [
            "battery",
            "MOSFET",
            "wake interrupt",
            "power gate",
            "coin-cell holder",
        ],
        "tower_concept_cues": [
            "raised chassis",
            "pedestal ring",
            "diagnostic mast",
            "layered tech pedestal",
            "holographic docking base",
            "glowing board socket",
            "side guide rail",
            "maglev base ring",
            "energy port",
        ],
        "hardware_accessory_cues": [
            "battery contacts",
            "wake coil",
            "power gate indicator",
        ],
        "circuit_layout_cues": [
            "non-overlapping component zones",
            "clear trace routing",
            "component clearance",
            "separate battery, MOSFET, wake line, and status gauge areas",
        ],
    },
}

COMPONENT_LAYOUT = {
    "i2c": [
        {"name": "imu sensor package", "box": [101, 113, 132, 143]},
        {"name": "header pins", "box": [66, 166, 126, 178]},
        {"name": "status connector", "box": [143, 151, 178, 174]},
        {"name": "pull-up resistor bank", "box": [146, 112, 180, 140]},
        {"name": "bus route vias", "box": [68, 94, 95, 115]},
        {"name": "sda probe", "box": [103, 83, 116, 106]},
        {"name": "scl probe", "box": [125, 83, 138, 106]},
        {"name": "bus activity light", "box": [125, 150, 134, 157]},
    ],
    "filter": [
        {"name": "op-amp package", "box": [114, 116, 150, 146]},
        {"name": "input resistor bank", "box": [66, 90, 98, 114]},
        {"name": "capacitor bank", "box": [162, 92, 194, 119]},
        {"name": "output capacitor bank", "box": [163, 149, 195, 176]},
        {"name": "waveform monitor", "box": [60, 157, 104, 174]},
        {"name": "input terminal", "box": [76, 122, 98, 143]},
        {"name": "output terminal", "box": [170, 126, 192, 142]},
        {"name": "mini waveform window", "box": [112, 154, 151, 174]},
    ],
    "peak": [
        {"name": "comparator package", "box": [68, 112, 102, 142]},
        {"name": "threshold package", "box": [153, 116, 190, 146]},
        {"name": "diode marker", "box": [116, 100, 144, 119]},
        {"name": "sample capacitor", "box": [182, 154, 196, 176]},
        {"name": "peak waveform bus", "box": [70, 169, 136, 181]},
        {"name": "reference resistor bank", "box": [70, 84, 190, 90]},
        {"name": "threshold trim knob", "box": [111, 143, 131, 163]},
        {"name": "diode direction label", "box": [110, 126, 142, 137]},
        {"name": "peak latch bar", "box": [144, 153, 170, 165]},
    ],
    "power": [
        {"name": "coin cell holder", "box": [70, 105, 121, 156]},
        {"name": "mosfet package", "box": [158, 110, 188, 140]},
        {"name": "status gauge", "box": [143, 154, 193, 176]},
        {"name": "wake antenna route", "box": [160, 85, 192, 101]},
        {"name": "power resistor bank", "box": [128, 88, 140, 103]},
        {"name": "battery contacts", "box": [60, 124, 63, 138]},
        {"name": "wake coil", "box": [130, 117, 146, 135]},
        {"name": "power gate indicator", "box": [122, 163, 137, 177]},
    ],
}

MECHANICAL_DETAIL_LAYOUT = {
    "i2c": [
        {"name": "machined fastener upper right", "box": [144, 81, 155, 93]},
        {"name": "machined fastener bus corner", "box": [68, 121, 79, 133]},
        {"name": "machined fastener lower left", "box": [80, 145, 91, 157]},
    ],
    "filter": [
        {"name": "machined fastener upper left", "box": [107, 86, 118, 98]},
        {"name": "machined fastener upper center", "box": [135, 86, 146, 98]},
    ],
    "peak": [
        {"name": "machined fastener upper center", "box": [151, 98, 162, 110]},
        {"name": "machined fastener upper right", "box": [179, 98, 190, 110]},
        {"name": "machined fastener lower left", "box": [63, 150, 74, 162]},
    ],
    "power": [
        {"name": "machined fastener upper left", "box": [62, 86, 73, 98]},
        {"name": "machined fastener upper center", "box": [90, 86, 101, 98]},
        {"name": "machined fastener lower left", "box": [62, 162, 73, 174]},
    ],
}


def _new_canvas() -> Image.Image:
    return Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))


def _downsample(image: Image.Image) -> Image.Image:
    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def _box(box: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    return tuple(int(v * SCALE) for v in box)


def _points(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(int(x * SCALE), int(y * SCALE)) for x, y in points]


def _rounded(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    radius: float,
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
) -> None:
    draw.rounded_rectangle(_box(box), radius=int(radius * SCALE), fill=fill, outline=outline, width=max(1, int(width * SCALE)))


def _line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
    width: int = 1,
) -> None:
    draw.line(_points(points), fill=fill, width=max(1, int(width * SCALE)), joint="curve")


def _ellipse(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
) -> None:
    draw.ellipse(_box(box), fill=fill, outline=outline, width=max(1, int(width * SCALE)))


def _arc(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    start: float,
    end: float,
    fill: tuple[int, int, int, int],
    width: int = 1,
) -> None:
    draw.arc(_box(box), start=start, end=end, fill=fill, width=max(1, int(width * SCALE)))


def _polygon(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], fill: tuple[int, int, int, int]) -> None:
    draw.polygon(_points(points), fill=fill)


def _soft_shadow(draw: ImageDraw.ImageDraw, cx: float = 128, cy: float = 218, rx: float = 64, ry: float = 13) -> None:
    draw.ellipse(_box((cx - rx, cy - ry, cx + rx, cy + ry)), fill=(13, 29, 45, 42))


def _tower_chassis(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int, int], variant: int) -> None:
    # A shared tower silhouette: the real board is mounted on a diagnostic stand,
    # so it reads as a tower without becoming a weapon.
    base_y = 205
    _ellipse(draw, (50, base_y - 17, 206, base_y + 17), (223, 238, 249, 230), (accent[0], accent[1], accent[2], 170), 3)
    _ellipse(draw, (68, base_y - 10, 188, base_y + 10), (235, 250, 255, 185), (255, 255, 255, 130), 1)
    _ellipse(draw, (82, base_y - 4, 174, base_y + 5), (accent[0], accent[1], accent[2], 55), (accent[0], accent[1], accent[2], 150), 2)
    _ellipse(draw, (42, base_y - 23, 214, base_y + 23), (0, 0, 0, 0), (accent[0], accent[1], accent[2], 80), 1)
    _ellipse(draw, (96, base_y - 6, 160, base_y + 7), (20, 42, 65, 85), (255, 255, 255, 120), 1)
    for x in (75, 181):
        _ellipse(draw, (x - 5, base_y - 9, x + 5, base_y + 1), (accent[0], accent[1], accent[2], 145), (255, 255, 255, 120), 1)

    deck = [(78, 179), (178, 179), (195, 194), (168, 207), (88, 207), (61, 194)]
    _polygon(draw, [(x + 5, y + 6) for x, y in deck], (15, 31, 48, 42))
    _polygon(draw, deck, (241, 248, 255, 205))
    _line(draw, deck + [deck[0]], (accent[0], accent[1], accent[2], 150), 2)
    _line(draw, [(70, 191), (88, 166), (95, 155)], (40, 66, 92, 140), 3)
    _line(draw, [(186, 191), (168, 166), (161, 155)], (40, 66, 92, 140), 3)
    _line(draw, [(74, 190), (91, 166)], (accent[0], accent[1], accent[2], 130), 1)
    _line(draw, [(182, 190), (165, 166)], (accent[0], accent[1], accent[2], 130), 1)

    socket = [(90, 166), (166, 166), (181, 178), (158, 189), (98, 189), (75, 178)]
    _polygon(draw, socket, (20, 42, 65, 145))
    _line(draw, socket + [socket[0]], (accent[0], accent[1], accent[2], 190), 2)
    for slot in range(4):
        x = 98 + slot * 18
        _line(draw, [(x, 173), (x + 14, 173)], (255, 255, 255, 105), 2)
    _rounded(draw, (118, 196, 138, 204), 3, (18, 37, 59, 170), accent, 1)
    _line(draw, [(122, 200), (134, 200)], (255, 255, 255, 120), 1)

    _line(draw, [(128, 188), (128, 139), (128, 84 - variant * 3)], (55, 78, 103, 105), 4)
    _ellipse(draw, (119, 76 - variant * 3, 137, 94 - variant * 3), (248, 252, 255, 210), accent, 2)
    _line(draw, [(137, 84 - variant * 3), (158 + variant * 8, 72 + variant * 4)], (accent[0], accent[1], accent[2], 135), 3)
    _line(draw, [(118, 86 - variant * 2), (97 - variant * 4, 75 + variant * 4)], (accent[0], accent[1], accent[2], 95), 2)


def _base_board(draw: ImageDraw.ImageDraw, cx: float, cy: float, w: float, h: float, fill: tuple[int, int, int, int], accent: tuple[int, int, int, int]) -> None:
    board = [(cx - w * 0.5, cy - h * 0.38), (cx + w * 0.42, cy - h * 0.5), (cx + w * 0.5, cy + h * 0.36), (cx - w * 0.43, cy + h * 0.5)]
    depth = 9
    lower = [(x + 7, y + depth) for x, y in board]
    _polygon(draw, [(x + 9, y + 15) for x, y in board], (15, 31, 48, 38))
    _polygon(draw, [board[3], board[2], lower[2], lower[3]], (15, 34, 50, 155))
    _polygon(draw, [board[1], board[2], lower[2], lower[1]], (10, 26, 43, 120))
    _polygon(draw, [board[0], board[3], lower[3], lower[0]], (24, 48, 68, 105))
    _line(draw, [lower[3], lower[2], lower[1]], (255, 255, 255, 48), 1)
    _polygon(draw, board, fill)
    _polygon(draw, [(board[0][0] + 5, board[0][1] + 5), (board[1][0] - 6, board[1][1] + 4), (board[2][0] - 7, board[2][1] - 6), (board[3][0] + 6, board[3][1] - 6)], (255, 255, 255, 24))
    _line(draw, board + [board[0]], accent, 2)
    _line(draw, [board[0], board[1]], (255, 255, 255, 120), 1)
    _line(draw, [board[3], board[2]], (accent[0], accent[1], accent[2], 185), 3)
    _line(draw, [board[2], lower[2], lower[3], board[3]], (accent[0], accent[1], accent[2], 95), 1)


def _draw_chip(draw: ImageDraw.ImageDraw, cx: float, cy: float, w: float, h: float, fill: tuple[int, int, int, int], accent: tuple[int, int, int, int]) -> None:
    _rounded(draw, (cx - w / 2 + 3, cy - h / 2 + 4, cx + w / 2 + 3, cy + h / 2 + 4), 5, (10, 22, 35, 110))
    _rounded(draw, (cx - w / 2 + 1.8, cy + h / 2 - 2, cx + w / 2 + 2.5, cy + h / 2 + 5), 3, (8, 18, 31, 190), accent, 1)
    _rounded(draw, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), 5, fill, accent, 2)
    _rounded(draw, (cx - w / 2 + 4, cy - h / 2 + 4, cx + w / 2 - 4, cy + h / 2 - 7), 3, (255, 255, 255, 24))
    _ellipse(draw, (cx - w / 2 + 5, cy - h / 2 + 5, cx - w / 2 + 9, cy - h / 2 + 9), (230, 240, 249, 170))
    for index in range(5):
        y = cy - h / 2 + 8 + index * (h - 16) / 4
        _line(draw, [(cx - w / 2 - 8, y + 1.5), (cx - w / 2, y + 1.5)], (9, 20, 31, 115), 2)
        _line(draw, [(cx + w / 2, y + 1.5), (cx + w / 2 + 8, y + 1.5)], (9, 20, 31, 115), 2)
        _line(draw, [(cx - w / 2 - 8, y), (cx - w / 2, y)], (210, 225, 235, 230), 2)
        _line(draw, [(cx + w / 2, y), (cx + w / 2 + 8, y)], (210, 225, 235, 230), 2)


def _draw_resistor(draw: ImageDraw.ImageDraw, x: float, y: float, color: tuple[int, int, int, int]) -> None:
    _line(draw, [(x - 12, y + 1), (x - 7, y + 1)], (10, 22, 33, 100), 2)
    _line(draw, [(x + 7, y + 1), (x + 12, y + 1)], (10, 22, 33, 100), 2)
    _line(draw, [(x - 12, y), (x - 7, y)], (210, 223, 230, 220), 2)
    _rounded(draw, (x - 7, y - 3, x + 7, y + 5), 2, (132, 105, 70, 210))
    _rounded(draw, (x - 7, y - 4, x + 7, y + 4), 2, (216, 193, 148, 245), (120, 102, 73, 210), 1)
    _line(draw, [(x - 3, y - 4), (x - 3, y + 4)], (84, 68, 52, 150), 1)
    _line(draw, [(x + 3, y - 4), (x + 3, y + 4)], (172, 92, 62, 135), 1)
    _line(draw, [(x + 7, y), (x + 12, y)], (210, 223, 230, 220), 2)


def _draw_capacitor(draw: ImageDraw.ImageDraw, x: float, y: float, color: tuple[int, int, int, int]) -> None:
    _line(draw, [(x + 1, y - 11), (x + 1, y + 11)], (9, 20, 31, 95), 2)
    _line(draw, [(x, y - 11), (x, y - 4)], (215, 228, 236, 215), 2)
    _rounded(draw, (x - 7, y - 6, x + 7, y + 6), 3, (22, 44, 58, 170), color, 1)
    _line(draw, [(x - 6, y - 3), (x + 6, y - 3)], (238, 248, 255, 180), 1)
    _line(draw, [(x - 6, y + 4), (x + 6, y + 4)], (16, 28, 42, 130), 1)
    _line(draw, [(x, y + 4), (x, y + 11)], (215, 228, 236, 215), 2)


def _draw_smd(draw: ImageDraw.ImageDraw, x: float, y: float, w: float, h: float, fill: tuple[int, int, int, int], outline: tuple[int, int, int, int]) -> None:
    _rounded(draw, (x - w / 2 + 1.5, y - h / 2 + 2, x + w / 2 + 1.5, y + h / 2 + 2), 1.8, (10, 22, 33, 95))
    _rounded(draw, (x - w / 2, y + h / 2 - 1, x + w / 2, y + h / 2 + 3), 1.4, (82, 70, 54, 155))
    _rounded(draw, (x - w / 2, y - h / 2, x + w / 2, y + h / 2), 1.8, fill, outline, 1)
    _line(draw, [(x - w / 2 + 2, y - h / 2 + 1), (x + w / 2 - 2, y - h / 2 + 1)], (255, 255, 255, 90), 1)
    _line(draw, [(x - w / 2, y), (x - w / 2 - 3, y)], (216, 226, 232, 190), 1)
    _line(draw, [(x + w / 2, y), (x + w / 2 + 3, y)], (216, 226, 232, 190), 1)


def _draw_clean_trace(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], color: tuple[int, int, int, int]) -> None:
    _line(draw, points, color, 1)
    for x, y in points[1:-1]:
        _ellipse(draw, (x - 1.8, y - 1.8, x + 1.8, y + 1.8), (236, 250, 255, 175), color, 1)


def _draw_terminal(draw: ImageDraw.ImageDraw, box: tuple[float, float, float, float], accent: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    _rounded(draw, (x0 + 2, y0 + 3, x1 + 2, y1 + 3), 3, (10, 22, 35, 115))
    _rounded(draw, (x0, y1 - 4, x1, y1 + 3), 2, (52, 68, 82, 185), accent, 1)
    _rounded(draw, box, 3, (224, 236, 244, 245), accent, 2)
    _line(draw, [(x0 + 3, y0 + 3), (x1 - 3, y0 + 3)], (255, 255, 255, 130), 1)
    x0, y0, x1, y1 = box
    for index in range(2):
        y = y0 + 7 + index * 8
        _line(draw, [(x0 + 5, y), (x1 - 5, y)], (53, 78, 103, 170), 1)
        _ellipse(draw, (x0 + 5, y - 2, x0 + 9, y + 2), (92, 107, 119, 150), (255, 255, 255, 95), 1)


def _draw_probe(draw: ImageDraw.ImageDraw, x: float, y: float, accent: tuple[int, int, int, int]) -> None:
    _line(draw, [(x + 1, y + 18), (x + 5, y + 8), (x + 5, y)], (10, 22, 35, 105), 2)
    _line(draw, [(x, y + 18), (x + 4, y + 8), (x + 4, y)], (220, 232, 240, 230), 2)
    _ellipse(draw, (x, y - 4, x + 8, y + 4), (238, 249, 255, 235), accent, 1)
    _ellipse(draw, (x + 2, y - 2, x + 5, y + 1), (255, 255, 255, 150))


def _draw_knob(draw: ImageDraw.ImageDraw, cx: float, cy: float, accent: tuple[int, int, int, int]) -> None:
    _ellipse(draw, (cx - 8, cy - 6, cx + 10, cy + 11), (8, 18, 31, 120))
    _ellipse(draw, (cx - 9, cy - 9, cx + 9, cy + 9), (78, 90, 105, 235), accent, 2)
    _ellipse(draw, (cx - 6, cy - 6, cx + 6, cy + 6), (226, 235, 242, 235), (112, 128, 143, 170), 1)
    _line(draw, [(cx, cy), (cx + 5, cy - 5)], (58, 80, 108, 190), 2)
    _ellipse(draw, (cx - 2, cy - 2, cx + 2, cy + 2), (255, 255, 255, 120))


def _draw_fastener(draw: ImageDraw.ImageDraw, x: float, y: float, accent: tuple[int, int, int, int]) -> None:
    _ellipse(draw, (x - 3.5, y - 2.5, x + 4.5, y + 5.5), (8, 18, 31, 95))
    _ellipse(draw, (x - 3.5, y - 3.5, x + 3.5, y + 3.5), (196, 207, 216, 235), accent, 1)
    _line(draw, [(x - 2, y), (x + 2, y)], (67, 82, 97, 165), 1)
    _ellipse(draw, (x - 1.1, y - 1.1, x + 1.1, y + 1.1), (255, 255, 255, 115))


def _mechanical_board_details(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int, int], variant: int) -> None:
    tower_id = TOWER_IDS[variant]
    for detail in MECHANICAL_DETAIL_LAYOUT[tower_id]:
        x0, y0, x1, y1 = detail["box"]
        _draw_fastener(draw, (x0 + x1) / 2 - 0.5, (y0 + y1) / 2 - 1, accent)


def _sci_fi_ambient(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int, int], variant: int) -> None:
    faint = (accent[0], accent[1], accent[2], 58)
    mid = (accent[0], accent[1], accent[2], 105)
    bright = (accent[0], accent[1], accent[2], 170)
    white = (255, 255, 255, 92)

    for inset, start in [(0, 198), (10, 212), (23, 228)]:
        _arc(draw, (38 + inset, 183 - inset * 0.18, 218 - inset, 231 + inset * 0.1), start, start + 124, faint, 1)
        _arc(draw, (44 + inset, 176 - inset * 0.12, 212 - inset, 225), start + 144, start + 236, mid, 1)

    for index in range(13):
        angle = math.radians(203 + index * 11)
        rx = 82 + (index % 3) * 7
        ry = 22 + (index % 2) * 4
        cx = 128 + math.cos(angle) * rx
        cy = 205 + math.sin(angle) * ry
        tick_len = 2.6 if index % 3 else 4.2
        _line(draw, [(cx, cy), (cx + math.cos(angle) * tick_len, cy + math.sin(angle) * tick_len)], white, 1)

    motes = [
        (48, 138, 2.2),
        (58, 116, 1.6),
        (203, 120, 2.0),
        (214, 151, 1.5),
        (86 + variant * 5, 68 - variant * 2, 1.8),
        (204 - variant * 4, 82 + variant * 3, 1.6),
        (72 + variant * 8, 62 + variant * 4, 1.2),
        (225 - variant * 5, 134 + variant * 2, 1.1),
        (35 + variant * 5, 164 - variant * 2, 1.3),
    ]
    for x, y, radius in motes:
        _ellipse(draw, (x - radius, y - radius, x + radius, y + radius), bright)

    filament_points = [
        (43, 151),
        (58, 132),
        (75, 148),
        (207, 106),
        (224, 128),
        (209, 151),
    ]
    for index in range(0, len(filament_points), 3):
        _line(draw, filament_points[index : index + 3], mid, 1)
    for left, right in [((51, 138), (70, 148)), ((199, 108), (217, 130)), ((44, 164), (59, 151)), ((206, 160), (221, 145))]:
        _line(draw, [left, right], white, 1)

    _line(draw, [(54, 194), (77, 184), (104, 183)], mid, 1)
    _line(draw, [(154, 184), (181, 185), (207, 196)], (accent[0], accent[1], accent[2], 85), 1)
    _line(draw, [(201, 92), (213, 88), (222, 94)], (255, 255, 255, 80), 1)
    _line(draw, [(48, 157), (56, 149)], white, 1)
    _line(draw, [(211, 161), (218, 153)], white, 1)

    if variant == 0:
        nodes = [(49, 119), (67, 105), (84, 116), (61, 145)]
        for node in nodes:
            _ellipse(draw, (node[0] - 1.6, node[1] - 1.6, node[0] + 1.6, node[1] + 1.6), bright)
        _line(draw, [nodes[0], nodes[1], nodes[2], nodes[3], nodes[0]], mid, 1)
    elif variant == 1:
        for offset in range(5):
            x = 202 + offset * 5
            _line(draw, [(x, 112 - offset * 2), (x, 146 + offset)], mid, 1)
    elif variant == 2:
        prism = [(211, 105), (225, 113), (219, 129), (204, 121)]
        _polygon(draw, prism, (accent[0], accent[1], accent[2], 34))
        _line(draw, prism + [prism[0]], mid, 1)
        _line(draw, [(207, 116), (222, 119)], white, 1)
    else:
        _arc(draw, (198, 99, 235, 139), 42, 318, mid, 1)
        _arc(draw, (204, 105, 229, 133), 68, 292, white, 1)


def _hardware_highlights(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int, int]) -> None:
    _line(draw, [(60, 58), (91, 52), (116, 55)], (255, 255, 255, 70), 2)
    _line(draw, [(172, 64), (202, 74)], (255, 255, 255, 62), 2)
    for x, y in [(58, 184), (198, 170), (214, 102)]:
        _ellipse(draw, (x - 3, y - 3, x + 3, y + 3), accent)


def draw_i2c() -> Image.Image:
    frame = _new_canvas()
    glow = _new_canvas()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    accent = (82, 170, 255, 225)

    _soft_shadow(draw)
    _tower_chassis(draw, accent, 0)
    _sci_fi_ambient(draw, accent, 0)
    _base_board(draw, 128, 128, 126, 100, (42, 111, 188, 245), accent)
    _rounded(glow_draw, (61, 74, 196, 190), 18, (82, 170, 255, 90))
    frame.alpha_composite(glow.filter(ImageFilter.GaussianBlur(9 * SCALE)))
    draw = ImageDraw.Draw(frame)

    _mechanical_board_details(draw, accent, 0)
    _draw_chip(draw, 116, 128, 31, 30, (22, 45, 82, 255), (190, 225, 255, 235))
    _rounded(draw, (140, 151, 177, 174), 3, (229, 245, 255, 235), (88, 168, 255, 225), 2)
    for index in range(5):
        x = 71 + index * 13
        _ellipse(draw, (x - 3.4, 170, x + 3.4, 177), (224, 242, 255, 235), accent, 1)
    for index in range(5):
        x = 71 + index * 13
        _draw_clean_trace(draw, [(x, 170), (x, 156), (92 + index * 5, 145)], accent)
    for x, y in [(153, 118), (170, 118), (153, 135), (170, 135)]:
        _draw_smd(draw, x, y, 12, 6, (206, 183, 139, 245), (120, 102, 73, 210))
    _draw_probe(draw, 105, 87, accent)
    _draw_probe(draw, 127, 87, accent)
    _ellipse(draw, (126, 151, 133, 156), (146, 239, 255, 205), accent, 2)
    _line(draw, [(128, 154), (132, 154)], (255, 255, 255, 145), 1)
    _draw_clean_trace(draw, [(134, 112), (147, 119), (153, 119)], (130, 210, 255, 155))
    _draw_clean_trace(draw, [(134, 129), (147, 136), (170, 136)], (130, 210, 255, 155))
    _line(draw, [(69, 96), (89, 96), (97, 113)], (130, 210, 255, 105), 2)
    _line(draw, [(69, 110), (88, 110), (98, 127)], (130, 210, 255, 105), 2)
    _hardware_highlights(draw, accent)
    return _downsample(frame)


def draw_filter() -> Image.Image:
    frame = _new_canvas()
    glow = _new_canvas()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    accent = (63, 219, 159, 225)

    _soft_shadow(draw)
    _tower_chassis(draw, accent, 1)
    _sci_fi_ambient(draw, accent, 1)
    _base_board(draw, 128, 131, 136, 96, (45, 127, 110, 242), accent)
    _rounded(glow_draw, (58, 78, 200, 188), 20, (63, 219, 159, 80))
    frame.alpha_composite(glow.filter(ImageFilter.GaussianBlur(9 * SCALE)))
    draw = ImageDraw.Draw(frame)

    _mechanical_board_details(draw, accent, 1)
    _draw_chip(draw, 132, 131, 36, 30, (16, 58, 54, 255), (185, 252, 225, 235))
    for x, y in [(73, 96), (91, 96), (73, 110), (91, 110)]:
        _draw_smd(draw, x, y, 14, 6, (206, 183, 139, 245), (120, 102, 73, 210))
    for x, y in [(163, 98), (187, 98), (165, 151), (189, 151)]:
        _draw_capacitor(draw, x, y, (196, 253, 230, 220))
    _draw_terminal(draw, (76, 122, 98, 143), accent)
    _draw_terminal(draw, (170, 126, 192, 142), accent)
    _rounded(draw, (112, 154, 151, 174), 4, (18, 57, 63, 220), (196, 253, 230, 215), 2)
    _line(draw, [(117, 166), (125, 161), (134, 168), (146, 160)], (196, 253, 230, 190), 2)
    noisy = [(63, 166), (75, 171), (87, 160), (101, 168)]
    smooth = [(150, 122), (164, 122), (179, 127), (194, 121)]
    _line(draw, noisy, (230, 252, 245, 135), 2)
    _line(draw, smooth, (196, 253, 230, 185), 3)
    _draw_clean_trace(draw, [(98, 110), (112, 110), (112, 124)], accent)
    _draw_clean_trace(draw, [(151, 132), (166, 132), (166, 151)], accent)
    _draw_clean_trace(draw, [(151, 119), (163, 108), (163, 98)], accent)
    _hardware_highlights(draw, accent)
    return _downsample(frame)


def draw_peak() -> Image.Image:
    frame = _new_canvas()
    glow = _new_canvas()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    accent = (255, 184, 77, 230)

    _soft_shadow(draw)
    _tower_chassis(draw, accent, 2)
    _sci_fi_ambient(draw, accent, 2)
    _base_board(draw, 128, 132, 136, 98, (78, 83, 126, 242), accent)
    _rounded(glow_draw, (58, 78, 199, 190), 18, (255, 184, 77, 70))
    frame.alpha_composite(glow.filter(ImageFilter.GaussianBlur(9 * SCALE)))
    draw = ImageDraw.Draw(frame)

    _mechanical_board_details(draw, accent, 2)
    _draw_chip(draw, 88, 125, 34, 30, (33, 39, 78, 255), (241, 245, 249, 230))
    _draw_chip(draw, 172, 129, 36, 29, (33, 39, 78, 255), (255, 232, 171, 230))
    _line(draw, [(70, 176), (89, 176), (101, 169), (113, 180), (124, 173), (136, 179)], (255, 230, 155, 190), 3)
    _line(draw, [(63, 153), (179, 153)], (105, 190, 255, 95), 2)
    _polygon(draw, [(123, 102), (139, 110), (123, 118)], (255, 246, 214, 235))
    _line(draw, [(106, 110), (123, 110)], accent, 2)
    _draw_knob(draw, 121, 153, accent)
    _line(draw, [(112, 131), (138, 131)], (255, 246, 214, 190), 2)
    _polygon(draw, [(135, 127), (142, 131), (135, 135)], (255, 246, 214, 220))
    _draw_capacitor(draw, 189, 165, (255, 232, 171, 220))
    _rounded(draw, (144, 153, 170, 165), 3, (44, 50, 83, 230), accent, 2)
    _line(draw, [(149, 159), (165, 159)], (255, 230, 155, 180), 2)
    for x, y in [(74, 87), (105, 87), (151, 87), (184, 87)]:
        _draw_smd(draw, x, y, 13, 6, (209, 196, 161, 238), (122, 106, 78, 200))
    _draw_clean_trace(draw, [(105, 125), (116, 125), (116, 104)], accent)
    _draw_clean_trace(draw, [(140, 104), (153, 104), (153, 126)], accent)
    _hardware_highlights(draw, accent)
    return _downsample(frame)


def draw_power() -> Image.Image:
    frame = _new_canvas()
    glow = _new_canvas()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    accent = (172, 126, 255, 230)

    _soft_shadow(draw)
    _tower_chassis(draw, accent, 3)
    _sci_fi_ambient(draw, accent, 3)
    _base_board(draw, 128, 132, 138, 98, (73, 64, 135, 242), accent)
    _rounded(glow_draw, (56, 78, 202, 191), 20, (172, 126, 255, 78))
    frame.alpha_composite(glow.filter(ImageFilter.GaussianBlur(9 * SCALE)))
    draw = ImageDraw.Draw(frame)

    _mechanical_board_details(draw, accent, 3)
    _ellipse(draw, (70, 105, 121, 156), (27, 34, 64, 255), (218, 207, 255, 230), 3)
    _ellipse(draw, (81, 116, 110, 145), (154, 125, 70, 245), (255, 242, 191, 220), 2)
    _rounded(draw, (75, 109, 116, 118), 4, (210, 221, 229, 215), (132, 146, 160, 170), 1)
    _rounded(draw, (75, 143, 116, 151), 4, (188, 200, 210, 210), (112, 126, 140, 160), 1)
    _line(draw, [(79, 114), (112, 114)], (255, 255, 255, 110), 1)
    _line(draw, [(61, 126), (64, 126)], (255, 242, 191, 220), 3)
    _line(draw, [(61, 136), (64, 136)], (255, 242, 191, 220), 3)
    _draw_chip(draw, 173, 125, 30, 28, (28, 34, 71, 255), (222, 214, 255, 235))
    _rounded(draw, (143, 154, 193, 176), 5, (22, 43, 69, 245), accent, 2)
    for index in range(4):
        x = 150 + index * 10
        _rounded(draw, (x, 159, x + 7, 171), 2, (113, 232, 151, 230))
    _draw_clean_trace(draw, [(103, 157), (126, 164), (143, 164)], (204, 189, 255, 150))
    _line(draw, [(162, 96), (177, 86), (192, 96)], (183, 233, 255, 135), 2)
    _line(draw, [(177, 86), (177, 100)], (183, 233, 255, 135), 2)
    for radius in (4, 8):
        _ellipse(draw, (138 - radius, 126 - radius, 138 + radius, 126 + radius), (0, 0, 0, 0), (183, 233, 255, 120), 1)
    _rounded(draw, (122, 163, 137, 177), 4, (31, 46, 79, 230), accent, 2)
    _ellipse(draw, (126, 167, 133, 174), (113, 232, 151, 230), (255, 255, 255, 130), 1)
    for x, y in [(134, 94), (134, 137), (190, 136)]:
        _draw_smd(draw, x, y, 12, 6, (207, 196, 236, 238), (102, 90, 145, 210))
    _hardware_highlights(draw, accent)
    return _downsample(frame)


DRAWERS = {
    "i2c": draw_i2c,
    "filter": draw_filter,
    "peak": draw_peak,
    "power": draw_power,
}

ANIMATION_ACCENTS = {
    "i2c": (66, 168, 255, 255),
    "filter": (47, 214, 128, 255),
    "peak": (255, 180, 64, 255),
    "power": (196, 136, 255, 255),
}


def write_manifest() -> None:
    payload = json.loads(json.dumps(MANIFEST))
    for tower_id, components in COMPONENT_LAYOUT.items():
        payload[tower_id]["component_layout"] = components
        payload[tower_id]["mechanical_detail_layout"] = MECHANICAL_DETAIL_LAYOUT[tower_id]
        payload[tower_id]["board_bounds"] = BOARD_BOUNDS[tower_id]
        payload[tower_id]["ambient_effect_cues"] = AMBIENT_EFFECT_CUES + [AMBIENT_SIGNATURE_CUES[tower_id]]
        payload[tower_id]["board_presentation_cues"] = BOARD_PRESENTATION_CUES
        payload[tower_id]["component_presentation_cues"] = COMPONENT_PRESENTATION_CUES
        payload[tower_id]["animation_cues"] = [
            "8-frame idle hardware sprite cycle",
            "8-frame attack hardware sprite burst",
            "board-contained scan pulse",
            f"{tower_id} specific attack energy signature",
        ]
        payload[tower_id]["attack_effect_cues"] = [
            "separate beam sprite sheet",
            "separate particle range sprite sheet",
            "clear emitter flare",
            "readable pulsed energy path",
            "volumetric glow",
            "soft scatter halo",
            "depth-layered particles",
            "perspective falloff",
        ]
    (OUT_DIR / "tower-hardware-manifest.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def _shift_image(image: Image.Image, y_offset: int) -> Image.Image:
    frame = Image.new("RGBA", image.size, (0, 0, 0, 0))
    frame.alpha_composite(image, (0, y_offset))
    return frame


def _draw_idle_overlay(frame: Image.Image, tower_id: str, frame_index: int) -> None:
    draw = ImageDraw.Draw(frame, "RGBA")
    accent = ANIMATION_ACCENTS[tower_id]
    phase = frame_index / TOWER_ANIM_COLUMNS
    board = BOARD_BOUNDS[tower_id]
    board_x0, board_y0, board_x1, board_y1 = board
    scan_y = int(board_y0 + 10 + ((board_y1 - board_y0 - 20) * phase))
    alpha = int(90 + 65 * math.sin(phase * math.tau) ** 2)
    draw.line((board_x0 + 10, scan_y, board_x1 - 10, scan_y - 7), fill=(*accent[:3], alpha), width=2)
    draw.line((board_x0 + 20, scan_y + 8, board_x1 - 22, scan_y + 3), fill=(*accent[:3], max(38, alpha // 2)), width=1)

    ring_alpha = int(44 + 28 * math.sin(phase * math.tau + 0.6))
    ring_y = 201 + int(2 * math.sin(phase * math.tau + 0.4))
    draw.ellipse((70, ring_y - 12, 186, ring_y + 18), outline=(*accent[:3], ring_alpha), width=2)
    mote_angle = phase * math.tau
    for offset in (0.0, 2.2, 4.3):
        mx = 128 + int(math.cos(mote_angle + offset) * 55)
        my = 123 + int(math.sin(mote_angle + offset) * 34)
        draw.ellipse((mx - 2, my - 2, mx + 2, my + 2), fill=(*accent[:3], 92))


def _draw_attack_overlay(frame: Image.Image, tower_id: str, frame_index: int) -> None:
    draw = ImageDraw.Draw(frame, "RGBA")
    accent = ANIMATION_ACCENTS[tower_id]
    progress = frame_index / max(1, TOWER_ANIM_COLUMNS - 1)
    pulse = math.sin(progress * math.pi)
    alpha = int(70 + 150 * pulse)

    radius = 30 + int(52 * progress)
    draw.ellipse((128 - radius, 128 - radius, 128 + radius, 128 + radius), outline=(*accent[:3], max(30, alpha // 2)), width=3)
    draw.ellipse((84 - radius // 3, 190 - radius // 6, 172 + radius // 3, 214 + radius // 6), outline=(*accent[:3], max(40, alpha // 3)), width=2)

    if tower_id == "i2c":
        y0 = 102 + int(3 * pulse)
        for lane in (0, 12):
            draw.line((72, y0 + lane, 184, y0 + lane - 18), fill=(*accent[:3], alpha), width=3)
            draw.line((92, y0 + lane + 11, 154, y0 + lane), fill=(230, 248, 255, max(70, alpha // 2)), width=1)
    elif tower_id == "filter":
        points = []
        for step in range(9):
            x = 66 + step * 15
            y = 119 + int(math.sin(step * 0.9 + progress * math.tau) * (16 - 8 * progress))
            points.append((x, y))
        draw.line(points, fill=(*accent[:3], alpha), width=3, joint="curve")
        draw.line((70, 141, 184, 141), fill=(215, 255, 235, max(65, alpha // 3)), width=2)
    elif tower_id == "peak":
        cx = 128
        cy = 108 - int(4 * pulse)
        draw.line((cx, cy - 38, cx, cy + 38), fill=(*accent[:3], alpha), width=3)
        draw.line((cx - 38, cy, cx + 38, cy), fill=(*accent[:3], alpha), width=3)
        draw.polygon(((cx, cy - 28), (cx + 16, cy + 14), (cx - 16, cy + 14)), outline=(255, 245, 205, max(70, alpha // 2)))
    else:
        cx = 128
        cy = 126
        for offset in (-34, -12, 12, 34):
            draw.arc((cx - 62 + offset // 5, cy - 54, cx + 62 + offset // 5, cy + 54), 210 + offset, 330 + offset, fill=(*accent[:3], alpha), width=3)
        draw.line((88, 154, 168, 105), fill=(238, 228, 255, max(80, alpha // 2)), width=2)


def make_animation_sheet(tower_id: str, base: Image.Image) -> Image.Image:
    sheet = Image.new("RGBA", (SIZE * TOWER_ANIM_COLUMNS, SIZE * TOWER_ANIM_ROWS), (0, 0, 0, 0))
    for frame_index in range(TOWER_ANIM_COLUMNS):
        phase = frame_index / TOWER_ANIM_COLUMNS
        idle_y = int(round(math.sin(phase * math.tau) * 2.0))
        idle = _shift_image(base, idle_y)
        _draw_idle_overlay(idle, tower_id, frame_index)
        sheet.alpha_composite(idle, (frame_index * SIZE, 0))

        attack_scale = 1.0 + 0.018 * math.sin((frame_index / max(1, TOWER_ANIM_COLUMNS - 1)) * math.pi)
        scaled_size = int(round(SIZE * attack_scale))
        attack_base = base.resize((scaled_size, scaled_size), Image.Resampling.LANCZOS)
        attack = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        attack.alpha_composite(attack_base, ((SIZE - scaled_size) // 2, (SIZE - scaled_size) // 2 - 1))
        _draw_attack_overlay(attack, tower_id, frame_index)
        sheet.alpha_composite(attack, (frame_index * SIZE, SIZE))
    return sheet


def make_attack_beam_sheet(tower_id: str) -> Image.Image:
    frame_width, frame_height = BEAM_FRAME_SIZE
    sheet = Image.new("RGBA", (frame_width * ATTACK_EFFECT_FRAMES, frame_height), (0, 0, 0, 0))
    accent = ANIMATION_ACCENTS[tower_id]
    for frame_index in range(ATTACK_EFFECT_FRAMES):
        progress = frame_index / max(1, ATTACK_EFFECT_FRAMES - 1)
        pulse = math.sin(progress * math.pi)
        frame = Image.new("RGBA", BEAM_FRAME_SIZE, (0, 0, 0, 0))
        start_x = 12
        end_x = int(54 + 128 * progress)
        center_y = frame_height // 2
        core_alpha = int(104 + 132 * pulse)

        glow = Image.new("RGBA", BEAM_FRAME_SIZE, (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow, "RGBA")
        glow_draw.line((start_x, center_y, end_x, center_y), fill=(*accent[:3], int(34 + 64 * pulse)), width=34)
        glow_draw.ellipse((start_x - 18, center_y - 22, start_x + 28, center_y + 22), fill=(*accent[:3], int(68 + 86 * pulse)))
        frame.alpha_composite(glow.filter(ImageFilter.GaussianBlur(8.0)))

        volume = Image.new("RGBA", BEAM_FRAME_SIZE, (0, 0, 0, 0))
        volume_draw = ImageDraw.Draw(volume, "RGBA")
        taper = 10 + int(8 * pulse)
        volume_draw.polygon(
            (
                (start_x, center_y - taper),
                (end_x, center_y - max(3, taper // 3)),
                (min(frame_width - 4, end_x + 12), center_y),
                (end_x, center_y + max(3, taper // 3)),
                (start_x, center_y + taper),
            ),
            fill=(*accent[:3], int(58 + 78 * pulse)),
        )
        frame.alpha_composite(volume.filter(ImageFilter.GaussianBlur(3.2)))

        draw = ImageDraw.Draw(frame, "RGBA")
        draw.line((start_x, center_y, end_x, center_y), fill=(*accent[:3], core_alpha), width=5)
        draw.line((start_x + 4, center_y - 1, end_x - 4, center_y - 1), fill=(250, 253, 255, max(94, core_alpha // 2)), width=2)
        draw.line((start_x + 7, center_y + 4, end_x - 2, center_y + 2), fill=(*accent[:3], max(50, core_alpha // 3)), width=2)

        flare_radius = 9 + int(12 * pulse)
        flare = Image.new("RGBA", BEAM_FRAME_SIZE, (0, 0, 0, 0))
        flare_draw = ImageDraw.Draw(flare, "RGBA")
        flare_draw.ellipse((start_x - flare_radius, center_y - flare_radius, start_x + flare_radius, center_y + flare_radius), fill=(*accent[:3], int(118 + 96 * pulse)))
        flare_draw.ellipse((start_x - flare_radius * 2, center_y - flare_radius, start_x + flare_radius * 2, center_y + flare_radius), fill=(*accent[:3], int(28 + 50 * pulse)))
        frame.alpha_composite(flare.filter(ImageFilter.GaussianBlur(2.8)))
        draw = ImageDraw.Draw(frame, "RGBA")
        draw.ellipse((start_x - 5, center_y - 5, start_x + 5, center_y + 5), fill=(255, 255, 255, 220))

        particle_glow = Image.new("RGBA", BEAM_FRAME_SIZE, (0, 0, 0, 0))
        particle_glow_draw = ImageDraw.Draw(particle_glow, "RGBA")
        sharp_particles = ImageDraw.Draw(frame, "RGBA")
        for particle_index in range(16):
            particle_progress = (progress + particle_index * 0.071) % 1.0
            depth = 0.45 + 0.55 * ((particle_index % 5) / 4.0)
            x = int(24 + particle_progress * 154)
            y = center_y + int(math.sin(particle_index * 1.47 + progress * math.tau) * (5 + 12 * pulse) * depth)
            size = 1 + ((particle_index + frame_index) % 4)
            alpha = int((44 + 92 * pulse) * depth)
            particle_glow_draw.ellipse((x - size * 2, y - size * 2, x + size * 2, y + size * 2), fill=(*accent[:3], alpha))
            if particle_index % 2 == 0:
                sharp_particles.ellipse((x - size, y - size, x + size, y + size), fill=(246, 252, 255, max(42, alpha // 2)))
        frame.alpha_composite(particle_glow.filter(ImageFilter.GaussianBlur(2.0)))

        if tower_id == "i2c":
            for offset in (-7, 7):
                draw.line((22, center_y + offset, end_x, center_y + offset // 2), fill=(*accent[:3], max(42, core_alpha // 3)), width=2)
        elif tower_id == "filter":
            wave = [(x, center_y + int(math.sin(x * 0.13 + progress * math.tau) * 7 * (1.0 - progress * 0.45))) for x in range(22, max(24, end_x), 12)]
            if len(wave) > 1:
                draw.line(wave, fill=(224, 255, 238, max(58, core_alpha // 3)), width=2)
        elif tower_id == "peak":
            tip_x = min(frame_width - 22, end_x)
            draw.line((tip_x, center_y - 17, tip_x, center_y + 17), fill=(255, 242, 204, max(72, core_alpha // 2)), width=2)
            draw.line((tip_x - 16, center_y, tip_x + 16, center_y), fill=(255, 242, 204, max(72, core_alpha // 2)), width=2)
        else:
            for arc_index in range(3):
                x0 = 28 + arc_index * 38 + int(progress * 18)
                draw.arc((x0, center_y - 22, x0 + 34, center_y + 22), 210, 330, fill=(238, 228, 255, max(48, core_alpha // 3)), width=2)

        sheet.alpha_composite(frame, (frame_index * frame_width, 0))
    return sheet


def make_attack_range_sheet(tower_id: str) -> Image.Image:
    frame_width, frame_height = RANGE_FRAME_SIZE
    sheet = Image.new("RGBA", (frame_width * ATTACK_EFFECT_FRAMES, frame_height), (0, 0, 0, 0))
    accent = ANIMATION_ACCENTS[tower_id]
    for frame_index in range(ATTACK_EFFECT_FRAMES):
        progress = frame_index / max(1, ATTACK_EFFECT_FRAMES - 1)
        pulse = math.sin(progress * math.pi)
        frame = Image.new("RGBA", RANGE_FRAME_SIZE, (0, 0, 0, 0))
        center = frame_width // 2
        radius = int(28 + progress * 84)
        alpha = int(150 * (1.0 - progress) + 54 * pulse)

        ground_glow = Image.new("RGBA", RANGE_FRAME_SIZE, (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(ground_glow, "RGBA")
        ellipse_height = max(18, int(radius * 0.62))
        glow_draw.ellipse(
            (center - radius - 18, center - ellipse_height - 8, center + radius + 18, center + ellipse_height + 8),
            fill=(*accent[:3], int(26 + 52 * pulse)),
        )
        glow_draw.ellipse(
            (center - radius, center - ellipse_height, center + radius, center + ellipse_height),
            outline=(*accent[:3], max(34, alpha)),
            width=8,
        )
        frame.alpha_composite(ground_glow.filter(ImageFilter.GaussianBlur(7.5)))

        ring_layer = Image.new("RGBA", RANGE_FRAME_SIZE, (0, 0, 0, 0))
        ring_draw = ImageDraw.Draw(ring_layer, "RGBA")
        ring_draw.ellipse((center - radius, center - ellipse_height, center + radius, center + ellipse_height), outline=(*accent[:3], max(35, alpha)), width=3)
        inner_radius = max(10, radius // 2)
        inner_height = max(8, ellipse_height // 2)
        ring_draw.ellipse((center - inner_radius, center - inner_height, center + inner_radius, center + inner_height), outline=(255, 255, 255, max(38, alpha // 2)), width=2)
        frame.alpha_composite(ring_layer.filter(ImageFilter.GaussianBlur(1.2)))

        draw = ImageDraw.Draw(frame, "RGBA")
        draw.ellipse((center - 7, center - 7, center + 7, center + 7), fill=(*accent[:3], int(72 + 94 * pulse)))

        particle_glow = Image.new("RGBA", RANGE_FRAME_SIZE, (0, 0, 0, 0))
        particle_glow_draw = ImageDraw.Draw(particle_glow, "RGBA")
        for particle_index in range(28):
            angle = particle_index * (math.tau / 28.0) + progress * math.tau * (0.45 if particle_index % 2 == 0 else -0.25)
            spread = radius * (0.58 + 0.34 * ((particle_index % 5) / 4.0))
            x = center + int(math.cos(angle) * spread)
            y = center + int(math.sin(angle) * spread * 0.72)
            size = 1 + ((particle_index + frame_index) % 4)
            depth_alpha = max(24, int(alpha * (0.46 + 0.45 * ((particle_index % 4) / 3.0))))
            particle_glow_draw.ellipse((x - size * 3, y - size * 2, x + size * 3, y + size * 2), fill=(*accent[:3], depth_alpha))
            if particle_index % 3 == 0:
                draw.ellipse((x - size, y - size, x + size, y + size), fill=(248, 252, 255, max(30, depth_alpha // 2)))
        frame.alpha_composite(particle_glow.filter(ImageFilter.GaussianBlur(2.4)))

        if tower_id == "filter":
            for offset in (-24, 0, 24):
                draw.arc((center - radius, center - ellipse_height + offset // 2, center + radius, center + ellipse_height + offset // 2), 20, 160, fill=(210, 255, 230, max(32, alpha // 2)), width=2)
        elif tower_id == "peak":
            draw.polygon(((center, center - ellipse_height), (center + radius // 5, center), (center, center + ellipse_height), (center - radius // 5, center)), outline=(255, 242, 204, max(42, alpha)))
        elif tower_id == "power":
            draw.arc((center - radius, center - ellipse_height, center + radius, center + ellipse_height), 230, 315, fill=(238, 228, 255, max(42, alpha)), width=5)
            draw.arc((center - radius + 12, center - ellipse_height + 8, center + radius - 12, center + ellipse_height - 8), 40, 145, fill=(238, 228, 255, max(32, alpha // 2)), width=3)
        else:
            draw.line((center - radius, center, center + radius, center), fill=(230, 248, 255, max(34, alpha // 2)), width=2)
            draw.line((center, center - ellipse_height, center, center + ellipse_height), fill=(230, 248, 255, max(34, alpha // 2)), width=2)

        sheet.alpha_composite(frame, (frame_index * frame_width, 0))
    return sheet


def make_overview() -> Image.Image:
    labels = {
        "i2c": "I2C sensor breakout",
        "filter": "op-amp RC filter",
        "peak": "comparator peak detector",
        "power": "battery wake",
    }
    overview = Image.new("RGBA", (600, 540), (248, 252, 255, 255))
    draw = ImageDraw.Draw(overview)
    for index, tower_id in enumerate(TOWER_IDS):
        image = Image.open(OUT_DIR / f"tower_{tower_id}_hardware.png").convert("RGBA")
        x = (index % 2) * 300 + 22
        y = (index // 2) * 270 + 0
        overview.alpha_composite(image, (x, y))
        draw.text((x + 6, y + 226), labels[tower_id], fill=(28, 54, 78, 255))
    return overview


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for tower_id in TOWER_IDS:
        base = DRAWERS[tower_id]()
        base.save(OUT_DIR / f"tower_{tower_id}_hardware.png")
        make_animation_sheet(tower_id, base).save(OUT_DIR / f"tower_{tower_id}_hardware_anim.png")
        make_attack_beam_sheet(tower_id).save(OUT_DIR / f"tower_{tower_id}_attack_beam.png")
        make_attack_range_sheet(tower_id).save(OUT_DIR / f"tower_{tower_id}_attack_range.png")
    write_manifest()
    make_overview().save(OUT_DIR / "refined-hardware-tower-overview.png")


if __name__ == "__main__":
    main()
