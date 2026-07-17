# Godot 游戏项目：手环数据链路防线

## 1. 项目概述

本文档用于说明第二个 Godot Web 小游戏 `ch11-band-defense` 的当前交付状态、玩法逻辑、目录结构、运行方式和后续接手事项。它和第一份 `GODOT_GAME_HANDOFF.md` 保持同类交接口径，但聚焦第 11 章“运动手环数据采集与处理”复习游戏。

`ch11-band-defense` 中文名为“手环数据链路防线”。游戏把智能手环的数据链路包装成一个轻量塔防循环：

- 敌人代表异常数据或系统风险，例如传感噪声、假峰值、配置错误、功耗尖峰。
- 防御塔代表第 11 章知识工具，例如 I2C 初始化、滤波、峰值检测、低功耗唤醒。
- 正确塔型克制正确异常时造成高伤害。
- 错误匹配时伤害很低，并在波后诊断中提示薄弱知识点。
- 波间答题给资源，并逐步解锁塔型。

当前版本已经从第一关灰盒 MVP 扩展到第二关综合诊断关，包含两关、每关三波、波前症状、波后诊断、敌人症状特效、第二关路线和 Web 导出物。

## 2. 当前交付物

### 2.1 Godot 源工程

源工程位置：

```text
packages/edugame/godot/games/ch11-band-defense/
```

关键文件：

```text
project.godot
export_presets.cfg
scenes/main.tscn
scripts/band_defense_root.gd
scripts/godot_bridge.gd
scripts/wave_level_director.gd
scripts/level_layouts.gd
scripts/wave_diagnostics.gd
scripts/symptom_fx.gd
levels/ch11_band_defense_level.json
data/waves.sample.json
data/questions.sample.json
data/waves.level2.json
data/questions.level2.json
ASSET_DESIGN.md
README.md
```

### 2.2 播放器 Web 导出物

播放器运行产物位置：

```text
apps/player/public/assets/godot/ch11-band-defense/
```

当前 Web 导出物包括：

```text
index.html
index.js
index.wasm
index.pck
index.png
index.icon.png
index.audio.worklet.js
index.audio.position.worklet.js
index.apple-touch-icon.png
```

关卡入口配置使用：

```text
/assets/godot/ch11-band-defense/index.html
```

### 2.3 素材库

中央素材库位置：

```text
packages/edugame/assets/games/ch11-band-defense/
```

Godot 工程内通过 `res://assets/...` 使用素材。当前素材覆盖：

- 概念图：敌人/塔视觉参考图。
- 背景图：第一关数据链路地图、第二关夜跑路线地图。
- 字体：`NotoSansSC-VF.ttf`，用于 Web 导出后的中文显示。
- 生成素材：敌人动画帧、症状表现贴图等。
- source prompts：图片生成提示词和过程记录。

## 3. 游戏内容说明

### 3.1 游戏定位

“手环数据链路防线”是第 11 章复习小游戏，目标不是做复杂商业塔防，而是让学生在可玩的循环里反复识别这些知识模块：

- IMU / 加速度计数据采样。
- I2C 地址、WHO_AM_I、ODR 和量程配置。
- 滤波、去毛刺、防抖。
- 合加速度、峰值阈值、最小步间隔。
- 低功耗模式、WOM 运动唤醒、中断策略。

核心原则：

```text
塔防只是载体，知识点匹配才是得分关键。
```

### 3.2 当前关卡配置

关卡配置位置：

```text
packages/edugame/godot/games/ch11-band-defense/levels/ch11_band_defense_level.json
```

当前配置：

| 参数 | 当前值 |
| --- | ---: |
| 游戏 ID | `ch11-band-defense` |
| 关卡 ID | `ch11-band-defense-mvp` |
| 星级阈值 | 50 / 75 / 90 |
| Web 入口 | `/assets/godot/ch11-band-defense/index.html` |
| 画幅 | `16 / 9` |
| 配置中的最大漏防数 | 5 |
| 配置中的波次数 | 3 |

说明：运行时代码当前使用 `MAX_LEAKS = 8`，并根据实际波次数据识别最大关卡数。文档里的配置值来自关卡 JSON，验收时以当前代码行为为准。

### 3.3 当前玩法

玩家操作：

- 点击“开始第 1 关 / 开始第 2 关”进入当前关卡。
- 点击地图上的塔位打开圆形建塔菜单。
- 使用能量建造或升级 I2C、滤波、峰值检测、低功耗四类塔。
- 波间回答选择题，答对给能量并解锁或巩固对应塔型。
- 观察右侧波前症状和波后诊断，调整后续建塔策略。

核心循环：

```text
进入关卡
  -> 阅读本波症状
  -> 点击塔位建塔或升级
  -> 异常数据沿路径进入
  -> 塔根据克制关系自动攻击
  -> 波结束后显示诊断
  -> 波间答题获得能量和解锁
  -> 完成三波后进入下一关或结算
```

已实现机制：

