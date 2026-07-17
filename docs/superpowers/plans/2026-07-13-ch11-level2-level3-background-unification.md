# Ch11 Level 2 and Level 3 Background Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Level 2 and Level 3 procedural map layers with newly generated hardware-map backgrounds that match the installed Level 1 style without intruding on routes, tower pads, or ports.

**Architecture:** Keep runtime layout data authoritative. Generate one visual structure guide per level from `level_layouts.gd` coordinates, use the installed Level 1 map as the Image 2 style reference, then normalize each selected output into the existing 1280 x 720 map-layer contract. Tests compare the new assets with Level 1 and validate safe-zone clarity, layer separation, port alignment, and runtime rendering.

**Tech Stack:** Godot 4, GDScript, Python 3, Pillow, pytest, Image 2.

## Global Constraints

- Redraw Level 2 and Level 3 from a fresh composition; do not patch or blur the old assets.
- Keep the right HUD area `x=960..1279` transparent and unchanged at runtime.
- Do not bake the cyan route into either background.
- Keep all chips, interfaces, traces, vents, and seams outside route and tower safe zones.
- Keep the border sparse, flat, crisp, and consistent with Level 1.

---

### Task 1: Lock Visual Similarity and Safe-Zone Requirements

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/tests/test_level2_background_integrity.py`
- Test: `packages/edugame/godot/games/ch11-band-defense/tests/test_level2_background_integrity.py`

**Interfaces:**
- Consumes: Level 1, Level 2, and Level 3 RGBA map layers.
- Produces: regression assertions for luma, edge detail, palette distance, border density, safe-zone darkness, and safe-zone edge density.

- [ ] Add a failing test that compares Level 2 and Level 3 board luma and edge density directly against Level 1.
- [ ] Add a failing test that rejects excessive dark components and high edge density in route and tower masks.
- [ ] Run `python -m pytest packages/edugame/godot/games/ch11-band-defense/tests/test_level2_background_integrity.py -q` and confirm the current procedural maps fail the new Level 1 similarity assertions.

### Task 2: Build Structural Reference Guides

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/scripts/generate_level_background_guides.py`
- Create: `packages/edugame/godot/games/ch11-band-defense/visual-audit/level2-background-layout-guide.png`
- Create: `packages/edugame/godot/games/ch11-band-defense/visual-audit/level3-background-layout-guide.png`

**Interfaces:**
- Consumes: exact route points and tower-slot centers from `scripts/level_layouts.gd`.
- Produces: two 1280 x 720 guides with labeled map boundary, path clearance, tower clearance, and port alignment regions.

- [ ] Draw the map boundary and mark the right HUD region as forbidden.
- [ ] Draw a 48 px route safety corridor and 52 px tower-slot safety circles.
- [ ] Mark entrance and exit port centers at each runtime route endpoint.
- [ ] Run the guide generator and inspect both guides for coordinate parity with `level_layouts.gd`.

### Task 3: Generate New Level 2 and Level 3 Hardware Maps

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/assets/backgrounds/band-defense-map-level2-watch-debug-map-layer.png`
- Modify: `packages/edugame/godot/games/ch11-band-defense/assets/backgrounds/band-defense-map-level3-watch-debug-map-layer.png`

**Interfaces:**
- Consumes: Level 1 style reference and each level's structural guide.
- Produces: two fresh Image 2 hardware-map renders with clear path and tower zones.

- [ ] Generate Level 2 using Level 1 as the style reference and the Level 2 guide as the layout reference.
- [ ] Inspect the output for sparse borders, coherent hardware scale, clean safety zones, and absent text/HUD content.
- [ ] Generate Level 3 using Level 1 as the style reference and the Level 3 guide as the layout reference.
- [ ] Inspect the output for the same constraints and keep only conforming results.

### Task 4: Normalize and Install the Map Layers

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/scripts/install_generated_level_backgrounds.py`
- Modify: `packages/edugame/godot/games/ch11-band-defense/assets/backgrounds/band-defense-map-level2-watch-debug-map-layer.png`
- Modify: `packages/edugame/godot/games/ch11-band-defense/assets/backgrounds/band-defense-map-level3-watch-debug-map-layer.png`

**Interfaces:**
- Consumes: selected Image 2 renders.
- Produces: exact-size RGBA runtime assets with transparent right HUD regions.

- [ ] Normalize each selected source to 1280 x 720 without stretching the left 960 x 720 map area.
- [ ] Clear the right HUD region to transparent pixels.
- [ ] Verify alpha coverage is at least 98 percent on the left and zero on the right.
- [ ] Install under the existing runtime filenames so no gameplay reference changes are required.

### Task 5: Verify All Three Levels and Export Web

**Files:**
- Verify: `packages/edugame/godot/games/ch11-band-defense/scripts/level_layouts.gd`
- Verify: `packages/edugame/godot/games/ch11-band-defense/scripts/audit_level1_visual_quality.py`
- Verify: `apps/player/public/assets/godot/ch11-band-defense/index.html`

**Interfaces:**
- Consumes: final runtime map layers and existing layout configuration.
- Produces: visual captures, passing tests, and a cache-busted Web export.

- [ ] Run the background integrity, route alignment, visual quality, and layout tests.
- [ ] Capture Levels 1, 2, and 3 at 1280 x 720 and inspect routes, ports, tower centers, border density, and HUD continuity.
- [ ] Re-export the Godot Web build and update the hashed PCK plus player manifest version.
- [ ] Load the final Web build and verify no game console warning or error is introduced.
