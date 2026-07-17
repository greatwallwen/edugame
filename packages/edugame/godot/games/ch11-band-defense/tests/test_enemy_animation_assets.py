from pathlib import Path

from PIL import Image


GAME_ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = GAME_ROOT / "assets" / "generated"
STAGED_ENEMY_DIR = GAME_ROOT / "assets" / "staged-production" / "refined-graybox"
ENEMY_TYPES = ("config", "noise", "false_peak", "power_spike", "drift_noise", "hybrid_fault")
SHARED_ENEMY_TYPES = ("unknown_fault",)


def _asset_path(enemy_type: str) -> Path:
    return ASSET_DIR / f"enemy_anim_{enemy_type}.png"


def test_enemy_animation_sheets_have_expected_grid() -> None:
    for enemy_type in ENEMY_TYPES + SHARED_ENEMY_TYPES:
        path = _asset_path(enemy_type)
        assert path.exists(), f"{path.name} should exist"
        with Image.open(path) as image:
            assert image.size == (1024, 768), f"{path.name} should be a 4x3 sheet of 256px frames"


def test_unknown_fault_sheet_uses_transparency_for_runtime_compositing() -> None:
    path = _asset_path("unknown_fault")
    assert path.exists(), "undiagnosed enemies should have a shared unknown fault animation sheet"
    with Image.open(path) as image:
        assert image.mode == "RGBA", "unknown fault sprite sheet should include alpha"
        alpha = image.getchannel("A")
        assert alpha.getextrema()[0] == 0, "unknown fault sprite sheet should have transparent frame padding"


def test_unknown_fault_sheet_uses_accepted_display_fault_source() -> None:
    source_path = STAGED_ENEMY_DIR / "enemy_anim_unknown_fault_display_fault_source.png"
    assert source_path.exists(), "accepted display fault preview should be preserved as the staged source"


def test_unknown_fault_sheet_contains_animated_frames() -> None:
    path = _asset_path("unknown_fault")
    with Image.open(path) as image:
        frames = []
        for row in range(3):
            for col in range(4):
                frames.append(image.crop((col * 256, row * 256, (col + 1) * 256, (row + 1) * 256)).tobytes())
        assert len(set(frames)) > 6, "unknown fault sheet should contain real animation variation, not one copied frame"


def test_enemy_animation_sheets_have_distinct_visual_identities() -> None:
    payloads = {enemy_type: _asset_path(enemy_type).read_bytes() for enemy_type in ENEMY_TYPES}

    for left in ENEMY_TYPES:
        for right in ENEMY_TYPES:
            if left >= right:
                continue
            assert payloads[left] != payloads[right], f"{left} and {right} should not share the same animation sheet"
