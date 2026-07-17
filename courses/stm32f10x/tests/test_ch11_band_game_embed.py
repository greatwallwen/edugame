import hashlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PUBLIC_DIR = ROOT / "apps" / "player" / "public"
if str(PUBLIC_DIR) not in sys.path:
    sys.path.insert(0, str(PUBLIC_DIR))

from manifest.chapters.ch10_ch12 import build_p11_pages  # noqa: E402


def test_ch11_page_embeds_band_defense_alpha_game():
    pages = build_p11_pages()
    page = next(item for item in pages if item["id"] == "p11-band")
    game = page.get("game")

    assert game is not None
    assert game["modeId"] == "godot-game"
    assert game["levelId"] == "ch11-band-defense-alpha"
    assert "Alpha" in game["title"]
    assert "互动练习" in game["objective"]
    assert game["data"]["gameId"] == "ch11-band-defense"
    export_dir = ROOT / "apps" / "player" / "public" / "assets" / "godot" / "ch11-band-defense"
    entry_prefix = "/assets/godot/ch11-band-defense/index.html?v="
    assert game["data"]["entryUrl"].startswith(entry_prefix)
    release_hash = game["data"]["entryUrl"].removeprefix(entry_prefix)
    assert len(release_hash) == 12

    release_assets = list(export_dir.glob(f"index.{release_hash}.*"))
    assert release_assets
    digest = hashlib.sha256()
    for path in sorted(release_assets, key=lambda item: item.name.replace(f"index.{release_hash}", "index", 1)):
        original_name = path.name.replace(f"index.{release_hash}", "index", 1)
        digest.update(original_name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\n")
    assert digest.hexdigest()[:12] == release_hash

    html = (export_dir / "index.html").read_text(encoding="utf-8")
    assert f'"executable":"index.{release_hash}"' in html
    assert f"index.{release_hash}.pck" in html
    assert f"index.{release_hash}.wasm" in html

    questions_path = ROOT / "courses" / "stm32f10x" / "knowledge" / "ch11-band-defense.questions.json"
    questions_hash = hashlib.sha256(questions_path.read_bytes()).hexdigest()[:12]
    assert game["data"]["questionsUrl"] == (
        f"/assets/courses/stm32-course/knowledge/ch11-band-defense.questions.json?v={questions_hash}"
    )
    assert game["data"]["aspectRatio"] == "16 / 9"
    assert game["data"]["deliveryStage"] == "alpha"
