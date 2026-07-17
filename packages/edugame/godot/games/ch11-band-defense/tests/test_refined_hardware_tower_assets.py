import importlib.util
import json
from pathlib import Path

from PIL import Image


GAME_ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = GAME_ROOT / "assets" / "staged-production" / "refined-hardware"
LIVE_ASSET_DIR = GAME_ROOT / "assets" / "generated"
GAME_SCRIPT_PATH = GAME_ROOT / "scripts" / "band_defense_root.gd"
SCRIPT_PATH = GAME_ROOT / "scripts" / "generate_refined_hardware_towers.py"

spec = importlib.util.spec_from_file_location("generate_refined_hardware_towers", SCRIPT_PATH)
assert spec is not None
towers = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(towers)


def test_refined_hardware_tower_assets_are_generated() -> None:
    for tower_id in towers.TOWER_IDS:
        path = ASSET_DIR / f"tower_{tower_id}_hardware.png"
        assert path.exists(), f"{path.name} should exist"
        with Image.open(path) as image:
            assert image.size == (256, 256), f"{path.name} should be a 256px transparent tower sprite"
            assert image.mode == "RGBA", f"{path.name} should keep alpha for Godot composition"


def test_refined_hardware_tower_animation_sheets_are_generated() -> None:
    frame_size = 256
    columns = 8
    rows = 2
    for tower_id in towers.TOWER_IDS:
        path = ASSET_DIR / f"tower_{tower_id}_hardware_anim.png"
        assert path.exists(), f"{path.name} should exist"
        with Image.open(path) as image:
            assert image.size == (frame_size * columns, frame_size * rows), (
                f"{path.name} should be an {columns}x{rows} tower animation sheet"
            )
            assert image.mode == "RGBA", f"{path.name} should keep alpha for Godot animation"

            idle_frames = [
                image.crop((index * frame_size, 0, (index + 1) * frame_size, frame_size)).tobytes()
                for index in range(columns)
            ]
            attack_frames = [
                image.crop((index * frame_size, frame_size, (index + 1) * frame_size, frame_size * rows)).tobytes()
                for index in range(columns)
            ]
            assert len(set(idle_frames)) > 3, f"{tower_id} idle animation should contain real frame changes"
            assert len(set(attack_frames)) > 5, f"{tower_id} attack animation should contain real frame changes"
            assert idle_frames[0] != attack_frames[0], f"{tower_id} attack row should differ from idle row"


def test_refined_hardware_attack_effect_sheets_are_generated() -> None:
    effect_specs = {
        "beam": (192, 64, 8, 1),
        "range": (256, 256, 8, 1),
    }
    for tower_id in towers.TOWER_IDS:
        for effect_name, (frame_width, frame_height, columns, rows) in effect_specs.items():
            path = ASSET_DIR / f"tower_{tower_id}_attack_{effect_name}.png"
            assert path.exists(), f"{path.name} should exist"
            with Image.open(path) as image:
                assert image.size == (frame_width * columns, frame_height * rows), (
                    f"{path.name} should be a {columns}-frame {effect_name} attack effect sheet"
                )
                assert image.mode == "RGBA", f"{path.name} should keep alpha for Godot composition"
                frames = [
                    image.crop((index * frame_width, 0, (index + 1) * frame_width, frame_height)).tobytes()
                    for index in range(columns)
                ]
                assert len(set(frames)) > 5, f"{tower_id} {effect_name} effect should contain real frame changes"
                assert any(image.getchannel("A").getextrema()[1] > 0 for image in [
                    image.crop((index * frame_width, 0, (index + 1) * frame_width, frame_height))
                    for index in range(columns)
                ]), f"{tower_id} {effect_name} effect should be visible"


def test_refined_hardware_attack_effects_use_volumetric_light_treatment() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_keywords = (
        "volumetric glow",
        "soft scatter halo",
        "depth-layered particles",
        "perspective falloff",
    )
    for tower_id in towers.TOWER_IDS:
        effect_notes = " ".join(manifest[tower_id]["attack_effect_cues"])
        for keyword in expected_keywords:
            assert keyword in effect_notes, f"{tower_id} attack effect should cite realistic light cue: {keyword}"


