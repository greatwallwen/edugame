from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


GAME_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = GAME_ROOT / "assets" / "generated"
FRAME_SIZE = 256
SCALE = 3
WORK_SIZE = FRAME_SIZE * SCALE
FRAME_COUNT = 12
SHEET_COLUMNS = 4
SHEET_ROWS = 3


def _scaled_box(box: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    return tuple(int(v * SCALE) for v in box)


def _scaled_points(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(int(x * SCALE), int(y * SCALE)) for x, y in points]


def _rounded_rect(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    radius: float,
    fill: tuple[int, int, int, int] | None,
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
) -> None:
    draw.rounded_rectangle(
        _scaled_box(box),
        radius=int(radius * SCALE),
        fill=fill,
        outline=outline,
        width=max(1, int(width * SCALE)),
    )


def _line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
    width: int = 1,
) -> None:
    draw.line(_scaled_points(points), fill=fill, width=max(1, int(width * SCALE)), joint="curve")


def _new_frame() -> Image.Image:
    return Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))


def _downsample(frame: Image.Image) -> Image.Image:
    return frame.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)


def _soft_shadow(draw: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float) -> None:
    draw.ellipse(_scaled_box((cx - rx, cy - ry, cx + rx, cy + ry)), fill=(15, 23, 42, 55))


def draw_config(frame_index: int) -> Image.Image:
    t = frame_index / FRAME_COUNT
    frame = _new_frame()
    glow = _new_frame()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = 128, 128
    pulse = 1.0 + 0.045 * math.sin(t * math.tau * 2.0)

    _soft_shadow(draw, cx, 218, 55, 10)
    _rounded_rect(glow_draw, (cx - 44 * pulse, cy - 44 * pulse, cx + 44 * pulse, cy + 44 * pulse), 14, (73, 126, 240, 130))
    frame = Image.alpha_composite(frame, glow.filter(ImageFilter.GaussianBlur(7 * SCALE)))
    draw = ImageDraw.Draw(frame)

    _rounded_rect(draw, (cx - 40 * pulse, cy - 40 * pulse, cx + 40 * pulse, cy + 40 * pulse), 12, (35, 71, 158, 255), (130, 177, 255, 255), 3)
    for pin in range(5):
        off = -27 + pin * 13.5
        _line(draw, [(cx - 53, cy + off), (cx - 41, cy + off)], (98, 151, 236, 230), 3)
        _line(draw, [(cx + 41, cy + off), (cx + 53, cy + off)], (98, 151, 236, 230), 3)
        _line(draw, [(cx + off, cy - 53), (cx + off, cy - 41)], (98, 151, 236, 230), 3)
        _line(draw, [(cx + off, cy + 41), (cx + off, cy + 53)], (98, 151, 236, 230), 3)

    _rounded_rect(draw, (cx - 26, cy - 24, cx + 26, cy + 24), 7, (24, 48, 112, 255), (231, 242, 255, 245), 3)
    draw.text((int((cx - 18) * SCALE), int((cy - 15) * SCALE)), "{}", fill=(235, 244, 255, 255))

    angle = t * math.tau
    for corner in range(4):
        a = angle + corner * math.pi / 2
        bx = cx + math.cos(a) * 63
        by = cy + math.sin(a) * 63
        tangent_x = math.cos(a + math.pi / 2)
        tangent_y = math.sin(a + math.pi / 2)
        _line(draw, [(bx - tangent_x * 11, by - tangent_y * 11), (bx + tangent_x * 11, by + tangent_y * 11)], (93, 146, 242, 220), 3)
        _line(draw, [(bx, by), (bx - math.cos(a) * 15, by - math.sin(a) * 15)], (93, 146, 242, 220), 3)

    for trace in range(3):
        y = cy - 22 + trace * 22
        _line(draw, [(cx - 18, y), (cx - 7, y), (cx - 7, y + 7), (cx + 18, y + 7)], (116, 170, 255, 145), 2)

    return _downsample(frame)


