# PS Light UI Design

## Goal

Replace the game's text-bearing frontend UI with a clean white-surface, black-text console-system theme inspired by the approved knowledge-card preview, with the right-side hardware screen as the primary visual focus.

## Visual Language

- Keep the right hardware shell and its black display cavity unchanged.
- Place one continuous white system surface inside the display, using black primary text, neutral-gray secondary text, and restrained blue focus accents.
- Use Noto Sans SC for titles, body copy, status text, and buttons. Short titles use a semibold variation; body copy remains medium to bold according to density.
- Replace textured UI frames and green instrument buttons with scalable flat surfaces, 12-20 px corner radii, thin cool-gray borders, and modest shadows.
- Use blue only for focus, selection, and primary emphasis. Preserve green, amber, and red only for semantic success, warning, and error feedback.
- Keep popup motion behavior, information architecture, gameplay copy, and control sizes intact.

## Scope

The theme applies to the right HUD, main menu, level select, tutorial card, diagnostic panels, quiz panel, codex, radial build controls, labels, and buttons.

The theme must not modify map backgrounds, route geometry, tower slots, enemy sprites, tower sprites, attack effects, or gameplay logic.

## Rollback

`project.godot` owns one setting: `band_defense/ui_style="ps_light"`. Changing it to `"watch_debug"` restores the existing texture-backed HUD and display-font treatment on the next launch. Existing HUD textures and old styling branches remain in the project.

## Verification

- Automated tests assert the default theme, white surfaces, black text, blue focus treatment, Noto Sans SC typography, and rollback behavior.
- Existing gameplay, route, diagnostics, and visual-alignment tests continue to pass.
- Web screenshots cover the main menu, first-level tutorial, active right HUD, diagnostic popup, and quiz popup at 1280x720.

