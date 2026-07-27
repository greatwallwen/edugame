# Ch09 Spire-Style Normal Run UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Ch09's form-like normal-run screens with a continuous engineering ascent built around a vertical route, a device-versus-fault combat stage, a bottom hand dock, and scene-local rewards and service actions.

**Architecture:** Keep the existing thin `main.tscn`, single `env_spire_root.gd` controller, local JSON data, `RunState` machine, Node Lab integration, and `dgbook_runtime` calls. Reorganize only UI construction and state rendering into focused helpers inside the existing root controller so gameplay rules and run transitions remain unchanged.

**Tech Stack:** Godot 4.6 GDScript, generated Control nodes, SceneTree tests, Web export, browser visual verification.

## Global Constraints

- Preserve the Ch11/Ch12-aligned thin-scene and single-root-controller structure.
- Preserve all card, enemy, relic, event, checkpoint, and route-balance rules.
- Preserve the 12-node single route, node 11 service, and node 12 Boss.
- Preserve Node Lab fixtures, hidden launcher, and runtime-reporting isolation.
- Preserve `dgbook_runtime` progress and completion payloads.
- Borrow Slay the Spire's information hierarchy, not its artwork, branding, or dark fantasy palette.
- Use the bundled Chinese font for every generated UI subtree and Web export.
- Reference viewports are exactly `1280 x 720` and `390 x 844`.
- Every command target must be at least 44 pixels high.
- Do not scale font size with viewport width.

---

## File Map

- `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`
  owns the existing state machine, builds the redesigned UI, and renders all
  normal-run states without moving gameplay rules.
- `packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd`
  receives only compatibility adjustments needed for the new HUD/stage nodes.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
  defines stable node contracts and desktop/mobile bounds.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
  protects normal state transitions while the presentation changes.
- `packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd`
  produces the full visual review set.
- `packages/edugame/godot/games/ch09-env-spire/README.md`
  documents the refreshed capture and verification commands.

---

### Task 1: Establish The Shared Run Scene Contract

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Consumes: existing `_build_ui()`, `_state_panel()`, `_panel_style()`, `ui_theme`, and `RunState`.
- Produces: stable nodes `RunHud`, `SceneStage`, `RunFooter`, `MapView`, `CombatView`, `ChoiceView`, and `ResultView`; helper `_scene_panel(node_name: String, background: Color, border: Color) -> PanelContainer`.

- [ ] **Step 1: Add failing stable-node and hierarchy assertions**

In `test_graybox_ui.gd`, resolve and assert the new shared nodes:

```gdscript
var run_hud = game.find_child("RunHud", true, false)
var scene_stage = game.find_child("SceneStage", true, false)
var run_footer = game.find_child("RunFooter", true, false)
_assert(run_hud != null, "normal flow should expose a stable RunHud")
_assert(scene_stage != null, "normal flow should expose a stable SceneStage")
_assert(run_footer != null, "normal flow should expose a stable RunFooter")
_assert(run_hud.theme == game.ui_theme, "RunHud should use the bundled UI theme")
```

Retain the existing state-view assertions, font checks, and footer coverage checks.

- [ ] **Step 2: Run the graybox test and verify the contract fails**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: FAIL because `RunHud`, `SceneStage`, and `RunFooter` do not exist.

- [ ] **Step 3: Rebuild the shared shell without changing run behavior**

In `_build_ui()`:

```gdscript
header_panel.name = "RunHud"
main_area.name = "SceneStage"
footer.name = "RunFooter"
```

Keep the current `shell` sizing, `ui_theme`, state views, log label, and runtime
startup behavior. Add:

```gdscript
func _scene_panel(node_name: String, background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(background, border))
	return panel
```

Use `_scene_panel()` for the four state views. Keep corners at four pixels and
avoid adding new nested decorative cards.

- [ ] **Step 4: Give the stage a quiet engineering field**

Use a low-contrast cool background and the existing icon asset. Add a tiled
`TextureRect` named `SceneGrid` behind the state views:

