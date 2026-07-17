# Ch11 Enemy Hit Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add physical, tower-specific enemy hit feedback, visual-only death echoes, and on-demand health information without changing combat balance or route logic.

**Architecture:** Keep gameplay damage authoritative in `band_defense_root.gd`, but move deterministic effect profiles and drawing helpers into a focused `hit_feedback_fx.gd` module. Active enemies store only short-lived visual reaction values; impact events and death echoes live in capped transient arrays, following the existing attack-effect pattern.

**Tech Stack:** Godot 4.x, GDScript, custom `CanvasItem` drawing, existing tower attack bitmap atlases, headless Godot tests and Web export.

> **Approved refinement:** The current delivery direction supersedes all particle, spark, and fragment requirements below. Impact events generate zero particles; damage states and death echoes generate no debris; filter and peak signatures use clean damping arcs and a threshold pulse. Bitmap bloom renders behind the enemy body with a maximum size of `54 px` and alpha of `0.64`, while compact tower signatures render in front.

## Global Constraints

- Do not change damage values, targeting, ranges, enemy speeds, rewards, route progress, or wave completion behavior.
- Matched recoil is approximately 4 px, at most 3 degrees, with scale compression near 0.94; mismatched recoil is at most 1.5 px.
- Matched hits use 4-7 particles; mismatched hits use 2-3 faint particles.
- Cap simultaneous impact events at 24, visible particles at 64, and death echoes at 12.
- Death rewards and active-enemy removal happen immediately; visual death echoes last approximately 260 ms and are never targetable.
- Remove persistent enemy health bars. Show exact health only on hover or in diagnosis.
- Use the existing realistic attack bitmap atlases for the primary localized bloom; procedural drawing is limited to signatures, particles, and small fragments.
- Do not add normal-hit camera shake, repeated global hit-stop, large cartoon bursts, or full-radius rings.
- Clear all transient effects and hover state on reset, level change, and return to menu.
- Preserve the bright smartwatch engineering/debug direction and keep the gameplay field readable.

---

### Task 1: Deterministic Hit Feedback Profiles

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/scripts/hit_feedback_fx.gd`
- Create: `packages/edugame/godot/games/ch11-band-defense/tests/test_enemy_hit_feedback.gd`

**Interfaces:**
- Produces: `HitFeedbackFx.reaction_profile(matched: bool) -> Dictionary`
- Produces: `HitFeedbackFx.health_state(hp: float, max_hp: float) -> String`
- Produces: `HitFeedbackFx.make_impact_event(...) -> Dictionary`
- Produces: `HitFeedbackFx.reaction_transform(enemy: Dictionary) -> Dictionary`
- Produces: `HitFeedbackFx.enforce_caps(events: Array, death_echoes: Array) -> void`

- [ ] **Step 1: Write the failing pure-logic test**

Create a headless test that asserts matched feedback has stronger recoil and more particles than mismatched feedback, reaction transforms never mutate `progress`, health thresholds are `stable`, `damaged`, and `critical`, and caps keep `24/64/12` limits.

```gdscript
extends SceneTree

const HitFeedbackFx = preload("res://scripts/hit_feedback_fx.gd")

func _init() -> void:
    var matched := HitFeedbackFx.reaction_profile(true)
    var mismatch := HitFeedbackFx.reaction_profile(false)
    assert(float(matched.recoil_px) > float(mismatch.recoil_px))
    assert(int(matched.particle_count) >= 4)
    assert(int(mismatch.particle_count) <= 3)
    assert(HitFeedbackFx.health_state(70.0, 100.0) == "stable")
    assert(HitFeedbackFx.health_state(40.0, 100.0) == "damaged")
    assert(HitFeedbackFx.health_state(20.0, 100.0) == "critical")
    quit(0)
```

- [ ] **Step 2: Run the new test and confirm it fails**

Run from `packages/edugame/godot/games/ch11-band-defense`:

```powershell
godot --headless --path . -s tests/test_enemy_hit_feedback.gd
```

Expected: load failure because `res://scripts/hit_feedback_fx.gd` does not exist.

- [ ] **Step 3: Implement the pure helper**

Use deterministic `RandomNumberGenerator` seeds and return data-only dictionaries. Keep event TTL at `0.26`, use normalized attack direction, and store particles as `offset`, `velocity`, `size`, and `life` values. `reaction_transform` must return visual `offset`, `angle`, and `scale` without writing to the enemy.

```gdscript
extends RefCounted

const IMPACT_DURATION := 0.26
const DEATH_DURATION := 0.26
const MAX_IMPACTS := 24
const MAX_PARTICLES := 64
const MAX_DEATHS := 12

static func reaction_profile(matched: bool) -> Dictionary:
    return {
        "recoil_px": 4.0 if matched else 1.35,
        "tilt_rad": deg_to_rad(3.0 if matched else 0.8),
        "compression": 0.94 if matched else 0.985,
        "particle_count": 6 if matched else 2,
    }

static func health_state(hp: float, max_hp: float) -> String:
    var ratio := hp / maxf(max_hp, 1.0)
    if ratio < 0.25:
        return "critical"
    if ratio <= 0.60:
        return "damaged"
    return "stable"
```

