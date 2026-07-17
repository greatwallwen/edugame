# Ch11 Band Defense Level 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the second playable level, "手环夜跑数据异常", in the existing Godot tower-defense MVP.

**Architecture:** Keep the current single-scene Godot MVP, but extract wave-entry behavior into a small tested helper so old string spawn queues and new dictionary spawn entries both work. Add level 2 as data-driven waves, then connect wave briefs, hybrid enemy switching, and level-aware diagnostics without adding new tower types or a full level-select screen.

**Tech Stack:** Godot 4.6 GDScript, JSON wave/question data, existing Web export pipeline.

---

### Task 1: Wave Director Helper

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/scripts/wave_level_director.gd`
- Create: `packages/edugame/godot/games/ch11-band-defense/tests/test_wave_level_director.gd`

- [ ] Write failing tests for old-format queue expansion, new-format hybrid entries, brief lookup, focus type lookup, and switch selection by path progress.
- [ ] Run the new Godot test and confirm it fails because the helper script does not exist.
- [ ] Implement the helper with static functions only.
- [ ] Run the helper test and existing diagnostics test.

### Task 2: Level 2 Data

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/data/waves.sample.json`
- Modify: `packages/edugame/godot/games/ch11-band-defense/data/questions.sample.json`

- [ ] Add three level-2 wave entries using `level`, `brief`, `focusType`, and optional `switches`.
- [ ] Add diagnosis-oriented level-2 questions.
- [ ] Validate both JSON files parse.

### Task 3: Main Scene Integration

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`

- [ ] Load `WaveLevelDirector`.
- [ ] Add `current_level`, level-aware wave totals, wave brief status text, and level completion transition.
- [ ] Spawn enemies from string or dictionary entries.
- [ ] Apply hybrid enemy type switches during movement.
- [ ] Keep old level-1 waves compatible.

### Task 4: Verification

**Files:**
- No new files expected.

- [ ] Run `test_wave_level_director.gd`.
- [ ] Run `test_wave_diagnostics.gd`.
- [ ] Run Godot `--check-only` on `band_defense_root.gd`.
- [ ] Run JSON parse verification.
- [ ] If the local web export is still used, export Web and verify in browser.
