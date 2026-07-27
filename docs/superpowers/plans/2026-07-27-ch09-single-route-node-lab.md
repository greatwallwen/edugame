# Ch09 Single-Route Run and Node Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Ch09's branching ten-node maps with deterministic twelve-node single routes and add a hidden Node Lab that can launch every node variant in an isolated fixture.

**Architecture:** Keep the existing Ch11/Ch12-aligned Godot structure and reuse the current map, combat, choice, result, and runtime surfaces. Normal run content remains JSON-driven in `run_maps.local.json`; a focused `dev/node_lab.gd` overlay builds its catalog from the already-loaded definitions and asks the root game loop to launch isolated scenarios.

**Tech Stack:** Godot 4.6 GDScript, JSON content files, SceneTree tests, Godot Web export, shared `dgbook_runtime`.

## Global Constraints

- The normal game uses a single route from the start; no relic or event changes route topology.
- Every map contains exactly twelve layers and every layer contains exactly one choice.
- Node 11 is always the pre-boss `service`; node 12 is always the `boss`.
- The fixed node sequence is ordinary, event, ordinary, service, sensor checkpoint, component, ordinary, trust checkpoint, shop, elite, service, boss.
- The Node Lab is hidden from normal play and is entered only with `--node-lab` or `?nodeLab=1`.
- Lab scenarios never report completion, score, stars, or learning stats to the shared runtime.
- Preserve the existing main scene, root loop, local JSON, shared runtime, and SceneTree-test organization used by Ch11 and Ch12.
- Do not add a second combat implementation or duplicate card rules.

## File Structure

- Modify `packages/edugame/godot/games/ch09-env-spire/data/run_maps.local.json`
  - Own the three twelve-layer single-route presets.
- Modify `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`
  - Own normal transitions, component selection, route scaling, lab fixture setup, and scenario dispatch.
- Create `packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd`
  - Own the hidden catalog overlay, catalog generation, fixture toggle, restart, and return controls.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd`
  - Enforce the twelve-node sequence and content references.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
  - Cover component selection and single-route progression.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/test_full_run.gd`
  - Autoplay all twelve nodes on all three presets.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
  - Cover the twelve-node progress UI and component choice layout.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd`
  - Cover twelve-node completion stats and lab runtime isolation.
- Create `packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd`
  - Cover catalog completeness, fixture reset, and every scenario launcher.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd`
  - Capture the normal map and Node Lab at desktop and mobile sizes.
- Modify `packages/edugame/godot/games/ch09-env-spire/README.md`
  - Document native and Web Node Lab entry points.

---

### Task 1: Twelve-Layer Single-Route Data Contract

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/data/run_maps.local.json`

**Interfaces:**
- Consumes: top-level `maps` array with `layers[].choices[]`.
- Produces: three maps whose layer types exactly match `SINGLE_ROUTE_TYPES`.

- [ ] **Step 1: Write the failing route-contract test**

Add the expected sequence and replace the ten-layer assertions:

```gdscript
const SINGLE_ROUTE_TYPES := [
	"ordinary", "event", "ordinary", "service",
	"checkpoint_sensor", "component", "ordinary", "checkpoint_trust",
	"shop", "elite", "service", "boss"
]

func _choice_type(layer: Dictionary) -> String:
	var choices: Array = layer.get("choices", [])
	return "" if choices.is_empty() else str((choices[0] as Dictionary).get("type", ""))
```

Inside the map loop assert:

```gdscript
_assert(layers.size() == 12, "%s should contain twelve layers" % run_map.get("id", "map"))
for index in range(layers.size()):
	var layer := layers[index] as Dictionary
	var choices: Array = layer.get("choices", [])
	_assert(int(layer.get("layer", 0)) == index + 1, "map layers should be numbered 1 through 12")
	_assert(choices.size() == 1, "single-route layers should contain exactly one choice")
	_assert(_choice_type(layer) == SINGLE_ROUTE_TYPES[index], "layer %d should be %s" % [index + 1, SINGLE_ROUTE_TYPES[index]])
```

Also build `enemy_ids` and `event_ids` dictionaries from the loaded arrays and assert that ordinary, elite, boss, and event `contentId` values resolve.

- [ ] **Step 2: Run the contract test and verify the old maps fail**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
```

Expected: exit 1 with failures stating that maps have ten layers, contain multiple choices, or do not match the fixed sequence.

- [ ] **Step 3: Replace the three map presets**

