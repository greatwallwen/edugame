# Godot 游戏项目

> 2026-07-16 更新：Godot 宿主接入已统一为 `packages/edugame/godot/shared/dgbook_runtime/`。模板和各游戏中的 `addons/dgbook_runtime/` 是同步生成的自包含副本；使用 `pnpm godot:runtime:sync` 更新，使用 `pnpm godot:runtime:check` 校验。旧的 `scripts/godot_bridge.gd` 路径不再使用。

## 1. 项目概述

本项目是在 DGBook 数字教材平台中新增的 Godot Web 小游戏能力。目标是在 STM32 互动教材中嵌入更接近“实训游戏”的章节复习内容，让课程播放器可以通过 iframe 加载 Godot Web 导出物，并用标准 `postMessage` 协议和 Godot 游戏交换初始化数据、进度、分数和控制命令。

当前已完成两块内容：

1. `godot-game` 通用接入模式：播放器侧可加载任意 Godot Web 小游戏。
2. `ch12-solar-survivor` 示例游戏：面向第 12 章“太阳追踪控制系统”的章节复习小游戏，中文名暂定为“追光幸存者”。

## 2. 当前交付物

### 2.1 Godot 通用接入接口

位置：

```text
packages/edugame/src/modes/godot-game/
packages/edugame/src/core/EduGameHost.tsx
packages/edugame/godot/template/
```

主要能力：

- 新增 `modeId: "godot-game"`。
- 播放器通过 iframe 加载 Godot Web 导出的 `index.html`。
- Web 播放器和 Godot 游戏通过 `window.postMessage` 通信。
- 支持 READY、INIT、PROGRESS、COMPLETE、LOG、PAUSE、RESUME、RESET 等消息。
- Web 侧会将 Godot 回传分数归一化到 `0..100`。
- Web 侧会根据 `starThresholds` 兼容旧成绩系统自动推导星级。
- Web 侧防止同一局多次 `complete` 重复结算。

### 2.2 Godot 模板工程

位置：

```text
packages/edugame/godot/template/
```

模板用途：

- 作为后续新 Godot 小游戏的复制起点。
- 内置公共桥接脚本 `scripts/godot_bridge.gd`。
- 内置最小示例关卡 `levels/gpio_wiring_01.json`。
- 可用 Godot 4.x 打开。

### 2.3 第 12 章游戏：追光幸存者

源工程位置：

```text
packages/edugame/godot/games/ch12-solar-survivor/
```

播放器运行产物位置：

```text
apps/player/public/assets/godot/ch12-solar-survivor/
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

## 3. 游戏内容说明

### 3.1 游戏定位

“追光幸存者”是一个 2D 顶视角教学复习小游戏，用轻量街机循环包装第 12 章知识点。它借鉴自动成长、自动攻击、经验升级节奏，但核心难度不是操作，而是答题和知识掌握。

核心原则：

```text
操作低难度，答题高权重。
```

覆盖知识点：

- 四象限光敏传感器
- 光照方向误差
- 舵机 PWM 控制
- Kp / Ki / Kd
- 死区阈值
- 输出限幅
- 积分限幅 / 抗饱和
- 滤波抗干扰
- 控制性能评估

### 3.2 当前实际配置

关卡配置位置：

```text
packages/edugame/godot/games/ch12-solar-survivor/levels/ch12_solar_survivor_level.json
```

当前实际参数：

| 参数 | 当前值 |
| --- | ---: |
| 单局时长 | 180 秒 |
| 最大故障数 | 5 |
| 答题时间 | 15 秒 |
| 分数回传比例 | 游戏内追光分 / 100 |
| 题库 | `res://data/questions.sample.json` |
| 升级库 | `res://data/upgrades.sample.json` |

说明：早期设计文档里曾建议 5 分钟、3 次故障、10 秒答题；当前代码已调整为 180 秒、5 次故障、15 秒答题，更适合快速演示和首次试玩。

### 3.3 当前玩法

玩家操作：

- `WASD` 或方向键移动。
- `P` 或 `Esc` 暂停/继续。
- 点击按钮回答题目、选择升级、重新开始。

