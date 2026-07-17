# Ch12 Solar Survivor UI Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle every Ch12 Solar Survivor UI state to the approved Ch11 smartwatch engineering/debug visual language without changing gameplay or user-facing copy.

**Architecture:** Keep the implementation local to `ch12-solar-survivor`. Add a tested font/theme layer and reusable card helpers inside the existing Godot root, then rebuild the persistent HUD and apply the same role-based styling to every modal state.

**Tech Stack:** Godot 4.6, GDScript, embedded TTF fonts, headless Godot tests, Web export at 1280 x 720.

## Global Constraints

- Do not modify Ch11 files.
- Do not change Ch12 gameplay, data, bridge messages, or existing user-facing copy.
- Do not regenerate gameplay artwork.
- Use image2 only if a new raster UI decoration is actually required; prefer `StyleBoxFlat` in this pass.
- Work in the current user-approved workspace and do not commit.

---

### Task 1: Add the watch-debug theme contract

**Files:**
- Create: `packages/edugame/godot/games/ch12-solar-survivor/tests/test_watch_debug_ui.gd`
- Copy: `packages/edugame/assets/games/ch11-band-defense/fonts/{DingTalkJinBuTi.ttf,Orbitron-wght.ttf,ZCOOLQingKeHuangYou-Regular.ttf}`
- Modify: `packages/edugame/godot/games/ch12-solar-survivor/scripts/solar_survivor_root.gd:17-253`

**Interfaces:**
- Produces: `_make_watch_shell_style() -> StyleBoxFlat`, `_make_surface_card_style() -> StyleBoxFlat`, `_make_metric_tile_style() -> StyleBoxFlat`, `_apply_text_role(Control, String) -> void`, `_font_base_path(Font) -> String` in the test.

- [ ] **Step 1: Write the failing theme test**

```gdscript
extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	for method in ["_make_watch_shell_style", "_make_surface_card_style", "_make_metric_tile_style", "_apply_text_role"]:
		_assert(game.has_method(method), "missing shared UI method: %s" % method)
	for path in ["res://assets/fonts/NotoSansSC-VF.ttf", "res://assets/fonts/DingTalkJinBuTi.ttf", "res://assets/fonts/Orbitron-wght.ttf", "res://assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf"]:
		_assert(ResourceLoader.exists(path), "missing embedded UI font: %s" % path)
	if game.has_method("_make_watch_shell_style"):
		var shell := game._make_watch_shell_style() as StyleBoxFlat
		_assert(shell.bg_color.get_luminance() < 0.08, "watch shell should be near-black")
		_assert(shell.corner_radius_top_left >= 20, "watch shell should have hardware-scale rounding")
	if game.has_method("_make_surface_card_style"):
		var card := game._make_surface_card_style() as StyleBoxFlat
		_assert(card.bg_color.get_luminance() > 0.88, "cards should be pale blue-white")
		_assert(card.shadow_size >= 4, "cards should have restrained elevation")
	game.queue_free()
	_finish()

func _assert(condition: bool, message: String) -> void:
	if !condition:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("watch debug UI tests passed" if failures == 0 else "watch debug UI tests failed: %d" % failures)
	quit(1 if failures > 0 else 0)
```

- [ ] **Step 2: Run the test and confirm RED**

Run: `& 'C:\Users\sy\bin\godot.cmd' --headless --path 'packages\edugame\godot\games\ch12-solar-survivor' --script 'res://tests/test_watch_debug_ui.gd'`

Expected: FAIL because the shared style methods and three additional fonts do not exist.

- [ ] **Step 3: Add the fonts and minimal shared theme implementation**

Add font constants and `FontVariation` roles matching Ch11, then implement these exact helpers:

```gdscript
func _make_watch_shell_style() -> StyleBoxFlat
func _make_screen_surface_style() -> StyleBoxFlat
func _make_surface_card_style() -> StyleBoxFlat
func _make_metric_tile_style() -> StyleBoxFlat
func _make_state_card_style(accent: Color) -> StyleBoxFlat
func _apply_text_role(control: Control, role: String) -> void
```

Use dark hardware, pale blue-white surface, cyan/green/amber/fault roles, 10-24 px radii, 1-2 px borders, and 4-12 px shadows. Keep all body-copy fallbacks on Noto Sans SC.

- [ ] **Step 4: Run the test and confirm GREEN**

Run the command from Step 2.

Expected: PASS with `watch debug UI tests passed`.

### Task 2: Rebuild the persistent HUD as telemetry cards

**Files:**
- Modify: `packages/edugame/godot/games/ch12-solar-survivor/tests/test_watch_debug_ui.gd`
- Modify: `packages/edugame/godot/games/ch12-solar-survivor/scripts/solar_survivor_root.gd:111-308,1448-1491,1648-1668`

**Interfaces:**
- Produces: `hud_shell: PanelContainer`, `hud_screen: PanelContainer`, `hud_metric_labels: Dictionary`, `hud_hint_card: PanelContainer`, `_create_hud_metric(String, String) -> PanelContainer`.

- [ ] **Step 1: Add failing HUD structure assertions**

