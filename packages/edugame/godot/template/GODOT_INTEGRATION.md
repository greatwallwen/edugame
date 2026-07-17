# Godot 小游戏公共模板说明

本文档说明本次新增的 Godot 小游戏板块能力、目录用途、接入协议、制作流程和注意事项。

## 本次已完成的工作

### 1. Web 播放器侧接入

在 `@dgbook/game` 中新增了一个通用游戏模式：

- `modeId: "godot-game"`
- 模式类：`packages/edugame/src/modes/godot-game/GodotGameMode.ts`
- 协议定义：`packages/edugame/src/modes/godot-game/protocol.ts`
- React 宿主面板：`packages/edugame/src/core/EduGameHost.tsx` 中的 `GodotGamePanel`

播放器侧现在可以用 iframe 加载 Godot Web 导出的 `index.html`，并通过 `window.postMessage` 与 Godot 游戏交换数据。

### 2. 关卡加载白名单

`packages/edugame/src/core/LevelLoader.ts` 已加入 `godot-game`，所以 JSON 关卡可以通过现有 `loadLevel()` 校验。

### 3. 包导出

`packages/edugame/src/index.ts` 和 `packages/edugame/package.json` 已导出 Godot 模式与协议类型，后续其他包可以复用：

```ts
import {
  GodotGameMode,
  type GodotGameData,
  GODOT_BRIDGE_VERSION,
} from '@dgbook/game';
```

### 4. Godot 模板工程

新增模板目录：

```text
packages/edugame/godot/template/
  project.godot
  export_presets.cfg
  README.md
  GODOT_INTEGRATION.md
  icon.svg
  scenes/main.tscn
  addons/dgbook_runtime/runtime.gd
  scripts/game_root.gd
  levels/gpio_wiring_01.json
```

这个模板可以直接用 Godot 4.x 打开。当前示例是一个极简 GPIO 接线实验室，用三个检查项模拟“限流电阻、LED 极性、PA5 输出高电平”，用于验证协议链路。

### 5. 测试覆盖

新增测试：

```text
packages/edugame/__tests__/godot-game.test.ts
```

覆盖内容：

- Godot 回传分数的 `0..100` 归一化
- 根据关卡 `starThresholds` 推导星级
- 防止同一局 Godot 多次 complete 重复结算

已执行：

```powershell
pnpm.cmd --filter @dgbook/game typecheck
pnpm.cmd --filter @dgbook/game test
```

结果：TypeScript 检查通过，测试 `5 passed / 62 passed`。

## 整体架构

Godot 小游戏不直接打进 React bundle，而是以 Web 导出产物的形式放到播放器静态资源目录：

```text
apps/player/public/assets/godot/<game-id>/index.html
```

播放器通过 iframe 加载：

```text
EduGameHost
  -> GodotGamePanel
    -> iframe /assets/godot/<game-id>/index.html
      -> Godot Web runtime
```

通信走浏览器标准 `postMessage`：

```text
播放器 -> Godot: DGB_GODOT_INIT / PAUSE / RESUME / RESET
Godot -> 播放器: DGB_GODOT_READY / PROGRESS / COMPLETE / LOG
```

这种方式的好处：

- Godot Web 导出是静态文件，部署简单
- 每个小游戏可以独立更新
- Godot runtime 与 React 应用隔离，减少依赖冲突
- 后续可以为不同课程复用同一个 Godot 游戏模板

## 关卡 JSON 结构

最小可用示例：

```json
{
  "modeId": "godot-game",
  "levelId": "godot-gpio-wiring-01",
  "title": "GPIO Wiring Lab: Light the LED",
  "objective": "Understand LED polarity, current limiting, and GPIO output level",
  "difficulty": 2,
  "starThresholds": [60, 80, 95],
  "timeLimit": 0,
  "data": {
    "gameId": "gpio-lab",
    "entryUrl": "/assets/godot/gpio-lab/index.html",
    "aspectRatio": "16 / 9",
    "target": "led_on",
    "rules": ["need_resistor", "correct_polarity", "pa5_output"]
  }
}
```

播放器只强依赖 `data.gameId` 和 `data.entryUrl`。其余字段都由具体 Godot 小游戏自己解释。

建议约定：

- `gameId`：小游戏类型，例如 `gpio-lab`、`pwm-tuning`、`uart-decoder`
- `entryUrl`：Godot Web 导出的入口 HTML
- `aspectRatio`：iframe 显示比例，默认 `16 / 9`
- `initialState`：初始电路、参数或任务状态
- `rules`：本关需要达成的判定规则
- `components`：本关可用器件或工具

## 通信协议

### Godot 通知已就绪

Godot 启动后发送：

```json
{
  "type": "DGB_GODOT_READY",
  "version": 1,
  "gameId": "gpio-lab"
}
```

宿主收到后会发送初始化数据。

### 播放器发送初始化数据

```json
{
  "type": "DGB_GODOT_INIT",
  "version": 1,
  "level": {},
  "data": {}
}
```

`level` 是完整 `LevelData`，`data` 是 `level.data` 的快捷副本。

### Godot 回传进度

```json
{
  "type": "DGB_GODOT_PROGRESS",
  "progress": 0.66,
  "hint": "2/3 checks passed",
  "stats": {
    "passed": 2,
    "mistakes": 1
  }
}
```

要求：

- `progress` 应为 `0..1`
- `stats` 只放数值字段，方便成绩系统统计

### Godot 完成关卡

```json
{
  "type": "DGB_GODOT_COMPLETE",
  "score": 92,
  "durationMs": 18000,
  "stats": {
    "mistakes": 1,
    "passed": 3
  }
}
```

要求：

