# Ch12 Solar Survivor UI Unification Design

## Objective

Unify every user-interface state in `ch12-solar-survivor` with the current visual language of `ch11-band-defense`, while preserving Ch12 gameplay, scene artwork, data, and every existing user-facing copy string.

The target is the current Ch11 light smartwatch engineering/debug interface: a dark physical screen surround, pale blue-white cards, compact telemetry hierarchy, restrained cyan/green/amber accents, and distinct display/body/technical typography.

## Confirmed Scope

The visual pass covers:

- the persistent gameplay HUD and hint area;
- pause controls and pause dialog;
- first-seen enemy information dialogs;
- question and countdown UI;
- correct-answer upgrade choices;
- wrong-answer feedback;
- end-of-run result UI;
- normal, hover, pressed, disabled, warning, and success states used by those surfaces.

The following are explicitly out of scope:

- gameplay rules, timing, scoring, difficulty, upgrades, enemy behavior, and bridge events;
- Ch12 background, player, enemy, projectile, and effect artwork;
- question, upgrade, and binding data;
- modifications to the Ch11 project;
- rewriting, shortening, or rewording any existing Ch12 user-facing copy.

## Visual Direction

### Hardware frame and surfaces

The persistent HUD and modal surfaces use the same material hierarchy as Ch11:

1. a near-black hardware-screen surround with subtle inset highlight and outer depth;
2. a pale blue-white screen surface;
3. grouped cards with one shared radius, border, highlight, and soft shadow system;
4. metric tiles and action controls nested inside those cards.

The Ch12 gameplay field remains visible and readable. Large opaque UI surfaces must not cover active movement space except when the game is already paused for a modal state.

### Color roles

- Cyan indicates active tracking, selection, and primary actions.
- Green indicates stable or successful system state.
- Amber indicates warnings, countdown pressure, or attention.
- Warm red-orange is reserved for faults and incorrect-answer states.
- Dark blue-grey is the primary text color on light surfaces.
- Muted blue-grey is used for supporting labels and explanations.

Color communicates status but is never the only signal; labels and existing text remain present.

### Typography

Ch12 adopts the font-role model already established by Ch11:

- the readable Chinese UI font for body copy, questions, explanations, and long descriptions;
- the display font for modal titles, major results, and high-level headings;
- the technical font for numeric telemetry, countdowns, compact status labels, and short Latin abbreviations.

Font variations provide regular, medium, semibold, and bold hierarchy where the source font supports it. All Chinese text must retain a readable fallback. Existing copy strings remain byte-for-byte unchanged in source unless a line is dynamically assembled from unchanged fragments.

## Interface Mapping

### Persistent HUD

The current free-floating multiline HUD becomes a compact telemetry card group inside a dark hardware frame. It continues to display the same Ch12 metrics and values. Metrics may be split into tiles or rows for scanning, but their labels and values do not change.

The existing hint text moves into a separate feedback card within the same visual family. The pause control uses the shared secondary button style and remains available in its current gameplay state.

### Pause and enemy information

The pause dialog and first-seen enemy information dialog use the shared modal frame, title hierarchy, body typography, spacing rhythm, and button states. Enemy icons and all dialog copy remain unchanged.

### Question and upgrade flow

The question panel uses a compact top status row for the existing countdown, followed by a title, prompt, and four consistent answer cards. Answer letters may use the technical font, while the option text uses the readable Chinese body font.

The upgrade panel reuses the same modal shell. Each existing upgrade choice becomes a card-like button with clear name/effect hierarchy while retaining its current string content. Empty-upgrade and continue states use the same component system.

### Wrong-answer feedback and results

Wrong-answer feedback uses the standard modal shell with warm fault accents and preserves the full explanation and system status text.

The result panel promotes the existing score as the main technical numeral, then presents all current result fields as aligned rows. The title and every field label remain unchanged. The restart action uses the shared primary button style.

## Implementation Structure

All production changes remain inside `packages/edugame/godot/games/ch12-solar-survivor/` and its Ch12-linked asset directory.

`solar_survivor_root.gd` will gain a small internal theme layer rather than copying style overrides independently into every dialog:

- font loading and font-role accessors;
- shared palette constants;
- shared hardware-frame, surface-card, metric-tile, and button style builders;
- small helpers that apply title, body, muted, technical, success, warning, and fault text roles;
- reusable construction helpers only where they reduce repeated UI code without changing gameplay flow.

This remains local to Ch12. A cross-game shared theme module is intentionally deferred so the stable Ch11 implementation is not put at risk during this pass.

If a raster texture is necessary for material depth that cannot be achieved cleanly with Godot style boxes, it will be limited to UI container decoration, generated with image2, and stored in the Ch12 asset area with its source prompt. No gameplay art will be regenerated as part of this work.

## Runtime Behavior and Failure Handling

The UI restyle does not introduce new data flow. Existing phase transitions, pause behavior, bridge messages, question selection, upgrade selection, scoring, and completion callbacks remain authoritative.

Missing optional display or technical fonts fall back to the readable Chinese UI font. A missing required readable font produces the existing warning behavior and falls back to Godot's default font rather than blocking gameplay.

Long dynamic text uses wrapping, clipping, or ellipsis according to its role:

- explanations and descriptions wrap and remain fully readable;
- compact metric labels may clip or ellipsize inside fixed tiles;
- questions and upgrade descriptions receive flexible vertical space;
- result rows remain inside the 1280 x 720 safe area.

## Testing and Acceptance

Automated checks will verify:

- expected font assets and font-role accessors are present;
- shared panel and button style builders expose the intended radius, border, and color roles;
- each major UI state uses the shared theme helpers;
- representative existing Ch12 copy strings remain unchanged;
- gameplay data files and bridge behavior are untouched.

Runtime visual verification will cover the 1280 x 720 Web target and capture at least:

- active gameplay HUD;
- pause dialog;
- enemy information dialog;
- question panel;
- upgrade panel;
- wrong-answer feedback;
- result panel.

Acceptance requires:

- clear visual family resemblance to the current Ch11 smartwatch engineering/debug UI;
- no text overflow, clipping of required content, overlap, or off-screen controls;
- readable gameplay behind the persistent HUD;
- consistent typography, spacing, radii, shadows, borders, and button states across all surfaces;
- no modification to existing Ch12 copy or gameplay behavior;
- relevant Godot checks and project tests pass.

## Approved Direction

The user selected the full visual-unification approach and approved the visual mapping shown in the brainstorming companion. The user explicitly rejected copy changes: only the visual and typographic treatment of text may change.