Use these exact content assignments:

```text
mvp_a: mq2_warmup, sensor_replacement, bh1750_stale, service,
       sensor_checkpoint, component, adc_spike, trust_checkpoint,
       shop, i2c_congestion, service, warehouse_acceptance

mvp_b: bh1750_stale, datasheet_errata, mq2_warmup, service,
       sensor_checkpoint, component, lcd_blocking, trust_checkpoint,
       shop, i2c_congestion, service, warehouse_acceptance

mvp_c: mq2_warmup, bench_cleanup, bh1750_stale, service,
       sensor_checkpoint, component, alarm_jitter, trust_checkpoint,
       shop, i2c_congestion, service, warehouse_acceptance
```

Each `layers` entry must contain one `choices` item. Use `lane: "merge"` for all twelve items because lane identity is no longer gameplay information. Label node 4 `阶段维护`, node 6 `工程组件`, and node 11 `Boss 前整备`.

- [ ] **Step 4: Run the contract test and verify it passes**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
```

Expected: `Ch09 data contract tests passed`.

- [ ] **Step 5: Commit the route data**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/data/run_maps.local.json packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd
git commit -m "feat: make ch09 a twelve-node single route"
```

---

### Task 2: Route Scaling and Progress Presentation

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd`

**Interfaces:**
- Produces: `const RUN_NODE_COUNT := 12`.
- Produces: `_run_progress() -> float`.
- Preserves: `choose_node(choice_index: int) -> bool`.

- [ ] **Step 1: Write failing flow and UI assertions**

In `test_run_flow.gd`, after reset assert:

```gdscript
_assert(game.RUN_NODE_COUNT == 12, "the single route should contain twelve nodes")
_assert((game.run_map.get("layers", []) as Array).size() == 12, "the active map should expose twelve layers")
_assert(!game.choose_node(1), "a single-route layer should reject a second choice")
```

In `test_graybox_ui.gd`, change the timeline assertion to:

```gdscript
_assert(map_timeline != null and map_timeline.get_child_count() == 12, "map should render a twelve-stage timeline")
```

In `test_runtime_integration.gd`, set `current_layer = 12` before completion and expect `visitedNodes == 12`.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
```

Expected: failures reference the missing `RUN_NODE_COUNT`, ten timeline markers, or ten-node runtime values.

- [ ] **Step 3: Replace hard-coded route lengths**

Add:

```gdscript
const RUN_NODE_COUNT := 12

func _run_progress() -> float:
	return clampf(float(current_layer) / float(RUN_NODE_COUNT), 0.0, 1.0)
```

Use `RUN_NODE_COUNT` in:

- `_render_header()`;
- `_render_map()` title and marker loop;
- `choose_node()` runtime progress;
- `_handle_defeat()` by setting `current_layer = RUN_NODE_COUNT - 1`;
- `_finish_run()` failure score scaling;
- any completion or summary logic still dividing by ten.

Change the rest title and description so node 4 is not called a boss rest:

```gdscript
choice_title.text = str(current_node.get("label", "阶段维护"))
choice_description.text = "选择一项整备操作。" if current_layer < RUN_NODE_COUNT - 1 else "Boss 前最后一次整备。"
```

Remove lane text from the current-node button:

```gdscript
button.text = "%02d  %s\n%s" % [
	current_layer + 1,
	node.get("label", "调试节点"),
	_node_type_name(str(node.get("type", "")))
]
```

- [ ] **Step 4: Run the focused tests and verify they pass**

Run the three commands from Step 2.

Expected: all three scripts print their `passed` messages and exit 0.

- [ ] **Step 5: Commit route scaling**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd
git commit -m "feat: scale ch09 flow to twelve nodes"
```

---

### Task 3: Engineering Component Node

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`

**Interfaces:**
- Produces: `RunState.COMPONENT`.
- Produces: `component_choices: Array`.
- Produces: `_open_component_choice() -> void`.
- Produces: `choose_component(component_id: String) -> bool`.
- Produces: `_component_choice_ids() -> Array[String]`.

- [ ] **Step 1: Write the failing component-selection test**

Add to `test_run_flow.gd`:

