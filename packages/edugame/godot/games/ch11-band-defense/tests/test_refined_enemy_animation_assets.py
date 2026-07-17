import importlib.util
from pathlib import Path

from PIL import Image


GAME_ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = GAME_ROOT / "assets" / "staged-production" / "refined-graybox"
SCRIPT_PATH = GAME_ROOT / "scripts" / "refine_enemy_animation_assets.py"

spec = importlib.util.spec_from_file_location("refine_enemy_animation_assets", SCRIPT_PATH)
assert spec is not None
refined = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(refined)


def test_refined_enemy_animation_sheets_are_generated() -> None:
    for enemy_type in refined.ENEMY_TYPES:
        path = ASSET_DIR / f"enemy_anim_{enemy_type}_refined_graybox.png"
        assert path.exists(), f"{path.name} should exist"
        with Image.open(path) as image:
            assert image.size == (1024, 768), f"{path.name} should remain a 4x3 sheet of 256px frames"


def test_refined_enemy_animation_sheets_change_graybox_source() -> None:
    for enemy_type in refined.ENEMY_TYPES:
        assert refined.sheet_changed(enemy_type), f"{enemy_type} should be visually refined from the graybox source"