核心循环：

```text
进入地图
  -> 普通光能自动产生并飞向玩家
  -> 偏移光能带出现，玩家靠近可获得更高收益
  -> 光能条满后进入答题
  -> 答对后选择升级
  -> 答错增加系统故障并降低稳定度
  -> 继续追光，直到倒计时结束或系统停机
```

已经实现的游戏机制：

- 玩家移动
- 光能自动吸收
- 偏移光能带
- 追光分
- 追光效率
- 稳定度
- 系统故障
- 答题弹窗
- 答错反馈
- 升级三选一
- 自动校正脉冲
- 干扰物/异常信号
- 暂停、继续、重新开始
- 结算页
- 向播放器回传完成结果

### 3.4 题库与升级

题库位置：

```text
packages/edugame/godot/games/ch12-solar-survivor/data/questions.sample.json
```

当前题目数量：

```text
25 题
```

升级库位置：

```text
packages/edugame/godot/games/ch12-solar-survivor/data/upgrades.sample.json
```

当前升级数量：

```text
10 个
```

已包含升级示例：

- 舵机 PWM 标定
- Kp 比例增益
- Ki 稳态补偿
- Kd 阻尼预测
- DZ 死区阈值
- LIM 输出限幅
- 校正脉冲提频
- 多点采样锁定
- 滤波视场扩展
- 四象限差分桥

## 4. 目录结构

Godot 相关目录：

```text
packages/edugame/
  src/
    modes/godot-game/
      GodotGameMode.ts
      protocol.ts
      index.ts
    core/
      EduGameHost.tsx
      LevelLoader.ts
  __tests__/
    godot-game.test.ts
  godot/
    README.md
    template/
      project.godot
      export_presets.cfg
      GODOT_INTEGRATION.md
      scenes/main.tscn
      scripts/godot_bridge.gd
      scripts/game_root.gd
      levels/gpio_wiring_01.json
    games/
      ch12-solar-survivor/
        project.godot
        export_presets.cfg
        DESIGN.md
        ASSET_PLAN.md
        scenes/main.tscn
        scripts/godot_bridge.gd
        scripts/solar_survivor_root.gd
        levels/ch12_solar_survivor_level.json
        data/questions.sample.json
        data/upgrades.sample.json
        assets/
```

播放器运行产物目录：

```text
apps/player/public/assets/godot/ch12-solar-survivor/
```

## 5. Godot 与播放器通信协议

协议版本：

```text
GODOT_BRIDGE_VERSION = 1
```

协议定义位置：

```text
packages/edugame/src/modes/godot-game/protocol.ts
```

Godot 公共桥接脚本：

```text
packages/edugame/godot/template/scripts/godot_bridge.gd
packages/edugame/godot/games/ch12-solar-survivor/scripts/godot_bridge.gd
```

### 5.0 知识包注入

当前已经支持把题库、升级和绑定关系放在课程侧，再由播放器注入 Godot：

```text
courses/stm32f10x/knowledge/
courses/stm32f10x/game-bindings/
```

播放器静态访问路径：

```text
/assets/courses/stm32-course/knowledge/ch12-solar-survivor.questions.json
/assets/courses/stm32-course/knowledge/ch12-solar-survivor.upgrades.json
/assets/courses/stm32-course/game-bindings/ch12-solar-survivor.binding.json
```

运行逻辑：

```text
Godot 负责玩法和表现
课程知识包负责题库、解释和升级文案
binding 负责把知识模块映射到游戏反馈
```

Godot 侧优先读取 `DGB_GODOT_INIT.data.questions`、`data.upgrades` 和 `data.bindings`。如果播放器没有注入，则回退读取本地 `res://data/*.sample.json`，方便在 Godot 编辑器里离线预览。

可回滚开关：

```json
"knowledgeSource": "external"
```

表示使用课程知识包。需要回滚时改为：

```json
"knowledgeSource": "embedded"
```

播放器将跳过外部知识包加载，Godot 使用工程内置 sample。也可用浏览器 `localStorage` 临时覆盖：