```gdscript
func _grid_texture() -> Texture2D:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var line := Color("#d9e7e9")
	for pixel in range(48):
		image.set_pixel(pixel, 0, line)
		image.set_pixel(0, pixel, line)
	return ImageTexture.create_from_image(image)

func _build_scene_grid() -> TextureRect:
	var grid := TextureRect.new()
	grid.name = "SceneGrid"
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.texture = _grid_texture()
	grid.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grid.stretch_mode = TextureRect.STRETCH_TILE
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return grid
```

Add `SceneGrid` to `main_area` before the four state views. Its lines must remain
below text contrast and it must not alter layout.

- [ ] **Step 5: Run focused and baseline tests**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
```

Expected: all three PASS.

- [ ] **Step 6: Commit the shared shell**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: add ch09 shared run scene shell"
```

---

### Task 2: Replace The Horizontal Timeline With A Vertical Climb

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Consumes: `run_map.layers`, `current_layer`, `RUN_NODE_COUNT`, `_node_type_short()`, `_node_type_name()`, and `choose_node(index: int)`.
- Produces: `MapRouteScroll`, `MapRoute`, `MapMissionSummary`, `MapNextDetail`, `MapEnterButton`; helpers `_render_map_route(layers: Array) -> void` and `_map_node_state(layer_number: int) -> String`.

- [ ] **Step 1: Replace timeline expectations with the climb contract**

In `test_graybox_ui.gd`, remove the `MapTimeline` assertion and add:

```gdscript
var map_route = game.find_child("MapRoute", true, false)
var map_enter = game.find_child("MapEnterButton", true, false)
var mission_summary = game.find_child("MapMissionSummary", true, false)
var next_detail = game.find_child("MapNextDetail", true, false)
_assert(map_route != null and map_route.get_child_count() == 12, "map climb should render twelve route nodes")
_assert(map_enter != null and map_enter.custom_minimum_size.y >= 44.0, "map enter should be a full touch target")
_assert(mission_summary != null and next_detail != null, "map should expose mission and next-node context")
```

After setting `current_layer = 10`, render and assert node 11 text contains
`整备`; after setting `current_layer = 11`, assert node 12 contains `综合验收`.

- [ ] **Step 2: Run the graybox test and verify it fails**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: FAIL because the map climb nodes do not exist.

- [ ] **Step 3: Build the map composition**

Replace `_build_map_view()` with:

- A three-column desktop `BoxContainer` named `MapComposition`.
- `MapMissionSummary` on the left.
- A vertically scrollable `MapRoute` in the center.
- `MapNextDetail` and `MapEnterButton` on the right.

The route contains one button-like marker per layer. Connect only the available
next marker and `MapEnterButton` to:

```gdscript
choose_node(0)
_render_state()
```

Do not introduce branching or lane controls.

- [ ] **Step 4: Render route states and current-node context**

Implement:

```gdscript
func _map_node_state(layer_number: int) -> String:
	if layer_number <= current_layer:
		return "completed"
	if layer_number == current_layer + 1:
		return "available"
	return "future"
```

`_render_map_route()` applies teal to completed nodes, coral emphasis to the
available node, violet to the Boss, and muted styling to future nodes. It fills
`MapNextDetail` from `layers[current_layer].choices[0]` and disables
`MapEnterButton` when the route is complete.

- [ ] **Step 5: Implement mobile reflow**

In `_apply_responsive_layout()`:

- Set `MapComposition.vertical = true` below 720 pixels.
- Hide `MapMissionSummary` in compact mode.
- Keep `MapNextDetail` below the route.
- Limit the route viewport so the available node and at least two neighboring
  nodes remain visible.
- Preserve a 44-pixel minimum for all route actions.

- [ ] **Step 6: Run route and UI tests**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: all three PASS.

