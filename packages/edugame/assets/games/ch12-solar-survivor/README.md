# ch12-solar-survivor Assets

This directory is the source asset library for `ch12-solar-survivor`.

The Godot project path:

```text
packages/edugame/godot/games/ch12-solar-survivor/assets
```

is a directory junction that points here, so runtime code can still use:

```text
res://assets/...
```

## Directory Conventions

- `sprites/`: runtime-ready sprites.
- `reference/`: style reference images.
- `concept/`: concept sheets and visual exploration.
- `fonts/`: embedded game fonts.
- `source-prompts/`: generation prompts and process notes.
- `v*/`: non-destructive generated asset passes.

## Notes

- Add new source assets here, not under exported Web build folders.
- Keep `.import` files beside their matching source assets when Godot generates them.
- Web exports under `apps/player/public/assets/godot/ch12-solar-survivor/` are build artifacts.
