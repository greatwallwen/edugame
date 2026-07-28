# Ch09 Interactive Tutorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-run, strongly guided practice encounter that teaches Ch09 combat operations and then starts an untouched formal 12-node run.

**Architecture:** Keep the current thin scene and single root controller. Add a versioned tutorial entry decision, a dedicated tutorial view and coach layer, and an explicit tutorial-step enum inside `env_spire_root.gd`; reuse the real card-effect and encounter rendering paths with deterministic tutorial fixtures. Persist only tutorial completion in `user://`, and begin the shared runtime attempt only after tutorial completion or skip.

**Tech Stack:** Godot 4, GDScript, programmatic Control UI, local JSON card data, `dgbook_runtime`, SceneTree tests, Godot Web export.

## Global Constraints

- Preserve the Ch11/Ch12-aligned thin `main.tscn`, single root controller, local JSON, shared runtime, and SceneTree test structure.
- The tutorial appears automatically only when the current tutorial version is incomplete.
- Node Lab bypasses the tutorial; `--tutorial` and `?tutorial=1` force it for QA.
- The tutorial is a deterministic isolated fixture and must not mutate formal deck, stability, budget, route, score, reports, or runtime completion.
- Only the target control is actionable at each tutorial step; skip remains available throughout.
- Desktop reference viewport is exactly `1280 x 720`; mobile reference viewport is exactly `390 x 844`.
- Formal route order, card rules, reward balance, Node Lab behavior, and runtime result contracts remain unchanged.

## File Map

- Modify `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`
  - Own first-run selection, persistence, tutorial state, tutorial UI, scripted fixture, step gating, and transition to the formal run.
- Create `packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd`
  - Exercise real first-run decisions, step progression, invalid actions, combat effects, skip, completion, and clean-run isolation.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
  - Assert stable tutorial node names and desktop/mobile bounds.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd`
  - Prove tutorial actions do not begin or complete a runtime attempt.
- Modify `packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd`
  - Capture briefing and all guided tutorial steps at both reference sizes.
- Modify `packages/edugame/godot/games/ch09-env-spire/README.md`
  - Document the forced tutorial launch and tutorial test command.

---

### Task 1: First-Run Selection And Completion Persistence

**Files:**
- Create: `packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd:1-250`

**Interfaces:**
- Produces: `const TUTORIAL_VERSION := 1`
- Produces: `func _select_initial_experience(node_lab_requested: bool, tutorial_forced: bool, completed_version: int) -> String`
- Produces: `func _load_tutorial_completed_version(path: String = "") -> int`
- Produces: `func _save_tutorial_completion(path: String = "") -> bool`
- Produces: `func _tutorial_forced() -> bool`
- Produces: `var tutorial_record_path := TUTORIAL_RECORD_PATH`
- Produces: `var formal_run_active := false`
- Produces: `func _start_clean_formal_run() -> void`
- Produces: `func _skip_tutorial(record_path: String = "") -> bool`
- Consumes: existing `_node_lab_requested()`, `_reset_run()`, `_enter_node_lab()`, runtime initialization callbacks.

- [ ] **Step 1: Write the failing entry-decision test**

Add a test runner that instantiates the real scene and derives expectations from
literal inputs:

```gdscript
extends SceneTree

const TEST_RECORD_PATH := "user://ch09_tutorial_test.cfg"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(TEST_RECORD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RECORD_PATH))
	var game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_record_path = TEST_RECORD_PATH
	get_root().add_child(game)
	await process_frame

	_assert(
		game._select_initial_experience(false, false, 0) == "tutorial",
		"missing completion should launch the tutorial"
	)
	_assert(
		game._select_initial_experience(false, false, game.TUTORIAL_VERSION) == "run",
		"matching completion should launch the formal run"
	)
	_assert(
		game._select_initial_experience(true, true, 0) == "node_lab",
		"Node Lab should take priority over forced tutorial"
	)
	_assert(
		game._select_initial_experience(false, true, game.TUTORIAL_VERSION) == "tutorial",
		"forced tutorial should override completion"
	)

	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if FileAccess.file_exists(TEST_RECORD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RECORD_PATH))
	if failures == 0:
		print("Ch09 tutorial tests passed")
	quit(1 if failures > 0 else 0)