def draw_noise(frame_index: int) -> Image.Image:
    t = frame_index / FRAME_COUNT
    frame = _new_frame()
    glow = _new_frame()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = 128, 128
    rng = random.Random(1729 + frame_index)
    particles = [
        (-58, -10, 16), (-37, -36, 12), (-13, -4, 26), (17, -26, 15),
        (45, -5, 19), (36, 34, 14), (-23, 36, 13), (63, 29, 8),
        (-64, 29, 9), (4, 49, 10),
    ]

    _soft_shadow(draw, cx, 219, 62, 9)
    for px, py, pr in particles:
        jx = rng.randint(-6, 6)
        jy = rng.randint(-6, 6)
        color = (24, 169, 153, 205) if pr >= 15 else (105, 234, 218, 175)
        glow_draw.ellipse(_scaled_box((cx + px + jx - pr, cy + py + jy - pr, cx + px + jx + pr, cy + py + jy + pr)), fill=color)
    frame = Image.alpha_composite(frame, glow.filter(ImageFilter.GaussianBlur(4 * SCALE)))
    draw = ImageDraw.Draw(frame)

    for px, py, pr in particles:
        jx = rng.randint(-6, 6)
        jy = rng.randint(-6, 6)
        color = (17, 146, 136, 235) if pr >= 15 else (115, 235, 220, 215)
        draw.ellipse(_scaled_box((cx + px + jx - pr, cy + py + jy - pr, cx + px + jx + pr, cy + py + jy + pr)), fill=color)

    jitter = math.sin(t * math.tau * 8.0) * 2.0
    for idx, yy in enumerate([-51, -18, 16, 49]):
        offset = (frame_index * (7 + idx)) % 30
        for xx in range(-85 + offset, 92, 30):
            _line(draw, [(cx + xx, cy + yy + jitter), (cx + xx + 15, cy + yy + jitter)], (14, 116, 108, 150), 2)

    for sx, sy in [(-45, 54), (60, -41), (5, 56), (-3, -61)]:
        _rounded_rect(draw, (cx + sx - 5, cy + sy - 5, cx + sx + 5, cy + sy + 5), 2, (167, 243, 232, 175))

    return _downsample(frame)


def draw_false_peak(frame_index: int) -> Image.Image:
    t = frame_index / FRAME_COUNT
    frame = _new_frame()
    glow = _new_frame()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    cx = 128
    cy = 126 + math.sin(t * math.tau * 1.5) * 8
    flap = math.sin(t * math.tau * 2.0)

    _soft_shadow(draw, cx, 220, 58, 9)
    for layer, alpha, ox in [(2, 60, -13), (1, 85, 9)]:
        gx = cx + ox + math.sin(t * math.tau * 3 + layer) * 4
        gy = cy + layer * 4
        left = [(gx - 10, gy - 8), (gx - 36, gy - 31 - flap * 10), (gx - 58, gy + 1), (gx - 34, gy + 12 + flap * 5)]
        right = [(gx + 10, gy - 8), (gx + 36, gy - 31 - flap * 10), (gx + 58, gy + 1), (gx + 34, gy + 12 + flap * 5)]
        draw.polygon(_scaled_points(left), fill=(74, 129, 255, alpha))
        draw.polygon(_scaled_points(right), fill=(74, 129, 255, alpha))
        draw.ellipse(_scaled_box((gx - 20, gy - 19, gx + 20, gy + 22)), fill=(42, 89, 190, alpha))

    left = [(cx - 13, cy - 10), (cx - 37, cy - 38 - flap * 10), (cx - 47, cy - 8), (cx - 70, cy + 10), (cx - 35, cy + 17 + flap * 5)]
    right = [(cx + 13, cy - 10), (cx + 37, cy - 38 - flap * 10), (cx + 47, cy - 8), (cx + 70, cy + 10), (cx + 35, cy + 17 + flap * 5)]
    glow_draw.polygon(_scaled_points(left), fill=(67, 142, 255, 165))
    glow_draw.polygon(_scaled_points(right), fill=(67, 142, 255, 165))
    frame = Image.alpha_composite(frame, glow.filter(ImageFilter.GaussianBlur(5 * SCALE)))
    draw = ImageDraw.Draw(frame)

    draw.polygon(_scaled_points(left), fill=(70, 132, 245, 225), outline=(168, 205, 255, 235))
    draw.polygon(_scaled_points(right), fill=(70, 132, 245, 225), outline=(168, 205, 255, 235))
    draw.ellipse(_scaled_box((cx - 23, cy - 25, cx + 23, cy + 26)), fill=(35, 69, 155, 250), outline=(167, 205, 255, 245), width=2 * SCALE)
    draw.ellipse(_scaled_box((cx - 8, cy - 35, cx + 8, cy - 18)), fill=(88, 166, 255, 240))

    wave = [(cx - 64, cy + 49), (cx - 38, cy + 49), (cx - 23, cy + 9), (cx - 9, cy + 58), (cx + 8, cy + 30), (cx + 22, cy + 49), (cx + 64, cy + 49)]
    _line(draw, wave, (41, 115, 230, 180), 3)
    for x0 in range(-58, 60, 18):
        _line(draw, [(cx + x0, cy - 57), (cx + x0 + 9, cy - 57)], (158, 201, 255, 150), 2)

    return _downsample(frame)


