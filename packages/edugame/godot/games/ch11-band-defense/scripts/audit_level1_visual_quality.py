import json
import math
import re
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = PROJECT_ROOT.parents[4]
LAYOUTS = PROJECT_ROOT / "scripts" / "level_layouts.gd"
BACKGROUND_DIR = PROJECT_ROOT / "assets" / "backgrounds"
SCREENSHOT_DIR = REPO_ROOT / ".superpowers" / "visual-qa" / "hud"
REPORT_PATH = PROJECT_ROOT / "visual-audit" / "visual-audit-report.json"

MAP_LAYER = BACKGROUND_DIR / "band-defense-map-level1-watch-debug-map-layer.png"
HUD_LAYER = BACKGROUND_DIR / "band-defense-hud-level1-watch-debug-layer.png"
COMPOSITE = BACKGROUND_DIR / "band-defense-map-level1-watch-debug.png"
MAP_LAYERS = {
    1: MAP_LAYER,
    2: BACKGROUND_DIR / "band-defense-map-level2-watch-debug-map-layer.png",
    3: BACKGROUND_DIR / "band-defense-map-level3-watch-debug-map-layer.png",
}
GAME_HUD_SHOT = SCREENSHOT_DIR / "03-game-hud.png"
GAME_HUD_SHOTS = {
    1: GAME_HUD_SHOT,
    2: SCREENSHOT_DIR / "06-level2-game-hud.png",
    3: SCREENSHOT_DIR / "07-level3-game-hud.png",
}
SLOT_MENU_SHOT = SCREENSHOT_DIR / "04-slot-menu.png"
MAIN_MENU_SHOT = SCREENSHOT_DIR / "01-main-menu.png"
LEVEL_SELECT_SHOT = SCREENSHOT_DIR / "02-level-select.png"
QUIZ_DIALOG_SHOT = SCREENSHOT_DIR / "05-quiz-dialog.png"

CANVAS = (1280, 720)
RIGHT_SCREEN_SAFE = (966, 8, 1276, 712)
RIGHT_WATCH_TOP = (960, 0, 1280, 24)
RIGHT_WATCH_EDGE = (1270, 0, 1280, 720)
LEFT_MAP_AREA = (0, 0, 960, 720)
RIGHT_HUD_AREA = (960, 0, 1280, 720)
MAP_DIALOG_AREA = (180, 80, 940, 640)


def _load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"missing visual asset: {path}")
    image = Image.open(path).convert("RGBA")
    if image.size != CANVAS:
        raise AssertionError(f"{path.name} should be {CANVAS}, got {image.size}")
    return image


def _extract_level_layout(level_number: int):
    source = LAYOUTS.read_text(encoding="utf-8")
    background = {
        1: "LEVEL_ONE_BACKGROUND",
        2: "LEVEL_TWO_BACKGROUND",
        3: "LEVEL_THREE_BACKGROUND",
    }[level_number]
    match = re.search(
        rf'"background": {background},.*?"path": \[(.*?)\],\s+"towerSlots": \[(.*?)\]',
        source,
        flags=re.S,
    )
    if not match:
        raise AssertionError(f"could not extract level {level_number} path and tower slots")
    path = [
        (float(x), float(y))
        for x, y in re.findall(r"Vector2\(([-\d.]+),\s*([-\d.]+)\)", match.group(1))
    ]
    slots = [
        (float(x), float(y))
        for x, y in re.findall(r"Vector2\(([-\d.]+),\s*([-\d.]+)\)", match.group(2))
    ]
    if len(path) < 2 or len(slots) < 4:
        raise AssertionError(f"unexpected level {level_number} layout: {len(path)} path points, {len(slots)} slots")
    return path, slots


def _extract_level_one_layout():
    return _extract_level_layout(1)


def _distance_to_segment(point, start, end):
    px, py = point
    ax, ay = start
    bx, by = end
    abx = bx - ax
    aby = by - ay
    denom = abx * abx + aby * aby
    if denom <= 0.001:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * abx + (py - ay) * aby) / denom))
    return math.hypot(px - (ax + abx * t), py - (ay + aby * t))


