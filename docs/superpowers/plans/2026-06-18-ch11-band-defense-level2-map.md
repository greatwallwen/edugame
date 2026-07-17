# Ch11 Band Defense Level 2 Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give level 2 its own complex route background, longer path, and expanded tower-slot layout.

**Architecture:** Add a small level layout helper that returns background path, route points, and tower slots by level. Keep level 1 layout unchanged and switch the main scene to call the helper whenever the current level changes.

**Tech Stack:** Godot 4.6 GDScript, PNG background assets, existing Web export preset.

---

### Task 1: Level Layout Helper

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/scripts/level_layouts.gd`
- Create: `packages/edugame/godot/games/ch11-band-defense/tests/test_level_layouts.gd`

- [ ] Write tests for level 1 compatibility, level 2 background, longer route, and expanded tower slots.
- [ ] Run the test and confirm it fails before the helper exists.
- [ ] Implement the helper.
- [ ] Run the test and confirm it passes.

### Task 2: Main Scene Integration

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`

- [ ] Replace hard-coded background loading with level-aware background loading.
- [ ] Replace hard-coded path/tower reset points with helper-provided layout.
- [ ] Apply layout when starting/resetting level 1 and when transitioning to level 2.

### Task 3: Asset Import And Web Export

**Files:**
- Add: `packages/edugame/assets/games/ch11-band-defense/backgrounds/band-defense-map-level2-night-run.png`
- Add: `packages/edugame/assets/games/ch11-band-defense/source-prompts/band-defense-map-level2-night-run.md`
- Modify: `apps/player/public/assets/godot/ch11-band-defense/index.html`

- [ ] Import the new PNG in Godot.
- [ ] Run tests and script checks.
- [ ] Export Web.
- [ ] Add a new cache-bust version to `index.html`.