```

- [ ] **Step 2: Run the test and verify RED**

Run from `packages/edugame/godot/games/ch09-env-spire`:

```powershell
godot.cmd --headless --path . -s tests/test_tutorial.gd
```

Expected: FAIL because `_select_initial_experience` and
`TUTORIAL_VERSION` do not exist.

- [ ] **Step 3: Add the minimal selection and persistence implementation**

Add constants and pure selection logic:

```gdscript
const TUTORIAL_VERSION := 1
const TUTORIAL_RECORD_PATH := "user://ch09_tutorial.cfg"

var tutorial_record_path := TUTORIAL_RECORD_PATH
var formal_run_active := false


func _select_initial_experience(
	node_lab_requested: bool,
	tutorial_forced: bool,
	completed_version: int
) -> String:
	if node_lab_requested:
		return "node_lab"
	if tutorial_forced or completed_version != TUTORIAL_VERSION:
		return "tutorial"
	return "run"


func _resolve_tutorial_record_path(path: String) -> String:
	return tutorial_record_path if path.is_empty() else path


func _load_tutorial_completed_version(path: String = "") -> int:
	path = _resolve_tutorial_record_path(path)
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return 0
	if !bool(config.get_value("tutorial", "completed", false)):
		return 0
	return int(config.get_value("tutorial", "version", 0))


func _save_tutorial_completion(path: String = "") -> bool:
	path = _resolve_tutorial_record_path(path)
	var config := ConfigFile.new()
	config.set_value("tutorial", "version", TUTORIAL_VERSION)
	config.set_value("tutorial", "completed", true)
	var result := config.save(path)
	if result != OK:
		push_warning("Could not persist Ch09 tutorial completion.")
	return result == OK
```

Implement `_tutorial_forced()` with the existing command-line and
`JavaScriptBridge` patterns:

```gdscript
func _tutorial_forced() -> bool:
	if OS.get_cmdline_user_args().has("--tutorial"):
		return true
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('tutorial')",
			true
		)
		return str(value) == "1"
	return false
```

Route initial startup through one helper so runtime session initialization and
standalone preview cannot both start an experience:

```gdscript
var initial_experience_started := false


func _start_initial_experience() -> void:
	if initial_experience_started:
		return
	initial_experience_started = true
	var mode := _select_initial_experience(
		_node_lab_requested(),
		_tutorial_forced(),
		_load_tutorial_completed_version()
	)
	match mode:
		"node_lab":
			_enter_node_lab()
		"tutorial":
			_start_tutorial_briefing()
		_:
			_reset_run()
	_render_state()
```

At this task, add `tutorial_active := false` and implement the minimal
`_start_tutorial_briefing()` below; Task 2 adds the complete briefing view:

```gdscript
func _start_tutorial_briefing() -> void:
	formal_run_active = false
	tutorial_active = true
	state = RunState.WAITING
```

Set `formal_run_active = true` at the start of `_reset_run()`. Set it to
`false` in `_enter_node_lab()` and `_start_tutorial_briefing()`. This is a
production guard used by `_finish_run()` and an observable runtime-isolation
contract for Task 4.

- [ ] **Step 4: Extend the test for a real completion record**

Append before freeing the game:

```gdscript
_assert(
	game._load_tutorial_completed_version(TEST_RECORD_PATH) == 0,
	"missing record should read as incomplete"
)
_assert(
	game._save_tutorial_completion(TEST_RECORD_PATH),
	"completion record should be writable"
)
_assert(
	game._load_tutorial_completed_version(TEST_RECORD_PATH) == game.TUTORIAL_VERSION,
	"saved record should contain the current completed version"
)
```

Add a real skip transition assertion:

```gdscript
game._start_tutorial_briefing()
game.stability = 9
game.budget = 99
game.current_layer = 4
_assert(game._skip_tutorial(TEST_RECORD_PATH), "skip should persist completion")
_assert(!game.tutorial_active, "skip should leave tutorial mode")
_assert(game.formal_run_active, "skip should activate a formal attempt")
_assert(game.state == game.RunState.MAP, "skip should open the formal map")
_assert(game.current_layer == 0, "skip should reset formal route progress")
_assert(game.stability == game.max_stability and game.budget == 30, "skip should restore formal resources")
```

Implement the shared transition and skip:

```gdscript
func _start_clean_formal_run() -> void:
	tutorial_active = false
	_reset_run()
	_render_state()


