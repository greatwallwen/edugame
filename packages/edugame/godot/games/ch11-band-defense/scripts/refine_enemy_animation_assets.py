from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


GAME_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = GAME_ROOT / "assets" / "generated"
OUT_DIR = GAME_ROOT / "assets" / "staged-production" / "refined-graybox"
FRAME_SIZE = 256
FRAME_COUNT = 12
SHEET_COLUMNS = 4
SHEET_ROWS = 3
ENEMY_TYPES = ("config", "noise", "false_peak", "power_spike", "drift_noise", "hybrid_fault")


TYPE_STYLES = {
    "config": {
        "accent": (255, 137, 45, 210),
        "secondary": (91, 141, 255, 170),
        "trail": (255, 107, 35, 65),
        "angle": -7.5,
        "jitter": 2.5,
    },
    "noise": {
        "accent": (72, 238, 214, 210),
        "secondary": (16, 185, 129, 160),
        "trail": (45, 212, 191, 70),
        "angle": 3.0,
        "jitter": 5.5,
    },
    "false_peak": {
        "accent": (96, 165, 250, 220),
        "secondary": (255, 194, 71, 170),
        "trail": (96, 165, 250, 65),
        "angle": -5.0,
        "jitter": 3.0,
    },
    "power_spike": {
        "accent": (255, 131, 46, 230),
        "secondary": (190, 58, 255, 170),
        "trail": (255, 107, 35, 75),
        "angle": 6.5,
        "jitter": 4.0,
    },
    "drift_noise": {
        "accent": (94, 234, 212, 215),
        "secondary": (20, 184, 166, 160),
        "trail": (45, 212, 191, 65),
        "angle": -3.5,
        "jitter": 4.5,
    },
    "hybrid_fault": {
        "accent": (168, 85, 247, 220),
        "secondary": (255, 177, 66, 170),
        "trail": (129, 140, 248, 70),
        "angle": 5.0,
        "jitter": 3.8,
    },
}


def _source_path(enemy_type: str) -> Path:
    return SOURCE_DIR / f"enemy_anim_{enemy_type}.png"


def _out_path(enemy_type: str) -> Path:
    return OUT_DIR / f"enemy_anim_{enemy_type}_refined_graybox.png"


def _frame_from_sheet(sheet: Image.Image, frame_index: int) -> Image.Image:
    x = (frame_index % SHEET_COLUMNS) * FRAME_SIZE
    y = (frame_index // SHEET_COLUMNS) * FRAME_SIZE
    return sheet.crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE)).convert("RGBA")


def _alpha_bbox(frame: Image.Image) -> tuple[int, int, int, int]:
    alpha = frame.getchannel("A")
    return alpha.getbbox() or (56, 56, 200, 200)


def _trim_soft_shadow(frame: Image.Image) -> Image.Image:
    r, g, b, a = frame.split()
    # The graybox sheets already carry useful soft shadows, but the stronger
    # bottom ovals make units feel planted. Fade only very low, dark pixels.
    pixels = frame.load()
    alpha = a.load()
    for y in range(FRAME_SIZE):
        for x in range(FRAME_SIZE):
            pr, pg, pb, pa = pixels[x, y]
            if pa > 0 and y > 184 and pr < 35 and pg < 40 and pb < 60:
                alpha[x, y] = int(pa * 0.14)
    return Image.merge("RGBA", (r, g, b, a))


def _transform_subject(frame: Image.Image, enemy_type: str, frame_index: int) -> Image.Image:
    style = TYPE_STYLES[enemy_type]
    t = frame_index / FRAME_COUNT
    wobble = math.sin(t * math.tau * 1.5) * style["jitter"]
    angle = style["angle"] + math.sin(t * math.tau * 2.0) * 2.2

    bbox = _alpha_bbox(frame)
    subject = frame.crop(bbox)
    subject = subject.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)

    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    center_x = 132 + int(math.sin(t * math.tau * 1.2) * style["jitter"] * 0.6)
    center_y = 126 + int(wobble)
    x = int(center_x - subject.width / 2)
    y = int(center_y - subject.height / 2)
    canvas.alpha_composite(subject, (x, y))
    return canvas