def _distance_to_path(point, path):
    return min(_distance_to_segment(point, path[i], path[i + 1]) for i in range(len(path) - 1))


def _crop_pixels(image: Image.Image, box):
    return list(image.crop(box).getdata())


def _alpha_ratio(image: Image.Image, box, threshold=8):
    pixels = _crop_pixels(image, box)
    return sum(1 for _, _, _, a in pixels if a > threshold) / len(pixels)


def _bright_ratio(image: Image.Image, box, threshold=230):
    pixels = _crop_pixels(image, box)
    bright = 0
    for r, g, b, a in pixels:
        if a > 8 and (r + g + b) / 3.0 >= threshold:
            bright += 1
    return bright / len(pixels)


def _cyan_mask(pixel):
    r, g, b, a = pixel
    return a > 64 and g >= 170 and b >= 190 and r <= 175 and (b - r) >= 45


def _slot_cross_metrics(image: Image.Image, slots):
    metrics = []
    for x, y in slots:
        radius = 24
        box = (
            int(round(x - radius)),
            int(round(y - radius)),
            int(round(x + radius + 1)),
            int(round(y + radius + 1)),
        )
        crop = image.crop(box)
        points = []
        for local_y in range(crop.height):
            for local_x in range(crop.width):
                if _cyan_mask(crop.getpixel((local_x, local_y))):
                    points.append((box[0] + local_x, box[1] + local_y))
        if not points:
            raise AssertionError(f"slot marker at {(x, y)} has no cyan center cross")
        if len(points) < 16:
            centroid_x = x
            centroid_y = y
            max_offset = 0.0
        else:
            centroid_x = sum(px for px, _ in points) / len(points)
            centroid_y = sum(py for _, py in points) / len(points)
            max_offset = max(abs(centroid_x - x), abs(centroid_y - y))
        metrics.append(
            {
                "center": [round(x, 2), round(y, 2)],
                "cyan_pixels": len(points),
                "centroid": [round(centroid_x, 2), round(centroid_y, 2)],
                "max_centroid_offset": round(max_offset, 2),
            }
        )
    return metrics


def _hud_white_panel_bounds(image: Image.Image):
    x1, y1, x2, y2 = RIGHT_SCREEN_SAFE
    points = []
    for y in range(y1, y2):
        for x in range(x1, x2):
            r, g, b, a = image.getpixel((x, y))
            if a > 8 and r >= 236 and g >= 240 and b >= 240:
                points.append((x, y))
    if not points:
        raise AssertionError("right HUD screenshot has no visible white smartwatch UI panel")
    min_x = min(x for x, _ in points)
    max_x = max(x for x, _ in points)
    min_y = min(y for _, y in points)
    max_y = max(y for _, y in points)
    return {
        "x": [min_x, max_x],
        "y": [min_y, max_y],
        "center_x": round((min_x + max_x) / 2.0, 2),
        "width": max_x - min_x + 1,
        "height": max_y - min_y + 1,
    }


def _bright_bounds(image: Image.Image, box, threshold=245):
    x1, y1, x2, y2 = box
    points = []
    for y in range(y1, y2):
        for x in range(x1, x2):
            r, g, b, a = image.getpixel((x, y))
            if a > 8 and min(r, g, b) >= threshold and max(r, g, b) - min(r, g, b) <= 18:
                points.append((x, y))
    if not points:
        raise AssertionError(f"no bright panel pixels found in {box}")
    min_x = min(x for x, _ in points)
    max_x = max(x for x, _ in points)
    min_y = min(y for _, y in points)
    max_y = max(y for _, y in points)
    return {
        "x": [min_x, max_x],
        "y": [min_y, max_y],
        "center_x": round((min_x + max_x) / 2.0, 2),
        "width": max_x - min_x + 1,
        "height": max_y - min_y + 1,
    }


