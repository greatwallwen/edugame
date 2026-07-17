# CH11 Late-Level Enemies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `drift_noise` for Level 2 and complete `hybrid_fault` as a visible Level 3 composite enemy.

**Architecture:** Reuse the existing enemy definition dictionary, wave JSON, `switches`-based type transition, and PNG spritesheet renderer. Add only the missing ids, assets, and tests needed for the two late-level enemies.

**Tech Stack:** Godot 4 GDScript, JSON wave data, Python/Pillow procedural spritesheet generation, pytest asset checks.

---

### Task 1: Asset Regression Coverage

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/tests/test_enemy_animation_assets.py`

- [ ] **Step 1: Extend `ENEMY_TYPES`**

```python
ENEMY_TYPES = ("config", "noise", "false_peak", "power_spike", "drift_noise", "hybrid_fault")
```

- [ ] **Step 2: Run test to verify it fails before assets exist**

Run: `python -m pytest packages\edugame\godot\games\ch11-band-defense\tests\test_enemy_animation_assets.py -q`

Expected: fail because `enemy_anim_drift_noise.png` and `enemy_anim_hybrid_fault.png` are missing.

### Task 2: Runtime Enemy Definitions

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Modify: `packages/edugame/godot/games/ch11-band-defense/tests/test_wave_level_director.gd`

- [ ] **Step 1: Add definitions**

Add `drift_noise` with `threatTag: "noise"` and `hybrid_fault` with a default `threatTag: "config"`.

- [ ] **Step 2: Preload animation sheets**

Add `enemy_anim_drift_noise.png` and `enemy_anim_hybrid_fault.png` to `enemy_anim_sheets`.

- [ ] **Step 3: Add wave coverage assertions**

Assert Level 2 covers `drift_noise` and Level 3 covers `hybrid_fault`.

### Task 3: Wave Integration

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/data/waves.level2.json`
- Modify: `packages/edugame/godot/games/ch11-band-defense/data/waves.level3.json`

- [ ] **Step 1: Add drift to Level 2**

Put `drift_noise` into Level 2 wave 1 and one switching `drift_noise -> false_peak` entry into Level 2 wave 2.

- [ ] **Step 2: Strengthen Level 3 hybrid**

Keep Level 3 `hybrid_fault` entries and ensure their switch tables exercise at least three core enemy types.

### Task 4: Animation Assets

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/generate_enemy_animation_assets.py`
- Create: `packages/edugame/assets/games/ch11-band-defense/generated/enemy_anim_drift_noise.png`
- Create: `packages/edugame/assets/games/ch11-band-defense/generated/enemy_anim_hybrid_fault.png`

- [ ] **Step 1: Add drawers**

Add `draw_drift_noise` and `draw_hybrid_fault` to the generator and `DRAWERS`.

- [ ] **Step 2: Generate sheets**

Run: `python packages\edugame\godot\games\ch11-band-defense\scripts\generate_enemy_animation_assets.py`

Expected: six 1024x768 enemy sheets.

### Task 5: Verification

**Files:**
- Test all changed runtime and asset behavior.

- [ ] **Step 1: Run pytest**

Run: `python -m pytest packages\edugame\godot\games\ch11-band-defense\tests -q`

Expected: all Python tests pass.

- [ ] **Step 2: Run Godot tests**

Run each `test_*.gd` under `packages\edugame\godot\games\ch11-band-defense\tests`.

Expected: all Godot tests pass.