- [ ] **Step 7: Commit the vertical map**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: turn ch09 map into a vertical climb"
```

---

### Task 3: Build The Device-Versus-Fault Combat Stage

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Consumes: existing combat labels, `repair_progress`, `repair_target`, `_current_intent_text()`, `_gate_status_text()`, `_card_cost_preview()`, `play_card(index)`, and `end_turn()`.
- Produces: `EncounterArena`, `DeviceUnit`, `EvidenceBridge`, `FaultUnit`, `EnemyIntent`, `HandDock`, `ProcessingPointCounter`, `HandScroll`, and `EndTurnButton`.

- [ ] **Step 1: Add failing combat-stage assertions**

Add:

```gdscript
var arena = game.find_child("EncounterArena", true, false)
var device_unit = game.find_child("DeviceUnit", true, false)
var evidence_bridge = game.find_child("EvidenceBridge", true, false)
var fault_unit = game.find_child("FaultUnit", true, false)
var enemy_intent = game.find_child("EnemyIntent", true, false)
var hand_dock = game.find_child("HandDock", true, false)
var point_counter = game.find_child("ProcessingPointCounter", true, false)
_assert(arena != null, "combat should expose an encounter arena")
_assert(device_unit != null and evidence_bridge != null and fault_unit != null, "combat should render device, evidence, and fault zones")
_assert(enemy_intent != null, "fault intent should have a stable visual anchor")
_assert(hand_dock != null and point_counter != null, "combat should expose a fixed action dock")
```

After `_start_encounter()`, assert `EnemyIntent` is above `FaultUnit` on desktop
and that `HandDock` is above `RunFooter`.

- [ ] **Step 2: Run the graybox test and verify it fails**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: FAIL because the stage zones do not exist.

- [ ] **Step 3: Rebuild `_build_combat_view()` as arena plus dock**

Create:

```text
CombatView
  EncounterArena
    DeviceUnit
    EvidenceBridge
    FaultUnit
      EnemyIntent
  HandDock
    ProcessingPointCounter
    HandScroll
      HandRow
    EndTurnButton
```

Reuse the existing labels and progress bar inside these zones:

- `status_label` and `data_label` in `DeviceUnit`
- `repair_label`, `repair_bar`, and `gate_label` in `EvidenceBridge`
- `encounter_name_label`, `encounter_meta_label`, and `intent_label` in
  `FaultUnit`

Do not duplicate combat state or introduce presentation-owned counters.

- [ ] **Step 4: Render the stage and card hierarchy**

Keep `_render_combat()` as the single state-to-view renderer. Update label copy
so:

- `intent_label` contains only the next action.
- `repair_label` contains repair progress.
- `gate_label` contains evidence requirements.
- `ProcessingPointCounter` displays `processing_points`.
- Card buttons place cost first, name second, type as a compact category, and
  effect text last.

Disabled cards remain readable and visibly unavailable.

- [ ] **Step 5: Implement desktop and mobile geometry**

Desktop:

- Arena uses horizontal `DeviceUnit`, `EvidenceBridge`, `FaultUnit` zones.
- Hand dock remains fixed below the arena.
- Enemy intent is visually attached above the fault.

Mobile:

- Arena stacks `FaultUnit`, `EvidenceBridge`, and `DeviceUnit`.
- Hand dock remains below the arena with horizontal card scrolling.
- `EndTurnButton` remains completely above `RunFooter`.
- Existing cards resize to compact dimensions during live resize.

- [ ] **Step 6: Run combat, resize, and gameplay tests**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_random_robustness.gd
```

Expected: all four PASS.

- [ ] **Step 7: Commit the combat stage**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: stage ch09 device and fault combat"
```

---

### Task 4: Turn Rewards And Utility Nodes Into Scene Decisions

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Consumes: existing `RunState.REWARD`, `EVENT`, `SHOP`, `REST`, and `COMPONENT`; `_latest_debug_summary()`, `choose_reward()`, `choose_event_option()`, `purchase_shop_card()`, `leave_shop()`, `choose_service()`, and `choose_component()`.
- Produces: `SceneChoiceBackdrop`, `SceneChoiceContext`, `RewardCards`, `ChoiceList`, `ServiceBench`, and helper `_choice_scene_kind() -> String`.

- [ ] **Step 1: Add failing state-specific scene assertions**

For reward:

```gdscript
var choice_backdrop = game.find_child("SceneChoiceBackdrop", true, false)
var choice_context = game.find_child("SceneChoiceContext", true, false)
var reward_cards = game.find_child("RewardCards", true, false)
_assert(choice_backdrop != null and choice_context != null, "choice states should retain scene context")
_assert(reward_cards != null, "reward should expose a dedicated card row")
```

For service:

```gdscript
var service_bench = game.find_child("ServiceBench", true, false)
_assert(service_bench != null and service_bench.visible, "service should present the engineering maintenance bench")
```

Assert the reward skip command is visually secondary and all service actions
remain at least 44 pixels high.

- [ ] **Step 2: Run focused tests and verify they fail**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
```