```gdscript
game.state = game.RunState.MAP
game.current_layer = 5
_assert(game.choose_node(0), "node six should open the component choice")
_assert(game.state == game.RunState.COMPONENT, "component node should use its own choice state")
_assert(game.component_choices.size() == 3, "component node should offer three choices")
var chosen_id := str((game.component_choices[0] as Dictionary).get("id", ""))
_assert(game.choose_component(chosen_id), "offered component should be selectable")
_assert(game.relics.has(chosen_id), "selected component should be added to the run")
_assert(game.state == game.RunState.MAP, "component choice should return to the route")
_assert(!game.choose_component("missing_component"), "unoffered component should be rejected")
```

Add a second case with four owned components and assert that one remaining component plus an `upgrade_fallback` entry is offered.

- [ ] **Step 2: Run the flow test and verify it fails**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_run_flow.gd
```

Expected: parse or assertion failure because `COMPONENT`, `component_choices`, and `choose_component` do not exist.

- [ ] **Step 3: Implement component state and selection**

Extend the enum:

```gdscript
enum RunState { WAITING, MAP, COMBAT, REWARD, EVENT, SHOP, REST, COMPONENT, RESULT }
```

Add `var component_choices: Array = []`. Route `"component"` in `choose_node()` to `_open_component_choice()`.

Implement:

```gdscript
func _component_choice_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in relic_defs.keys():
		var component_id := str(raw_id)
		if !relics.has(component_id):
			ids.append(component_id)
	ids.sort()
	_shuffle(ids)
	return ids

func _open_component_choice() -> void:
	component_choices.clear()
	var ids := _component_choice_ids()
	for index in range(mini(3, ids.size())):
		component_choices.append((relic_defs[ids[index]] as Dictionary).duplicate(true))
	if component_choices.size() < 3:
		component_choices.append({
			"id": "upgrade_fallback",
			"name": "固件优化",
			"description": "升级牌组中的第一张未升级卡牌。"
		})
	state = RunState.COMPONENT

func choose_component(component_id: String) -> bool:
	if state != RunState.COMPONENT:
		return false
	var offered := component_choices.any(func(item: Dictionary) -> bool: return str(item.get("id", "")) == component_id)
	if !offered:
		return false
	if component_id == "upgrade_fallback":
		_upgrade_first_card()
	else:
		relics.append(component_id)
		_log("获得工程组件：%s" % (relic_defs[component_id] as Dictionary).get("name", component_id))
	component_choices.clear()
	state = RunState.MAP
	return true
```

Include `RunState.COMPONENT` in choice-view visibility and render a button for each `component_choices` item using its name and description.

- [ ] **Step 4: Add component UI assertions**

In `test_graybox_ui.gd`, open node 6, render, and assert:

```gdscript
_assert(choice_view.visible, "component state should reuse the choice view")
_assert(choice_list.get_child_count() == 3, "component node should render three choices")
_assert((choice_list.get_child(0) as Button).text.contains("工程") or !(choice_list.get_child(0) as Button).text.is_empty(), "component choices should have readable labels")
```

- [ ] **Step 5: Run flow and UI tests**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: both scripts pass.

- [ ] **Step 6: Commit the component node**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: add ch09 engineering component node"
```

---

### Task 4: Node Lab Catalog and Scenario Fixtures

**Files:**
- Create: `packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd`
- Create: `packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Produces: `EnvSpireNodeLab.configure(game_root: Control) -> void`.
- Produces: `EnvSpireNodeLab.catalog_entries() -> Array`.
- Produces: `start_lab_scenario(entry: Dictionary, deck_fixture: String = "starter") -> bool`.
- Produces: `restart_lab_scenario() -> bool`.
- Produces: `return_to_node_lab() -> void`.

- [ ] **Step 1: Write the failing Node Lab catalog test**

Create `tests/test_node_lab.gd` and instantiate `main.tscn`. Load `dev/node_lab.gd`, configure it, and assert:

```gdscript
var lab_script := load("res://dev/node_lab.gd")
var lab = lab_script.new()
game.add_child(lab)
lab.configure(game)
var entries: Array = lab.catalog_entries()

for enemy_id in game.enemy_defs.keys():
	_assert(_has_entry(entries, str(enemy_id)), "lab should include enemy %s" % enemy_id)
for event_id in game.event_defs.keys():
	_assert(_has_entry(entries, str(event_id)), "lab should include event %s" % event_id)
for required_id in [
	"boss_phase_1", "boss_phase_2", "boss_phase_3",
	"sensor_checkpoint", "trust_checkpoint", "component",
	"shop", "service", "ordinary_reward", "elite_reward"
]:
	_assert(_has_entry(entries, required_id), "lab should include %s" % required_id)