def test_refined_hardware_attack_effects_have_soft_alpha_gradients() -> None:
    for tower_id in towers.TOWER_IDS:
        for effect_name in ("beam", "range"):
            path = ASSET_DIR / f"tower_{tower_id}_attack_{effect_name}.png"
            with Image.open(path) as image:
                alpha_values = {alpha for alpha in image.getchannel("A").getdata() if 0 < alpha < 255}
                assert len(alpha_values) > 35, (
                    f"{tower_id} {effect_name} effect should use soft transparency gradients, "
                    f"not flat 2D line art"
                )


def test_refined_hardware_tower_assets_are_installed_for_game_runtime() -> None:
    script_text = GAME_SCRIPT_PATH.read_text(encoding="utf-8")
    for tower_id in towers.TOWER_IDS:
        staged_path = ASSET_DIR / f"tower_{tower_id}_hardware.png"
        live_path = LIVE_ASSET_DIR / f"tower_{tower_id}_hardware.png"
        assert live_path.exists(), f"{live_path.name} should be installed in the game runtime asset folder"
        assert live_path.read_bytes() == staged_path.read_bytes(), f"{live_path.name} should match the approved staged asset"
        assert f'res://assets/generated/tower_{tower_id}_hardware.png' in script_text, (
            f"{tower_id} tower should be preloaded by the Godot game"
        )


def test_refined_hardware_tower_animation_sheets_are_installed_for_game_runtime() -> None:
    script_text = GAME_SCRIPT_PATH.read_text(encoding="utf-8")
    assert "TOWER_ANIM_COLUMNS" in script_text
    assert "attackAnim" in script_text
    for tower_id in towers.TOWER_IDS:
        staged_path = ASSET_DIR / f"tower_{tower_id}_hardware_anim.png"
        live_path = LIVE_ASSET_DIR / f"tower_{tower_id}_hardware_anim.png"
        assert live_path.exists(), f"{live_path.name} should be installed in the game runtime asset folder"
        assert live_path.read_bytes() == staged_path.read_bytes(), f"{live_path.name} should match the approved staged animation"
        assert f'res://assets/generated/tower_{tower_id}_hardware_anim.png' in script_text, (
            f"{tower_id} tower animation should be loaded by the Godot game"
        )


def test_refined_hardware_attack_effect_sheets_are_installed_for_game_runtime() -> None:
    script_text = GAME_SCRIPT_PATH.read_text(encoding="utf-8")
    assert "attack_effects" in script_text
    assert "_draw_attack_effects" in script_text
    assert "_add_attack_effect" in script_text
    for tower_id in towers.TOWER_IDS:
        for effect_name in ("beam", "range"):
            staged_path = ASSET_DIR / f"tower_{tower_id}_attack_{effect_name}.png"
            live_path = LIVE_ASSET_DIR / f"tower_{tower_id}_attack_{effect_name}.png"
            assert live_path.exists(), f"{live_path.name} should be installed in the game runtime asset folder"
            assert live_path.read_bytes() == staged_path.read_bytes(), f"{live_path.name} should match the approved staged effect"
            assert f'res://assets/generated/tower_{tower_id}_attack_{effect_name}.png' in script_text, (
                f"{tower_id} {effect_name} attack effect should be loaded by the Godot game"
            )


def test_refined_hardware_towers_have_distinct_images() -> None:
    payloads = {tower_id: (ASSET_DIR / f"tower_{tower_id}_hardware.png").read_bytes() for tower_id in towers.TOWER_IDS}

    for left in towers.TOWER_IDS:
        for right in towers.TOWER_IDS:
            if left >= right:
                continue
            assert payloads[left] != payloads[right], f"{left} and {right} should not share one generic module"


