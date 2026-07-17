# Ch11 Band Defense Art Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a staged production-art pass for Chapter 11 Band Defense using concept-sheet quality assets without replacing the current live Godot assets.

**Architecture:** New generated artwork lands in a parallel staging directory under `packages/edugame/assets/games/ch11-band-defense/staged-production/`. The live `generated/`, `backgrounds/`, and Godot preload paths remain untouched until a later review and integration pass. Preview/contact-sheet files are used for visual review before any runtime wiring.

**Tech Stack:** Built-in image generation, PNG staging assets, PowerShell/Python image inspection, existing Godot asset conventions.

---

### Task 1: Staging Structure and Prompts

**Files:**
- Create: `packages/edugame/assets/games/ch11-band-defense/staged-production/README.md`
- Create: `packages/edugame/assets/games/ch11-band-defense/staged-production/prompts/enemy-sheet-v1.md`
- Create: `packages/edugame/assets/games/ch11-band-defense/staged-production/prompts/tower-sheet-v1.md`

- [ ] **Step 1: Create a staging README**

Document that staged assets are review-only and must not replace live Godot assets.

- [ ] **Step 2: Save the enemy image-generation prompt**

Prompt must request six polished abnormal-data enemies: `config`, `noise`, `false_peak`, `power_spike`, `drift_noise`, and `hybrid_fault`.

- [ ] **Step 3: Save the tower image-generation prompt**

Prompt must request four polished defense towers: `i2c`, `filter`, `peak`, and `power`.

### Task 2: First Generated Enemy Sheet

**Files:**
- Create: `packages/edugame/assets/games/ch11-band-defense/staged-production/enemy-sheet-v1.png`

- [ ] **Step 1: Generate one enemy contact sheet**

Use the concept-sheet visual language: dark damaged hardware modules, orange/purple warning glow, asymmetric glitch fragments, no monsters, no readable in-image labels.

- [ ] **Step 2: Inspect output**

Verify the six enemy types are visually distinct, centered, and usable as source material for later sprite-frame extraction.

### Task 3: First Generated Tower Sheet

**Files:**
- Create: `packages/edugame/assets/games/ch11-band-defense/staged-production/tower-sheet-v1.png`

- [ ] **Step 1: Generate one tower contact sheet**

Use the concept-sheet visual language: clean white/blue diagnostic hardware, symmetric trusted modules, green check/valid-data cues, no weapon barrels, no readable in-image labels.

- [ ] **Step 2: Inspect output**

Verify the four tower types are distinct and align with I2C initialization, filtering, peak detection, and low-power wakeup semantics.

### Task 4: Review Companion

**Files:**
- Create: `.superpowers/brainstorm/20260623-151359/content/ch11-generated-assets-03.html`

- [ ] **Step 1: Copy generated images into the companion content folder**

Use copy-only review artifacts so the companion can serve them via `/files/...`.

- [ ] **Step 2: Publish a review screen**

Show the newly generated enemy sheet and tower sheet beside the existing concept sheet, with concise notes about next refinements.

### Self-Review

This plan covers the approved B+A direction: concept-to-runtime production assets first, current-system polish later. It intentionally excludes Godot integration, slicing, animation-frame authoring, and replacement of existing assets until visual quality is approved.