```

Add `_has_entry(entries: Array, id: String) -> bool` that checks each dictionary's `id`.

- [ ] **Step 2: Run the Node Lab test and verify it fails**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_node_lab.gd
```

Expected: failure because `res://dev/node_lab.gd` does not exist.

- [ ] **Step 3: Implement the generated catalog**

Create `dev/node_lab.gd` with `extends CanvasLayer` and:

```gdscript
var game: Control
var entries: Array = []
var current_entry := {}
var deck_fixture := "starter"

func configure(game_root: Control) -> void:
	game = game_root
	entries = _build_catalog()

func catalog_entries() -> Array:
	return entries.duplicate(true)
```

`_build_catalog()` must:

1. sort enemy ids and add ordinary and elite entries;
2. add one full-boss entry and three boss-phase entries;
3. sort event ids and add each event;
4. append the two checkpoints, component, shop, service, ordinary reward, and elite reward.

Each entry has:

```gdscript
{
	"id": "mq2_warmup",
	"group": "普通故障",
	"label": "MQ-2 预热不足",
	"kind": "enemy",
	"contentId": "mq2_warmup",
	"tier": "ordinary",
	"phase": -1
}
```

- [ ] **Step 4: Write failing fixture and dispatch assertions**

Extend `test_node_lab.gd` to launch:

- one ordinary enemy and assert `RunState.COMBAT`;
- one event and assert `RunState.EVENT`;
- both checkpoints and assert checkpoint combat;
- component, shop, service, and rewards and assert their expected states;
- each boss phase and assert `boss_phase` matches 0, 1, or 2.

Before each launch mutate stability, budget, deck, and relics. After launch assert:

```gdscript
_assert(game.stability == game.max_stability, "lab fixture should restore full stability")
_assert(game.budget == 100, "lab fixture should provide deterministic budget")
_assert(game.relics.is_empty(), "lab fixture should clear components")
```

Launch with `"coverage"` and assert `_deck_has_any_tag()` succeeds for `smoke`, `light`, `i2c`, `filter`, `display`, `uart`, `alarm`, and `scheduler`.

- [ ] **Step 5: Implement isolated scenario dispatch in the root**

Add:

```gdscript
const LAB_COVERAGE_CARD_IDS := [
	"mq2_sample", "bh1750_read", "hdc1080_read", "adc_convert",
	"i2c_transaction", "sliding_average", "lcd_display",
	"uart_log", "threshold_judgement", "time_slice"
]

var node_lab_active := false
var lab_current_entry := {}
var lab_deck_fixture := "starter"
var node_lab_overlay: CanvasLayer
```

Implement `_reset_lab_fixture(deck_fixture: String) -> void` by calling `_reset_run()`, replacing the deck when `deck_fixture == "coverage"`, setting `budget = 100`, restoring stability, clearing relics, resetting combat piles, and setting `node_lab_active = true`.

Implement `start_lab_scenario(entry, deck_fixture)` with an exact `kind` match:

```gdscript
match str(entry.get("kind", "")):
	"enemy":
		_start_encounter(str(entry.get("contentId", "")), str(entry.get("tier", "ordinary")))
	"boss_phase":
		current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
		boss_phase = int(entry.get("phase", 0))
		_start_encounter("warehouse_acceptance", "boss")
		boss_phase = int(entry.get("phase", 0))
		_apply_boss_phase()
	"event":
		current_event = (event_defs[str(entry.get("contentId", ""))] as Dictionary).duplicate(true)
		state = RunState.EVENT
	"checkpoint_sensor":
		current_node = {"type": "checkpoint_sensor"}
		_start_checkpoint(true)
	"checkpoint_trust":
		current_node = {"type": "checkpoint_trust"}
		_start_checkpoint(false)
	"component":
		_open_component_choice()
	"shop":
		_open_shop()
	"service":
		current_node = {"type": "service", "label": "节点实验室休整"}
		state = RunState.REST
	"reward":
		_open_reward()
	_:
		return false
```

Store `lab_current_entry`, render state, and return true. Implement restart and return with:

```gdscript
func restart_lab_scenario() -> bool:
	if lab_current_entry.is_empty():
		return false
	return start_lab_scenario(lab_current_entry, lab_deck_fixture)

func return_to_node_lab() -> void:
	_reset_combat_resources()
	reward_choices.clear()
	component_choices.clear()
	current_event.clear()
	shop_cards.clear()
	state = RunState.WAITING
	if node_lab_overlay != null:
		node_lab_overlay.show_catalog()
	_render_state()
```