```js
localStorage.setItem('dgbook:godot:ch12-solar-survivor:knowledgeSource', 'embedded')
```

### 5.1 播放器加载流程

```text
EduGameHost
  -> GodotGamePanel
    -> iframe /assets/godot/<game-id>/index.html
      -> Godot Web runtime
```

推荐握手链路：

```text
Godot -> 播放器: DGB_GODOT_READY
播放器 -> Godot: DGB_GODOT_INIT
Godot -> 播放器: DGB_GODOT_PROGRESS
Godot -> 播放器: DGB_GODOT_COMPLETE
```

### 5.2 关卡 JSON 示例

```json
{
  "modeId": "godot-game",
  "levelId": "ch12-solar-survivor-mvp",
  "title": "追光幸存者：太阳追踪挑战",
  "objective": "复习四象限光敏、舵机 PWM、PID、死区与限幅",
  "difficulty": 3,
  "starThresholds": [50, 75, 90],
  "timeLimit": 0,
  "data": {
    "gameId": "ch12-solar-survivor",
    "entryUrl": "/assets/godot/ch12-solar-survivor/index.html",
    "aspectRatio": "16 / 9",
    "durationSec": 180,
    "maxFaults": 5,
    "questionTimeSec": 15
  }
}
```

播放器强依赖字段：

- `data.gameId`
- `data.entryUrl`

游戏自定义字段：

- `durationSec`
- `maxFaults`
- `questionTimeSec`
- `questionsUrl`
- `upgradesUrl`
- 其他后续游戏需要的配置

### 5.3 Godot 发送 READY

```json
{
  "type": "DGB_GODOT_READY",
  "version": 1,
  "gameId": "ch12-solar-survivor"
}
```

### 5.4 播放器发送 INIT

```json
{
  "type": "DGB_GODOT_INIT",
  "version": 1,
  "level": {},
  "data": {}
}
```

### 5.5 Godot 回传进度

```json
{
  "type": "DGB_GODOT_PROGRESS",
  "progress": 0.66,
  "hint": "追光分 4200",
  "stats": {
    "correct": 4,
    "wrong": 1
  }
}
```

要求：

- `progress` 范围为 `0..1`。
- `stats` 只能放数字字段。
- 字符串说明放到 `hint` 或 `DGB_GODOT_LOG`。

### 5.6 Godot 回传完成

```json
{
  "type": "DGB_GODOT_COMPLETE",
  "score": 86,
  "stars": 0,
  "durationMs": 180000,
  "stats": {
    "solarScore": 8600,
    "correct": 7,
    "wrong": 1,
    "trackingEfficiency": 91,
    "stability": 82,
    "shutdown": 0
  }
}
```

说明：

- `score` 是给播放器成绩系统的 `0..100` 分数。
- 游戏内显示的是 `solarScore`，建议 `0..10000`。
- 当前游戏传 `stars: 0`，因为结算页主展示追光分和称号，不以星级作为目标。
- 如果 Godot 不传 `stars`，Web 侧会按 `starThresholds` 自动推导。

## 6. 开发和运行方式

### 6.1 安装前端依赖

在项目根目录执行：

```powershell
pnpm install
```

### 6.2 启动播放器

```powershell
pnpm -F @dgbook/player dev
```

然后在浏览器访问 Vite 输出的本地地址，通常是：

```text
http://localhost:5173/
```

Godot Web 导出物已经放在：

```text
apps/player/public/assets/godot/ch12-solar-survivor/index.html
```

因此播放器可通过下面的静态路径加载：

```text
/assets/godot/ch12-solar-survivor/index.html
```

### 6.3 打开 Godot 源工程

需要 Godot 4.x。

打开：

```text
packages/edugame/godot/games/ch12-solar-survivor/project.godot
```

主场景：

```text
packages/edugame/godot/games/ch12-solar-survivor/scenes/main.tscn
```

主脚本：

```text
packages/edugame/godot/games/ch12-solar-survivor/scripts/solar_survivor_root.gd
```

### 6.4 重新导出 Godot Web