def draw_power_spike(frame_index: int) -> Image.Image:
    t = frame_index / FRAME_COUNT
    frame = _new_frame()
    glow = _new_frame()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = 128, 126
    hit = max(0.0, math.sin(t * math.tau * 2.2))
    tremor = math.sin(t * math.tau * 7.0) * 2
    scale = 1 + hit * 0.08

    _soft_shadow(draw, cx, 220, 48, 9)
    ring = 45 + hit * 25
    alpha = int(150 - hit * 80)
    glow_draw.ellipse(_scaled_box((cx - ring, cy - ring * 0.72, cx + ring, cy + ring * 0.72)), outline=(255, 117, 31, alpha), width=5 * SCALE)
    glow_draw.ellipse(_scaled_box((cx - ring * 0.68, cy - ring, cx + ring * 0.68, cy + ring)), outline=(215, 38, 56, int(alpha * 0.75)), width=4 * SCALE)

    bolt = [
        (cx - 7 * scale + tremor, cy - 66 * scale),
        (cx + 18 * scale + tremor, cy - 18 * scale),
        (cx + 7 * scale + tremor, cy - 18 * scale),
        (cx + 26 * scale + tremor, cy + 56 * scale),
        (cx - 12 * scale + tremor, cy + 7 * scale),
        (cx + 1 * scale + tremor, cy + 7 * scale),
    ]
    glow_draw.polygon(_scaled_points(bolt), fill=(255, 120, 24, 210))
    glow_draw.line(_scaled_points(bolt) + [_scaled_points(bolt)[0]], fill=(255, 221, 91, 220), width=3 * SCALE, joint="curve")
    frame = Image.alpha_composite(frame, glow.filter(ImageFilter.GaussianBlur(9 * SCALE)))
    draw = ImageDraw.Draw(frame)

    draw.polygon(_scaled_points(bolt), fill=(255, 117, 31, 245), outline=(215, 38, 56, 255))
    inner = [
        (cx - 1 + tremor, cy - 51),
        (cx + 10 + tremor, cy - 14),
        (cx + 3 + tremor, cy - 14),
        (cx + 14 + tremor, cy + 37),
        (cx - 5 + tremor, cy + 3),
        (cx + 3 + tremor, cy + 3),
    ]
    draw.polygon(_scaled_points(inner), fill=(255, 242, 142, 240))

    for arc in range(4):
        phase = t * math.tau * (1.8 + arc * 0.25) + arc
        ax = cx + math.cos(phase) * (35 + arc * 7)
        ay = cy + math.sin(phase * 1.3) * (26 + arc * 4)
        bx = cx + math.cos(phase + 0.9) * (46 + arc * 6)
        by = cy + math.sin(phase * 1.1 + 0.6) * (37 + arc * 3)
        midx = (ax + bx) / 2 + math.sin(phase * 2) * 10
        midy = (ay + by) / 2 + math.cos(phase * 2) * 7
        _line(draw, [(ax, ay), (midx, midy), (bx, by)], (255, 190, 74, 155), 2)

    y = cy + 68
    wave = [(cx - 55, y), (cx - 24, y), (cx - 12, y - 21 - hit * 7), (cx, y + 10), (cx + 14, y - 8), (cx + 31, y), (cx + 56, y)]
    _line(draw, wave, (215, 38, 56, 180), 3)

    return _downsample(frame)


def draw_drift_noise(frame_index: int) -> Image.Image:
    t = frame_index / FRAME_COUNT
    frame = _new_frame()
    glow = _new_frame()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = 128, 128
    drift = math.sin(t * math.tau) * 14
    rng = random.Random(4200 + frame_index)
    particles = [
        (-52, -8, 15), (-29, -31, 11), (-5, -2, 23), (23, -22, 14),
        (49, 0, 17), (33, 34, 13), (-20, 35, 12), (59, 31, 8),
    ]

    _soft_shadow(draw, cx, 219, 62, 9)
    for px, py, pr in particles:
        jx = rng.randint(-4, 4)
        jy = rng.randint(-4, 4)
        glow_draw.ellipse(
            _scaled_box((cx + px + jx - pr, cy + py + jy - pr, cx + px + jx + pr, cy + py + jy + pr)),
            fill=(35, 185, 166, 195),
        )
    frame = Image.alpha_composite(frame, glow.filter(ImageFilter.GaussianBlur(5 * SCALE)))
    draw = ImageDraw.Draw(frame)

    # Slow baseline wander distinguishes drift from high-frequency noise.
    baseline = [
        (cx - 72, cy + 52 + drift * 0.28),
        (cx - 38, cy + 42 + drift * 0.45),
        (cx - 4, cy + 48 + drift * 0.75),
        (cx + 33, cy + 38 + drift),
        (cx + 72, cy + 45 + drift * 1.08),
    ]
    _line(draw, baseline, (13, 148, 136, 190), 4)
    _line(draw, [(cx - 74, cy + 58), (cx + 74, cy + 58)], (148, 232, 218, 110), 2)

    for px, py, pr in particles:
        jx = rng.randint(-4, 4)
        jy = rng.randint(-4, 4)
        color = (13, 148, 136, 230) if pr >= 15 else (94, 234, 212, 210)
        draw.ellipse(_scaled_box((cx + px + jx - pr, cy + py + jy - pr, cx + px + jx + pr, cy + py + jy + pr)), fill=color)

    for marker in range(4):
        x = cx - 54 + marker * 35
        _line(draw, [(x, cy + 65), (x + drift * 0.18, cy + 46)], (20, 184, 166, 145), 2)

    return _downsample(frame)