```gdscript
	_assert(game.get("hud_shell") is PanelContainer, "HUD should expose the dark hardware shell")
	_assert(game.get("hud_screen") is PanelContainer, "HUD should expose the pale screen surface")
	var metrics := game.get("hud_metric_labels") as Dictionary
	for key in ["time", "energy", "faults", "efficiency", "stability", "correction", "shadow", "protection", "score"]:
		_assert(metrics.has(key), "HUD should expose metric: %s" % key)
	game._update_hud()
	_assert(str((metrics["energy"] as Label).text).contains("%"), "energy metric should keep its percentage value")
	_assert(str((metrics["faults"] as Label).text).contains("/"), "fault metric should keep current/max formatting")
	_assert(str(game.hint_label.text) == "普通光能会自动吸收；金色偏移带需要主动靠近。", "HUD hint copy must remain unchanged")
```

- [ ] **Step 2: Run the test and confirm RED**

Expected: FAIL because the HUD shell and metric dictionary do not exist.

- [ ] **Step 3: Build the HUD hierarchy and update values**

Create a 350 x 330 left-side hardware shell containing a pale screen, 3 x 3 metric grid, and separate feedback card. Replace `_draw_teaching_ui_frames()` with node-based surfaces. Preserve the exact labels `时间`, `光能`, `系统故障`, `追光效率`, `稳定度`, `校正脉冲`, `云影`, `保护`, `追光分`, and `WASD 控制移动`.

- [ ] **Step 4: Run the test and confirm GREEN**

Expected: PASS.

### Task 3: Apply the shared visual hierarchy to every modal state

**Files:**
- Modify: `packages/edugame/godot/games/ch12-solar-survivor/tests/test_watch_debug_ui.gd`
- Modify: `packages/edugame/godot/games/ch12-solar-survivor/scripts/solar_survivor_root.gd:309-403,1097-1410,1648-1668`

**Interfaces:**
- Produces: `_apply_modal_shell(PanelContainer) -> void`, `_add_modal_kicker(VBoxContainer, String, Color) -> Label`; all existing `_show_*` methods retain their signatures and copy.

- [ ] **Step 1: Add failing modal assertions**

```gdscript
	_assert(game.has_method("_apply_modal_shell"), "modal states should share one shell helper")
	_assert(game.has_method("_add_modal_kicker"), "modal states should share one compact hierarchy helper")
	_assert(game.pause_panel.get_theme_stylebox("panel").corner_radius_top_left >= 20, "pause modal should use the hardware shell")
	_assert(str(game.pause_box.get_child(0).text) == "已暂停", "pause title copy must remain unchanged")
	game.active_question = {"prompt":"PID 控制中 D 项主要用于什么？", "choices":["抑制变化趋势，减少超调和抖动","消除长期稳态误差","提高 PWM 频率","扩大 ADC 采样范围"], "answerIndex":0, "explanation":"D 项根据误差变化率进行抑制。"}
	game.question_time_left = 12.0
	game._show_question()
	_assert(str(game.question_title_label.text).begins_with("升级校验"), "question title copy must remain unchanged")
	game.shutdown = false
	game._show_result()
	_assert(str(game.question_box.get_child(1).text) == "追光挑战完成", "result title copy must remain unchanged")
```

- [ ] **Step 2: Run the test and confirm RED**

Expected: FAIL because the modal helper and hierarchy do not exist.

- [ ] **Step 3: Implement modal shells and role styling**

Apply the same hardware/screen/card system to pause, enemy information, question, upgrade, wrong-answer, and result UI. Add visual kickers without changing the existing dynamic copy. Use display typography for titles, readable Chinese typography for prompts/explanations, technical typography for countdown and score, and warm fault styling only for incorrect states.

- [ ] **Step 4: Run the test and confirm GREEN**

Expected: PASS.

### Task 4: Verify project integrity and visual output

**Files:**
- Modify only if verification finds a real issue: Ch12 files above.
- Create: `packages/edugame/godot/games/ch12-solar-survivor/visual-audit/` screenshots.

- [ ] **Step 1: Run GDScript parse and UI tests**

Run:

```powershell
& 'C:\Users\sy\bin\godot.cmd' --headless --path 'packages\edugame\godot\games\ch12-solar-survivor' --check-only --script 'res://scripts/solar_survivor_root.gd'
& 'C:\Users\sy\bin\godot.cmd' --headless --path 'packages\edugame\godot\games\ch12-solar-survivor' --script 'res://tests/test_watch_debug_ui.gd'
```

Expected: both commands exit 0 with no script errors.

- [ ] **Step 2: Run the existing repository game tests**

Run: `pnpm --filter @dgbook/edugame test`

Expected: all existing tests pass.

- [ ] **Step 3: Export the Web build**

Run: `& 'C:\Users\sy\bin\godot.cmd' --headless --path 'packages\edugame\godot\games\ch12-solar-survivor' --export-release Web`

Expected: exit 0 and updated Ch12 Web output.

- [ ] **Step 4: Capture and inspect 1280 x 720 runtime states**

Capture active HUD, pause, enemy information, question, upgrade, wrong-answer, and result states. Verify no overflow, off-screen controls, gameplay obstruction, or copy changes. Compare typography, card material, status colors, radii, and spacing against the approved visual mapping and current Ch11 screenshots.