- [ ] **Step 6: Run the Node Lab test**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_node_lab.gd
```

Expected: `Ch09 node lab tests passed`.

- [ ] **Step 7: Commit the catalog and fixture engine**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd
git commit -m "feat: add isolated ch09 node lab scenarios"
```

---

### Task 5: Hidden Node Lab Launcher, Controls, and Runtime Isolation

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`

**Interfaces:**
- Produces: `_node_lab_requested() -> bool`.
- Produces: `_enter_node_lab() -> void`.
- Produces: `EnvSpireNodeLab.show_catalog() -> void`.
- Produces: `EnvSpireNodeLab.show_scenario_controls() -> void`.

- [ ] **Step 1: Write failing launcher and isolation tests**

In `test_node_lab.gd`, call `_enter_node_lab()` and assert:

```gdscript
_assert(game.node_lab_active, "manual lab entry should activate lab mode")
_assert(game.find_child("NodeLabCatalog", true, false) != null, "lab should render a catalog")
_assert(game.find_child("NodeLabRestart", true, false) != null, "lab should expose restart")
_assert(game.find_child("NodeLabReturn", true, false) != null, "lab should expose return")
```

In `test_runtime_integration.gd`, collect outbound payloads, enter lab, launch the full boss, call `_finish_run(true)`, and assert no new `DGB_GODOT_COMPLETE` payload appears.

- [ ] **Step 2: Run the launcher and runtime tests and verify they fail**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_node_lab.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
```

Expected: failures for missing lab controls or an unexpected completion payload.

- [ ] **Step 3: Implement hidden launch detection**

Add:

```gdscript
func _node_lab_requested() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--node-lab":
			return true
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('nodeLab')",
			true
		)
		return str(value) == "1"
	return false
```

At startup, after data and normal UI exist, call `_enter_node_lab()` instead of scheduling standalone preview when this returns true.

Implement the loader:

```gdscript
func _enter_node_lab() -> void:
	if node_lab_overlay != null:
		node_lab_overlay.show_catalog()
		return
	var lab_script := load("res://dev/node_lab.gd")
	node_lab_overlay = lab_script.new() as CanvasLayer
	add_child(node_lab_overlay)
	node_lab_overlay.configure(self)
	node_lab_active = true
	state = RunState.WAITING
	node_lab_overlay.show_catalog()
	_render_state()
```

- [ ] **Step 4: Build the lab overlay UI**

In `dev/node_lab.gd`, create:

- a full-rect catalog panel named `NodeLabCatalog`;
- a compact top toolbar that remains visible during scenarios;
- icon/text buttons named `NodeLabReturn` and `NodeLabRestart`;
- a two-option fixture selector for `starter` and `coverage`;
- group headings and scenario buttons generated from `entries`.

Use these concrete construction helpers:

```gdscript
func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	catalog = PanelContainer.new()
	catalog.name = "NodeLabCatalog"
	catalog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(catalog)
	toolbar = HBoxContainer.new()
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_bottom = 56
	root.add_child(toolbar)
	_add_toolbar_button("NodeLabReturn", "返回目录", func() -> void: game.return_to_node_lab())
	_add_toolbar_button("NodeLabRestart", "重开节点", func() -> void: game.restart_lab_scenario())

func _add_entry_button(parent: Container, entry: Dictionary) -> void:
	var button := Button.new()
	button.text = str(entry.get("label", entry.get("id", "测试节点")))
	button.custom_minimum_size.y = 44
	button.pressed.connect(func() -> void:
		if game.start_lab_scenario(entry, deck_fixture):
			show_scenario_controls()
	)
	parent.add_child(button)
```

`show_catalog()` sets `catalog.visible = true`, hides restart while no scenario is active, rebuilds grouped buttons in deterministic `group` then `label` order, and keeps return hidden because the player is already in the catalog. `show_scenario_controls()` hides the catalog and shows return and restart.

Scenario buttons call:

```gdscript
if game.start_lab_scenario(entry, deck_fixture):
	show_scenario_controls()
```

Return calls `game.return_to_node_lab()`. Restart calls `game.restart_lab_scenario()`.

Use the existing Chinese font from `game.ui_font`, 44-pixel minimum button height, one catalog column below 720 pixels, and two columns otherwise.