def draw_hybrid_fault(frame_index: int) -> Image.Image:
    t = frame_index / FRAME_COUNT
    frame = _new_frame()
    glow = _new_frame()
    draw = ImageDraw.Draw(frame)
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = 128, 128
    pulse = 1 + 0.05 * math.sin(t * math.tau * 2.0)

    _soft_shadow(draw, cx, 220, 58, 10)
    _rounded_rect(glow_draw, (cx - 50 * pulse, cy - 50 * pulse, cx + 50 * pulse, cy + 50 * pulse), 18, (92, 120, 255, 105))
    frame = Image.alpha_composite(frame, glow.filter(ImageFilter.GaussianBlur(8 * SCALE)))
    draw = ImageDraw.Draw(frame)

    _rounded_rect(draw, (cx - 47, cy - 47, cx + 47, cy + 47), 16, (35, 48, 104, 245), (142, 171, 255, 240), 3)
    for offset in [-28, 0, 28]:
        _line(draw, [(cx - 46, cy + offset), (cx + 46, cy + offset)], (96, 132, 234, 90), 2)
        _line(draw, [(cx + offset, cy - 46), (cx + offset, cy + 46)], (96, 132, 234, 90), 2)

    # Four rotating symptom cores: config, noise, peak, power.
    orbit = 31
    colors = [(118, 169, 255, 235), (45, 212, 191, 230), (96, 165, 250, 230), (255, 137, 45, 235)]
    for idx, color in enumerate(colors):
        angle = t * math.tau + idx * math.tau / 4
        x = cx + math.cos(angle) * orbit
        y = cy + math.sin(angle) * orbit
        draw.ellipse(_scaled_box((x - 10, y - 10, x + 10, y + 10)), fill=color)
        if idx == 0:
            _rounded_rect(draw, (x - 7, y - 7, x + 7, y + 7), 3, None, (231, 242, 255, 210), 2)
        elif idx == 1:
            for dot in [(-5, -1), (3, -5), (5, 5)]:
                draw.ellipse(_scaled_box((x + dot[0] - 2, y + dot[1] - 2, x + dot[0] + 2, y + dot[1] + 2)), fill=(240, 253, 250, 210))
        elif idx == 2:
            _line(draw, [(x - 7, y + 4), (x - 2, y - 6), (x + 4, y + 5), (x + 8, y - 1)], (239, 246, 255, 210), 2)
        else:
            draw.polygon(_scaled_points([(x - 3, y - 8), (x + 6, y - 1), (x + 1, y - 1), (x + 6, y + 9), (x - 6, y + 1), (x - 1, y + 1)]), fill=(255, 247, 237, 220))

    _rounded_rect(draw, (cx - 18, cy - 18, cx + 18, cy + 18), 8, (18, 29, 72, 245), (219, 234, 254, 230), 2)
    for crack in [[(cx - 44, cy - 31), (cx - 31, cy - 19), (cx - 39, cy - 5)], [(cx + 41, cy + 25), (cx + 26, cy + 17), (cx + 34, cy + 3)]]:
        _line(draw, crack, (255, 221, 91, 170), 2)

    return _downsample(frame)


DRAWERS = {
    "config": draw_config,
    "noise": draw_noise,
    "false_peak": draw_false_peak,
    "power_spike": draw_power_spike,
    "drift_noise": draw_drift_noise,
    "hybrid_fault": draw_hybrid_fault,
}


def make_sheet(enemy_type: str) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_SIZE * SHEET_COLUMNS, FRAME_SIZE * SHEET_ROWS), (0, 0, 0, 0))
    drawer = DRAWERS[enemy_type]
    for frame_index in range(FRAME_COUNT):
        x = (frame_index % SHEET_COLUMNS) * FRAME_SIZE
        y = (frame_index // SHEET_COLUMNS) * FRAME_SIZE
        sheet.alpha_composite(drawer(frame_index), (x, y))
    return sheet


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for enemy_type in DRAWERS:
        make_sheet(enemy_type).save(OUT_DIR / f"enemy_anim_{enemy_type}.png")


if __name__ == "__main__":
    main()