- 两关流程。
- 每关三波。
- 第一关固定数据路径和 4 个塔位。
- 第二关夜跑数据异常路径和 6 个塔位。
- 圆形塔位建造菜单。
- 建塔和升级。
- 四类塔：I2C、滤波、峰值检测、低功耗。
- 四类异常：配置错误、噪声、假峰值、功耗尖峰。
- 正确匹配伤害 `x1.8`，错误匹配伤害 `x0.25`。
- 第二关精英综合异常包可随路径进度切换异常类型。
- 波前症状提示。
- 波后诊断和关卡诊断。
- 波间答题。
- 中文字体嵌入。
- Godot 与播放器 READY / INIT / PROGRESS / COMPLETE 通信。

## 4. 题库与波次

### 4.1 题库

题库位置：

```text
packages/edugame/godot/games/ch11-band-defense/data/questions.sample.json
packages/edugame/godot/games/ch11-band-defense/data/questions.level2.json
```

当前数量：

```text
第一关 8 题
第二关 6 题
合计 14 题
```

题目结构包含：

- `id`
- `module`
- `knowledgePoint`
- `prompt`
- `choices`
- `answerIndex`
- `explanation`
- `unlockTag`
- `level`

运行时会优先选择当前关卡对应题目，并优先选择能解锁仍未解锁塔型的题。

### 4.2 波次

波次数据位置：

```text
packages/edugame/godot/games/ch11-band-defense/data/waves.sample.json
packages/edugame/godot/games/ch11-band-defense/data/waves.level2.json
```

当前数量：

```text
第一关 3 波
第二关 3 波
合计 6 波
```

波次结构支持：

- `level`：所属关卡，缺省为第 1 关。
- `wave`：关内波次。
- `brief`：波前症状提示。
- `focusType`：本波主要异常类型。
- `enemies`：敌人类型、数量、倍率、切换规则。

第二关使用的综合异常包通过 `switches` 在路径进度中切换类型，用来模拟真实设备故障跨模块变化。

## 5. 目录结构

当前第二个游戏相关目录：

```text
packages/edugame/
  godot/
    games/
      ch11-band-defense/
        project.godot
        export_presets.cfg
        README.md
        ASSET_DESIGN.md
        scenes/
          main.tscn
        scripts/
          band_defense_root.gd
          godot_bridge.gd
          wave_level_director.gd
          level_layouts.gd
          wave_diagnostics.gd
          symptom_fx.gd
        levels/
          ch11_band_defense_level.json
        data/
          waves.sample.json
          questions.sample.json
          waves.level2.json
          questions.level2.json
        tests/
          test_wave_level_director.gd
          test_level_layouts.gd
          test_wave_diagnostics.gd
          test_level2_background.py
  assets/
    games/
      ch11-band-defense/
        backgrounds/
        concept/
        fonts/
        generated/
        source-prompts/

apps/player/public/assets/godot/ch11-band-defense/
```

## 6. Godot 与播放器通信协议

本游戏复用通用 `godot-game` 协议。

协议定义位置：

```text
packages/edugame/src/modes/godot-game/protocol.ts
```

游戏桥接脚本：

```text
packages/edugame/godot/games/ch11-band-defense/scripts/godot_bridge.gd
```

### 6.1 播放器加载流程

```text
EduGameHost
  -> GodotGamePanel
    -> iframe /assets/godot/ch11-band-defense/index.html
      -> Godot Web runtime
```

握手链路：

```text
Godot -> 播放器: DGB_GODOT_READY
播放器 -> Godot: DGB_GODOT_INIT
Godot -> 播放器: DGB_GODOT_PROGRESS
Godot -> 播放器: DGB_GODOT_COMPLETE
```

### 6.2 关卡 JSON 示例

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

### 6.3 Godot 回传进度

进度回传包含当前关卡、波次、漏防、稳定度和答题统计：

```json
{
  "type": "DGB_GODOT_PROGRESS",
  "progress": 0.5,
  "hint": "第 2 关准备",
  "stats": {
    "level": 2,
    "wave": 1,
    "leaks": 0,
    "stable": 100,
    "correct": 3,
    "wrong": 1
  }
}
```

### 6.4 Godot 回传完成

结算时游戏内分数为 `bandScore`，范围建议 `0..10000`；回传给播放器的 `score` 会按 `bandScore / 100` 转为 `0..100`。

```json
{
  "type": "DGB_GODOT_COMPLETE",
  "score": 86,
  "stars": 0,
  "durationMs": 180000,
  "stats": {
    "bandScore": 8600,
    "trustedData": 32,
    "leaks": 1,
    "linkStability": 88,
    "correct": 7,
    "wrong": 1,
    "shutdown": 0
  }
}
```

当前游戏传 `stars: 0`，主要展示链路分、可信数据、稳定度和学习诊断。如果后续需要星级展示，可以交给 Web 侧按 `starThresholds` 推导。

## 7. 开发和运行方式

### 7.1 安装前端依赖