func _skip_tutorial(record_path: String = "") -> bool:
	var persisted := _save_tutorial_completion(record_path)
	_start_clean_formal_run()
	return persisted
```

- [ ] **Step 5: Run entry and existing startup tests**

```powershell
godot.cmd --headless --path . -s tests/test_tutorial.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
godot.cmd --headless --path . -s tests/test_node_lab.gd
```

Expected: all PASS. The runtime and Node Lab tests prove the new initial
selection has not changed their explicit entry behavior.

- [ ] **Step 6: Commit**

```powershell
git add packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd
git commit -m "feat: route ch09 first run through tutorial"
```

---

### Task 2: Tutorial Briefing And Coach UI

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd:90-890`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd`

**Interfaces:**
- Produces: `enum TutorialStep { INACTIVE, BRIEFING, READ_INTENT, PLAY_DEFENSE, END_TURN, PLAY_SAMPLE, PLAY_CONVERT, PLAY_OUTPUT, COMPLETE }`
- Produces: `func _build_tutorial_view() -> void`
- Produces: `func _start_tutorial_briefing() -> void`
- Produces: `func _render_tutorial() -> void`
- Produces stable nodes: `TutorialView`, `TutorialRouteSummary`,
  `TutorialStartButton`, `TutorialCoachLayer`, `TutorialCoachText`,
  `TutorialSkipButton`, `TutorialIntentButton`.
- Consumes: shared `ui_theme`, `_scene_panel()`, `_skin_button()`,
  `SceneStage`, `RunHud`, and `RunFooter`.

- [ ] **Step 1: Add failing UI contract assertions**

In `test_graybox_ui.gd`, collect the tutorial nodes:

```gdscript
var tutorial_view = game.find_child("TutorialView", true, false)
var tutorial_route = game.find_child("TutorialRouteSummary", true, false)
var tutorial_start = game.find_child("TutorialStartButton", true, false)
var tutorial_coach = game.find_child("TutorialCoachLayer", true, false)
var tutorial_text = game.find_child("TutorialCoachText", true, false)
var tutorial_skip = game.find_child("TutorialSkipButton", true, false)
var tutorial_intent = game.find_child("TutorialIntentButton", true, false)
```

Add behavior and bound checks after the viewport rectangle is created:

```gdscript
_assert(tutorial_view != null, "tutorial should expose a dedicated scene view")
_assert(tutorial_route != null, "tutorial briefing should explain the route")
_assert(tutorial_start != null, "tutorial briefing should expose its start command")
_assert(tutorial_coach != null and tutorial_text != null, "tutorial should expose coach guidance")
_assert(tutorial_skip != null, "tutorial skip should remain available")
_assert(tutorial_intent != null, "tutorial intent should be an actionable target")

game._start_tutorial_briefing()
game._render_state()
await process_frame
_assert(tutorial_view.visible, "tutorial briefing should be visible when active")
_assert(viewport_rect.encloses(tutorial_start.get_global_rect()), "tutorial start should fit the viewport")
_assert(viewport_rect.encloses(tutorial_skip.get_global_rect()), "tutorial skip should fit the viewport")
_assert(tutorial_start.custom_minimum_size.y >= 44.0, "tutorial start should be a touch target")
```

- [ ] **Step 2: Run gray-box UI and verify RED**

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: FAIL because the named tutorial nodes do not exist.

- [ ] **Step 3: Build the tutorial view with stable nodes**

Add the enum, node references, and `tutorial_step`. Build a tutorial scene panel
under `SceneStage` after the existing state views:

```gdscript
enum TutorialStep {
	INACTIVE,
	BRIEFING,
	READ_INTENT,
	PLAY_DEFENSE,
	END_TURN,
	PLAY_SAMPLE,
	PLAY_CONVERT,
	PLAY_OUTPUT,
	COMPLETE
}

