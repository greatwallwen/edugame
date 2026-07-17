# Ch11 Band Defense Greybox MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable Godot greybox tower-defense MVP for chapter 11, "手环数据链路防线".

**Architecture:** Create a new Godot project by copying the existing template, then replace the sample root scene script with a focused band-defense implementation. Keep the bridge script unchanged, load waves/questions from small JSON files, and verify the playable scene through Godot MCP before any Web export work.

**Tech Stack:** Godot 4.x, GDScript, DGBook `godot_bridge.gd`, JSON sample data, Godot MCP enhanced tools.

---

## File Structure

- Create: `packages/edugame/godot/games/ch11-band-defense/project.godot`
  - New Godot project metadata, main scene remains `res://scenes/main.tscn`.
- Create: `packages/edugame/godot/games/ch11-band-defense/export_presets.cfg`
  - Web export target for later, pointing to `apps/player/public/assets/godot/ch11-band-defense/index.html`.
- Create: `packages/edugame/godot/games/ch11-band-defense/scenes/main.tscn`
  - Root `Control` scene with `band_defense_root.gd`.
- Create: `packages/edugame/godot/games/ch11-band-defense/scripts/godot_bridge.gd`
  - Copied bridge from template without behavior changes.
- Create: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
  - Greybox game root, UI, game state, spawning, towers, quiz, scoring, and bridge calls.
- Create: `packages/edugame/godot/games/ch11-band-defense/data/questions.sample.json`
  - Small chapter 11 question set with unlock tags.
- Create: `packages/edugame/godot/games/ch11-band-defense/data/waves.sample.json`
  - Three-wave enemy sequence.
- Create: `packages/edugame/godot/games/ch11-band-defense/levels/ch11_band_defense_level.json`
  - `modeId: "godot-game"` level config for local and future player use.

For the greybox MVP, use a single `band_defense_root.gd` instead of multiple gameplay scripts. This keeps the first Godot MCP pass smaller. The design doc still defines later split points (`enemy.gd`, `tower.gd`, `wave_director.gd`, `quiz_controller.gd`) once the loop proves itself.

## Task 1: Scaffold The Godot Project

**Files:**
- Create directory: `packages/edugame/godot/games/ch11-band-defense/`
- Copy from: `packages/edugame/godot/template/icon.svg`
- Copy from: `packages/edugame/godot/template/scripts/godot_bridge.gd`
- Create: `packages/edugame/godot/games/ch11-band-defense/project.godot`
- Create: `packages/edugame/godot/games/ch11-band-defense/export_presets.cfg`
- Create: `packages/edugame/godot/games/ch11-band-defense/scenes/main.tscn`

- [ ] **Step 1: Create directories**

Run:

```powershell
New-Item -ItemType Directory -Force `
  packages\edugame\godot\games\ch11-band-defense\scenes, `
  packages\edugame\godot\games\ch11-band-defense\scripts, `
  packages\edugame\godot\games\ch11-band-defense\data, `
  packages\edugame\godot\games\ch11-band-defense\levels | Out-Null
```

Expected: directories exist.

- [ ] **Step 2: Copy reusable template files**

Run:

```powershell
Copy-Item packages\edugame\godot\template\icon.svg packages\edugame\godot\games\ch11-band-defense\icon.svg -Force
Copy-Item packages\edugame\godot\template\scripts\godot_bridge.gd packages\edugame\godot\games\ch11-band-defense\scripts\godot_bridge.gd -Force
```

Expected: `icon.svg` and `scripts/godot_bridge.gd` exist in the new project.

- [ ] **Step 3: Write `project.godot`**

Use this exact content:

```ini
; Engine configuration file.
; Open with Godot 4.x.

config_version=5

[application]

config/name="Ch11 Band Defense"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.6", "Forward Plus")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Step 4: Write `export_presets.cfg`**

Use this exact content:

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../../../../../apps/player/public/assets/godot/ch11-band-defense/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
```

- [ ] **Step 5: Write `scenes/main.tscn`**

Use this exact content:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/band_defense_root.gd" id="1_band_root"]

