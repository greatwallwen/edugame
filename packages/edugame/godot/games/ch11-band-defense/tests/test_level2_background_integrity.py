from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


EDUGAME_ROOT = Path(__file__).resolve().parents[4]
BACKGROUND_DIR = EDUGAME_ROOT / "assets" / "games" / "ch11-band-defense" / "backgrounds"
REFERENCE = BACKGROUND_DIR / "band-defense-map-level2-night-run.png"
LEVEL_ONE_WATCH = BACKGROUND_DIR / "band-defense-map-level1-watch-debug.png"
LEVEL_ONE_WATCH_BASE = BACKGROUND_DIR / "band-defense-map-level1-watch-debug-base.png"
LEVEL_ONE_MAP_LAYER = BACKGROUND_DIR / "band-defense-map-level1-watch-debug-map-layer.png"
LEVEL_ONE_HUD_LAYER = BACKGROUND_DIR / "band-defense-hud-level1-watch-debug-layer.png"
LEVEL_ONE_OLD = BACKGROUND_DIR / "band-defense-map-v2-screen.png"
CALIBRATED = BACKGROUND_DIR / "band-defense-map-level2-watch-debug-map-layer.png"
LEVEL_THREE = BACKGROUND_DIR / "band-defense-map-level3-watch-debug-map-layer.png"

LEVEL_ONE_TOWER_SLOTS = [(214, 207), (470, 207), (550, 405), (762, 257)]
LEVEL_TWO_TOWER_SLOTS = [(214, 207), (476, 142), (332, 354), (550, 405), (762, 257), (806, 487)]
LEVEL_THREE_TOWER_SLOTS = [(212, 227), (362, 398), (476, 240), (562, 432), (644, 212), (772, 288), (826, 472)]

LEVEL_TWO_PATH = [
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
]

LEVEL_THREE_PATH = [
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
]


def _distance_to_segment(point, a, b):
    px, py = point
    ax, ay = a
    bx, by = b
    abx = bx - ax
    aby = by - ay
    denom = abx * abx + aby * aby
    if denom <= 0.001:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((px - ax) * abx + (py - ay) * aby) / denom))
    cx = ax + abx * t
    cy = ay + aby * t
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def _near_route(point, radius=28):
    return any(
        _distance_to_segment(point, LEVEL_TWO_PATH[i], LEVEL_TWO_PATH[i + 1]) <= radius
        for i in range(len(LEVEL_TWO_PATH) - 1)
    )


def _is_route_glow(pixel):
    red, green, blue = pixel[:3]
    return blue >= 170 and green >= 170 and blue - red >= 55


def _changed_substantially(a, b):
    return sum(abs(int(a[i]) - int(b[i])) for i in range(3)) >= 95


def _dark_outer_ring_ratio(image, slots):
    dark_pixels = 0
    sampled_pixels = 0
    for center_x, center_y in slots:
        for y in range(center_y - 40, center_y + 41):
            for x in range(center_x - 40, center_x + 41):
                distance = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
                if 25 <= distance <= 40:
                    sampled_pixels += 1
                    red, green, blue = image.getpixel((x, y))
                    if red + green + blue < 185:
                        dark_pixels += 1
    return dark_pixels / sampled_pixels


def _edge_mean(image, rect):
    crop = image.crop(rect).convert("L").filter(ImageFilter.FIND_EDGES)
    pixels = list(crop.getdata())
    return sum(pixels) / len(pixels)


def _combined_edge_mean(image, rects):
    weighted_total = 0.0
    pixel_count = 0
    for rect in rects:
        width = rect[2] - rect[0]
        height = rect[3] - rect[1]
        area = width * height
        weighted_total += _edge_mean(image, rect) * area
        pixel_count += area
    return weighted_total / pixel_count


def _mean_luma(image, rect):
    crop = image.crop(rect).convert("L")
    pixels = list(crop.getdata())
    return sum(pixels) / len(pixels)