var tutorial_step := TutorialStep.INACTIVE
var tutorial_active := false
var tutorial_view: PanelContainer
var tutorial_route_summary: Label
var tutorial_start_button: Button
var tutorial_coach_layer: PanelContainer
var tutorial_coach_text: Label
var tutorial_skip_button: Button
var tutorial_intent_button: Button
```

`_build_tutorial_view()` must:

- Use the existing cool-white scene panel and shared theme.
- Render a concise route summary with explicit node 11 and 12 labels.
- Create `TutorialStartButton` as disabled; Task 3 connects and enables it
  when `_start_tutorial_encounter()` exists.
- Keep `TutorialSkipButton` visible and connect it to `_skip_tutorial()`.
- Add a coach strip with no layout-changing focus animation.
- Add `TutorialIntentButton` as the accessible intent target used during combat.

Call `_build_tutorial_view()` from `_build_ui()` and update `_render_state()` so
the briefing view is visible only while the tutorial is in `BRIEFING`.

At the end of this task, keep `TutorialStartButton` disabled with the tooltip
`训练场景将在战斗引导就绪后启用`. Task 3 connects and enables it in the same
commit that creates `_start_tutorial_encounter()`. `TutorialSkipButton` is
active because Task 1 already provides `_skip_tutorial()`.

- [ ] **Step 4: Render the briefing and coach copy**

Implement:

```gdscript
func _start_tutorial_briefing() -> void:
	tutorial_active = true
	tutorial_step = TutorialStep.BRIEFING
	state = RunState.WAITING


func _render_tutorial() -> void:
	tutorial_view.visible = tutorial_active and tutorial_step == TutorialStep.BRIEFING
	tutorial_coach_layer.visible = tutorial_active and tutorial_step != TutorialStep.BRIEFING
	tutorial_skip_button.visible = tutorial_active
```

The route copy must include:

```text
12 节点单线调试
故障与检查点：验证工程证据
事件、组件、商店与休整：调整卡组
节点 11：Boss 前整备
节点 12：三阶段综合验收
```

- [ ] **Step 5: Run tutorial and gray-box tests**

```powershell
godot.cmd --headless --path . -s tests/test_tutorial.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: PASS at both desktop and mobile viewport loops.

- [ ] **Step 6: Commit**

```powershell
git add packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd
git commit -m "feat: add ch09 tutorial briefing and coach"
```

---

### Task 3: Strongly Guided Practice Encounter

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd:990-2005`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd`

**Interfaces:**
- Produces: `func _start_tutorial_encounter() -> void`
- Produces: `func confirm_tutorial_intent() -> bool`
- Produces: `func _tutorial_expected_card_id() -> String`
- Produces: `func _tutorial_card_allowed(card_id: String) -> bool`
- Produces: `func _advance_tutorial_after_card(card_id: String) -> void`
- Produces: `func _tutorial_end_turn_allowed() -> bool`
- Consumes: existing `_card_copy()`, `play_card()`, `_apply_card_effect()`,
  `_take_damage()`, `_reset_combat_resources()`, `_render_state()`, and
  encounter UI.

- [ ] **Step 1: Write the failing scripted-progression test**

Append a helper that enters the practice encounter:

```gdscript
func _enter_practice(game) -> void:
	game._start_tutorial_briefing()
	game._start_tutorial_encounter()
```

Add assertions:

```gdscript
_enter_practice(game)
_assert(
	game.tutorial_step == game.TutorialStep.READ_INTENT,
	"practice should begin by reading intent"
)
_assert(!game.play_card(0), "cards should be locked before intent confirmation")
_assert(!game._tutorial_end_turn_allowed(), "end turn should be locked before defense")
_assert(game.confirm_tutorial_intent(), "intent target should advance the tutorial")
_assert(
	game.tutorial_step == game.TutorialStep.PLAY_DEFENSE,
	"confirmed intent should unlock defense"
)
_assert(
	str((game.hand[0] as Dictionary).get("id", "")) == "sliding_average",
	"first scripted hand should contain sliding average"
)
_assert(game.play_card(0), "required defense card should be playable")
_assert(game.block == 7, "defense card should create seven real block")
_assert(
	game.tutorial_step == game.TutorialStep.END_TURN,
	"defense should unlock end turn"
)
```

- [ ] **Step 2: Run tutorial test and verify RED**

```powershell
godot.cmd --headless --path . -s tests/test_tutorial.gd
```

Expected: FAIL because the practice encounter and gating methods do not exist.

- [ ] **Step 3: Add deterministic fixture initialization**

