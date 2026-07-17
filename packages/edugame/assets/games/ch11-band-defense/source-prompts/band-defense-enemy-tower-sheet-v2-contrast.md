# Band Defense Enemy/Tower Sheet v2 Contrast Prompt

Mode: built-in image generation, default image2 workflow.

Output:

```text
assets/concept/band-defense-enemy-tower-sheet-v2-contrast.png
```

Prompt:

```text
Use case: stylized-concept
Asset type: 2D tower-defense concept asset sheet for a Godot educational STM32 smart-band data-link defense game
Primary request: Create exactly 8 separated sprite concepts for Chapter 11 smart-band data pipeline tower defense, with a very obvious visual contrast between enemies and towers. Top row: 4 enemy signal threats. Bottom row: 4 defensive knowledge towers. The subject is IMU/PPG smart-band data acquisition, I2C configuration, filtering, step peak detection, and low-power wakeup. Do not include solar panels, sunlight, PID, PWM servo, or solar tracking concepts.
Scene/backdrop: clean pale blue-white embedded-systems UI presentation sheet, faint PCB traces and wearable-device data-path lines, no full game scene.
Layout requirement: exactly 2 rows and 4 columns, eight equal rounded tiles, one asset centered per tile, generous spacing, no merged cells, no empty cells, no overlapping. Top row enemies, bottom row towers.
Strong style separation: ENEMIES must be dark, angular, corrupted, asymmetrical, cracked data blocks with jagged orange/amber warning edges, glitch pixels, broken traces, and unstable waveforms. TOWERS must be bright, clean, rounded, stable, symmetrical, white/blue hardware modules with cyan/green trusted-data glow, smooth signal lines, check marks or validation symbols, and calm readable silhouettes.
Top row enemies, left to right: 1 configuration error packet representing wrong I2C address / WHO_AM_I mismatch / ODR register misconfiguration; dark register cube with red-orange cross marks and broken bus pins. 2 sensor noise packet representing raw accelerometer jitter and sampling noise; dark noisy waveform module shedding orange jitter pixels. 3 false step peak representing arm shake counted as invalid step peaks; dark jagged peak graph with repeated false peaks and unstable motion icon. 4 power spike representing excessive current draw from missed STOP mode or bad wakeup strategy; dark battery/current surge module with purple lightning and warning aura.
Bottom row towers, left to right: 1 I2C initialization tower showing clean SDA/SCL bus lines, register check, and device ID validation; bright blue-white module with green validation lens. 2 filtering tower showing noisy waveform entering and smooth waveform exiting after low-pass/debounce filtering; bright module with funnel/filter core and green smooth output. 3 peak detection tower showing resultant acceleration magnitude curve with valid threshold and minimum step interval gate; bright analyzer display with green accepted peaks and interval brackets. 4 low-power wakeup tower showing STOP sleep state, WOM motion interrupt, and battery-preserving wake signal; bright sleep/wakeup module with moon icon, motion interrupt symbol, and green battery cells.
Style/medium: polished 2D vector-like game art, semi-flat, crisp silhouettes, minimal friendly sci-fi, educational hardware UI, suitable as Godot sprite concepts, not photorealistic.
Color palette: enemies use charcoal, dark slate, amber-orange warnings, a little purple for power spike; towers use white, pale blue, cyan data lines, green trusted-data accents. Keep the background pale and neutral. Avoid solar-gold dominance, dark cyberpunk overall, beige dominance, and horror red.
Knowledge constraints: Keep concepts accurate. I2C tower validates connection/configuration, not signal filtering. Filtering tower reduces noise/jitter, not configuration faults. Peak detection tower handles false peaks using threshold and minimum interval, not low power. Low-power tower represents STOP mode and WOM wakeup, not battery as a weapon. Enemies must look like bad data packets, signal anomalies, or system states, not creatures.
Text: no words, no long labels, no watermark, no logo; abstract icons, waveforms, register blocks, thresholds, battery symbol, bus lines, check marks, and warning symbols are allowed.
Avoid: solar panels, sun rays, PID, Kp/Ki/Kd, PWM servo, chase-light visuals, guns, missiles, explosions, monsters, faces, clutter, illegible tiny text.
```
