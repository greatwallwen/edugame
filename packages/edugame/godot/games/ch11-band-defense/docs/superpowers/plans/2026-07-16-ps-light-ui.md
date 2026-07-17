# PS Light UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a reversible white-surface, black-text PS-inspired UI theme without changing gameplay art.

**Architecture:** A project setting selects `ps_light` or the existing `watch_debug` theme. Central style and font helpers branch on that setting, so current UI construction code and legacy texture assets remain intact.

**Tech Stack:** Godot 4.6, GDScript, headless SceneTree tests, Web export.

## Global Constraints

- Do not modify map, route, enemy, tower, or attack-effect assets.
- Default to `band_defense/ui_style="ps_light"`.
- Preserve `watch_debug` as the rollback value.
- Keep all text clipped within existing panel and button bounds.

---

### Task 1: Theme Contract

**Files:**
- Modify: `project.godot`
- Modify: `scripts/band_defense_root.gd`
- Test: `tests/test_platform_ui_theme.gd`

- [ ] Add failing assertions for `_ui_style_id()`, `_uses_ps_light_ui()`, and the `ps_light` default.
- [ ] Run `godot --headless --path . -s tests/test_platform_ui_theme.gd` and confirm the missing-method failure.
- [ ] Add the project setting and read-only theme helpers.
- [ ] Re-run the focused test and confirm it advances to the visual-style assertions.

### Task 2: Right HUD and Shared Controls

**Files:**
- Modify: `scripts/band_defense_root.gd`
- Test: `tests/test_platform_ui_theme.gd`

- [ ] Replace old texture/font expectations with assertions for white flat panels, dark Noto Sans SC text, and blue focus borders.
- [ ] Run the focused test and confirm it fails against the watch-debug styling.
- [ ] Add PS Light palette, font, panel, button, readout, and metrics-strip branches while preserving legacy branches.
- [ ] Re-run the focused test and resolve only theme-related failures.

### Task 3: Popup and Diagnostic Consistency

**Files:**
- Modify: `scripts/band_defense_root.gd`
- Test: `tests/test_diagnostic_chain.gd`
- Test: `tests/test_platform_ui_theme.gd`

- [ ] Add failing assertions for white tutorial/quiz/diagnostic surfaces and consistent Noto Sans SC typography.
- [ ] Apply the shared theme helpers to menus, knowledge/tutorial cards, quiz, diagnostics, codex, and radial build buttons.
- [ ] Run both focused suites until they pass without changing copy or layout behavior.

### Task 4: Rollback and Visual Verification

**Files:**
- Test: `tests/test_platform_ui_theme.gd`
- Verify: Web export output

- [ ] Instantiate the scene with `watch_debug` and assert legacy texture-backed styles remain available, then restore `ps_light`.
- [ ] Run all Ch11 headless tests.
- [ ] Export Web with `godot --headless --path . --export-release Web`.
- [ ] Capture the menu, tutorial, right HUD, diagnostic, and quiz states at 1280x720 and verify no overlap, clipping, or gameplay-art changes.