Use existing card IDs and a local encounter dictionary:

```gdscript
const TUTORIAL_ENCOUNTER := {
	"id": "training_signal_chain",
	"name": "训练故障：信号链中断",
	"tier": "tutorial",
	"repairTarget": 20,
	"weaknessTags": ["smoke", "adc", "alarm"],
	"evidenceGroups": [["smoke"], ["adc"]],
	"intentPattern": [
		{"type": "damage", "amount": 6, "text": "模拟漂移：稳定度 -6"}
	]
}
```

Initialize every mutable combat value explicitly:

```gdscript
func _start_tutorial_encounter() -> void:
	tutorial_active = true
	tutorial_step = TutorialStep.READ_INTENT
	state = RunState.COMBAT
	current_node = {"type": "tutorial", "contentId": "training_signal_chain"}
	current_encounter = TUTORIAL_ENCOUNTER.duplicate(true)
	current_intents = (current_encounter.get("intentPattern", []) as Array).duplicate(true)
	repair_target = 20
	repair_progress = 0
	intent_index = 0
	stability = max_stability
	_reset_combat_resources()
	turn_number = 1
	hand = [_card_copy("sliding_average")]
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	_render_state()
```

Connect `TutorialStartButton.pressed` to `_start_tutorial_encounter()` and set
`tutorial_start_button.disabled = false` after the fixture functions exist.

- [ ] **Step 4: Gate real card and end-turn methods**

At the top of `play_card()` after retrieving the card:

```gdscript
var card_id := str(card.get("id", ""))
if tutorial_active and !_tutorial_card_allowed(card_id):
	_log("请先完成当前教学操作。")
	return false
```

After a successful card resolves:

```gdscript
if tutorial_active:
	_advance_tutorial_after_card(card_id)
```

Replace the normal repair-completion branch with an explicit tutorial guard so
the output card cannot open formal rewards:

```gdscript
if repair_progress >= repair_target:
	if tutorial_active:
		pass
	elif str(current_encounter.get("tier", "")) != "checkpoint" or _checkpoint_requirements_met():
		_finish_encounter()
```

Change `end_turn()` to return `bool` while preserving existing callers:

```gdscript
func end_turn() -> bool:
	if state != RunState.COMBAT:
		return false
	if tutorial_active and !_tutorial_end_turn_allowed():
		_log("请先完成当前教学操作。")
		return false
	# Existing end-turn body.
	return true
```

During the tutorial end turn, resolve the real six-point intent, assert that
block absorbs it, then replace the hand without drawing from the formal deck:

```gdscript
if tutorial_active and tutorial_step == TutorialStep.END_TURN:
	_resolve_intent()
	_reset_turn_state(true)
	hand = [
		_card_copy("mq2_sample"),
		_card_copy("adc_convert"),
		_card_copy("led_alarm")
	]
	tutorial_step = TutorialStep.PLAY_SAMPLE
	_render_state()
	return true
```

- [ ] **Step 5: Implement exact step gating**

```gdscript
func _tutorial_expected_card_id() -> String:
	return {
		TutorialStep.PLAY_DEFENSE: "sliding_average",
		TutorialStep.PLAY_SAMPLE: "mq2_sample",
		TutorialStep.PLAY_CONVERT: "adc_convert",
		TutorialStep.PLAY_OUTPUT: "led_alarm"
	}.get(tutorial_step, "")


func _tutorial_card_allowed(card_id: String) -> bool:
	return tutorial_active and card_id == _tutorial_expected_card_id()


func confirm_tutorial_intent() -> bool:
	if !tutorial_active or tutorial_step != TutorialStep.READ_INTENT:
		return false
	tutorial_step = TutorialStep.PLAY_DEFENSE
	_render_state()
	return true
```

Advance only after the real `play_card()` call succeeds:

```gdscript
func _advance_tutorial_after_card(card_id: String) -> void:
	match tutorial_step:
		TutorialStep.PLAY_DEFENSE:
			if card_id == "sliding_average":
				tutorial_step = TutorialStep.END_TURN
		TutorialStep.PLAY_SAMPLE:
			if card_id == "mq2_sample":
				tutorial_step = TutorialStep.PLAY_CONVERT
		TutorialStep.PLAY_CONVERT:
			if card_id == "adc_convert":
				tutorial_step = TutorialStep.PLAY_OUTPUT
		TutorialStep.PLAY_OUTPUT:
			if card_id == "led_alarm":
				tutorial_step = TutorialStep.COMPLETE
	_render_state()
```

