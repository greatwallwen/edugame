# Band Defense Enemy/Tower Sheet v1 Prompt

Mode: built-in image generation, default image2 workflow.

Output:

```text
assets/concept/band-defense-enemy-tower-sheet-v1.png
```

Prompt:

```text
Use case: stylized-concept
Asset type: 2D tower-defense concept asset sheet for a Godot educational STM32 smart-band data-link defense game
Primary request: Create exactly 8 separated sprite concepts for Chapter 11 smart-band data pipeline tower defense. The top row has exactly 4 enemy signal threats, and the bottom row has exactly 4 defensive knowledge towers. This is about IMU/PPG smart-band data acquisition, I2C configuration, filtering, step peak detection, and low-power wakeup. Do not include solar panels, sunlight, PID, PWM servo, or solar tracking concepts.
Scene/backdrop: clean pale blue-white embedded-systems UI presentation sheet, faint PCB traces and wearable-device data path lines, no full game scene.
Layout requirement: exactly 2 rows and 4 columns, eight equal rounded tiles, one asset centered per tile, generous spacing, no merged cells, no empty cells, no overlapping. Top row enemies, bottom row towers.
Top row enemies, left to right: 1 configuration error packet representing wrong I2C address / WHO_AM_I mismatch / ODR register misconfiguration, 2 sensor noise packet representing raw accelerometer jitter and sampling noise, 3 false step peak representing arm shake counted as an invalid step peak, 4 power spike representing excessive current draw from missed STOP mode or wakeup strategy.
Bottom row towers, left to right: 1 I2C initialization tower showing bus lines, register check, and device ID validation; 2 filtering tower showing noisy waveform becoming smooth after low-pass/debounce filtering; 3 peak detection tower showing resultant acceleration magnitude curve with valid peak threshold and minimum step interval gate; 4 low-power wakeup tower showing STOP sleep state, WOM motion interrupt, and battery-preserving wake signal.
Style/medium: polished 2D vector-like game art, semi-flat, crisp silhouettes, minimal friendly sci-fi, educational hardware UI, suitable as Godot sprite concepts, not photorealistic.
Color palette: pale blue-white panels, blue-gray hardware outlines, cyan data signals, green trusted-data accents, amber warning accents for enemy threats, small magenta-purple only for power spike if needed. Avoid solar-gold dominance, dark cyberpunk, beige dominance, and horror red.
Knowledge constraints: Keep concepts accurate. I2C tower validates connection/configuration, not signal filtering. Filtering tower reduces noise/jitter, not configuration faults. Peak detection tower handles false peaks using threshold and minimum interval, not low power. Low-power tower represents STOP mode and WOM wakeup, not battery as a weapon. Enemies must look like bad data packets, signal anomalies, or system states, not creatures.
Text: no words, no long labels, no watermark, no logo; abstract icons, waveforms, register blocks, thresholds, battery symbol, and bus lines are allowed.
Avoid: solar panels, sun rays, PID, Kp/Ki/Kd, PWM servo, chase-light visuals, guns, missiles, explosions, monsters, faces, clutter, illegible tiny text.
```
