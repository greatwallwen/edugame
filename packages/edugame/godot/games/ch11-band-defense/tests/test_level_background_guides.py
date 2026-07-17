from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
AUDIT_DIR = ROOT / "visual-audit"


def _assert_guide(path: Path, expected_slot_centers: list[tuple[int, int]]) -> None:
    assert path.exists(), f"missing structural guide: {path.name}"
    image = Image.open(path).convert("RGB")
    assert image.size == (1280, 720)

    assert image.getpixel((1100, 360)) == (22, 24, 30), "right HUD area must be marked forbidden"
    for x, y in expected_slot_centers:
        red, green, blue = image.getpixel((x, y))
        assert red >= 235 and green >= 185 and blue <= 90, f"tower slot {(x, y)} must be marked amber"


def test_level2_background_guide_marks_runtime_slot_centers_and_hud_exclusion() -> None:
    _assert_guide(
        AUDIT_DIR / "level2-background-layout-guide.png",
        [(214, 207), (476, 142), (332, 354), (550, 405), (762, 257), (806, 487)],
    )


def test_level3_background_guide_marks_runtime_slot_centers_and_hud_exclusion() -> None:
    _assert_guide(
        AUDIT_DIR / "level3-background-layout-guide.png",
        [(212, 227), (362, 398), (476, 240), (562, 432), (644, 212), (772, 288), (826, 472)],
    )