在 Godot 编辑器中使用 Web 导出预设，导出到：

```text
apps/player/public/assets/godot/ch12-solar-survivor/
```

入口文件需要保持为：

```text
index.html
```

这样关卡 JSON 中的 `entryUrl` 不需要修改。

## 7. 素材说明

素材库位置：

```text
packages/edugame/godot/games/ch12-solar-survivor/assets/
```

目录约定：

- `sprites/`：游戏内直接使用的角色、干扰物、光球、UI 面板等成品贴图。
- `reference/`：视觉风格参考图，当前浅色电路板风格主要来自这里。
- `concept/`：概念图和早期风格稿。
- `fonts/`：内嵌中文字体，保证 Web 导出后中文 UI 可独立显示。
- `source-prompts/`：素材生成提示词或过程记录。

当前已接入的主要贴图：

- `player_rover.png`
- `light_orb.png`
- `offset_band.png`
- `energy_panel.png`
- `error_block.png`
- `sampling_noise_source.png`
- `noise_pulse.png`
- `shadow_cloud.png`
- `stray_light.png`
- `control_saturation_block.png`
- `actuator_oscillation_core.png`

素材风格方向：

```text
浅色电路板背景 + 蓝灰 UI + 金色太阳能粒子 + 少量青色高亮。
```

设计上应避免恐怖、战斗、过暗、过重惩罚感，保持教学产品的清晰、友好和可读性。

## 8. 已验证内容

已验证：

- `godot-game` 模式代码已接入 `@dgbook/game`。
- `LevelLoader` 已允许加载 `modeId: "godot-game"`。
- `@dgbook/game` 已导出 Godot 模式和协议类型。
- Web 侧有单测覆盖分数归一化、星级推导和重复完成防护。
- Godot 源工程、场景、桥接脚本、题库、升级库、素材目录均已建立。
- `ch12-solar-survivor` 的 Godot Web 导出产物已存在于播放器静态资源目录。

相关测试文件：

```text
packages/edugame/__tests__/godot-game.test.ts
```

历史执行记录：

```powershell
pnpm.cmd --filter @dgbook/game typecheck
pnpm.cmd --filter @dgbook/game test
```

记录结果：

```text
TypeScript 检查通过。
@dgbook/game 测试通过。
```

## 9. 当前限制与待确认

需要继续确认：

- 在装有 Godot 4.x 的机器上重新打开工程并检查导入状态。
- 重新导出 Web 后，在播放器内做一次完整冒烟测试。
- 确认线上部署环境是否允许 Godot Web 的 `.wasm`、`.pck`、worklet 文件正常加载。
- 确认 `SharedArrayBuffer`、音频 worklet、浏览器跨源隔离等 Web 导出运行条件是否需要额外服务器配置。
- 将示例题库扩展为正式题库，并由课程老师审校。
- 如果要面向正式课堂使用，需要补一份学生端操作说明和教师端验收表。

当前还可以继续优化：

- 关卡入口和课程页面的整合方式。
- 结算页的复习建议更精细地按错题模块生成。
- 题库从 sample 文件升级为正式版本。
- 升级选项按题目知识点进行更强关联。
- 增加 Web 端集成测试，验证 iframe 消息链路。
- 增加 Godot 导出流程说明截图。

## 10. 后续新增 Godot 小游戏的流程

1. 复制模板：

```text
packages/edugame/godot/template
```

到：

```text
packages/edugame/godot/games/<game-id>
```

2. 用 Godot 4.x 打开新目录下的 `project.godot`。

3. 保留或复用：

```text
scripts/godot_bridge.gd
```

4. 替换玩法脚本和主场景。

5. 在关卡 JSON 中配置：

```json
{
  "modeId": "godot-game",
  "data": {
    "gameId": "<game-id>",
    "entryUrl": "/assets/godot/<game-id>/index.html"
  }
}
```

6. 导出 Web 到：

```text
apps/player/public/assets/godot/<game-id>/
```

7. 在播放器中验证 READY、INIT、PROGRESS、COMPLETE 四类消息。