Prevent the normal reward transition when the tutorial repair target is
reached; tutorial completion shows the tutorial completion layer instead.

- [ ] **Step 6: Extend the test through the full engineering chain**

```gdscript
var stability_before: int = game.stability
_assert(game.end_turn(), "guided end turn should resolve")
_assert(game.stability == stability_before, "seven block should absorb six damage")
_assert(game.block == 0, "defense should reset when the next turn begins")
_assert(game.tutorial_step == game.TutorialStep.PLAY_SAMPLE, "turn two should begin at sampling")

_assert(!game.play_card(1), "ADC conversion should be rejected before sampling")
_assert(game.play_card(0), "MQ-2 sampling should succeed")
_assert(int(game.raw_data.get("smoke", 0)) == 1, "sampling should create raw smoke data")

_assert(game.play_card(0), "ADC conversion should succeed after sampling")
_assert(int(game.raw_data.get("smoke", 0)) == 0, "conversion should consume raw smoke")
_assert(int(game.trusted_data.get("smoke", 0)) == 1, "conversion should create trusted smoke")

_assert(game.play_card(0), "LED output should consume trusted smoke")
_assert(int(game.trusted_data.get("smoke", 0)) == 0, "output should consume trusted smoke")
_assert(game.tutorial_step == game.TutorialStep.COMPLETE, "output should complete the practice")
```

- [ ] **Step 7: Run tutorial, card-rule, and run-flow tests**

```powershell
godot.cmd --headless --path . -s tests/test_tutorial.gd
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
```

Expected: all PASS. Changing `end_turn()` to return `bool` must not change
existing formal behavior.

- [ ] **Step 8: Commit**

```powershell
git add packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd
git commit -m "feat: guide ch09 tutorial practice combat"
```

---

### Task 4: Clean Completion, Skip, And Runtime Isolation

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd:1300-2400`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd`

**Interfaces:**
- Produces: `func _complete_tutorial(record_path: String = "") -> bool`
- Consumes: `_skip_tutorial()`, `_start_clean_formal_run()`,
  `_save_tutorial_completion()`, `_reset_run()`, runtime
  `begin_attempt()`, normal map rendering.

- [ ] **Step 1: Write failing clean-run assertions**

In `test_tutorial.gd`, deliberately dirty every tutorial-facing mutable value,
then skip:

```gdscript
game.tutorial_active = true
game.tutorial_step = game.TutorialStep.PLAY_CONVERT
game.stability = 13
game.budget = 999
game.current_layer = 7
game.visited_nodes = [{"type": "tutorial"}]
game.deck = [game._card_copy("led_alarm")]
game.debug_reports = [{"encounterId": "training_signal_chain"}]

_assert(game._skip_tutorial(TEST_RECORD_PATH), "skip should enter a formal run")
_assert(!game.tutorial_active, "skip should clear tutorial activity")
_assert(game.tutorial_step == game.TutorialStep.INACTIVE, "skip should clear tutorial step")
_assert(game.state == game.RunState.MAP, "skip should enter the formal map")
_assert(game.current_layer == 0 and game.visited_nodes.is_empty(), "formal route should be untouched")
_assert(game.stability == game.max_stability, "formal stability should be restored")
_assert(game.budget == 30, "formal budget should use its normal starting value")
_assert(game.deck.size() == game.STARTER_CARD_IDS.size(), "formal deck should be rebuilt")
_assert(game.debug_reports.is_empty(), "tutorial reports should not enter the formal run")
```

Repeat with `_complete_tutorial(TEST_RECORD_PATH)` after entering a practice
fixture. Assert the same clean state.

Remove one required card definition, start the fixture, and restore the
definition after the assertion:

```gdscript
var saved_led := (game.card_defs.get("led_alarm", {}) as Dictionary).duplicate(true)
game.card_defs.erase("led_alarm")
game._start_tutorial_encounter()
_assert(
	game.state == game.RunState.MAP and game.formal_run_active,
	"missing tutorial fixture data should fall back to a formal run"
)
game.card_defs["led_alarm"] = saved_led
```

