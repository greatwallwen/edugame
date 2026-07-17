# Godot Mini-Games

This folder keeps Godot templates, game projects, and design files for `@dgbook/game`.

Game art and source assets live in the central EduGame asset library:

```text
packages/edugame/assets/games/<game-id>/
```

Each Godot game keeps an `assets` directory junction so `res://assets/...` continues to work inside Godot.

## Structure

```text
packages/edugame/godot/
  README.md
  shared/dgbook_runtime/
    runtime.gd
    bridge.gd
    protocol.gd
    knowledge_provider.gd
    session_config.gd
    result_reporter.gd
  template/
    project.godot
    GODOT_INTEGRATION.md
    addons/dgbook_runtime/  # generated self-contained copy
    scripts/game_root.gd
    levels/gpio_wiring_01.json
  games/
    ch11-band-defense/
      assets -> ../../../../assets/games/ch11-band-defense
      README.md
    ch12-solar-survivor/
      assets -> ../../../../assets/games/ch12-solar-survivor
      DESIGN.md
```

## What Belongs Here

- Godot Web template projects.
- The canonical Godot runtime that talks to the DGBook player.
- Chapter-level game design docs.
- Sample level data for `modeId: "godot-game"`.

Generated/source game assets belong in `packages/edugame/assets/games/<game-id>/`, not directly inside the Godot project folder.

## Player Integration

The runtime integration lives in:

```text
packages/edugame/src/modes/godot-game/
packages/edugame/src/core/EduGameHost.tsx
```

Godot Web builds should still be exported to the player static asset folder:

```text
apps/player/public/assets/godot/<game-id>/index.html
```

Read `template/GODOT_INTEGRATION.md` before building a new Godot mini-game.

## Shared Runtime Workflow

`shared/dgbook_runtime/` is the only editable runtime source. Each game and the template receive a self-contained copy under `addons/dgbook_runtime/`.

```powershell
pnpm godot:runtime:sync
pnpm godot:runtime:check
```

The sync command overwrites only the generated runtime directory and lock file. It never modifies game-owned scripts, data, scenes, or assets.
