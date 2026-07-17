# DGBook Godot Game Template

This folder is the starter template for Godot-based training mini-games.

## Contract

The DGBook player hosts exported Godot Web builds in an iframe. Communication uses `window.postMessage`.

Host to Godot:

- `DGB_GODOT_INIT`: sends the full `LevelData` and `data` payload.
- `DGB_GODOT_PAUSE`: pause the scene.
- `DGB_GODOT_RESUME`: resume the scene.
- `DGB_GODOT_RESET`: reset the current attempt.

Godot to host:

- `DGB_GODOT_READY`: Godot scene is ready for init data.
- `DGB_GODOT_PROGRESS`: progress ratio `0..1`, optional hint and numeric stats.
- `DGB_GODOT_COMPLETE`: final score `0..100`, optional stars, duration and stats.
- `DGB_GODOT_LOG`: lightweight diagnostics shown by the host.

## Suggested Workflow

1. Copy this folder to a new game folder, for example `packages/edugame/godot/games/gpio-lab`.
2. Open it with Godot 4.x.
3. Run `pnpm godot:runtime:sync` from the repository root.
4. Treat `addons/dgbook_runtime/` as generated code; edit the canonical runtime under `godot/shared/dgbook_runtime/` instead.
5. Build your gameplay scene under `scenes/` and call the runtime facade:
   - `runtime.report_progress(0.5, "2/4 checks passed")`
   - `runtime.complete(92, -1, elapsed_ms, {"mistakes": 1})`
6. Export as Web into `apps/player/public/assets/godot/<game-id>/`.
7. Reference it from an edugame level with `modeId: "godot-game"`.

The runtime resolves knowledge arrays injected by the player first and falls back to JSON files declared by the game. Run `pnpm godot:runtime:check` before export to detect stale generated copies.

## Level Data Example

See `levels/gpio_wiring_01.json`.

The host only requires:

```json
{
  "modeId": "godot-game",
  "data": {
    "gameId": "gpio-lab",
    "entryUrl": "/assets/godot/gpio-lab/index.html"
  }
}
```

Everything else inside `data` belongs to the Godot game.
