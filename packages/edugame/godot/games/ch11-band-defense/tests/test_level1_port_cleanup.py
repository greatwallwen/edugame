from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LEVEL_ONE_MAP = (
    PROJECT_ROOT
    / "assets"
    / "backgrounds"
    / "band-defense-map-level1-watch-debug-map-layer.png"
)

FLAT_CONNECTOR_EXTENSIONS = {
    "left": (69, 326, 89, 374),
    "right": (866, 326, 881, 374),
}


def _dark_ratio(image, box):
    pixels = list(image.crop(box).convert("RGB").getdata())
    return sum(max(pixel) < 105 for pixel in pixels) / len(pixels)


def test_level1_background_removes_flat_auxiliary_port_extensions():
    image = Image.open(LEVEL_ONE_MAP)
    for side, box in FLAT_CONNECTOR_EXTENSIONS.items():
        ratio = _dark_ratio(image, box)
        assert ratio <= 0.35, (
            f"level 1 {side} flat connector extension should be removed, "
            f"but dark coverage is {ratio:.3f}"
        )