Expected: graybox FAILS on missing scene nodes; run-flow behavior remains PASS.

- [ ] **Step 3: Rebuild the shared choice scene**

Build `ChoiceView` with:

- A subdued `SceneChoiceBackdrop`
- `choice_title`
- `SceneChoiceContext` using `choice_description`
- A centered scroll region
- `RewardCards` for rewards
- `ChoiceList` for events, shop, components, and service
- `ServiceBench`, hidden outside `RunState.REST`

Implement:

```gdscript
func _choice_scene_kind() -> String:
	return {
		RunState.REWARD: "reward",
		RunState.EVENT: "event",
		RunState.SHOP: "shop",
		RunState.REST: "service",
		RunState.COMPONENT: "component"
	}.get(state, "choice")
```

- [ ] **Step 4: Render reward as encounter resolution**

Use `_latest_debug_summary()` as the report under a resolved title. Render three
card-shaped reward buttons in `RewardCards`. Render skip below or beside the row
as a smaller neutral command, never as an equal fourth reward card.

Do not change `choose_reward()` or reward generation.

- [ ] **Step 5: Render event, component, shop, and service variants**

- Event: concise context plus option buttons.
- Component: three engineering component choices.
- Shop: card-sized inventory with price and disabled affordability state.
- Service: visible `ServiceBench` plus restore, upgrade, remove, and shop
  actions.

Keep node 11's copy as `Boss 前最后一次整备。`.

- [ ] **Step 6: Refresh the result composition**

Keep result data unchanged. Recompose `ResultView` into:

- `RunResultHeading`
- `RunResultMetrics`
- `RunLearningSummary`
- `RestartButton`

The summary still includes score, node count, stability, checkpoints, deck
size, and the latest debugging conclusion.

- [ ] **Step 7: Run flow and UI tests**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_node_lab.gd
```

Expected: all three PASS.

- [ ] **Step 8: Commit the scene decisions**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd
git commit -m "feat: stage ch09 rewards and utility nodes"
```

---

### Task 5: Preserve Responsive And Node Lab Isolation

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Consumes: `_apply_responsive_layout()`, `NodeLab.show_catalog()`, `NodeLab.show_scenario_controls()`, `header_panel`, `shell`, and `ui_theme`.
- Produces: responsive bounds guarantees at both reference sizes and restored Node Lab compatibility with `RunHud` and the redesigned scene views.

- [ ] **Step 1: Add complete viewport-bound assertions**

At `1280 x 720` and `390 x 844`, assert:

```gdscript
_assert(viewport_rect.encloses(run_hud.get_global_rect()), "RunHud should stay in the viewport")
_assert(viewport_rect.encloses(end_turn.get_global_rect()), "End turn should stay in the viewport")
_assert(end_turn.get_global_rect().end.y <= run_footer.get_global_rect().position.y, "End turn should stay above the footer")
_assert(viewport_rect.intersects(map_enter.get_global_rect()), "Available map action should remain visible")
```

Also retain live-resize card height checks and assert every visible primary
command is at least 44 pixels high.

- [ ] **Step 2: Add Node Lab compatibility assertions**

In both Node Lab tests:

- Catalog hides the normal shell.
- Scenario toolbar replaces `RunHud`.
- Scenario combat still exposes the redesigned arena and hand dock.
- Return restores the catalog.
- Restart keeps runtime calls at zero.
- Lab root uses `game.ui_theme`.