[node name="BandDefenseRoot" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_band_root")
```

- [ ] **Step 6: Verify scaffold**

Run:

```powershell
Test-Path packages\edugame\godot\games\ch11-band-defense\project.godot
Test-Path packages\edugame\godot\games\ch11-band-defense\scenes\main.tscn
Test-Path packages\edugame\godot\games\ch11-band-defense\scripts\godot_bridge.gd
```

Expected: all three commands print `True`.

## Task 2: Add Level, Wave, And Question Data

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/levels/ch11_band_defense_level.json`
- Create: `packages/edugame/godot/games/ch11-band-defense/data/waves.sample.json`
- Create: `packages/edugame/godot/games/ch11-band-defense/data/questions.sample.json`

- [ ] **Step 1: Write level JSON**

Use this exact content:

```json
{
  "modeId": "godot-game",
  "levelId": "ch11-band-defense-mvp",
  "title": "手环数据链路防线",
  "objective": "复习 IMU、计步算法、PPG、OLED 与低功耗设计",
  "difficulty": 3,
  "starThresholds": [50, 75, 90],
  "timeLimit": 0,
  "data": {
    "gameId": "ch11-band-defense",
    "entryUrl": "/assets/godot/ch11-band-defense/index.html",
    "aspectRatio": "16 / 9",
    "maxLeaks": 5,
    "waveCount": 3
  }
}
```

- [ ] **Step 2: Write waves JSON**

Use this exact content:

```json
[
  { "wave": 1, "enemies": [{ "type": "config", "count": 4 }, { "type": "noise", "count": 4 }] },
  { "wave": 2, "enemies": [{ "type": "noise", "count": 5 }, { "type": "false_peak", "count": 5 }] },
  { "wave": 3, "enemies": [{ "type": "power_spike", "count": 4 }, { "type": "false_peak", "count": 4 }, { "type": "config", "count": 3 }] }
]
```

- [ ] **Step 3: Write questions JSON**

Use at least these eight questions:

```json
[
  {
    "id": "ch11-i2c-whoami-001",
    "module": "i2c",
    "knowledgePoint": "WHO_AM_I 检测",
    "prompt": "初始化 IMU 时读取 WHO_AM_I 寄存器的主要目的是什么？",
    "choices": ["确认器件连接和地址正确", "直接计算步数", "刷新 OLED 画面", "进入 STOP 模式"],
    "answerIndex": 0,
    "explanation": "WHO_AM_I 返回固定器件 ID，用来确认 I2C 通信、地址和器件连接正常。",
    "unlockTag": "i2c"
  },
  {
    "id": "ch11-i2c-odr-001",
    "module": "i2c",
    "knowledgePoint": "采样率配置",
    "prompt": "加速度计 ODR 配置主要决定什么？",
    "choices": ["传感器输出数据率", "OLED 屏幕宽度", "蓝牙名称", "电池容量"],
    "answerIndex": 0,
    "explanation": "ODR 是输出数据率，决定传感器多久产生一次新数据。",
    "unlockTag": "i2c"
  },
  {
    "id": "ch11-filter-noise-001",
    "module": "filter",
    "knowledgePoint": "滤波抗噪",
    "prompt": "计步前对加速度信号做滤波，最直接的作用是什么？",
    "choices": ["减少噪声和抖动造成的误判", "改变 I2C 地址", "提高 OLED 亮度", "关闭中断"],
    "answerIndex": 0,
    "explanation": "滤波能让原始加速度曲线更平滑，减少瞬时噪声触发假峰值。",
    "unlockTag": "filter"
  },
  {
    "id": "ch11-filter-threshold-001",
    "module": "filter",
    "knowledgePoint": "阈值判断",
    "prompt": "计步阈值设置过低最可能导致什么？",
    "choices": ["轻微晃动也被误计为步数", "无法读取 WHO_AM_I", "OLED 无法显示中文", "STOP 模式无法唤醒"],
    "answerIndex": 0,
    "explanation": "阈值过低会把小幅晃动当成有效步态峰值，造成计步偏大。",
    "unlockTag": "filter"
  },
  {
    "id": "ch11-peak-interval-001",
    "module": "step",
    "knowledgePoint": "步间隔防抖",
    "prompt": "计步算法中为什么要设置最小步间隔？",
    "choices": ["避免一次晃动被重复计为多步", "提高 I2C 时钟频率", "降低 OLED 分辨率", "关闭加速度计"],
    "answerIndex": 0,
    "explanation": "最小步间隔相当于时间防抖，能避免同一次摆动产生多个峰值被重复计步。",
    "unlockTag": "peak"
  },
  {
    "id": "ch11-peak-mag-001",
    "module": "step",
    "knowledgePoint": "合加速度",
    "prompt": "用三轴加速度计计步时，常计算合加速度 |a| 的原因是什么？",
    "choices": ["减少手环佩戴方向变化的影响", "直接控制蜂鸣器", "替代所有传感器供电", "让 I2C 变成 SPI"],
    "answerIndex": 0,
    "explanation": "合加速度综合 ax、ay、az，比单轴更不依赖手环具体朝向。",
    "unlockTag": "peak"
  },
  {
    "id": "ch11-power-stop-001",
    "module": "power",
    "knowledgePoint": "STOP 模式",
    "prompt": "运动手环静止时进入 STOP 模式的主要收益是什么？",
    "choices": ["降低 MCU 功耗、延长续航", "提高屏幕刷新率", "增加假峰值数量", "改变加速度量程"],
    "answerIndex": 0,
    "explanation": "STOP 模式会关闭大部分时钟并保留必要状态，适合可穿戴设备省电。",
    "unlockTag": "power"
  },
  {
    "id": "ch11-power-wom-001",
    "module": "power",
    "knowledgePoint": "WOM 运动唤醒",
    "prompt": "WOM 运动唤醒适合解决什么问题？",
    "choices": ["静止低功耗，运动时再唤醒 MCU", "把 OLED 变成触摸屏", "让 PPG 不需要光源", "跳过 I2C 初始化"],
    "answerIndex": 0,
    "explanation": "WOM 由 IMU 检测运动并产生中断，能让 MCU 平时休眠，运动时恢复工作。",
    "unlockTag": "power"
  }
]
```

- [ ] **Step 4: Validate JSON**

Run:

```powershell
node -e "for (const f of ['packages/edugame/godot/games/ch11-band-defense/levels/ch11_band_defense_level.json','packages/edugame/godot/games/ch11-band-defense/data/waves.sample.json','packages/edugame/godot/games/ch11-band-defense/data/questions.sample.json']) { JSON.parse(require('fs').readFileSync(f,'utf8')); console.log('ok', f); }"
```

Expected: three `ok` lines.

## Task 3: Implement The Greybox Game Root

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`

- [ ] **Step 1: Write the first implementation**

The script must:

- Create a full-screen greybox layout.
- Define four tower slots and four tower types.
- Define four enemy types with `threatTag`.
- Load `data/questions.sample.json` and `data/waves.sample.json`.
- Spawn three waves.
- Apply damage multiplier `1.8` for matching `counterTags`, `0.25` for mismatch.
- Show wave-between quiz.
- Unlock `filter`, `peak`, and `power` towers from quiz answers.
- Send `send_progress` during play and `send_complete` once on result.

- [ ] **Step 2: Keep public method names stable**

Use these root methods so MCP and manual testing can inspect behavior:

```gdscript
func start_game() -> void
func build_tower(slot_index: int, tower_id: String) -> void
func answer_quiz(choice_index: int) -> void
func finish_game(shutdown: bool) -> void
```

- [ ] **Step 3: Run a syntax smoke check through Godot MCP**

Use Godot MCP:

```text
open_scene("res://scenes/main.tscn")
play_scene("res://scenes/main.tscn")
get_godot_errors()
```

Expected: no parser errors for `band_defense_root.gd`.

## Task 4: Verify Gameplay Through Godot MCP

**Files:**
- Read: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Read: `packages/edugame/godot/games/ch11-band-defense/data/*.json`

- [ ] **Step 1: Open the scene**

Use Godot MCP:

```text
open_scene("res://scenes/main.tscn")
```

Expected: scene tree root is `BandDefenseRoot`.

- [ ] **Step 2: Play the scene**

Use Godot MCP:

```text
play_scene("res://scenes/main.tscn")
```

Expected: game window starts.

- [ ] **Step 3: Capture screenshot**

Use Godot MCP:

```text
get_running_scene_screenshot()
```

Expected: screenshot shows the greybox map, HUD, tower buttons, and start state.

- [ ] **Step 4: Read errors**

Use Godot MCP:

```text
get_godot_errors()
```

Expected: no script parser errors and no runtime exceptions.

- [ ] **Step 5: Iterate fixes**

If errors appear, edit only the new `ch11-band-defense` project files, then repeat steps 2-4 until clean.

## Task 5: Document Current Verification Boundary

**Files:**
- Create: `packages/edugame/godot/games/ch11-band-defense/README.md`

- [ ] **Step 1: Write README**

Include:

- What the greybox MVP contains.
- How to open it in Godot.
- How to run it.
- What is intentionally not included yet.
- Web export is a future step.

- [ ] **Step 2: Final file list check**

Run:

```powershell
Get-ChildItem -Recurse packages\edugame\godot\games\ch11-band-defense | Select-Object FullName
```

Expected: only the new project files are listed.

- [ ] **Step 3: Commit if a git repository is available**

Run:

```powershell
git status --short
```

Expected in this workspace right now: `fatal: not a git repository`. If the repo is later restored, commit with:

```powershell
git add docs/superpowers/specs/2026-06-16-ch11-band-defense-design.md docs/superpowers/plans/2026-06-16-ch11-band-defense-greybox-mvp.md packages/edugame/godot/games/ch11-band-defense
git commit -m "feat: add ch11 band defense greybox mvp"
```

## Self-Review

Spec coverage:

- New standalone Godot project: Task 1.
- Greybox fixed path and tower slots: Task 3.
- Three waves and local sample data: Task 2 and Task 3.
- Question resource and unlock flow: Task 2 and Task 3.
- Tower/enemy correct-vs-wrong damage: Task 3.
- Bridge progress/complete: Task 3 and Task 4.
- Godot MCP verification: Task 4.
- No Web export in MVP: Task 5 README boundary.

Placeholder scan:

- No `TBD`, `TODO`, `FIXME`, or "implement later" placeholders are allowed in created source files.
- The implementation may leave formal Web export for a later plan, but the README must explicitly mark it out of scope for this MVP.

Type consistency:

- Tower matching uses `counterTags` on tower definitions and `threatTag` on enemy definitions.
- Unlocks use question `unlockTag`.
- Result stats use numeric keys: `bandScore`, `wavesCleared`, `leaks`, `correct`, `wrong`, `linkStability`, `shutdown`.