- [ ] **Step 5: Block runtime reporting in lab mode**

At the start of `_finish_run(won)` keep normal result calculation, but guard shared reporting:

```gdscript
if node_lab_active:
	completed = true
	victory = won
	state = RunState.RESULT
	_render_state()
	return
```

Also prevent `choose_node()` progress reporting while `node_lab_active` is true. Normal runs must retain all existing runtime behavior.

- [ ] **Step 6: Add desktop and mobile UI assertions**

In `test_graybox_ui.gd`, call `_enter_node_lab()` at both 1280x720 and 390x844. Assert the catalog is visible, scenario buttons are inside the viewport, controls are at least 44 pixels high, and starting an event hides the catalog while keeping restart and return visible.

- [ ] **Step 7: Run Node Lab, runtime, and UI tests**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_node_lab.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: all three scripts pass.

- [ ] **Step 8: Commit the hidden launcher**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: expose hidden ch09 node lab"
```

---

### Task 6: Full-Run Autoplay, Documentation, and Visual Verification

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_full_run.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/README.md`

**Interfaces:**
- Consumes: `RunState.COMPONENT`, `choose_component()`, and twelve-layer maps.
- Produces: repeatable end-to-end verification for normal runs and Node Lab.

- [ ] **Step 1: Update full-run assertions before changing the autoplayer**

Change:

```gdscript
_assert(game.current_layer == 12 and game.visited_nodes.size() == 12, "full run should visit twelve nodes")
```

Add a `RunState.COMPONENT` match arm that currently fails explicitly:

```gdscript
game.RunState.COMPONENT:
	_assert(false, "autoplayer must select an engineering component")
```

- [ ] **Step 2: Run all three full maps and verify the new state fails**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_a
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_b
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_c
```

Expected: each run reaches the component node and fails with the explicit component message.

- [ ] **Step 3: Teach the autoplayer to select a component**

Replace the failing arm with:

```gdscript
game.RunState.COMPONENT:
	var component_id := str((game.component_choices[0] as Dictionary).get("id", ""))
	_assert(game.choose_component(component_id), "autoplayer should select an offered component")
```

Keep existing evidence-aware card selection. Do not weaken engineering gates to make autoplay pass.

- [ ] **Step 4: Extend visual capture**

Update `capture_graybox.gd` to save:

- desktop normal twelve-node map;
- mobile normal twelve-node map;
- desktop Node Lab catalog;
- mobile Node Lab catalog;
- desktop lab event scenario;
- mobile lab combat scenario.

Enter the lab by calling `_enter_node_lab()` directly in the capture script so the capture does not depend on platform query parsing.

- [ ] **Step 5: Document tester entry points**

Add to `README.md`:

```powershell
godot.cmd --path . -- --node-lab
```

And:

```text
http://127.0.0.1:<preview-port>/index.html?nodeLab=1
```

State that the lab is not part of course progression, resets resources between scenarios, and offers starter and coverage deck fixtures.

- [ ] **Step 6: Run the complete test matrix**

Run:

```powershell
$core = @(
  'test_data_contract.gd',
  'test_card_rules.gd',
  'test_run_flow.gd',
  'test_random_robustness.gd',
  'test_graybox_ui.gd',
  'test_runtime_integration.gd',
  'test_node_lab.gd'
)
foreach ($test in $core) {
  & godot.cmd --headless --path . -s ("tests/" + $test)
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
foreach ($map in @('mvp_a', 'mvp_b', 'mvp_c')) {
  & godot.cmd --headless --path . -s tests/test_full_run.gd -- ("--map=" + $map)
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: seven core test scripts and all three complete maps exit 0.

- [ ] **Step 7: Export and visually inspect**

Run:

```powershell
godot.cmd --headless --path . --export-release Web
godot.cmd --path . -s tests/capture_graybox.gd
godot.cmd --path . -s tests/capture_graybox.gd -- --mobile
```

Inspect every generated capture for clipped labels, overlapping controls, unreadable twelve-node markers, or a catalog that obscures restart/return controls. Open the exported normal URL and `?nodeLab=1` URL in the in-app browser at 1280x720 and 390x844, then verify browser error and warning logs are empty.

- [ ] **Step 8: Commit verification support and docs**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/tests/test_full_run.gd packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd packages/edugame/godot/games/ch09-env-spire/README.md
git commit -m "test: verify ch09 single route and node lab"
```
