# EduGame Asset Library

This folder is the central source library for EduGame mini-game assets.

## Structure

```text
packages/edugame/assets/
  games/
    ch11-band-defense/
      concept/
      fonts/
      source-prompts/
    ch12-solar-survivor/
      concept/
      fonts/
      reference/
      sprites/
      source-prompts/
      v2/
      v3/
      v4/
      v4_simplified/
```

Each game keeps its own assets under `games/<game-id>/`. Do not share files by reaching into another game's folder from runtime code; copy or promote a reusable asset into an explicit shared folder first.

## Godot Compatibility

Godot projects still load runtime assets with:

```text
res://assets/...
```

To keep that path working, each Godot game has an `assets` directory junction pointing back to its central library folder:

```text
packages/edugame/godot/games/<game-id>/assets
  -> packages/edugame/assets/games/<game-id>
```

The central `packages/edugame/assets/games/<game-id>/` folder is the source of truth. The per-project `assets` path is only a Godot-facing compatibility entry point.

## Exported Builds

Web exports under:

```text
apps/player/public/assets/godot/<game-id>/
```

are runtime build artifacts, not the source asset library.