在项目根目录执行：

```powershell
pnpm install
```

### 7.2 启动播放器

```powershell
pnpm -F @dgbook/player dev
```

然后访问 Vite 输出地址，通常是：

```text
http://localhost:5173/
```

Godot Web 导出物已经放在：

```text
apps/player/public/assets/godot/ch11-band-defense/index.html
```

播放器可通过下面路径加载：

```text
/assets/godot/ch11-band-defense/index.html
```

### 7.3 打开 Godot 源工程

需要 Godot 4.x。

打开：

```text
packages/edugame/godot/games/ch11-band-defense/project.godot
```

主场景：

```text
packages/edugame/godot/games/ch11-band-defense/scenes/main.tscn
```

主脚本：

```text
packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd
```

### 7.4 重新导出 Godot Web

在 Godot 编辑器中使用 Web 导出预设，导出到：

```text
apps/player/public/assets/godot/ch11-band-defense/
```

入口文件保持为：

```text
index.html
```

这样关卡 JSON 中的 `entryUrl` 不需要修改。

## 8. 素材说明

素材设计文档：

```text
packages/edugame/godot/games/ch11-band-defense/ASSET_DESIGN.md
```

视觉方向：

```text
浅色科技 UI + 手环数据链路 + 异常数据包 + 可信数据处理模块。
```

敌人视觉规则：

- 像异常数据包、错误状态、噪声事件。
- 使用深色、破碎、棱角、故障像素、琥珀或紫色警告色。
- 不画成生物，也不表现成战斗怪物。

塔视觉规则：

- 像数据处理节点、传感器模块、算法模块。
- 使用干净、对称、浅色、青色数据线、绿色可信反馈。
- 不画成炮台武器。

当前推荐背景：

```text
res://assets/backgrounds/band-defense-map-v2-screen.png
res://assets/backgrounds/band-defense-map-level2-roadside-slots.png
```

## 9. 已验证内容

项目内已有的验证记录包括：

- Godot 工程可打开。
- 主场景 `res://scenes/main.tscn` 可运行。
- Godot MCP 曾返回 `Ch11 Band Defense`，并能打开和播放主场景。
- `get_godot_errors` 曾返回无脚本或运行时错误。
- Web 导出预设存在，当前 Web 构建产物已放入播放器静态资源目录。
- JSON 数据文件可由 Node 解析。
- 第二关相关脚本已有独立测试文件。

建议常用验证命令：

```powershell
node -e "for (const f of ['packages/edugame/godot/games/ch11-band-defense/levels/ch11_band_defense_level.json','packages/edugame/godot/games/ch11-band-defense/data/waves.sample.json','packages/edugame/godot/games/ch11-band-defense/data/questions.sample.json','packages/edugame/godot/games/ch11-band-defense/data/waves.level2.json','packages/edugame/godot/games/ch11-band-defense/data/questions.level2.json']) { JSON.parse(require('fs').readFileSync(f,'utf8')); console.log('ok', f); }"
```

Godot 命令行检查示例：

```powershell
Godot_v4.6.3-stable_win64_console.exe --headless --path packages/edugame/godot/games/ch11-band-defense --check-only --script res://scripts/band_defense_root.gd
Godot_v4.6.3-stable_win64_console.exe --headless --path packages/edugame/godot/games/ch11-band-defense --scene res://scenes/main.tscn --quit-after 20
```

## 10. 当前限制与待确认

需要继续确认：

- 在浏览器里完整跑通第一关和第二关。
- 确认第二关综合异常包切换时，视觉、弱点和诊断统计都符合预期。
- 确认线上部署环境允许 Godot Web 的 `.wasm`、`.pck`、worklet 文件正常加载。
- 确认课程 manifest 是否已经接入 `ch11-band-defense` 入口。
- 将当前 sample 题库升级为正式题库，并由课程老师审校。
- 补学生端操作说明和教师端验收表。

当前还可以继续优化：

- 把单个 `band_defense_root.gd` 继续拆成敌人、塔、波次、答题等更小脚本。
- 将题库从 Godot 工程内抽到课程侧知识包。
- 给第 1 关和第 2 关提供明确关卡选择界面。
- 增加 Web 端 iframe 通信集成测试。
- 将素材从概念图进一步拆分为正式独立 PNG 或纹理图集。
- 将结算诊断和课程知识点复习建议关联得更细。

## 11. 后续新增或扩展流程

如果继续扩展第 11 章游戏，建议按以下顺序：

1. 先确认当前 Web 导出能在播放器中完整通关。
2. 再整理正式题库和知识点映射。
3. 然后拆分 `band_defense_root.gd`，降低后续维护成本。
4. 再做正式素材替换和 UI 打磨。
5. 最后接入课程 manifest 和教师验收材料。

如果要新增第三关，建议主题为 PPG/心率数据异常，不要直接增加普通刷怪难度，而是延续“症状判断 -> 建塔选择 -> 波后诊断”的教学主线。