- [ ] **Step 2: Run tutorial test and verify RED**

```powershell
godot.cmd --headless --path . -s tests/test_tutorial.gd
```

Expected: FAIL because completion and skip methods do not exist.

- [ ] **Step 3: Implement one shared clean transition**

```gdscript
func _complete_tutorial(record_path: String = "") -> bool:
	var persisted := _save_tutorial_completion(record_path)
	_start_clean_formal_run()
	return persisted
```

Extend `_start_clean_formal_run()` with
`tutorial_step = TutorialStep.INACTIVE`. Connect the completion button to
`_complete_tutorial()`; the skip button already calls `_skip_tutorial()`. A
persistence failure still starts the run and returns `false`.

Add fixture validation and call it at the start of
`_start_tutorial_encounter()`:

```gdscript
func _tutorial_fixture_available() -> bool:
	for card_id in ["sliding_average", "mq2_sample", "adc_convert", "led_alarm"]:
		if !card_defs.has(card_id):
			return false
	return true
```

```gdscript
if !_tutorial_fixture_available():
	push_warning("Missing Ch09 tutorial fixture data; starting formal run.")
	_start_clean_formal_run()
	return
```

- [ ] **Step 4: Add runtime isolation assertions**

In `test_runtime_integration.gd`, keep using the real runtime bridge and its
existing `outbound_payloads` collection. Set a temporary completed tutorial
record path on the game before adding it to the tree when the test needs its
existing formal-run startup assertions:

```gdscript
const TEST_TUTORIAL_PATH := "user://ch09_runtime_tutorial_test.cfg"

var game = scene.instantiate()
game.tutorial_record_path = TEST_TUTORIAL_PATH
game._save_tutorial_completion(TEST_TUTORIAL_PATH)
get_root().add_child(game)
```

For tutorial isolation, call `_start_tutorial_briefing()`, perform tutorial
actions, and assert `formal_run_active` remains false and the bridge emits no
`DGB_GODOT_COMPLETE` payload. The break this catches is an accidental formal
attempt or completion path from tutorial entry or card resolution.

Required assertions:

```gdscript
_assert(!game.completed, "tutorial should not mark gameplay complete")
_assert(game.score == 0, "tutorial should not calculate a score")
_assert(game.current_layer == 0, "tutorial should not visit formal nodes")
_assert(int(game._run_stats().get("visitedNodes", -1)) == 0, "tutorial should not enter run stats")
_assert(!game.formal_run_active, "tutorial should not activate the formal attempt")
```

After skip, assert `formal_run_active` is true, `state == RunState.MAP`, and
the runtime still emits no completion payload until the existing explicit
`_finish_run(true)` test action. Remove `TEST_TUTORIAL_PATH` in the test's
`_finish()` cleanup.

- [ ] **Step 5: Run tutorial and runtime integration tests**

```powershell
godot.cmd --headless --path . -s tests/test_tutorial.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
```

Expected: PASS with no tutorial completion report and one formal attempt start.

- [ ] **Step 6: Run all three full routes**

```powershell
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_a
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_b
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_c
```

Expected: all PASS with 12 visited nodes and unchanged scores/stability outcomes
for their deterministic fixtures.

- [ ] **Step 7: Commit**

```powershell
git add packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_tutorial.gd packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd
git commit -m "fix: isolate ch09 tutorial from formal runs"
```

---

### Task 5: Responsive Tutorial QA, Captures, Web Export, And Documentation

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd:790-860`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/README.md`

**Interfaces:**
- Consumes: all stable tutorial nodes and methods from Tasks 1-4.
- Produces: tutorial captures `19-desktop-tutorial-*` and
  `39-mobile-tutorial-*`.
- Produces: documented `--tutorial` and `?tutorial=1` QA entry points.

- [ ] **Step 1: Add failing responsive and live-resize assertions**

In `test_graybox_ui.gd`, exercise briefing, intent, defense, end-turn, and each
turn-two card step. For each state assert:

```gdscript
_assert(viewport_rect.encloses(tutorial_coach.get_global_rect()), "coach should fit the viewport")
_assert(tutorial_coach.get_global_rect().end.y <= footer.get_global_rect().position.y, "coach should stay above the footer")
_assert(viewport_rect.encloses(tutorial_skip.get_global_rect()), "skip should remain reachable")
```