def _draw_motion_trails(draw: ImageDraw.ImageDraw, enemy_type: str, frame_index: int) -> None:
    style = TYPE_STYLES[enemy_type]
    rng = random.Random(9100 + frame_index * 31 + ENEMY_TYPES.index(enemy_type) * 1009)
    accent = style["accent"]
    trail = style["trail"]
    t = frame_index / FRAME_COUNT

    for band in range(5):
        y = 82 + band * 22 + math.sin(t * math.tau * 1.5 + band) * 6
        start = 27 + band * 4 + rng.randint(-2, 3)
        length = 30 + band * 8 + rng.randint(-4, 5)
        alpha = max(24, trail[3] - band * 8)
        draw.line(
            [(start, y), (start + length, y - 5), (start + length + 18, y - 2)],
            fill=(trail[0], trail[1], trail[2], alpha),
            width=max(2, 6 - band),
            joint="curve",
        )

    for shard in range(11):
        x = rng.randint(35, 204)
        y = rng.randint(54, 182)
        if rng.random() < 0.6:
            x = rng.randint(42, 82)
        size = rng.randint(3, 8)
        skew = rng.randint(-5, 7)
        color = accent if shard % 3 == 0 else style["secondary"]
        draw.polygon(
            [(x, y), (x + size + skew, y - size // 2), (x + size, y + size), (x - size // 2, y + size // 2)],
            fill=(color[0], color[1], color[2], rng.randint(95, 175)),
        )


def _irregular_blob_points(
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    seed: int,
    phase: float,
    count: int = 18,
) -> list[tuple[float, float]]:
    rng = random.Random(seed)
    points: list[tuple[float, float]] = []
    for index in range(count):
        angle = math.tau * index / count
        wobble = 1.0 + rng.uniform(-0.22, 0.2) + math.sin(phase + index * 1.7) * 0.055
        x = cx + math.cos(angle) * rx * wobble
        y = cy + math.sin(angle) * ry * wobble
        points.append((x, y))
    return points


def _draw_dimensional_shell(draw: ImageDraw.ImageDraw, enemy_type: str, frame_index: int) -> None:
    style = TYPE_STYLES[enemy_type]
    accent = style["accent"]
    secondary = style["secondary"]
    t = frame_index / FRAME_COUNT
    phase = t * math.tau
    seed = 12000 + ENEMY_TYPES.index(enemy_type) * 997 + frame_index * 17

    if enemy_type in ("config", "hybrid_fault"):
        cx = 127 + math.sin(phase * 1.2) * 3
        cy = 126 + math.cos(phase * 1.1) * 3
        points = _irregular_blob_points(cx, cy, 62, 48, seed, phase)
        offset_points = [(x + 8, y + 9) for x, y in points]
        draw.polygon(offset_points, fill=(8, 18, 31, 54))
        draw.polygon(points, fill=(accent[0], accent[1], accent[2], 42))
        draw.line(points + [points[0]], fill=(accent[0], accent[1], accent[2], 110), width=2, joint="curve")
        highlight = _irregular_blob_points(cx - 10, cy - 13, 37, 22, seed + 1, phase, 12)
        draw.line(highlight[:7], fill=(235, 244, 255, 100), width=3, joint="curve")
    elif enemy_type == "power_spike":
        points = _irregular_blob_points(128, 129, 45, 70, seed, phase, 14)
        draw.polygon([(x + 5, y + 7) for x, y in points], fill=(42, 18, 14, 54))
        draw.polygon(points, fill=(255, 118, 35, 36))
        draw.line(points + [points[0]], fill=(255, 207, 94, 95), width=2, joint="curve")
    else:
        cx = 127 + math.sin(phase) * 3
        cy = 125 + math.cos(phase * 1.3) * 2
        points = _irregular_blob_points(cx, cy, 69, 43, seed, phase)
        draw.polygon([(x + 7, y + 8) for x, y in points], fill=(6, 22, 32, 45))
        draw.polygon(points, fill=(secondary[0], secondary[1], secondary[2], 34))
        draw.line(points + [points[0]], fill=(secondary[0], secondary[1], secondary[2], 90), width=2, joint="curve")


def _draw_foreground_damage(draw: ImageDraw.ImageDraw, enemy_type: str, frame_index: int) -> None:
    style = TYPE_STYLES[enemy_type]
    accent = style["accent"]
    secondary = style["secondary"]
    rng = random.Random(15000 + ENEMY_TYPES.index(enemy_type) * 677 + frame_index * 29)

    for shard in range(9):
        x = rng.randint(72, 190)
        y = rng.randint(62, 170)
        size = rng.randint(5, 15)
        color = accent if shard % 2 == 0 else secondary
        alpha = rng.randint(75, 145)
        points = [
            (x, y - size),
            (x + size + rng.randint(-3, 5), y + rng.randint(-4, 4)),
            (x + rng.randint(-4, 4), y + size),
            (x - size + rng.randint(-4, 3), y + rng.randint(-4, 4)),
        ]
        draw.polygon(points, fill=(color[0], color[1], color[2], alpha))
        draw.line(points + [points[0]], fill=(238, 246, 255, min(95, alpha)), width=1)

    for crack in range(4):
        x = rng.randint(84, 174)
        y = rng.randint(76, 154)
        pts = [(x, y)]
        for _ in range(3):
            x += rng.randint(-15, 15)
            y += rng.randint(6, 17)
            pts.append((x, y))
        draw.line(pts, fill=(255, 238, 177, 115), width=2, joint="curve")


def _draw_type_signature(draw: ImageDraw.ImageDraw, enemy_type: str, frame_index: int) -> None:
    style = TYPE_STYLES[enemy_type]
    accent = style["accent"]
    secondary = style["secondary"]
    t = frame_index / FRAME_COUNT
    phase = t * math.tau

    if enemy_type == "config":
        for i in range(3):
            y = 93 + i * 22 + math.sin(phase + i) * 2
            draw.line([(168, y), (193, y + 4), (207, y + 4)], fill=accent, width=3)
            draw.line([(197, y - 7), (207, y + 4), (196, y + 14)], fill=accent, width=2)
    elif enemy_type == "noise":
        for i in range(18):
            x = 54 + i * 8
            y = 196 + math.sin(phase * 5 + i) * 8
            draw.point((x, y), fill=accent)
            draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(accent[0], accent[1], accent[2], 130))
    elif enemy_type == "false_peak":
        base_y = 191
        pts = [(55, base_y), (91, base_y), (108, 142), (125, base_y + 13), (144, 166), (166, base_y), (206, base_y)]
        draw.line(pts, fill=secondary, width=4, joint="curve")
        draw.line([(108, 142), (108, 122)], fill=accent, width=3)
    elif enemy_type == "power_spike":
        for i in range(4):
            x = 65 + i * 41 + math.sin(phase + i) * 5
            draw.arc((x - 18, 74, x + 18, 174), start=250, end=92, fill=secondary, width=3)
        draw.line([(65, 194), (101, 194), (113, 166), (128, 211), (147, 182), (163, 194), (204, 194)], fill=accent, width=4)
    elif enemy_type == "drift_noise":
        pts = []
        for i in range(9):
            x = 48 + i * 20
            y = 187 + math.sin(phase * 0.9 + i * 0.7) * 12 + i * 0.8
            pts.append((x, y))
        draw.line(pts, fill=secondary, width=4, joint="curve")
    elif enemy_type == "hybrid_fault":
        cx, cy = 180, 78
        for i in range(4):
            a = phase + i * math.tau / 4
            x = cx + math.cos(a) * 21
            y = cy + math.sin(a) * 21
            draw.line([(cx, cy), (x, y)], fill=(secondary[0], secondary[1], secondary[2], 120), width=2)
            draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=accent if i % 2 == 0 else secondary)


