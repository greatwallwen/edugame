# Ch11 Band Defense

`ch11-band-defense` is a Godot greybox MVP for the chapter 11 review game "手环数据链路防线".

The prototype turns the smart-band data pipeline into a small tower-defense loop:

- Enemies represent bad signals or system threats: sensor noise, false step peaks, configuration errors, and power spikes.
- Towers represent chapter 11 knowledge tools: I2C initialization, filtering, peak detection, and low-power wakeup.
- Correct tower/enemy matching deals high damage.
- Wrong matching deals very low damage.
- Between waves, quiz answers grant energy and unlock tower types.

## Current MVP Scope

Implemented:

- One fixed greybox path.
- Four fixed tower slots.
- Nine enemy waves from the three `data/waves*.json` gameplay files.
- Thirty course-owned chapter 11 questions, mirrored to `data/questions.local.json` for local preview only.
- Four tower types with `counterTags`.
- Four enemy types with `threatTag`.
- Damage multiplier rules:
  - Matching tower: `baseDamage * 1.8`
  - Mismatched tower: `baseDamage * 0.25`
- HUD, build buttons, quiz panel, result panel.
- Local Godot preview through `godot_bridge.gd`.
- `DGB_GODOT_PROGRESS` and `DGB_GODOT_COMPLETE` messages.
- Godot MCP plugin copied into the project for editor verification.
- Web export preset and current Web build under `apps/player/public/assets/godot/ch11-band-defense/`.
- Embedded Noto Sans SC font for Chinese text in Web builds.

Not included yet:

- Course manifest integration.
- Full chapter 11 formal question bank.
- Production art assets.
- Free tower placement.
- Complex pathfinding.
- Separate `enemy.gd`, `tower.gd`, `wave_director.gd`, and `quiz_controller.gd` files.

## Open In Godot

Open this project:

```text
packages/edugame/godot/games/ch11-band-defense/project.godot
```

Main scene:

```text
res://scenes/main.tscn
```

Main script:

```text
res://scripts/band_defense_root.gd
```

## Verification Used

JSON validation:

```powershell
node packages/edugame/godot/tools/sync_teaching_assets.mjs check
```

GDScript parse check:

```powershell
Godot_v4.6.3-stable_win64_console.exe --headless --path packages/edugame/godot/games/ch11-band-defense --check-only --script res://scripts/band_defense_root.gd
```

Scene smoke run:

```powershell
Godot_v4.6.3-stable_win64_console.exe --headless --path packages/edugame/godot/games/ch11-band-defense --scene res://scenes/main.tscn --quit-after 20
```

Godot MCP verification:

- `get_project_info` returned `Ch11 Band Defense`.
- `open_scene("res://scenes/main.tscn")` succeeded.
- `play_scene("res://scenes/main.tscn")` succeeded.
- `get_godot_errors` returned no script or runtime errors.

## Next Step

The next implementation pass should exercise the full wave loop interactively in the editor, then split the single root script into focused gameplay scripts once the behavior is stable.