- [ ] **Step 4: Run the pure helper test**

Run the command from Step 2. Expected: exit code `0` with every assertion passing.

---

### Task 2: Combat Lifecycle And Death Echoes

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Modify: `packages/edugame/godot/games/ch11-band-defense/tests/test_enemy_hit_feedback.gd`

**Interfaces:**
- Consumes: all Task 1 `HitFeedbackFx` interfaces.
- Produces: `_add_enemy_hit_effect(...)`, `_update_enemy_hit_feedback(delta)`, `_clear_enemy_hit_feedback()`, and visual-only `death_echoes` state.

- [ ] **Step 1: Extend tests for lifecycle behavior**

Instantiate the game root, create one enemy, resolve a lethal hit, and assert reward changes immediately, the enemy leaves `enemies`, and one entry appears in `death_echoes`. Call `_reset()` and assert `hit_effects`, `death_echoes`, and hover state are empty.

- [ ] **Step 2: Run the test and confirm missing state/functions fail**

```powershell
godot --headless --path . -s tests/test_enemy_hit_feedback.gd
```

Expected: assertion or method failure for the new transient lifecycle.

- [ ] **Step 3: Integrate hit events without changing damage authority**

Preload `HitFeedbackFx`, add capped `hit_effects` and `death_echoes` arrays, and give spawned enemies `hitReactionTtl`, `hitReactionDuration`, and `hitDirection`. In `_fire_tower`, apply damage first, then populate visual reaction values and append an impact event using the tower-to-enemy direction.

```gdscript
var direction := (Vector2(target.pos) - Vector2(slot.pos)).normalized()
target.hp = float(target.hp) - float(resolution.damage)
target.hitReactionTtl = HitFeedbackFx.IMPACT_DURATION
target.hitReactionDuration = HitFeedbackFx.IMPACT_DURATION
target.hitDirection = direction
_add_enemy_hit_effect(target, tower, resolution, direction)
```

- [ ] **Step 4: Create non-targetable death echoes during cleanup**

Before erasing a dead enemy, duplicate only the values needed to draw its final frame and append a `0.26` second echo. Award energy/trusted data and remove the active enemy in the same cleanup pass as before. Update and expire visual events only while gameplay time advances.

- [ ] **Step 5: Centralize reset cleanup**

Implement `_clear_enemy_hit_feedback()` and call it at every existing `attack_effects.clear()` reset/menu/level boundary. Also clear the hover target and alpha there.

- [ ] **Step 6: Run lifecycle and existing combat tests**

```powershell
godot --headless --path . -s tests/test_enemy_hit_feedback.gd
godot --headless --path . -s tests/test_tower_attack_identities.gd
godot --headless --path . -s tests/test_full_run_balance.gd
```

Expected: all commands exit `0`; balance totals and tower behavior remain unchanged.

---

