# CH11 Learning Feedback UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add teaching-focused hit feedback, explicit tower upgrade descriptions, and an enemy codex that does not reveal counters.

**Architecture:** Keep the feature inside the existing Godot root script because the current MVP UI is built there. Add small helper methods for testable text generation, then wire those helpers into attack feedback, the circular build menu, and a side-panel codex toggle.

**Tech Stack:** Godot 4 GDScript, existing headless Godot tests.

---

### Task 1: Testable Text Helpers

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/tests/test_platform_ui_theme.gd`
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`

- [ ] Add tests for `_tower_upgrade_description`, `_attack_feedback_text`, and `_build_codex_text`.
- [ ] Verify the tests fail before implementation.
- [ ] Implement the helper methods.

### Task 2: UI Wiring

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`

- [ ] Add a codex button and collapsible label to the side panel.
- [ ] Use `_tower_upgrade_description` in the circular tower menu upgrade cost label.
- [ ] Use `_attack_feedback_text` in `_fire_tower`.
- [ ] Keep the codex text enemy-focused and omit tower names, counter tags, and damage multipliers.

### Task 3: Verification

**Files:**
- Test: `packages/edugame/godot/games/ch11-band-defense/tests/test_platform_ui_theme.gd`
- Test: all existing `test_*.gd`

- [ ] Run `godot --headless --path packages\edugame\godot\games\ch11-band-defense -s res://tests/test_platform_ui_theme.gd`.
- [ ] Run all Godot tests.
- [ ] Run Python tests.
