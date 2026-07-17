# Ch11 Tower Attack Identities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each tower attack feel distinct while reinforcing Chapter 11 concepts.

**Architecture:** Keep the existing single-scene Godot structure, but isolate attack math behind small helper methods on `band_defense_root.gd`. Towers declare an `attackStyle` and concept text in `tower_defs`; `_fire_tower()` computes match multiplier, then applies tower-specific effects to enemy dictionaries and game energy.

**Tech Stack:** Godot 4.6 GDScript, existing `SceneTree` test scripts, existing JSON wave/question data.

---

### Task 1: Attack Mechanic Tests

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/tests/test_tower_attack_identities.gd`
- Modify: none

- [ ] **Step 1: Write the failing test**

Create a `SceneTree` test that loads `res://scenes/main.tscn`, instantiates the game, and calls the intended helper methods:

```gdscript
extends SceneTree

var failures := 0

func _init() -> void:
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	_test_i2c_calibration_marks_and_boosts(game)
	_test_filter_slows_noise(game)
	_test_peak_burst_marks_threshold_capture(game)
	_test_power_stuns_and_refunds_energy(game)
	game.queue_free()
	if failures > 0:
		quit(1)
	else:
		print("tower attack identity tests passed")
		quit(0)

func _test_i2c_calibration_marks_and_boosts(game) -> void:
	var enemy := {"type": "config", "threatTag": "config", "hp": 100.0, "pos": Vector2.ZERO}
	var report := game._resolve_tower_attack("i2c", 1, enemy)
	_assert(bool(enemy.get("calibrated", false)), "I2C should mark config enemies as calibrated")
	_assert(str(report.get("concept", "")).contains("校准"), "I2C feedback should mention calibration")
	var boosted := game._resolve_tower_attack("i2c", 1, enemy)
	_assert(float(boosted.get("damage", 0.0)) > float(report.get("damage", 0.0)), "I2C should boost follow-up damage on calibrated enemies")

func _test_filter_slows_noise(game) -> void:
	var enemy := {"type": "noise", "threatTag": "noise", "hp": 100.0, "pos": Vector2.ZERO}
	var report := game._resolve_tower_attack("filter", 1, enemy)
	_assert(float(enemy.get("slowTimer", 0.0)) > 0.0, "Filter should add slow timer")
	_assert(float(enemy.get("slowMultiplier", 1.0)) < 1.0, "Filter should reduce speed multiplier")
	_assert(str(report.get("concept", "")).contains("滤波"), "Filter feedback should mention filtering")

func _test_peak_burst_marks_threshold_capture(game) -> void:
	var enemy := {"type": "false_peak", "threatTag": "false_peak", "hp": 100.0, "pos": Vector2.ZERO}
	var report := game._resolve_tower_attack("peak", 1, enemy)
	_assert(float(report.get("damage", 0.0)) >= 100.0, "Peak should deliver a burst against false peaks")
	_assert(str(enemy.get("captureTag", "")) == "threshold", "Peak should mark threshold capture")
	_assert(str(report.get("concept", "")).contains("峰值"), "Peak feedback should mention peak capture")

func _test_power_stuns_and_refunds_energy(game) -> void:
	game.energy = 100
	var enemy := {"type": "power_spike", "threatTag": "power", "hp": 100.0, "pos": Vector2.ZERO}
	var report := game._resolve_tower_attack("power", 1, enemy)
	_assert(float(enemy.get("stunTimer", 0.0)) > 0.0, "Power should stun power spikes")
	_assert(int(game.energy) > 100, "Power should refund energy on matched power faults")
	_assert(str(report.get("concept", "")).contains("低功耗"), "Power feedback should mention low power")

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'C:\Users\sy\bin\godot.cmd' --headless --path 'C:\Users\sy\Desktop\dgbook-ref-main\dgbook-ref\packages\edugame\godot\games\ch11-band-defense' --script 'res://tests/test_tower_attack_identities.gd'
```

Expected: FAIL because `_resolve_tower_attack` does not exist yet.

### Task 2: Attack Helper Implementation

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Test: `packages/edugame/godot/games/ch11-band-defense/tests/test_tower_attack_identities.gd`

- [ ] **Step 1: Add tower metadata**

Add `attackStyle` and concept feedback strings to each tower definition:

```gdscript
"attackStyle": "calibrate",
"conceptText": "I2C 校准"
```

- [ ] **Step 2: Add `_resolve_tower_attack`**

Implement a helper returning `{damage, matched, concept, color}`. It should apply existing match multipliers, then add tower-specific state changes: I2C calibration follow-up boost, filter slow, peak burst capture, power stun and small energy refund.

- [ ] **Step 3: Route `_fire_tower` through the helper**

Replace direct damage math in `_fire_tower()` with `_resolve_tower_attack(...)`, then keep existing cooldown, hit pulse, wave stats, and feedback behavior.

- [ ] **Step 4: Run test to verify it passes**

Run the same `test_tower_attack_identities.gd` command.

Expected: PASS.

### Task 3: Movement Status Integration

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Test: `packages/edugame/godot/games/ch11-band-defense/tests/test_full_run_balance.gd`

- [ ] **Step 1: Apply slow and stun in movement**

Update `_update_enemies(delta)` so enemies with `stunTimer` pause briefly and enemies with `slowTimer` move at `speed * slowMultiplier`. Timers tick down each frame.

- [ ] **Step 2: Run balance test**

Run:

```powershell
& 'C:\Users\sy\bin\godot.cmd' --headless --path 'C:\Users\sy\Desktop\dgbook-ref-main\dgbook-ref\packages\edugame\godot\games\ch11-band-defense' --script 'res://tests/test_full_run_balance.gd'
```

Expected: PASS and reaches result state.

### Task 4: Final Verification and Web Export

**Files:**
- Modify only if export output changes: `apps/player/public/assets/godot/ch11-band-defense/*`

- [ ] **Step 1: Run script check**

```powershell
& 'C:\Users\sy\bin\godot.cmd' --headless --path 'C:\Users\sy\Desktop\dgbook-ref-main\dgbook-ref\packages\edugame\godot\games\ch11-band-defense' --check-only --script 'res://scripts/band_defense_root.gd'
```

- [ ] **Step 2: Run focused tests**

```powershell
& 'C:\Users\sy\bin\godot.cmd' --headless --path 'C:\Users\sy\Desktop\dgbook-ref-main\dgbook-ref\packages\edugame\godot\games\ch11-band-defense' --script 'res://tests/test_tower_attack_identities.gd'
& 'C:\Users\sy\bin\godot.cmd' --headless --path 'C:\Users\sy\Desktop\dgbook-ref-main\dgbook-ref\packages\edugame\godot\games\ch11-band-defense' --script 'res://tests/test_full_run_balance.gd'
```

- [ ] **Step 3: Export Web**

```powershell
& 'C:\Users\sy\bin\godot.cmd' --headless --path 'C:\Users\sy\Desktop\dgbook-ref-main\dgbook-ref\packages\edugame\godot\games\ch11-band-defense' --export-release Web
```

Expected: Export exits 0 and the exported PCK is reachable from the local player server.