### Task 3: Physical Rendering And Tower Signatures

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/hit_feedback_fx.gd`
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Create: `packages/edugame/godot/games/ch11-band-defense/tests/capture_enemy_hit_feedback.gd`

**Interfaces:**
- Consumes: `hit_effects`, `death_echoes`, and `attack_effect_textures`.
- Produces: `HitFeedbackFx.draw_impact(...)`, `draw_death_echo(...)`, and health-state sprite modulation.

- [ ] **Step 1: Add a deterministic capture scene script**

Build a capture with one matched hit, one mismatched hit, all four tower IDs, damaged/critical enemies, and a lethal echo. Save the viewport image to `visual-audit/enemy-hit-feedback.png` after effects reach their peak frame.

- [ ] **Step 2: Render enemy bodies with visual-only transforms**

Draw the aura and route position normally, then apply `draw_set_transform(visual_pos + offset, angle, scale)` only around the body sprite. Reset transform immediately with `draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)`. Add a small soft shadow that shifts less than the body.

- [ ] **Step 3: Replace the full hit ring with localized bitmap bloom**

Stop calling `SymptomFx.draw_hit_pulse`. Reuse each tower's existing attack-range bitmap atlas at a compact `40-74 px` target size, rotated to attack direction and faded by event progress. Do not draw a complete circular outline.

- [ ] **Step 4: Draw the four signatures**

Draw I2C cyan brackets contracting toward the core, filter teal particles moving inward, peak amber-white core plus a narrow spark cone, and low-power paired clamp arcs plus a brief core blackout. Mismatched events use weak red-orange color and suppress the strong tower signature.

- [ ] **Step 5: Draw health states and death echoes**

Use stable normal modulation, damaged intermittent core flicker/local fault sparks, and critical amber instability. Draw death echoes from duplicated visual data with compression, dimming, and a few fragments; never put them back in `enemies`.

- [ ] **Step 6: Capture and inspect the rendered result**

```powershell
godot --headless --path . -s tests/capture_enemy_hit_feedback.gd
```

Expected: `visual-audit/enemy-hit-feedback.png` exists; effects remain localized, distinct, and free of flat full rings.

---

### Task 4: Hover-Only And Diagnosis Health

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Modify: `packages/edugame/godot/games/ch11-band-defense/tests/test_enemy_hit_feedback.gd`
- Modify: `packages/edugame/godot/games/ch11-band-defense/tests/test_diagnostic_chain.gd`

**Interfaces:**
- Produces: `_enemy_health_readout(enemy) -> String`, `_find_hovered_enemy(mouse_pos) -> Dictionary`, and `_draw_hover_health_chip()`.

- [ ] **Step 1: Add health visibility tests**

Assert the persistent health-bar draw path is absent, hover picks the closest live enemy with greatest progress as tie-breaker, the chip rectangle is clamped before the HUD, and diagnosis output includes exact health and percentage.

- [ ] **Step 2: Run tests and confirm current behavior fails**

```powershell
godot --headless --path . -s tests/test_enemy_hit_feedback.gd
godot --headless --path . -s tests/test_diagnostic_chain.gd
```

Expected: failure because persistent bars remain and diagnosis omits exact health.

- [ ] **Step 3: Implement mouse hover selection and fading**

Handle `InputEventMouseMotion` before mouse-button input. Search live enemies within `36 px`, choose the smallest pointer distance, then greatest route progress. Fade a single chip in quickly and out within approximately `0.12` seconds without pausing or selecting.

- [ ] **Step 4: Remove persistent health bars and draw one glass chip**

Delete the unconditional `52 x 5` bar draw from `_draw_enemies`. Format exact health as `生命 68 / 120 · 57%`, measure the text, add sufficient padding, and clamp the chip inside the map with its right edge at least `12 px` before `HUD_PANEL_RECT.position.x`.

- [ ] **Step 5: Add exact health to diagnosis**

Prepend `_enemy_health_readout(enemy)` to `_diagnostic_report_for_method` so touch users retain exact health access using existing right-HUD typography.

- [ ] **Step 6: Run health and UI regressions**

```powershell
godot --headless --path . -s tests/test_enemy_hit_feedback.gd
godot --headless --path . -s tests/test_diagnostic_chain.gd
godot --headless --path . -s tests/test_platform_ui_theme.gd
```

Expected: all commands exit `0`.

---

### Task 5: Density QA, Full Regression, And Web Delivery

**Files:**
- Modify if required by QA: `packages/edugame/godot/games/ch11-band-defense/scripts/hit_feedback_fx.gd`
- Modify if required by QA: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Regenerate: `packages/edugame/godot/games/ch11-band-defense/visual-audit/enemy-hit-feedback.png`
- Regenerate: `packages/edugame/godot/games/ch11-band-defense/export/web/*`

**Interfaces:**
- Consumes: completed effect, health, and reset behavior.
- Produces: tested Web build available from the existing local server.

- [ ] **Step 1: Run the focused and complete regression suite**

```powershell
godot --headless --path . -s tests/test_enemy_hit_feedback.gd
godot --headless --path . -s tests/test_tower_attack_identities.gd
godot --headless --path . -s tests/test_diagnostic_chain.gd
godot --headless --path . -s tests/test_platform_ui_theme.gd
godot --headless --path . -s tests/test_full_run_balance.gd
```

Expected: all five commands exit `0` without parser errors or leaked nodes.

- [ ] **Step 2: Stress visual caps**

Create more than 24 simultaneous effects through the focused test and assert `hit_effects.size() <= 24`, summed particles `<= 64`, and `death_echoes.size() <= 12`. Confirm mismatched/oldest events are discarded before strong matched or death feedback.

- [ ] **Step 3: Inspect captures at gameplay scale**

Open `visual-audit/enemy-hit-feedback.png` and verify matched/mismatched readability, all four signatures, medium/critical states, one hover chip over overlapping enemies, level 2/3 simultaneous attacks, and final death frame. Adjust only localized opacity, scale, or timing if paths or tower pads are obscured.

- [ ] **Step 4: Export the Web build**

```powershell
godot --headless --path . --export-release Web
```

Expected: export completes and updates the configured Web output without errors.

- [ ] **Step 5: Verify the local preview endpoint**

```powershell
curl.exe -I http://127.0.0.1:8000/index.pck
```

Expected: HTTP `200` and a nonzero `Content-Length`.

The repository currently has no commit history and no configured Git identity, so this plan intentionally omits commit steps; do not change user-level Git configuration as part of the feature.