def _mean_abs_channel_delta(a, b, rect):
    crop_a = a.crop(rect).convert("RGB")
    crop_b = b.crop(rect).convert("RGB")
    total = 0
    count = 0
    for px_a, px_b in zip(crop_a.getdata(), crop_b.getdata()):
        total += sum(abs(int(px_a[i]) - int(px_b[i])) for i in range(3))
        count += 3
    return total / count


def _ratio_matching(image, rect, predicate):
    crop = image.crop(rect).convert("RGB")
    pixels = list(crop.getdata())
    return sum(1 for pixel in pixels if predicate(pixel)) / len(pixels)


def _opaque_ratio(image, rect):
    crop = image.crop(rect).convert("RGBA")
    pixels = list(crop.getdata())
    return sum(1 for pixel in pixels if pixel[3] > 0) / len(pixels)


def _level_one_safety_mask():
    mask = Image.new("L", (960, 720), 0)
    draw = ImageDraw.Draw(mask)
    level_one_path = [
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
    for start, end in zip(level_one_path, level_one_path[1:]):
        draw.line([start, end], fill=255, width=96)
    for center_x, center_y in (level_one_path[0], level_one_path[-1]):
        draw.ellipse((center_x - 56, center_y - 56, center_x + 56, center_y + 56), fill=0)
    for center_x, center_y in LEVEL_ONE_TOWER_SLOTS:
        draw.ellipse((center_x - 64, center_y - 64, center_x + 64, center_y + 64), fill=255)
    return mask


def _safety_mask(path, slots):
    mask = Image.new("L", (960, 720), 0)
    draw = ImageDraw.Draw(mask)
    for start, end in zip(path, path[1:]):
        draw.line([start, end], fill=255, width=96)
    for center_x, center_y in (path[0], path[-1]):
        draw.ellipse((center_x - 56, center_y - 56, center_x + 56, center_y + 56), fill=0)
    for center_x, center_y in slots:
        draw.ellipse((center_x - 64, center_y - 64, center_x + 64, center_y + 64), fill=255)
    return mask


def _masked_dark_ratio(image, mask):
    crop = image.crop((0, 0, 960, 720)).convert("RGB")
    selected = [pixel for pixel, mask_value in zip(crop.getdata(), mask.getdata()) if mask_value > 0]
    return sum(1 for red, green, blue in selected if red + green + blue < 180) / len(selected)


def _masked_edge_mean(image, mask):
    edge = image.crop((0, 0, 960, 720)).convert("L").filter(ImageFilter.FIND_EDGES)
    selected = [value for value, mask_value in zip(edge.getdata(), mask.getdata()) if mask_value > 0]
    return sum(selected) / len(selected)


def test_level1_watch_debug_background_replaces_old_runtime_map():
    assert LEVEL_ONE_WATCH.exists(), "Level 1 should have a dedicated watch-debug background asset"
    assert LEVEL_ONE_WATCH_BASE.exists(), "Level 1 should have a route-free background base asset"
    old = Image.open(LEVEL_ONE_OLD).convert("RGB")
    watch = Image.open(LEVEL_ONE_WATCH_BASE).convert("RGB")
    assert watch.size == (1280, 720)

    screen_rect = (950, 20, 1256, 708)
    assert _mean_abs_channel_delta(old, watch, screen_rect) >= 5.0, (
        "Level 1 watch-debug background should visibly replace the old right-side screen treatment"
    )


def test_level1_generated_map_and_hud_background_layers_stay_separate():
    assert LEVEL_ONE_MAP_LAYER.exists(), "Level 1 should have a separated left map background layer"
    assert LEVEL_ONE_HUD_LAYER.exists(), "Level 1 should have a separated right HUD background layer"
    base = Image.open(LEVEL_ONE_WATCH_BASE).convert("RGBA")
    map_layer = Image.open(LEVEL_ONE_MAP_LAYER).convert("RGBA")
    hud_layer = Image.open(LEVEL_ONE_HUD_LAYER).convert("RGBA")
    assert map_layer.size == base.size == hud_layer.size == (1280, 720)

    split_x = 960
    assert _opaque_ratio(map_layer, (split_x, 0, base.width, base.height)) == 0.0, (
        "Left map background layer should not include the right smartwatch HUD region"
    )
    assert _opaque_ratio(hud_layer, (0, 0, split_x, base.height)) == 0.0, (
        "Right HUD background layer should not include the left gameplay board region"
    )

    recombined = Image.alpha_composite(map_layer, hud_layer)
    full_delta = _mean_abs_channel_delta(base, recombined, (0, 0, base.width, base.height))
    map_delta = _mean_abs_channel_delta(base, recombined, (0, 0, split_x, base.height))
    hud_delta = _mean_abs_channel_delta(base, recombined, (split_x, 0, base.width, base.height))
    assert 20.0 <= map_delta <= 70.0, (
        "Separated Level 1 map layer should be a newly generated hardware map, "
        f"but map mean channel delta is {map_delta:.3f}"
    )
    assert hud_delta <= 0.01, (
        "Right HUD layer should remain visually identical while the map layer is simplified, "
        f"but HUD mean channel delta is {hud_delta:.3f}"
    )
    assert full_delta <= 45.0, (
        "Separated Level 1 layers should still preserve the overall watch-board visual family, "
        f"but full mean channel delta is {full_delta:.3f}"
    )


def test_level1_hud_layer_is_clean_runtime_backdrop_without_mock_content():
    base = Image.open(LEVEL_ONE_WATCH_BASE).convert("RGB")
    hud_layer = Image.open(LEVEL_ONE_HUD_LAYER).convert("RGBA")

    assert _opaque_ratio(hud_layer, (0, 0, 960, 720)) == 0.0, (
        "Right HUD layer should stay transparent over the left map area"
    )
    assert hud_layer.getchannel("A").getbbox() == (960, 0, 1280, 720), (
        "Right HUD layer should only cover the right smartwatch screen area"
    )

    top_frame_rect = (1085, 20, 1255, 44)
    top_frame_white_ratio = _ratio_matching(
        base,
        top_frame_rect,
        lambda px: px[0] > 220 and px[1] > 220 and px[2] > 220,
    )
    assert top_frame_white_ratio <= 0.01, (
        "Right HUD top frame should remain consistently black without a large white reflection, "
        f"but bright white ratio is {top_frame_white_ratio:.3f}"
    )

    header_rect = (1018, 96, 1224, 154)
    header_dark_ratio = _ratio_matching(base, header_rect, lambda px: sum(px) < 180)
    assert header_dark_ratio <= 0.005, (
        "Right HUD background should be a clean runtime backdrop without baked fake header text, "
        f"but dark text-like pixel ratio is {header_dark_ratio:.3f}"
    )

    content_rect = (1000, 72, 1240, 620)
    old_mock_cyan_ratio = _ratio_matching(
        base,
        content_rect,
        lambda px: px[2] > 120 and px[1] > 120 and px[0] < 80,
    )
    old_mock_dark_ratio = _ratio_matching(base, content_rect, lambda px: sum(px) < 180)
    assert old_mock_cyan_ratio <= 0.005, (
        "Right HUD background should not contain the old dark mock-HUD cyan graph/details, "
        f"but saturated cyan ratio is {old_mock_cyan_ratio:.3f}"
    )
    assert old_mock_dark_ratio <= 0.02, (
        "Right HUD screen should not be a baked dark diagnostic mockup behind runtime UI, "
        f"but dark content ratio is {old_mock_dark_ratio:.3f}"
    )


def test_level1_generated_map_layer_keeps_route_and_tower_safe_zones_clear():
    base = Image.open(LEVEL_ONE_WATCH_BASE).convert("RGBA")
    map_layer = Image.open(LEVEL_ONE_MAP_LAYER).convert("RGBA")
    hardware_rects = [
        (88, 468, 610, 620),
        (610, 54, 855, 366),
        (650, 408, 842, 590),
    ]

    safety_mask = _level_one_safety_mask()
    assert _masked_dark_ratio(map_layer, safety_mask) <= 0.035, (
        "Level 1 generated map should keep dark components out of tower and route safety zones"
    )
    assert _masked_edge_mean(map_layer, safety_mask) <= 18.0, (
        "Level 1 selected stylized 2D map should keep tower and route safety zones visually calm"
    )

    base_hardware_edges = _combined_edge_mean(base, hardware_rects)
    map_hardware_edges = _combined_edge_mean(map_layer, hardware_rects)
    assert map_hardware_edges >= base_hardware_edges * 0.55, (
        "Level 1 map layer should keep recognizable real hardware modules after border cleanup, "
        f"but core hardware edge density is {map_hardware_edges:.2f} vs base {base_hardware_edges:.2f}"
    )


def test_level1_generated_map_layer_keeps_edge_components_sparse():
    map_layer = Image.open(LEVEL_ONE_MAP_LAYER).convert("RGBA")
    edge_component_rects = [
        (28, 88, 90, 255),
        (28, 400, 92, 610),
        (70, 28, 330, 92),
        (410, 28, 590, 92),
        (700, 28, 860, 102),
        (120, 610, 360, 700),
        (620, 610, 860, 700),
        (835, 115, 930, 315),
        (835, 430, 930, 620),
    ]

    edge_component_density = _combined_edge_mean(map_layer, edge_component_rects)
    assert edge_component_density <= 42.0, (
        "Level 1 generated map should keep peripheral hardware components sparse, "
        f"but edge component density is {edge_component_density:.2f}"
    )


def test_level1_background_has_no_central_concept_ui_overlay():
    watch = Image.open(LEVEL_ONE_WATCH_BASE).convert("RGB")
    central_list_rect = (410, 235, 720, 500)

    white_panel_ratio = _ratio_matching(
        watch,
        central_list_rect,
        lambda px: px[0] > 225 and px[1] > 225 and px[2] > 225 and max(px) - min(px) < 20,
    )
    assert white_panel_ratio <= 0.80, (
        "Level 1 background should not include the concept mockup's central white card, "
        f"but central white-panel ratio is {white_panel_ratio:.3f}"
    )

    gray_ui_bar_ratio = _ratio_matching(
        watch,
        central_list_rect,
        lambda px: abs(px[0] - px[1]) <= 8 and abs(px[1] - px[2]) <= 8 and 100 <= px[0] <= 190,
    )
    assert gray_ui_bar_ratio <= 0.080, (
        "Level 1 background should not include the concept mockup's dense gray list bars, "
        f"but gray UI bar ratio is {gray_ui_bar_ratio:.3f}"
    )


def test_level1_background_base_has_no_baked_cyan_route():
    watch = Image.open(LEVEL_ONE_WATCH_BASE).convert("RGB")
    board_rect = (70, 170, 850, 470)
    cyan_route_ratio = _ratio_matching(watch, board_rect, _is_route_glow)
    assert cyan_route_ratio <= 0.004, (
        "Level 1 route-free background base should not bake in the cyan route, "
        f"but route-like pixel ratio is {cyan_route_ratio:.3f}"
    )


def test_level2_and_3_generated_map_layers_stay_separate_from_hud():
    for path in (CALIBRATED, LEVEL_THREE):
        assert path.exists(), f"{path.name} should exist"
        image = Image.open(path).convert("RGBA")
        assert image.size == (1280, 720)
        assert _opaque_ratio(image, (960, 0, 1280, 720)) == 0.0, (
            f"{path.name} should leave the right smartwatch HUD region transparent"
        )
        assert _opaque_ratio(image, (0, 0, 960, 720)) >= 0.98, (
            f"{path.name} should fully cover the left gameplay hardware board"
        )


def test_level2_and_3_map_layers_keep_route_and_tower_safe_zones_clear():
    for image_path, route, slots in [
        (CALIBRATED, LEVEL_TWO_PATH, LEVEL_TWO_TOWER_SLOTS),
        (LEVEL_THREE, LEVEL_THREE_PATH, LEVEL_THREE_TOWER_SLOTS),
    ]:
        image = Image.open(image_path).convert("RGBA")
        safety_mask = _safety_mask(route, slots)
        assert _masked_dark_ratio(image, safety_mask) <= 0.035, (
            f"{image_path.name} should keep dark hardware components out of tower and route safety zones"
        )
        assert _masked_edge_mean(image, safety_mask) <= 18.0, (
            f"{image_path.name} should keep tower and route safety zones visually calm"
        )


def test_level2_and_3_tower_bases_match_level_one_light_ring_style():
    level_one = Image.open(LEVEL_ONE_WATCH).convert("RGB")
    level_one_dark_ratio = _dark_outer_ring_ratio(level_one, LEVEL_ONE_TOWER_SLOTS)
    for image_path, slots in [(CALIBRATED, LEVEL_TWO_TOWER_SLOTS), (LEVEL_THREE, LEVEL_THREE_TOWER_SLOTS)]:
        image = Image.open(image_path).convert("RGB")
        dark_ratio = _dark_outer_ring_ratio(image, slots)
        assert dark_ratio <= level_one_dark_ratio + 0.07, (
            f"{image_path.name} tower bases should use the same light ring style as level 1, "
            f"but dark ring ratio is {dark_ratio:.3f} vs level 1 {level_one_dark_ratio:.3f}"
        )


def test_level3_background_inherits_level_one_two_visual_system():
    level_two = Image.open(CALIBRATED).convert("RGB")
    level_three = Image.open(LEVEL_THREE).convert("RGB")

    board_rect = (24, 92, 924, 672)
    reference_edge_mean = _edge_mean(level_two, board_rect)
    level_three_edge_mean = _edge_mean(level_three, board_rect)
    assert level_three_edge_mean >= reference_edge_mean * 0.80, (
        "Level 3 should stay in the same detailed watch hardware visual system as level 2, "
        f"but board edge density is {level_three_edge_mean:.2f} vs reference {reference_edge_mean:.2f}"
    )

    reference_luma = _mean_luma(level_two, board_rect)
    level_three_luma = _mean_luma(level_three, board_rect)
    assert abs(level_three_luma - reference_luma) <= 16.0, (
        "Level 3 should keep the same bright hardware-map luma family as level 2, "
        f"but board luma is {level_three_luma:.2f} vs reference {reference_luma:.2f}"
    )

    reference_dark_ratio = _dark_outer_ring_ratio(level_two, LEVEL_TWO_TOWER_SLOTS)
    level_three_dark_ratio = _dark_outer_ring_ratio(level_three, LEVEL_THREE_TOWER_SLOTS)
    assert level_three_dark_ratio <= reference_dark_ratio + 0.07, (
        "Level 3 tower bases should use the same light ring style as level 1, "
        f"but dark ring ratio is {level_three_dark_ratio:.3f} vs level 1 {reference_dark_ratio:.3f}"
    )


def test_level2_and_3_match_level_one_board_material_family():
    level_one = Image.open(LEVEL_ONE_MAP_LAYER).convert("RGB")
    board_rect = (24, 92, 924, 672)
    reference_luma = _mean_luma(level_one, board_rect)
    reference_edge_mean = _edge_mean(level_one, board_rect)

    for image_path in (CALIBRATED, LEVEL_THREE):
        image = Image.open(image_path).convert("RGB")
        image_luma = _mean_luma(image, board_rect)
        image_edge_mean = _edge_mean(image, board_rect)

        assert abs(image_luma - reference_luma) <= 22.0, (
            f"{image_path.name} should use the same bright silver board material as level 1, "
            f"but board luma is {image_luma:.2f} vs level 1 {reference_luma:.2f}"
        )
        assert reference_edge_mean * 0.62 <= image_edge_mean <= reference_edge_mean * 1.30, (
            f"{image_path.name} should keep level 1's crisp but restrained hardware detail density, "
            f"but board edge density is {image_edge_mean:.2f} vs level 1 {reference_edge_mean:.2f}"
        )


def test_level3_bottom_left_module_has_no_overlapping_dark_chip():
    level_three = Image.open(LEVEL_THREE).convert("RGB")
    module_clear_rect = (200, 600, 300, 644)
    dark_component_ratio = _ratio_matching(
        level_three,
        module_clear_rect,
        lambda px: sum(px) < 330,
    )
    assert dark_component_ratio == 0.0, (
        "Level 3 lower-left light information module should not be overlapped by the dark chip component, "
        f"but dark component ratio is {dark_component_ratio:.3f}"
    )