- [ ] **Step 3: Run tests and verify any renamed-node failures**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_node_lab.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
```

Expected: failures identify any stale `Header`/`Footer` or layout assumptions.

- [ ] **Step 4: Update responsive and Node Lab references**

Update `node_lab.gd` to address `game.header_panel` by variable, not a hardcoded
node path. Keep:

```gdscript
game.header_panel.visible = false
game.shell.offset_top = 58
```

for scenarios, and restore header visibility plus zero shell offset in the
catalog. Update `_apply_responsive_layout()` so map composition, combat arena,
choice rows, and result content reflow without changing gameplay state.

- [ ] **Step 5: Run the full focused compatibility suite**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_node_lab.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
godot.cmd --headless --path . -s tests/test_random_robustness.gd
```

Expected: all four PASS.

- [ ] **Step 6: Commit responsive and lab compatibility**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd
git commit -m "fix: preserve ch09 mobile and node lab layouts"
```

---

### Task 6: Complete Visual, Route, And Web Verification

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/README.md`

**Interfaces:**
- Consumes: all redesigned state views and existing hidden Node Lab launcher.
- Produces: updated desktop/mobile capture set, passing full-route evidence, successful Web export, and documented verification commands.

- [ ] **Step 1: Expand the capture matrix**

Keep existing captures and add normal-run captures for:

```text
desktop/mobile event
desktop/mobile component
desktop/mobile service at node 11
desktop/mobile empty-or-skip reward fallback
```

Use deterministic fixture state and semantic filenames. Continue capturing map,
ordinary combat, reward, shop, checkpoints, all Boss phases, result, Node Lab
catalog, Node Lab event, and Node Lab combat.

- [ ] **Step 2: Run all automated tests**

Run:

```powershell
$tests = @(
  'test_data_contract.gd',
  'test_card_rules.gd',
  'test_run_flow.gd',
  'test_random_robustness.gd',
  'test_graybox_ui.gd',
  'test_runtime_integration.gd',
  'test_node_lab.gd'
)
foreach ($test in $tests) {
  & godot.cmd --headless --path . -s "tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: all seven PASS.

- [ ] **Step 3: Run all three complete routes**

Run:

```powershell
foreach ($map in @('mvp_a', 'mvp_b', 'mvp_c')) {
  & godot.cmd --headless --path . -s tests/test_full_run.gd -- "--map=$map"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: all three routes visit 12 nodes, pass both checkpoints, and defeat the
Boss.

- [ ] **Step 4: Export Web**

Run:

```powershell
godot.cmd --headless --path . --export-release Web
```

Expected: exit code 0 and refreshed output at
`apps/player/public/assets/godot/ch09-env-spire/index.html`.

- [ ] **Step 5: Capture desktop and mobile images**

Run:

```powershell
godot.cmd --path . -s tests/capture_graybox.gd
godot.cmd --path . -s tests/capture_graybox.gd -- --mobile
```

Expected: both commands exit 0 and refresh the visual QA directory. Inspect
every required state for overlap, clipping, unreadable text, blank content, and
incorrect state emphasis.

- [ ] **Step 6: Verify the actual Web export**

Serve the export through the existing local preview helper. In the browser,
verify:

```text
http://127.0.0.1:<port>/index.html
http://127.0.0.1:<port>/index.html?nodeLab=1
```

At `1280 x 720` and `390 x 844`, confirm:

- Canvas size matches viewport.
- Rendering is nonblank.
- Chinese text renders with the bundled font.
- Normal map and combat composition match the selected design.
- Node Lab catalog and a launched scenario work.
- Console has no errors or warnings.

- [ ] **Step 7: Update README verification notes**

Document the refreshed capture commands, reference sizes, normal preview URL,
and Node Lab preview URL. Do not describe controls inside the game UI.

- [ ] **Step 8: Run final diff and verification checks**

Run:

```powershell
git diff --check
git status --short
```

Review only the intended Ch09 files. Do not stage unrelated existing workspace
changes or generated visual-companion files.

- [ ] **Step 9: Commit final verification**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd packages/edugame/godot/games/ch09-env-spire/README.md
git commit -m "test: verify ch09 redesigned normal run"
```