When a required card exists:

```gdscript
var required_card = game.find_child("TutorialRequiredCard", true, false)
_assert(required_card != null, "active tutorial card should expose a stable target")
_assert(viewport_rect.encloses(required_card.get_global_rect()), "required card should be fully visible")
```

During live resize, store `tutorial_step`, resize from desktop to mobile, and
assert the step is unchanged and the active target remains inside the viewport.

- [ ] **Step 2: Run gray-box UI and verify RED**

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: FAIL where coach/required-card bounds or stable target naming have not
yet been implemented.

- [ ] **Step 3: Apply compact tutorial layout without changing step state**

Extend `_apply_responsive_layout()`:

- Briefing content uses one column below `720` pixels.
- Coach text uses at most two lines on mobile.
- `TutorialSkipButton` remains in the coach strip.
- Active card buttons receive the stable name `TutorialRequiredCard`.
- The hand scroll position is deferred to the active card when the step changes.
- Focus styling uses `StyleBoxFlat` border changes and does not change minimum
  sizes or anchors.

Do not scale font size with viewport width.

- [ ] **Step 4: Extend the capture script**

Before normal-run captures, force each tutorial state and write:

```text
19-desktop-tutorial-briefing.png
20-desktop-tutorial-intent.png
21-desktop-tutorial-defense.png
22-desktop-tutorial-end-turn.png
23-desktop-tutorial-sample.png
24-desktop-tutorial-convert.png
25-desktop-tutorial-output.png
26-desktop-tutorial-complete.png
```

Use the same state sequence for mobile with these fixed names:

```text
39-mobile-tutorial-briefing.png
40-mobile-tutorial-intent.png
41-mobile-tutorial-defense.png
42-mobile-tutorial-end-turn.png
43-mobile-tutorial-sample.png
44-mobile-tutorial-convert.png
45-mobile-tutorial-output.png
46-mobile-tutorial-complete.png
```

Keep every existing capture filename unchanged.

- [ ] **Step 5: Document launch and verification commands**

Add to `README.md`:

```powershell
godot.cmd --path . -- --tutorial
godot.cmd --headless --path . -s tests/test_tutorial.gd
```

And the Web URL:

```text
http://127.0.0.1:<preview-port>/index.html?tutorial=1
```

State that normal first-run persistence uses `user://ch09_tutorial.cfg` and
that the forced entry ignores completion for QA without deleting the record.

- [ ] **Step 6: Run the complete automated suite**

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_tutorial.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_random_robustness.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
godot.cmd --headless --path . -s tests/test_node_lab.gd
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_a
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_b
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_c
```

Expected: all PASS.

- [ ] **Step 7: Export Web and capture both viewports**

```powershell
godot.cmd --headless --path . --export-release Web
godot.cmd --path . -s tests/capture_graybox.gd
godot.cmd --path . -s tests/capture_graybox.gd -- --mobile
```

Expected: export succeeds and every tutorial capture is nonblank with no
overlap, clipped action, or unreadable coach text.

- [ ] **Step 8: Verify the real Web tutorial**

Start the existing local preview helper and open:

```text
http://127.0.0.1:<preview-port>/index.html?tutorial=1
```

At `1280 x 720` and `390 x 844`, verify:

- Canvas intrinsic and client dimensions match the viewport.
- The forced URL opens the briefing even with a completion record.
- Every required target can be activated in order.
- The completion command reaches the untouched node-1 map.
- Browser error and warning logs are empty.

Also verify `?nodeLab=1` still opens Node Lab instead of the tutorial.

- [ ] **Step 9: Commit**

```powershell
git add packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd packages/edugame/godot/games/ch09-env-spire/README.md
git commit -m "test: verify ch09 interactive tutorial"
```

## Final Verification

- [ ] Run `git diff --check`.
- [ ] Run `git status --short --untracked-files=no` and confirm no tracked changes remain.
- [ ] Inspect the final commit range for unrelated files.
- [ ] Review the complete branch for Critical, Important, and Minor findings.
- [ ] Fix Critical and Important findings with a focused test-first change.
- [ ] Re-run the affected tests and the full Ch09 suite.