def _dialog_screen_metrics(name: str, image: Image.Image):
    bounds = _bright_bounds(image, MAP_DIALOG_AREA)
    return {
        "name": name,
        "bright_panel_bounds": bounds,
        "right_watch_top_bright_ratio": round(_bright_ratio(image, RIGHT_WATCH_TOP), 5),
        "right_outer_edge_bright_ratio": round(_bright_ratio(image, RIGHT_WATCH_EDGE), 5),
    }


def _assert(condition, message):
    if not condition:
        raise AssertionError(message)


def build_report():
    path, slots = _extract_level_one_layout()
    map_layer = _load_rgba(MAP_LAYER)
    hud_layer = _load_rgba(HUD_LAYER)
    composite = _load_rgba(COMPOSITE)
    game_shot = _load_rgba(GAME_HUD_SHOT)
    slot_shot = _load_rgba(SLOT_MENU_SHOT)
    main_menu_shot = _load_rgba(MAIN_MENU_SHOT)
    level_select_shot = _load_rgba(LEVEL_SELECT_SHOT)
    quiz_dialog_shot = _load_rgba(QUIZ_DIALOG_SHOT)

    slot_distances = [_distance_to_path(slot, path) for slot in slots]
    slot_cross_metrics = _slot_cross_metrics(game_shot, slots)
    hud_bounds = _hud_white_panel_bounds(game_shot)
    levels_report = {}
    for level_number in (1, 2, 3):
        level_path, level_slots = _extract_level_layout(level_number)
        level_map = _load_rgba(MAP_LAYERS[level_number])
        level_shot = _load_rgba(GAME_HUD_SHOTS[level_number])
        distances = [_distance_to_path(slot, level_path) for slot in level_slots]
        level_hud_bounds = _hud_white_panel_bounds(level_shot)
        level_cross_metrics = _slot_cross_metrics(level_shot, level_slots)
        levels_report[str(level_number)] = {
            "path": [[round(x, 2), round(y, 2)] for x, y in level_path],
            "tower_slots": [[round(x, 2), round(y, 2)] for x, y in level_slots],
            "slot_route_min_distance": round(min(distances), 2),
            "slot_route_distances": [round(value, 2) for value in distances],
            "map_alpha_in_right_hud_area": round(_alpha_ratio(level_map, RIGHT_HUD_AREA), 5),
            "hud_panel_center_x": level_hud_bounds["center_x"],
            "hud_panel_width": level_hud_bounds["width"],
            "tower_slot_crosses": level_cross_metrics,
        }

    report = {
        "assets": {
            "map_layer": str(MAP_LAYER.relative_to(PROJECT_ROOT)),
            "hud_layer": str(HUD_LAYER.relative_to(PROJECT_ROOT)),
            "composite": str(COMPOSITE.relative_to(PROJECT_ROOT)),
            "game_hud_shot": str(GAME_HUD_SHOT.relative_to(REPO_ROOT)),
            "slot_menu_shot": str(SLOT_MENU_SHOT.relative_to(REPO_ROOT)),
        },
        "layout": {
            "path": [[round(x, 2), round(y, 2)] for x, y in path],
            "tower_slots": [[round(x, 2), round(y, 2)] for x, y in slots],
            "slot_route_min_distance": round(min(slot_distances), 2),
            "slot_route_distances": [round(value, 2) for value in slot_distances],
        },
        "layer_separation": {
            "map_alpha_in_right_hud_area": round(_alpha_ratio(map_layer, RIGHT_HUD_AREA), 5),
            "hud_alpha_in_left_map_area": round(_alpha_ratio(hud_layer, LEFT_MAP_AREA), 5),
            "composite_alpha_in_canvas": round(_alpha_ratio(composite, (0, 0, 1280, 720)), 5),
        },
        "right_watch": {
            "top_bright_ratio": round(_bright_ratio(game_shot, RIGHT_WATCH_TOP), 5),
            "outer_edge_bright_ratio": round(_bright_ratio(game_shot, RIGHT_WATCH_EDGE), 5),
            "white_panel_bounds": hud_bounds,
        },
        "tower_slots": slot_cross_metrics,
        "levels": levels_report,
        "slot_menu": {
            "right_watch_top_bright_ratio": round(_bright_ratio(slot_shot, RIGHT_WATCH_TOP), 5),
            "right_outer_edge_bright_ratio": round(_bright_ratio(slot_shot, RIGHT_WATCH_EDGE), 5),
        },
        "dialog_screens": [
            _dialog_screen_metrics("main_menu", main_menu_shot),
            _dialog_screen_metrics("level_select", level_select_shot),
            _dialog_screen_metrics("quiz_dialog", quiz_dialog_shot),
        ],
    }

    _assert(report["layout"]["slot_route_min_distance"] >= 50.0, "runtime path is too close to a tower slot")
    for level_number, level_report in levels_report.items():
        _assert(level_report["slot_route_min_distance"] >= 50.0, f"level {level_number} runtime path is too close to a tower slot")
        _assert(level_report["map_alpha_in_right_hud_area"] <= 0.08, f"level {level_number} map layer should not paint over the right HUD layer")
        _assert(1119.0 <= level_report["hud_panel_center_x"] <= 1122.0, f"level {level_number} white HUD panel should be centered in the right smartwatch screen")
        _assert(level_report["hud_panel_width"] <= 300, f"level {level_number} white HUD panel should stay inside the right smartwatch screen")
        for metric in level_report["tower_slot_crosses"]:
            _assert(metric["max_centroid_offset"] <= 2.5, f"level {level_number} tower cross is off center: {metric}")
            _assert(metric["cyan_pixels"] <= 180, f"level {level_number} tower cross is too visually loud: {metric}")
    _assert(report["layer_separation"]["map_alpha_in_right_hud_area"] <= 0.08, "map layer should not paint over the right HUD layer")
    _assert(report["layer_separation"]["hud_alpha_in_left_map_area"] <= 0.08, "right HUD layer should not paint over the left gameplay map")
    _assert(report["right_watch"]["top_bright_ratio"] <= 0.04, "right smartwatch top shell should not contain a large white block")
    _assert(report["right_watch"]["outer_edge_bright_ratio"] <= 0.03, "rightmost watch edge should remain dark")
    _assert(1119.0 <= hud_bounds["center_x"] <= 1122.0, "white HUD panel should be visually centered in the right smartwatch screen")
    _assert(hud_bounds["width"] <= 300, "white HUD panel should stay inside the right smartwatch screen")
    _assert(hud_bounds["x"][0] >= 970 and hud_bounds["x"][1] <= 1270, "white HUD panel should stay within the rounded display glass")
    for metric in slot_cross_metrics:
        _assert(metric["max_centroid_offset"] <= 2.5, f"tower cross is off center: {metric}")
        _assert(metric["cyan_pixels"] <= 180, f"tower cross is too visually loud: {metric}")
    _assert(report["slot_menu"]["right_watch_top_bright_ratio"] <= 0.04, "slot menu should not introduce a white block in the right watch top")
    _assert(report["slot_menu"]["right_outer_edge_bright_ratio"] <= 0.03, "slot menu should keep the right watch edge dark")
    for screen in report["dialog_screens"]:
        bounds = screen["bright_panel_bounds"]
        _assert(bounds["x"][1] <= 930, f"{screen['name']} dialog should leave a clear gutter before the right HUD")
        _assert(bounds["x"][0] >= 180, f"{screen['name']} dialog should stay centered on the map surface")
        _assert(bounds["height"] >= 260, f"{screen['name']} dialog should expose a substantial polished panel")
        _assert(screen["right_watch_top_bright_ratio"] <= 0.04, f"{screen['name']} should not introduce a white block in the right watch top")
        _assert(screen["right_outer_edge_bright_ratio"] <= 0.03, f"{screen['name']} should keep the right watch edge dark")
    return report


def main():
    report = build_report()
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"visual quality audit passed: {REPORT_PATH}")


if __name__ == "__main__":
    main()
