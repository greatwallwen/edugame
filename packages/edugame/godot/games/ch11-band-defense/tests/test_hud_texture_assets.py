import importlib.util
import json
from pathlib import Path

from PIL import Image


GAME_ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = GAME_ROOT / "assets" / "staged-production" / "hud"
LIVE_ASSET_DIR = GAME_ROOT / "assets" / "generated"
SCRIPT_PATH = GAME_ROOT / "scripts" / "generate_hud_textures.py"
GAME_SCRIPT_PATH = GAME_ROOT / "scripts" / "band_defense_root.gd"


def test_hud_texture_generator_exists() -> None:
    assert SCRIPT_PATH.exists(), "HUD texture generator should exist"


def test_hud_texture_assets_are_generated() -> None:
    expected_assets = {
        "hud_panel_frame.png": (384, 384),
        "hud_button_plate.png": (320, 96),
        "hud_button_plate_primary.png": (320, 96),
        "hud_status_tray.png": (320, 96),
        "hud_dialog_frame.png": (512, 320),
        "hud_text_plate.png": (320, 160),
        "hud_text_chip.png": (192, 72),
        "hud_section_card.png": (320, 240),
    }
    for filename, expected_size in expected_assets.items():
        path = ASSET_DIR / filename
        assert path.exists(), f"{filename} should be generated"
        with Image.open(path) as image:
            assert image.size == expected_size, f"{filename} should use the expected texture dimensions"
            assert image.mode == "RGBA", f"{filename} should keep alpha for Godot texture styles"
            alpha = image.getchannel("A")
            assert alpha.getextrema()[0] < 255, f"{filename} should include transparent glass edges"
            assert len({value for value in alpha.getdata() if 0 < value < 255}) > 24, (
                f"{filename} should use soft transparency rather than flat fills"
            )


def test_hud_texture_manifest_records_hidden_debug_watch_direction() -> None:
	manifest_path = ASSET_DIR / "hud-texture-manifest.json"
	assert manifest_path.exists(), "HUD texture manifest should exist"
	manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
	cues = " ".join(manifest["visual_cues"])
	for keyword in (
		"light smartwatch hidden debug mode",
		"real smartwatch glass system UI",
		"capsule controls",
		"ring progress and compact telemetry",
		"soft iOS card depth",
		"cyan green status with amber warnings",
	):
		assert keyword in cues, f"HUD manifest should document visual cue: {keyword}"


def test_hud_textures_use_light_glass_watch_surfaces() -> None:
	light_regions = {
		"hud_panel_frame.png": (34, 36, 350, 350),
		"hud_dialog_frame.png": (38, 42, 474, 278),
        "hud_status_tray.png": (24, 24, 296, 72),
        "hud_text_plate.png": (24, 24, 296, 136),
        "hud_text_chip.png": (18, 20, 174, 52),
        "hud_section_card.png": (22, 22, 298, 218),
	}
	for filename, region in light_regions.items():
		path = ASSET_DIR / filename
		with Image.open(path) as image:
			rgba = image.convert("RGBA")
			x0, y0, x1, y1 = region
			samples = []
			for y in range(y0, y1, 4):
				for x in range(x0, x1, 4):
					r, g, b, alpha = rgba.getpixel((x, y))
					if alpha > 80:
						samples.append((r + g + b) / 3)
			assert samples, f"{filename} should include visible glass panel pixels"
			assert sum(samples) / len(samples) >= 145, f"{filename} should use a light hidden-debug watch surface"


def test_hud_panel_textures_do_not_use_long_pale_scanlines() -> None:
    striped_regions = {
        "hud_panel_frame.png": (30, 32, 354, 352),
        "hud_dialog_frame.png": (34, 38, 478, 282),
    }
    for filename, region in striped_regions.items():
        path = ASSET_DIR / filename
        with Image.open(path) as image:
            rgba = image.convert("RGBA")
            x0, y0, x1, y1 = region
            for y in range(y0, y1):
                pale_pixels = 0
                for x in range(x0, x1):
                    r, g, b, alpha = rgba.getpixel((x, y))
                    if 8 <= alpha <= 18 and r >= 100 and g >= 220 and b >= 200:
                        pale_pixels += 1
                assert pale_pixels < 40, f"{filename} should not contain long pale horizontal scanlines"


def test_hud_texture_assets_are_installed_for_game_runtime() -> None:
    script_text = GAME_SCRIPT_PATH.read_text(encoding="utf-8")
    assert "StyleBoxTexture" in script_text, "game HUD should use texture-backed style boxes"
    assert "_make_hud_texture_style" in script_text, "game HUD should expose texture style helper"
    for filename in (
        "hud_panel_frame.png",
        "hud_button_plate.png",
        "hud_button_plate_primary.png",
        "hud_status_tray.png",
        "hud_dialog_frame.png",
        "hud_text_plate.png",
        "hud_text_chip.png",
        "hud_section_card.png",
    ):
        staged_path = ASSET_DIR / filename
        live_path = LIVE_ASSET_DIR / filename
        assert live_path.exists(), f"{filename} should be installed in runtime assets"
        assert live_path.read_bytes() == staged_path.read_bytes(), f"{filename} should match the staged HUD texture"
        assert f"res://assets/generated/{filename}" in script_text, f"{filename} should be loaded by the game"


