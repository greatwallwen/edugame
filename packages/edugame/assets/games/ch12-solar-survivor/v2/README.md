# Solar Survivor v2 Assets

This folder contains a non-destructive v2 asset pass generated with the image generation workflow.

## Contents

```text
backgrounds/
  light-pcb-background-v2.png
sprites/
  player_rover_v2.png
  light_orb_v2.png
  offset_band_v2.png
  energy_panel_v2.png
  error_block_v2.png
  sampling_noise_source_v2.png
  noise_pulse_v2.png
  shadow_cloud_v2.png
  stray_light_v2.png
  control_saturation_block_v2.png
  actuator_oscillation_core_v2.png
solar-survivor-v2-sprites-preview.png
```

## Direction

The v2 pass keeps the light educational PCB style:

- pale blue-white circuit-board world
- blue-gray hardware outlines
- cyan signal highlights
- warm solar-gold energy effects
- friendly low-pressure STM32 training tone

## Integration Note

These files are intentionally not wired into `solar_survivor_root.gd` yet. The current playable build still references the original assets under `assets/sprites/` and `assets/reference/`.

To adopt v2 in-game, either:

1. copy selected v2 files over the matching files in `assets/sprites/`, or
2. change the `load("res://assets/...")` paths in `scripts/solar_survivor_root.gd` to point to `res://assets/v2/...`.

Use option 2 first if you want an easy rollback.

