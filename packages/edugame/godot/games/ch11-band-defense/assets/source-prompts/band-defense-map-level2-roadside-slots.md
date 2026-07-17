# Band Defense Background Map Level 2 Roadside Slots

Generated for `ch11-band-defense` level 2 visual calibration.

Workspace asset:

```text
packages/edugame/assets/games/ch11-band-defense/backgrounds/band-defense-map-level2-roadside-slots.png
```

Runtime path from the Godot project:

```text
res://assets/backgrounds/band-defense-map-level2-roadside-slots.png
```

Final project image size:

```text
1280x720
```

## Method

This version is a deterministic raster correction of:

```text
packages/edugame/assets/games/ch11-band-defense/backgrounds/band-defense-map-level2-night-run.png
```

The correction keeps the level 2 route, right-side HUD panel, PCB background style, and smart-band data-link mood. The previous far-away circular pads were muted into low-contrast sealed PCB covers that do not overlap the route, then six calibrated build pads were drawn at the same coordinates used by `level_layouts.gd`.

The calibrated build pads use the same visual language as the level 1 tower bases: light gray metal disks, fine inner rims, and a restrained blue dashed construction ring. They deliberately avoid the heavy black double-ring treatment from the earlier level 2 correction.

```text
(205, 280)
(385, 235)
(520, 205)
(700, 320)
(790, 455)
(800, 300)
```

## Constraints

- Tower pads must visually sit near the route instead of isolated open space.
- The only high-contrast circular build sockets should correspond to real interactive tower slots.
- No repair patch, cover, tower pad, or decorative element may overlap the visible cyan route.
- No tower pad may overlap the level-end core.
- Level 2 build sockets should stay visually consistent with level 1 sockets.
- Do not add readable text, enemies, towers, characters, people, logos, weapons, solar panels, PID/PWM imagery, or chapter 12 visual concepts.
- Keep the background as a gameplay map, not an explanatory diagram.

## Notes

- The source level 2 background was generated with the built-in image generation path using the repo default `image2` preference.
- This roadside-slot version was produced locally from that generated source to preserve exact gameplay coordinates.
