# Band Defense Background Map v1

Generated for `ch11-band-defense`.

Workspace asset:

```text
packages/edugame/assets/games/ch11-band-defense/backgrounds/band-defense-map-v1.png
```

Runtime path from the Godot project:

```text
res://assets/backgrounds/band-defense-map-v1.png
```

Final project image size:

```text
1280x720
```

## Prompt

```text
Use case: stylized-concept
Asset type: final 16:9 2D background map for a Godot educational tower-defense game, canvas 1280x720.
Primary request: Create a clean science-fiction background map for "smart-band data link defense". It must be a usable gameplay background, not a poster or app dashboard.
Scene/backdrop: A wearable-device signal-processing PCB and lab surface. The left 70% is the playable map area; the right 25% is a restrained dark empty HUD/sidebar panel with subtle border texture and no labels. A vertical divider separates gameplay and HUD.
Subject: A single clear cyan data lane runs from an abstract raw-sensor input node on the left to an abstract trusted-data core near the right edge of the playable area. The lane should follow this approximate polyline on a 1280x720 canvas: (68,360) -> (165,190) -> (365,190) -> (520,360) -> (690,530) -> (884,360). Include exactly four empty circular tower pads near the lane at about (190,270), (395,290), (490,475), and (700,315). Pads are blank sockets only; no towers, no icons on pads.
Knowledge anchors: Smart-band IMU acceleration and PPG signals, I2C bus traces, signal filtering, step peak detection, low-power wakeup. Express these only through abstract motifs: SDA/SCL paired circuit traces, small unlabeled waveform grids, threshold bands, battery-outline circuitry, sleep-mode crescent as a tiny decorative circuit symbol, sensor-board geometry.
Composition/framing: Top-down game-board readability. Keep all path and pads inside the left playable field. Make background motifs lower contrast so enemies/towers will read on top. Right sidebar must remain mostly empty for UI.
Lighting/mood: Bright, calm, precise, classroom-lab clarity, not dark cyberpunk.
Color palette: blue-white and cool gray base, cyan bus lines, small green trusted-data accents, minimal amber warning accents.
Materials/textures: matte glass, etched PCB traces, soft diagnostic grid, subtle waveform overlays.
Text: absolutely no text, no letters, no numbers, no labels, no watermark.
Constraints: No people, no human silhouettes, no runners, no checkmark icons, no app badges, no enemies, no towers, no characters, no biological monsters, no weapons. Avoid solar panels, sunlight chasing, PID, Kp/Ki/Kd, PWM, servos, or chapter 12 solar-tracking imagery.
```

## Notes

- Generated with the built-in image generation path using the repo default `image2` preference.
- The generated source was copied from Codex's generated-image directory into the central `edugame` asset library.
- The workspace copy was resized to 1280x720 for the current Godot canvas.
