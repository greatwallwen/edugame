import importlib.util
import shutil
import subprocess
from pathlib import Path


GAME_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = GAME_ROOT.parents[4]
AUDIT_SCRIPT = GAME_ROOT / "scripts" / "audit_level1_visual_quality.py"


def _load_audit_module():
    spec = importlib.util.spec_from_file_location("level1_visual_audit", AUDIT_SCRIPT)
    assert spec is not None and spec.loader is not None, "visual audit script should be importable"
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _godot_command() -> list[str]:
    godot = shutil.which("godot") or shutil.which("godot.cmd")
    if godot is None:
        user_cmd = Path.home() / "bin" / "godot.cmd"
        if user_cmd.exists():
            godot = str(user_cmd)
    assert godot is not None, "Godot executable should be available for visual capture"
    if godot.lower().endswith(".cmd"):
        return ["cmd", "/c", godot]
    return [godot]


def test_level1_runtime_visual_quality_audit_passes() -> None:
    capture = subprocess.run(
        _godot_command()
        + [
            "--path",
            str(GAME_ROOT),
            "--script",
            "res://tests/capture_hud_visuals.gd",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=120,
        check=False,
    )
    assert capture.returncode == 0, (
        "HUD visual capture should complete before the pixel audit\n"
        f"stdout:\n{capture.stdout}\n"
        f"stderr:\n{capture.stderr}"
    )

    audit = _load_audit_module()
    report = audit.build_report()
    audit.REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    audit.REPORT_PATH.write_text(
        audit.json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    assert report["layout"]["slot_route_min_distance"] >= 50.0
    assert report["right_watch"]["outer_edge_bright_ratio"] == 0.0
    assert 1119.0 <= report["right_watch"]["white_panel_bounds"]["center_x"] <= 1122.0
