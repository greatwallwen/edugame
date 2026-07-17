# Ch12 Solar Survivor Asset Plan

## Visual Direction

Style target:

```text
2D top-down educational arcade game.
Light PCB-style circuit-board world, warm solar-gold light energy, soft blue-gray UI frames, small cyan highlights.
Friendly sci-fi, low pressure, readable during gameplay.
```

This should stay close to the broader DGBook embedded-systems course style: clean, technical, bright teaching UI, blue-gray circuit details, gold light-energy accents, and no dark horror or combat-heavy tone.

## Generated Concept Assets

Initial generated samples:

```text
assets/concept/solar-survivor-asset-style-sheet-v1.png
assets/concept/solar-survivor-asset-style-sheet-v2-hardware-icons.png
assets/concept/solar-survivor-circuit-background-v1.png
```

These are concept/style references, not final sliced Godot sprites yet. Use `solar-survivor-asset-style-sheet-v2-hardware-icons.png` as the current preferred upgrade icon direction.

Latest approved light-style references:

```text
assets/reference/light-pcb-background-reference.png
assets/reference/light-asset-sheet-reference.png
```

Use these two images as the primary visual direction for future production assets.

## V2 Asset Pass

A non-destructive v2 pass has been generated under:

```text
assets/v2/
```

Key files:

```text
assets/concept/solar-survivor-v2-asset-overview.png
assets/v2/backgrounds/light-pcb-background-v2.png
assets/v2/sprites/
assets/v2/solar-survivor-v2-sprites-preview.png
```

The v2 pass keeps the approved light PCB direction and provides replacement candidates for the current runtime sprites. These assets are not wired into the Godot script yet; adopt them by changing `res://assets/...` paths or copying selected v2 files into `assets/sprites/` after visual QA in the editor.

## MVP Asset List

### Must Have

| Asset | Purpose | Target Format | Notes |
| --- | --- | --- | --- |
| player_core | Player unit with STM32 controller + small solar panel | transparent PNG | Main character |
| ordinary_light | Auto-collected light particle | transparent PNG or Godot particle | Small gold orb |
| offset_light_band | Active chase zone | PNG or shader | Should be readable but not threatening |
| stability_meter | UI status element | Godot UI preferred | Can be built with Control nodes |
| quiz_panel | Upgrade question UI | Godot UI preferred | No raster text needed |
| upgrade_icon_p | Kp proportional gain upgrade | transparent PNG | Short label P, use amplifier/gain-slope metaphor |
| upgrade_icon_i | Ki integral compensation upgrade | transparent PNG | Short label I, use capacitor charging / accumulated energy metaphor |
| upgrade_icon_d | Kd derivative damping upgrade | transparent PNG | Short label D, use resistor or RC damping / slope suppression metaphor |
| upgrade_icon_pwm | Servo PWM pulse-width calibration | transparent PNG | Label PWM |
| upgrade_icon_deadzone | Deadband threshold | transparent PNG | Label DZ |
| upgrade_icon_limit | Output limit / servo angle clamp | transparent PNG | Label LIM |
| circuit_background | Playfield background | PNG/WebP | Low contrast, readable |

### Nice To Have

| Asset | Purpose |
| --- | --- |
| answer_correct_burst | Short gold/cyan positive feedback |
| answer_wrong_alert | Non-scary red/orange system warning |
| light_absorb_trail | Curved trail for particles flying to player |
| shutdown_overlay | Soft system stop overlay |
| final_score_panel | Result screen frame |

## Asset Rules

- Keep gameplay items readable at small sizes.
- Do not rely on long text inside images; use Godot UI text instead.
- Icons may use short labels: `P`, `I`, `D`, `PWM`, `DZ`, `LIM`.
- `I` and `D` icons should not be plain letters only. Add hardware-flavored symbols: capacitor/charge tank for integral accumulation, resistor/RC damping plus slope waveform for derivative damping.
- Avoid purple-dominant, beige-dominant, and heavy dark-blue palettes.
- Prefer the light PCB style shown in the latest reference images: pale blue-white board, blue-gray lines, golden light points, cyan highlights.
- Avoid weapons, monsters, horror, or failure visuals that feel punitive.
- Ordinary light energy should feel abundant and safe.
- Offset light bands should invite movement, not feel like hazards.

