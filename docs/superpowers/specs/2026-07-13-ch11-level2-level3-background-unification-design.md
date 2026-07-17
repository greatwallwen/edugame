# Ch11 Level 2 and Level 3 Background Unification

## Goal

Redraw the Level 2 and Level 3 map backgrounds so they share the current Level 1 bright smartwatch-hardware visual system while preserving each level's route, tower slots, entrances, and exits.

## Visual Direction

- Use the installed Level 1 map layer as the sole style reference.
- Keep the light silver hardware substrate, shallow etched panel seams, restrained cyan and amber accents, and crisp semi-real hardware illustration.
- Keep the board frame flatter and quieter than the original realistic concepts.
- Use fewer, larger, more intentional hardware details instead of many small decorative parts.
- Do not copy consumer health-app UI, diagnostic cards, text, or HUD content into the map.

## Composition Rules

- Produce a new composition for each level; do not blur, cover, or patch the existing Level 2 and Level 3 maps.
- Preserve the existing 1280 x 720 canvas and left-map/right-HUD layer separation.
- Keep the right HUD region transparent in both map assets.
- Preserve each level's current route geometry and tower-slot coordinates.
- Keep the route corridor, tower-pad circles, and entrance/exit areas free of chips, connectors, traces, screws, vents, and decorative seams.
- Keep border components sparse and place most detail away from the route corridor.
- Use the same entrance and exit hardware language as Level 1 and align both ports with the runtime route endpoints.
- Do not bake the cyan runtime route into the background.

## Asset Strategy

1. Build one structural guide per level from the authoritative route and tower-slot coordinates.
2. Use Image 2 with the Level 1 map layer as the style reference and each structural guide as the layout reference.
3. Generate a fresh hardware-map substrate for Level 2 and Level 3.
4. Apply only deterministic canvas/layer cleanup needed for exact 1280 x 720 dimensions and right-HUD transparency.
5. Keep the existing runtime filenames so no gameplay lookup changes are required.

## Acceptance Criteria

- Level 2 and Level 3 read as members of the same asset family as Level 1 at first glance.
- The map area remains light, crisp, low-noise, and readable behind enemies and towers.
- No decorative component overlaps a route safety corridor or tower pad.
- Tower pads are centered on the configured tower-slot coordinates.
- Routes terminate outside the entrance and exit frames and visually align with the ports.
- The right HUD remains unchanged and centered.
- All background integrity, layout, route alignment, and visual quality tests pass.
- Web export renders all three levels without visual regressions or game console errors.