def test_text_ui_surfaces_preserve_texture_assets_for_rollback() -> None:
    script_text = GAME_SCRIPT_PATH.read_text(encoding="utf-8")
    assert '"text_plate": "res://assets/generated/hud_text_plate.png"' in script_text
    assert '"text_chip": "res://assets/generated/hud_text_chip.png"' in script_text
    assert '"section_card": "res://assets/generated/hud_section_card.png"' in script_text
    assert "_make_text_plate_style" in script_text
    assert "_make_text_chip_style" in script_text
    assert "hud_status_text_plate.add_theme_stylebox_override(\"panel\", status_text_style)" in script_text
    assert "diagnostic_hud_overlay.add_theme_stylebox_override(\"panel\", _make_text_plate_style" in script_text
    assert "card.add_theme_stylebox_override(\"panel\", _make_text_plate_style" in script_text
    assert "title_style := StyleBoxEmpty.new()" in script_text
    assert "func _make_ps_surface_style" in script_text
    assert "if _uses_ps_light_ui():\n\t\treturn null" in script_text
    assert 'const UI_STYLE_WATCH_DEBUG: String = "watch_debug"' in script_text
    assert '"costPlate": cost_plate' not in script_text


def test_dialog_texture_has_one_clean_surface_without_nested_frame_chrome() -> None:
    path = ASSET_DIR / "hud_dialog_frame.png"
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        dark_chrome = [
            pixel
            for pixel in rgba.getdata()
            if pixel[3] > 80 and sum(pixel[:3]) / 3 < 180
        ]
        assert len(dark_chrome) <= 16, "dialog should not contain nested frames, status dots, or decorative rails"


def test_section_card_has_soft_ios_depth_without_grid_noise() -> None:
    path = ASSET_DIR / "hud_section_card.png"
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        inner = rgba.crop((24, 24, 296, 216))
        visible = [pixel for pixel in inner.getdata() if pixel[3] > 100]
        assert visible, "section card should have a visible light body"
        lumas = [(r + g + b) / 3 for r, g, b, _ in visible]
        assert sum(lumas) / len(lumas) >= 205, "section card should stay bright like a light iOS surface"
        depth_range = max(lumas) - min(lumas)
        assert depth_range >= 8, "section card should retain a soft highlight instead of becoming flat"
        assert depth_range <= 18, "section card depth should stay restrained and uncluttered"

        top = rgba.crop((28, 24, 292, 72))
        bottom = rgba.crop((28, 168, 292, 216))
        top_luma = sum((r + g + b) / 3 for r, g, b, a in top.getdata() if a > 100)
        bottom_luma = sum((r + g + b) / 3 for r, g, b, a in bottom.getdata() if a > 100)
        top_count = sum(1 for *_, a in top.getdata() if a > 100)
        bottom_count = sum(1 for *_, a in bottom.getdata() if a > 100)
        assert top_count and bottom_count
        assert top_luma / top_count > bottom_luma / bottom_count, "section card should carry a soft top highlight"


def test_neutral_hud_chrome_avoids_decorative_accent_clutter() -> None:
    neutral_assets = (
        "hud_panel_frame.png",
        "hud_section_card.png",
        "hud_button_plate.png",
        "hud_status_tray.png",
        "hud_text_plate.png",
        "hud_text_chip.png",
    )
    for filename in neutral_assets:
        with Image.open(ASSET_DIR / filename) as image:
            saturated = [
                (r, g, b, a)
                for r, g, b, a in image.convert("RGBA").getdata()
                if a > 80 and max(r, g, b) - min(r, g, b) >= 70
            ]
        assert len(saturated) <= 12, f"{filename} should not carry decorative rails or status dots: {len(saturated)} pixels"


def test_text_plate_has_inner_depth_and_subtle_detail() -> None:
    path = ASSET_DIR / "hud_text_plate.png"
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        inner = rgba.crop((24, 26, 296, 134))
        visible = [pixel for pixel in inner.getdata() if pixel[3] > 80]
        assert visible, "text plate should have a visible inner glass body"
        lumas = [(r + g + b) / 3 for r, g, b, _ in visible]
        assert sum(lumas) / len(lumas) >= 170, "text plate should stay light enough for dark text"
        depth_range = max(lumas) - min(lumas)
        assert depth_range >= 6, "text plate should retain subtle surface depth"
        assert depth_range <= 16, "text plate should avoid a strong nested bevel"

        lower_accent = rgba.crop((28, 130, 108, 138))
        accent_pixels = [
            (r, g, b, a)
            for r, g, b, a in lower_accent.getdata()
            if a > 70 and g >= 140 and b >= 145 and r <= 120
        ]
        assert len(accent_pixels) <= 4, "text plate should avoid a decorative cyan status rail"


def test_text_chip_has_compact_glass_depth_for_small_labels() -> None:
    path = ASSET_DIR / "hud_text_chip.png"
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        inner = rgba.crop((18, 20, 174, 52))
        visible = [pixel for pixel in inner.getdata() if pixel[3] > 80]
        assert visible, "text chip should have a visible compact body"
        lumas = [(r + g + b) / 3 for r, g, b, _ in visible]
        assert sum(lumas) / len(lumas) >= 170, "text chip should stay light enough for small dark labels"
        depth_range = max(lumas) - min(lumas)
        assert depth_range >= 5, "text chip should retain subtle surface depth"
        assert depth_range <= 12, "text chip should avoid a strong nested bevel"

        accent = rgba.crop((28, 50, 68, 56))
        accent_pixels = [
            (r, g, b, a)
            for r, g, b, a in accent.getdata()
            if a > 35 and g >= 135 and b >= 140 and r <= 130
        ]
        assert len(accent_pixels) <= 4, "text chip should stay neutral without decorative engineering accents"