def refine_frame(source: Image.Image, enemy_type: str, frame_index: int) -> Image.Image:
    source = _trim_soft_shadow(source)
    subject = _transform_subject(source, enemy_type, frame_index)

    trails = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    trail_draw = ImageDraw.Draw(trails)
    _draw_motion_trails(trail_draw, enemy_type, frame_index)
    trails = trails.filter(ImageFilter.GaussianBlur(0.45))

    glow = subject.getchannel("A").filter(ImageFilter.GaussianBlur(7))
    style = TYPE_STYLES[enemy_type]
    glow_color = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), style["accent"])
    glow_color.putalpha(glow.point(lambda p: int(p * 0.36)))

    shell = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    shell_draw = ImageDraw.Draw(shell)
    _draw_dimensional_shell(shell_draw, enemy_type, frame_index)
    shell = shell.filter(ImageFilter.GaussianBlur(0.25))

    frame = Image.alpha_composite(trails, shell)
    frame = Image.alpha_composite(frame, glow_color)
    frame = Image.alpha_composite(frame, subject)

    linework = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    line_draw = ImageDraw.Draw(linework)
    _draw_type_signature(line_draw, enemy_type, frame_index)
    _draw_foreground_damage(line_draw, enemy_type, frame_index)
    frame = Image.alpha_composite(frame, linework)
    return frame


def refine_sheet(enemy_type: str) -> Image.Image:
    source_path = _source_path(enemy_type)
    if not source_path.exists():
        raise FileNotFoundError(source_path)
    with Image.open(source_path) as sheet:
        sheet = sheet.convert("RGBA")
        if sheet.size != (FRAME_SIZE * SHEET_COLUMNS, FRAME_SIZE * SHEET_ROWS):
            raise ValueError(f"{source_path.name} must be a 4x3 sheet of 256px frames")
        refined = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
        for frame_index in range(FRAME_COUNT):
            frame = _frame_from_sheet(sheet, frame_index)
            refined_frame = refine_frame(frame, enemy_type, frame_index)
            x = (frame_index % SHEET_COLUMNS) * FRAME_SIZE
            y = (frame_index // SHEET_COLUMNS) * FRAME_SIZE
            refined.alpha_composite(refined_frame, (x, y))
    return refined


def sheet_changed(enemy_type: str) -> bool:
    source_path = _source_path(enemy_type)
    out_path = _out_path(enemy_type)
    if not source_path.exists() or not out_path.exists():
        return False
    with Image.open(source_path) as source, Image.open(out_path) as out:
        diff = ImageChops.difference(source.convert("RGBA"), out.convert("RGBA"))
        return diff.getbbox() is not None


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for enemy_type in ENEMY_TYPES:
        refine_sheet(enemy_type).save(_out_path(enemy_type))


if __name__ == "__main__":
    main()
