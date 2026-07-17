import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "install_generated_level_backgrounds.py"


def _load_installer():
    spec = importlib.util.spec_from_file_location("background_installer", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_normalize_source_detects_divider_and_clears_hud_region() -> None:
    installer = _load_installer()
    source = Image.new("RGB", (1672, 941), (224, 226, 224))
    draw = ImageDraw.Draw(source)
    draw.rectangle((1248, 0, 1253, 940), fill=(240, 50, 78))
    draw.rectangle((1254, 0, 1671, 940), fill=(22, 24, 30))

    normalized = installer.normalize_source(source)

    assert normalized.mode == "RGBA"
    assert normalized.size == (1280, 720)
    assert normalized.getpixel((400, 360))[3] == 255
    assert normalized.getpixel((1100, 360))[3] == 0


def test_stamp_tower_pads_places_template_at_exact_runtime_centers() -> None:
    installer = _load_installer()
    map_layer = Image.new("RGBA", (1280, 720), (220, 222, 220, 255))
    stamp = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(stamp)
    draw.ellipse((8, 8, 88, 88), outline=(60, 62, 60, 255), width=4)

    installer.stamp_tower_pads(map_layer, stamp, [(214, 207), (550, 405)])

    assert map_layer.getpixel((214, 167))[:3] == (60, 62, 60)
    assert map_layer.getpixel((550, 365))[:3] == (60, 62, 60)
    assert map_layer.getpixel((300, 300))[:3] == (220, 222, 220)


def test_level_one_pad_stamp_keeps_center_transparent_to_avoid_texture_halos() -> None:
    installer = _load_installer()
    stamp = installer.extract_level_one_pad_stamp()

    assert stamp.getpixel((48, 48))[3] <= 16
    assert stamp.getpixel((48, 9))[3] >= 180
    assert stamp.getpixel((48, 22))[3] >= 180
    assert stamp.getpixel((48, 55))[3] >= 180


def test_restore_slot_surfaces_removes_circular_ghost_before_pad_stamp() -> None:
    installer = _load_installer()
    map_layer = Image.new("RGBA", (1280, 720), (220, 222, 220, 255))
    draw = ImageDraw.Draw(map_layer)
    draw.ellipse((154, 147, 274, 267), fill=(248, 248, 244, 255))

    installer.restore_slot_surfaces(map_layer, [(214, 207)], source_box=(400, 500, 528, 628))

    red, green, blue, alpha = map_layer.getpixel((214, 207))
    assert abs(red - 220) <= 2
    assert abs(green - 222) <= 2
    assert abs(blue - 220) <= 2
    assert alpha == 255
    assert map_layer.getpixel((140, 207)) == (220, 222, 220, 255)


def test_stamp_tower_pads_adapts_level_one_highlight_to_local_board_luma() -> None:
    installer = _load_installer()
    map_layer = Image.new("RGBA", (1280, 720), (180, 180, 180, 255))
    stamp = Image.new("RGBA", (96, 96), (210, 210, 210, 0))
    draw = ImageDraw.Draw(stamp)
    draw.ellipse((8, 8, 88, 88), outline=(240, 240, 240, 255), width=4)

    installer.stamp_tower_pads(map_layer, stamp, [(214, 207)])

    red, green, blue, _ = map_layer.getpixel((214, 167))
    assert 205 <= red <= 215
    assert 205 <= green <= 215
    assert 205 <= blue <= 215
