# CH11 Late-Level Enemies Design

## Goal

Add late-level enemy variety without diluting the four core Chapter 11 knowledge categories.

## Design

Level 2 gains `drift_noise`, a noise-family variant that represents baseline drift during night-run sensor data. It should still be countered by the Filter tower, but it may switch into `false_peak` later in the path to test whether the player can recognize drift becoming a step-count false positive.

Level 3 keeps and strengthens `hybrid_fault`, a composite enemy that changes its active threat type through the existing `switches` table. It represents integrated diagnosis across configuration, noise, false peak, and power-spike symptoms.

## Constraints

- Do not add a fifth tower.
- Keep `drift_noise` in the existing `noise` counter family.
- Keep `hybrid_fault` based on existing stage switching rather than a boss system.
- Give both enemy families explicit visual identities so they do not silently fall back to generic sprites.

## Acceptance

- Level 2 wave data includes `drift_noise`.
- Level 3 wave data includes multi-stage `hybrid_fault`.
- Runtime enemy definitions include both new enemy ids.
- Animation assets include distinct 4x3 sheets for both new enemy ids.
- Asset tests guard expected sheet size and visual uniqueness.