def test_refined_hardware_manifest_maps_to_real_components() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_keywords = {
        "i2c": ("sensor breakout", "header pins", "pull-up resistors"),
        "filter": ("op-amp", "resistors", "capacitors"),
        "peak": ("comparator", "diode", "threshold"),
        "power": ("battery", "MOSFET", "wake interrupt"),
    }
    for tower_id, keywords in expected_keywords.items():
        entry = manifest[tower_id]
        hardware_notes = " ".join(entry["real_hardware_cues"])
        for keyword in keywords:
            assert keyword in hardware_notes, f"{tower_id} should cite real hardware cue: {keyword}"


def test_refined_hardware_manifest_keeps_tower_concept() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for tower_id in towers.TOWER_IDS:
        tower_notes = " ".join(manifest[tower_id]["tower_concept_cues"])
        for keyword in ("raised chassis", "pedestal ring", "diagnostic mast"):
            assert keyword in tower_notes, f"{tower_id} should combine hardware board with tower cue: {keyword}"


def test_refined_hardware_manifest_uses_technology_base() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for tower_id in towers.TOWER_IDS:
        tower_notes = " ".join(manifest[tower_id]["tower_concept_cues"])
        for keyword in ("layered tech pedestal", "holographic docking base", "glowing board socket"):
            assert keyword in tower_notes, f"{tower_id} should use a polished technology base: {keyword}"


def test_refined_hardware_manifest_adds_runtime_tower_details() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for tower_id in towers.TOWER_IDS:
        tower_notes = " ".join(manifest[tower_id]["tower_concept_cues"])
        for keyword in ("side guide rail", "maglev base ring", "energy port"):
            assert keyword in tower_notes, f"{tower_id} should gain sharper runtime tower detail: {keyword}"


def test_refined_hardware_manifest_adds_sci_fi_ambient_effects() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for tower_id in towers.TOWER_IDS:
        effects = " ".join(manifest[tower_id]["ambient_effect_cues"])
        for keyword in ("orbiting data motes", "scan arc", "energy spark"):
            assert keyword in effects, f"{tower_id} should add sci-fi ambient effect: {keyword}"


def test_refined_hardware_manifest_adds_advanced_sci_fi_detail_layers() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_signatures = {
        "i2c": "bus constellation links",
        "filter": "frequency comb field",
        "peak": "peak lock prism",
        "power": "wake pulse halo",
    }
    for tower_id in towers.TOWER_IDS:
        effects = " ".join(manifest[tower_id]["ambient_effect_cues"])
        for keyword in ("layered hologram rings", "data filament lattice", "micro telemetry ticks"):
            assert keyword in effects, f"{tower_id} should add advanced sci-fi detail layer: {keyword}"
        assert expected_signatures[tower_id] in effects, f"{tower_id} should have a tower-specific sci-fi signature"


def test_refined_hardware_manifest_adds_dimensional_board_treatment() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for tower_id in towers.TOWER_IDS:
        treatment = " ".join(manifest[tower_id]["board_presentation_cues"])
        for keyword in ("angled board plane", "visible board thickness", "beveled edge highlight", "contact shadow"):
            assert keyword in treatment, f"{tower_id} should have dimensional board treatment: {keyword}"


def test_refined_hardware_manifest_adds_mechanical_component_treatment() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for tower_id in towers.TOWER_IDS:
        treatment = " ".join(manifest[tower_id]["component_presentation_cues"])
        for keyword in ("raised IC packages", "metal pin shadows", "connector housings", "machined fasteners"):
            assert keyword in treatment, f"{tower_id} should make board components more mechanical: {keyword}"


def test_refined_hardware_ambient_effects_are_not_board_components() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    effect_words = ("mote", "spark", "scan arc")
    for tower_id in towers.TOWER_IDS:
        component_names = " ".join(component["name"] for component in manifest[tower_id]["component_layout"])
        for word in effect_words:
            assert word not in component_names, f"{tower_id} should keep ambient effect outside board component layout: {word}"


