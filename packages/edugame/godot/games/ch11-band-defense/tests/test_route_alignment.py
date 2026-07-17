import math
import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LAYOUTS = PROJECT_ROOT / "scripts" / "level_layouts.gd"

REFERENCE_ROUTES = {
    1: [
        (68, 321),
        (126, 321),
        (185, 260),
        (340, 260),
        (520, 260),
        (639, 322),
        (639, 385),
        (695, 440),
        (734, 440),
        (815, 350),
        (878, 350),
    ],
    2: [
        (68, 334),
        (132, 334),
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
        (880, 347),
    ],
    3: [
        (68, 350),
        (124, 350),
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
        (880, 350),
    ],
}

EXPECTED_ROUTE_ENDPOINTS = {
    1: ((68.0, 321.0), (878.0, 350.0)),
    2: ((68.0, 334.0), (880.0, 347.0)),
    3: ((68.0, 350.0), (880.0, 350.0)),
}

EXPECTED_PORT_TERMINALS = {
    1: ((68.0, 321.0), (878.0, 350.0)),
    2: ((68.0, 334.0), (880.0, 347.0)),
    3: ((68.0, 350.0), (880.0, 350.0)),
}


def _extract_path(level_number: int):
    source = LAYOUTS.read_text(encoding="utf-8")
    background = {
        1: "LEVEL_ONE_BACKGROUND",
        2: "LEVEL_TWO_BACKGROUND",
        3: "LEVEL_THREE_BACKGROUND",
    }[level_number]
    match = re.search(
        rf'"background": {background},.*?"path": \[(.*?)\]',
        source,
        flags=re.S,
    )
    assert match, f"missing path for level {level_number}"
    return [
        (float(x), float(y))
        for x, y in re.findall(r"Vector2\(([-\d.]+),\s*([-\d.]+)\)", match.group(1))
    ]


def _extract_port_centers(level_number: int):
    source = LAYOUTS.read_text(encoding="utf-8")
    background = {
        1: "LEVEL_ONE_BACKGROUND",
        2: "LEVEL_TWO_BACKGROUND",
        3: "LEVEL_THREE_BACKGROUND",
    }[level_number]
    match = re.search(
        rf'"background": {background},.*?"pathLayer": \{{(.*?)\}},\s*"path":',
        source,
        flags=re.S,
    )
    assert match, f"missing path layer for level {level_number}"
    start = re.search(r'"startPort": Vector2\(([-\d.]+),\s*([-\d.]+)\)', match.group(1))
    end = re.search(r'"endPort": Vector2\(([-\d.]+),\s*([-\d.]+)\)', match.group(1))
    assert start and end, f"missing hardware port centers for level {level_number}"
    return (
        (float(start.group(1)), float(start.group(2))),
        (float(end.group(1)), float(end.group(2))),
    )


def _distance_to_segment(point, a, b):
    px, py = point
    ax, ay = a
    bx, by = b
    abx = bx - ax
    aby = by - ay
    denom = abx * abx + aby * aby
    if denom <= 0.001:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * abx + (py - ay) * aby) / denom))
    return math.hypot(px - (ax + abx * t), py - (ay + aby * t))


def _distance_to_polyline(point, route):
    return min(
        _distance_to_segment(point, route[i], route[i + 1])
        for i in range(len(route) - 1)
    )


def _path_length(path):
    return sum(math.dist(path[i], path[i + 1]) for i in range(len(path) - 1))


def _point_at_distance(path, distance):
    remaining = distance
    for i in range(len(path) - 1):
        a = path[i]
        b = path[i + 1]
        segment = math.dist(a, b)
        if remaining <= segment:
            ratio = remaining / segment if segment else 0.0
            return (
                a[0] + (b[0] - a[0]) * ratio,
                a[1] + (b[1] - a[1]) * ratio,
            )
        remaining -= segment
    return path[-1]


def _sample_path(path, count=48):
    total = _path_length(path)
    return [_point_at_distance(path, total * i / (count - 1)) for i in range(count)]


def test_enemy_routes_follow_visible_background_roads():
    for level_number, reference_route in REFERENCE_ROUTES.items():
        actual_route = _extract_path(level_number)
        deviations = [
            _distance_to_polyline(point, reference_route)
            for point in _sample_path(actual_route)
        ]
        max_deviation = max(deviations)
        assert max_deviation <= 44.0, (
            f"level {level_number} enemy route leaves the visible road centerline "
            f"by {max_deviation:.1f}px"
        )


def test_later_levels_enter_goal_without_terminal_zigzag():
    for level_number in (2, 3):
        actual_route = _extract_path(level_number)
        assert actual_route[-1] == EXPECTED_ROUTE_ENDPOINTS[level_number][1]
        assert (855.0, 320.0) not in actual_route


def test_enemy_routes_start_and_end_at_visible_metal_port_terminals():
    for level_number, (expected_start, expected_end) in EXPECTED_ROUTE_ENDPOINTS.items():
        actual_route = _extract_path(level_number)
        assert actual_route[0] == expected_start
        assert actual_route[-1] == expected_end


def test_enemy_route_endpoints_coincide_with_metal_port_terminals():
    for level_number, expected_terminals in EXPECTED_PORT_TERMINALS.items():
        start_port, end_port = _extract_port_centers(level_number)
        route = _extract_path(level_number)
        assert (start_port, end_port) == expected_terminals
        assert start_port == route[0]
        assert end_port == route[-1]