- `score` 推荐 Godot 侧给 `0..100`
- 如果不传 `stars`，Web 侧会用 `starThresholds` 自动计算
- 同一局多次发送 `DGB_GODOT_COMPLETE`，Web 侧只会结算第一次

### Godot 日志

```json
{
  "type": "DGB_GODOT_LOG",
  "level": "info",
  "message": "Godot level initialized."
}
```

用于开发期排查 iframe 通信问题。

## Godot 模板脚本说明

### `addons/dgbook_runtime/runtime.gd`

这是公共桥接脚本，建议后续小游戏直接复用。

主要职责：

- Web 环境下注册 `window.message` 监听
- 接收播放器发来的 `DGB_GODOT_INIT`
- 提供 `send_progress()` / `send_complete()` / `send_log()`
- 本地非 Web 运行时提供一份 sample init，方便在 Godot 编辑器里预览

常用方法：

```gdscript
bridge.send_progress(0.5, "2/4 checks passed", {"mistakes": 1})
bridge.send_complete(90, -1, elapsed_ms, {"mistakes": 1})
bridge.send_log("Level initialized.")
```

### `scripts/game_root.gd`

这是示例玩法脚本，不是强制公共逻辑。

当前做了一个 GPIO 演示：

- 切换 3 个检查项
- 每次变化回传进度
- 全部通过后回传完成结果
- 重置时使用 `set_pressed_no_signal(false)`，避免误触发 toggle 事件
- 根节点和 bridge 设置了 `PROCESS_MODE_ALWAYS`，避免暂停后无法恢复

后续正式小游戏可以替换这个脚本，但建议保留 bridge 接入方式。

## 制作新 Godot 小游戏的推荐流程

1. 复制模板目录：

```text
packages/edugame/godot/template
```

到：

```text
packages/edugame/godot/games/<game-id>
```

2. 用 Godot 4.x 打开 `project.godot`。

3. 运行 `pnpm godot:runtime:sync`，保留生成的 `addons/dgbook_runtime/`，替换或扩展 `scripts/game_root.gd`。

4. 在 Godot 中设计实际玩法场景。

5. 游戏启动后等待 `init_received`：

```gdscript
bridge.init_received.connect(_on_init_received)
```

6. 每次关键操作后回传进度：

```gdscript
bridge.send_progress(progress, hint, stats)
```

7. 完成后回传分数：

```gdscript
bridge.send_complete(score, -1, elapsed_ms, stats)
```

8. 导出 Web 到：

```text
apps/player/public/assets/godot/<game-id>/index.html
```

9. 在课程关卡 JSON 中使用：

```json
{
  "modeId": "godot-game",
  "data": {
    "gameId": "<game-id>",
    "entryUrl": "/assets/godot/<game-id>/index.html"
  }
}
```

## 适合优先开发的小游戏类型

建议优先从这些做起：

- `gpio-lab`：GPIO 接线、LED、按键、上拉下拉
- `pwm-tuning`：调 `PSC / ARR / CCR`，实时看频率和占空比
- `uart-decoder`：调波特率、校验位、停止位，修复乱码
- `adc-filter-lab`：采样频率、阈值、防抖、滑动平均
- `interrupt-priority`：配置 NVIC 优先级，避免关键任务超时

优先级建议：

1. GPIO 接线实验室
2. PWM 调参挑战
3. 串口报文破译

这三类最贴 STM32 入门课程，也最容易做出“实训感”。

## 注意事项

### 1. 不要把 Godot runtime 混进 React bundle

当前设计是 iframe 加载 Godot Web 静态导出，保持隔离。不要在 React 里直接 import Godot runtime。

### 2. `entryUrl` 要指向播放器可访问的静态路径

推荐：

```text
/assets/godot/<game-id>/index.html
```

对应文件位置：

```text
apps/player/public/assets/godot/<game-id>/index.html
```

### 3. Godot 侧必须发送 READY

Web 宿主会在 iframe `onLoad` 时尝试发送 init，但更可靠的链路是：

```text
Godot READY -> Host INIT -> Godot init_received
```

模板已经实现了这条链路。

### 4. 完成结果只发一次

Godot 玩法侧最好自己避免重复 `send_complete()`。Web 侧也有防重结算，但不要依赖它处理玩法状态。

### 5. `stats` 只放数字

`GameResult.stats` 类型是 `Record<string, number>`。字符串类说明放在 `hint` 或日志里，不要塞进 `stats`。

### 6. 暂停恢复要小心

如果游戏实现了暂停，桥接节点需要保持可处理消息。模板中已经设置：

```gdscript
process_mode = Node.PROCESS_MODE_ALWAYS
bridge.process_mode = Node.PROCESS_MODE_ALWAYS
```

### 7. Godot 版本

模板面向 Godot 4.x。当前机器未安装 `godot` CLI，因此还没有做编辑器导入或 Web 导出级验证。

## 已知验证边界

已验证：

- TypeScript 类型检查通过
- `@dgbook/game` 单测通过
- Godot 关卡 JSON 可解析
- 模板关键文件存在
- Web 宿主协议和分数结算逻辑有测试覆盖

未验证：

- Godot 编辑器打开工程
- Godot Web 导出产物实际加载
- 浏览器中 iframe 与导出后的 Godot runtime 实测通信

原因：当前环境没有 `godot` 命令。

下一步建议在安装 Godot 4.x 的机器上做一次完整冒烟：

1. 打开 `packages/edugame/godot/template/project.godot`
2. 运行主场景，确认本地 sample init 生效
3. 导出 Web 到 `apps/player/public/assets/godot/gpio-lab/`
4. 用 `modeId: "godot-game"` 的关卡打开播放器
5. 确认 READY、INIT、PROGRESS、COMPLETE 四类消息都能走通