## Generation Prompts Used

The prompts below document the first dark-style concept pass. For future production assets, use the approved light-style reference images above as the primary style source.

Recommended production prompt direction:

```text
Use the provided light PCB reference style: pale blue-white circuit-board background, blue-gray UI frames, clean white panels, cyan highlights, warm golden solar light particles.
Create polished 2D educational arcade game assets for a Godot STM32 solar tracking game.
Keep the overall tone bright, technical, friendly, and consistent with a digital textbook product.
Icons may show short labels P, I, D, PWM, DZ, LIM, but the concept behind them is Kp proportional gain, Ki integral compensation, Kd derivative damping, servo PWM pulse-width calibration, deadband threshold, and output limit.
For I and D, include hardware metaphors: I as a capacitor or charge reservoir gradually filling; D as a resistor/RC damping element reducing a steep slope or spike.
Avoid dark neon palettes, horror/combat feeling, long text, clutter, and photorealism.
```

### Asset Style Sheet v1

```text
Use case: stylized-concept
Asset type: 2D Godot game asset concept sheet for an educational STM32 solar tracking mini-game
Primary request: Create a clean 2D game asset concept sheet containing multiple separated assets for a chapter 12 solar tracker survivor game.
Scene/backdrop: flat dark teal circuit-board presentation sheet, not a full scene.
Subject: include a small player unit shaped like a compact STM32 control core with a tiny solar panel, ordinary golden light-energy particles, an offset light-energy band marker, a stability meter widget, and six upgrade icons: P gain, I compensation, D damping, PWM servo pulse, deadband protection, output limit.
Style/medium: polished 2D vector-like game art, crisp edges, semi-flat illustration, subtle glow, suitable for Godot sprites.
Composition/framing: arranged as a tidy asset board with generous spacing, each asset isolated in its own area, no overlapping.
Color palette: match an educational embedded-systems product style: deep teal, circuit green, warm solar gold, clean white labels, small cyan accents; avoid purple-dominant, avoid beige-dominant.
Lighting/mood: bright, friendly, low-pressure arcade learning game.
Text (verbatim): no long text; only short icon labels: "P", "I", "D", "PWM", "DZ", "LIM".
Constraints: no watermark, no logo, no photorealism, no complex background clutter, no tiny unreadable text, no character faces, no weapons, no danger or horror tone.
```

### Circuit Background v1

```text
Use case: stylized-concept
Asset type: tileable 2D background concept for a Godot educational arcade game
Primary request: Create a seamless-looking top-down dark circuit-board background tile for an STM32 solar tracking survivor game.
Scene/backdrop: abstract embedded electronics PCB field with subtle traces, pads, vias, and faint grid.
Subject: no characters, no text, no logos; only a clean game background that can sit behind sprites.
Style/medium: polished semi-flat 2D game art, crisp but understated, suitable for Godot as a 16:9 background or cropped tile.
Composition/framing: full-bleed background, balanced density, no central focal object, leave playable area readable.
Color palette: deep teal and forest green base, muted circuit green traces, tiny warm solar-gold accent dots, small cyan highlights; avoid purple-dominant, avoid beige-dominant, avoid dark blue/slate dominance.
Lighting/mood: calm educational sci-fi, friendly, low visual noise.
Constraints: no text, no watermark, no realistic photos, no complex clutter, no high-contrast objects that could be confused with gameplay items.
```

## Next Step

If this direction is approved, generate final production sprites as separate assets. For transparent PNGs, use the built-in image generation flow with a flat chroma-key background, then remove the key color locally and save final PNGs under:

```text
assets/sprites/
assets/icons/
assets/effects/
assets/backgrounds/
```