def test_refined_hardware_manifest_adds_tower_specific_accessories() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_accessories = {
        "i2c": ("SDA probe", "SCL probe", "bus activity light"),
        "filter": ("input terminal", "output terminal", "mini waveform window"),
        "peak": ("threshold trim knob", "diode direction label", "peak latch bar"),
        "power": ("battery contacts", "wake coil", "power gate indicator"),
    }
    for tower_id, keywords in expected_accessories.items():
        accessories = " ".join(manifest[tower_id]["hardware_accessory_cues"])
        component_names = " ".join(component["name"] for component in manifest[tower_id]["component_layout"])
        for keyword in keywords:
            assert keyword in accessories, f"{tower_id} should cite added hardware accessory: {keyword}"
            assert keyword.lower() in component_names, f"{tower_id} should reserve layout space for: {keyword}"


def test_refined_hardware_manifest_requires_clean_circuit_layout() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for tower_id in towers.TOWER_IDS:
        layout_notes = " ".join(manifest[tower_id]["circuit_layout_cues"])
        for keyword in ("non-overlapping component zones", "clear trace routing", "component clearance"):
            assert keyword in layout_notes, f"{tower_id} should keep board details rigorous: {keyword}"


def test_refined_hardware_component_boxes_do_not_overlap() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    clearance = 3
    for tower_id in towers.TOWER_IDS:
        components = manifest[tower_id]["component_layout"]
        for left_index, left in enumerate(components):
            left_box = _expand_box(left["box"], clearance)
            for right in components[left_index + 1 :]:
                right_box = _expand_box(right["box"], clearance)
                assert not _boxes_overlap(left_box, right_box), (
                    f"{tower_id} components should not overlap after clearance: "
                    f"{left['name']} {left['box']} vs {right['name']} {right['box']}"
                )


def test_refined_hardware_mechanical_details_are_registered_and_clear() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    clearance = 3
    for tower_id in towers.TOWER_IDS:
        board_bounds = manifest[tower_id]["board_bounds"]
        mechanical_details = manifest[tower_id]["mechanical_detail_layout"]
        assert mechanical_details, f"{tower_id} should register visible mechanical board details"

        board_items = manifest[tower_id]["component_layout"] + mechanical_details
        for item in board_items:
            assert _box_contains(board_bounds, item["box"]), (
                f"{tower_id} board item should stay inside board bounds: "
                f"{item['name']} {item['box']} outside {board_bounds}"
            )

        for left_index, left in enumerate(board_items):
            left_box = _expand_box(left["box"], clearance)
            for right in board_items[left_index + 1 :]:
                right_box = _expand_box(right["box"], clearance)
                assert not _boxes_overlap(left_box, right_box), (
                    f"{tower_id} board items should not overlap after clearance: "
                    f"{left['name']} {left['box']} vs {right['name']} {right['box']}"
                )


def test_refined_hardware_component_boxes_stay_inside_board_bounds() -> None:
    manifest_path = ASSET_DIR / "tower-hardware-manifest.json"
    assert manifest_path.exists(), "tower hardware manifest should exist"

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for tower_id in towers.TOWER_IDS:
        board_bounds = manifest[tower_id]["board_bounds"]
        for component in manifest[tower_id]["component_layout"]:
            assert _box_contains(board_bounds, component["box"]), (
                f"{tower_id} component should stay inside board bounds: "
                f"{component['name']} {component['box']} outside {board_bounds}"
            )


def _expand_box(box: list[int], clearance: int) -> tuple[int, int, int, int]:
    return (box[0] - clearance, box[1] - clearance, box[2] + clearance, box[3] + clearance)


def _boxes_overlap(left: tuple[int, int, int, int], right: tuple[int, int, int, int]) -> bool:
    return left[0] < right[2] and right[0] < left[2] and left[1] < right[3] and right[1] < left[3]


def _box_contains(container: list[int], child: list[int]) -> bool:
    return container[0] <= child[0] and child[2] <= container[2] and container[1] <= child[1] and child[3] <= container[3]
