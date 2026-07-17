# 第 11 章手环数据链路防线 Godot 灰盒 MVP 设计

## 1. 背景

DGBook 已经具备通用 Godot Web 小游戏接入能力：

- 播放器通过 `modeId: "godot-game"` 加载 Godot Web 导出物。
- Godot 与播放器通过 `DGB_GODOT_READY / INIT / PROGRESS / COMPLETE` 通信。
- `packages/edugame/godot/template/` 提供可复制的 Godot 模板工程。
- `ch12-solar-survivor` 已验证了一套“Godot 工程 + 题库 + 升级 + 回传”的小游戏形态。

本设计要新增一个第 11 章“运动手环”复习小游戏原型，先做灰盒可玩 MVP。目标不是一次做完正式美术和完整题库，而是尽快用 Godot MCP 落出可运行、可验证、可迭代的塔防骨架。

## 2. 设计决策

本次选择路线：

- 新建独立 Godot 工程，不改造现有 `ch12-solar-survivor`。
- 游戏主题覆盖第 11 章综合知识点，而不是只聚焦 IMU、PPG 或低功耗单点。
- 第一版采用灰盒 MVP：固定路径、固定塔位、少量波次、少量题目、最小 UI。
- 答题机制采用“答题给资源 + 首次答对模块题解锁对应塔”。

项目名建议：

```text
ch11-band-defense
```

中文名建议：

```text
手环数据链路防线
```

## 3. 学习目标

MVP 覆盖第 11 章主线知识：

| 知识模块 | 游戏表达 |
| --- | --- |
| IMU / MPU6050 / LSM6DS3 采集 | 身体运动信号进入数据链路，需要正确初始化和采样 |
| I2C 与传感器配置 | I2C 初始化塔负责识别采集配置问题 |
| 加速度合矢量与计步 | 峰值检测塔负责识别有效步态峰值 |
| 阈值、防抖、滤波 | 滤波塔、防抖效果克制噪声、抖动、假峰值 |
| PPG 心率信号 | 心率干扰作为敌人类型或题目模块出现 |
| OLED 显示与数据同步 | 可信数据核心代表步数、心率、电量等输出结果 |
| STOP 模式、WOM 唤醒、低功耗 | 低功耗塔克制功耗尖峰和同步延迟 |

核心教学原则：

```text
塔防只是载体，题目和塔的知识映射必须清楚。
```

## 4. MVP 范围

第一版必须做：

- 一个 16:9 的 2D Control 根场景。
- 一条固定路径，敌人按预设点移动。
- 四个固定塔位。
- 三波敌人。
- 四类塔：I2C 初始化塔、滤波塔、峰值检测塔、低功耗塔。
- 建塔和升级消耗能量。
- 塔类型与敌人类型存在克制关系：打对敌人加伤害，打错敌人大幅降低伤害。
- 波间答题，答对给能量；首次答对模块题解锁对应塔。
- 漏防计数、链路稳定度、可信数据计数、波次显示。
- 胜利/失败结算。
- 通过 `godot_bridge.gd` 发送 progress 和 complete。

第一版不做：

- 自由摆塔。
- 复杂寻路。
- 大规模波次。
- 正式图片素材。
- 完整课程知识包注入。
- 真实传感器信号仿真。
- 复杂塔升级树。
- 多地图、多难度、商店或养成系统。

## 5. 游戏循环

```text
进入场景
  -> 显示灰盒路径、塔位和 HUD
  -> 第 1 波敌人沿固定路径移动
  -> 玩家在已解锁塔位建塔
  -> 塔自动攻击匹配或通用敌人
  -> 漏过敌人会降低链路稳定度并增加漏防
  -> 波次结束后弹出答题面板
  -> 答对：获得能量，首次答对该模块题会解锁对应塔
  -> 答错：少量或不获得能量，记录错题模块
  -> 进入下一波
  -> 3 波结束或漏防过多后结算
```

胜利条件：

```text
完成 3 波，并且漏防数没有达到失败上限。
```

失败条件：

```text
漏防数达到 5，表示手环数据链路失真。
```

## 6. 场景布局

主场景采用单屏灰盒 UI：

- 左侧 75%：塔防路径和塔位。
- 右侧 25%：HUD、建塔按钮、当前波次状态。
- 中央路径：从“身体信号入口”到“可信数据核心”。
- 四个固定塔位分布在路径附近。
- 波间答题面板作为全屏半透明弹窗。
- 结算面板复用弹窗层。

HUD 显示：

```text
波次：1 / 3
能量：80
可信数据：0 / 20
链路稳定度：100%
漏防：0 / 5
答题正确：0
答题错误：0
```

## 7. 塔与敌人

### 7.1 塔

| 塔 | 解锁方式 | MVP 效果 | 知识映射 |
| --- | --- | --- | --- |
| I2C 初始化塔 | 默认可用 | 中速单体攻击，克制配置错误 | I2C 地址、WHO_AM_I、采样率配置 |
| 滤波塔 | 答对滤波/阈值题解锁 | 范围减速，克制噪声和抖动 | 滤波、阈值、防抖 |
| 峰值检测塔 | 答对计步题解锁 | 高伤害单体，克制假峰值 | 合加速度、峰值检测、步间隔 |
| 低功耗塔 | 答对低功耗题解锁 | 周期脉冲攻击，克制功耗尖峰 | STOP 模式、WOM、中断唤醒 |

MVP 中塔只需要三个属性：

```text
range
damage
fireInterval
```

塔可升级一次：

```text
level 1 -> level 2
```

升级提升伤害或射速，不引入分支。

### 7.2 克制与错配伤害

为了让塔防选择和知识点匹配更清晰，MVP 增加塔与敌人的克制机制：

```text
正确克制：最终伤害 = 基础伤害 × 1.8
错误错配：最终伤害 = 基础伤害 × 0.25
```

规则：

- 每种塔有一个 `counterTags` 列表。
- 每种敌人有一个 `threatTag`。
- `threatTag` 命中塔的 `counterTags` 时，造成克制伤害。
- 如果塔攻击了不匹配的敌人，只造成 25% 伤害。
- 默认可用的 I2C 初始化塔只保证玩家能处理第 1 波中的配置错误敌人，不承担万能塔职责。

示例：

| 塔 | 克制标签 | 打对敌人 | 打错敌人 |
| --- | --- | --- | --- |
| I2C 初始化塔 | `config` | 配置错误 | 噪声包、假峰值、功耗尖峰低效伤害 |
| 滤波塔 | `noise`, `jitter` | 噪声包 | 配置错误、功耗尖峰低效伤害 |
| 峰值检测塔 | `false_peak`, `missed_step` | 假峰值 | 噪声包、功耗尖峰低效伤害 |
| 低功耗塔 | `power` | 功耗尖峰 | 噪声包、假峰值低效伤害 |

UI 反馈：

- 打对时显示短标签：`克制 +80%`。
- 打错时显示短标签：`不匹配`。
- 反馈只做轻量飘字，不打断游戏节奏。

### 7.3 敌人

| 敌人 | 行为 | 弱点塔 | 知识隐喻 |
| --- | --- | --- | --- |
| 噪声包 | 普通速度，普通血量 | 滤波塔 | 原始传感器噪声 |
| 假峰值 | 快速，低血量 | 峰值检测塔 | 手臂晃动造成误计步 |
| 配置错误 | 慢速，高血量 | I2C 初始化塔 | 地址、寄存器、采样率错误 |
| 功耗尖峰 | 间歇加速 | 低功耗塔 | 没有休眠或唤醒策略导致耗电 |

MVP 只需在视觉上用不同颜色圆点区分敌人。

## 8. 答题与解锁

题目内置在 Godot 工程的 sample JSON 中，后续再抽到课程侧知识包。

文件建议：

```text
packages/edugame/godot/games/ch11-band-defense/data/questions.sample.json
```

题目结构：

```json
{
  "id": "ch11-step-threshold-001",
  "module": "step",
  "knowledgePoint": "峰值检测计步",
  "prompt": "计步算法中为什么要设置最小步间隔？",
  "choices": [
    "避免一次晃动被重复计为多步",
    "提高 I2C 时钟频率",
    "降低 OLED 分辨率",
    "关闭加速度计"
  ],
  "answerIndex": 0,
  "explanation": "最小步间隔相当于时间防抖，能避免同一次摆动产生多个峰值被重复计步。",
  "unlockTag": "peak"
}
```

模块到塔的映射：

| `unlockTag` | 解锁内容 |
| --- | --- |
| `i2c` | I2C 初始化塔强化或建塔资源 |
| `filter` | 解锁滤波塔 |
| `peak` | 解锁峰值检测塔 |
| `power` | 解锁低功耗塔 |
| `ppg` | 给额外资源，MVP 不单独做 PPG 塔 |

答题奖励：

- 答对：能量 +60。
- 答错：能量 +15。
- 首次答对某个 `unlockTag`：解锁对应塔或允许升级。

## 9. 数据文件

MVP 使用三个本地数据文件：

```text
levels/ch11_band_defense_level.json
data/questions.sample.json
data/waves.sample.json
```

`levels/ch11_band_defense_level.json` 用于播放器和本地配置：

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

`waves.sample.json` 只描述 3 波敌人：

```json
[
  { "wave": 1, "enemies": [{ "type": "noise", "count": 6 }, { "type": "config", "count": 2 }] },
  { "wave": 2, "enemies": [{ "type": "noise", "count": 5 }, { "type": "false_peak", "count": 5 }] },
  { "wave": 3, "enemies": [{ "type": "power_spike", "count": 4 }, { "type": "false_peak", "count": 4 }, { "type": "config", "count": 3 }] }
]
```

## 10. Godot 架构

工程目录：

```text
packages/edugame/godot/games/ch11-band-defense/
  project.godot
  export_presets.cfg
  scenes/main.tscn
  scripts/godot_bridge.gd
  scripts/band_defense_root.gd
  scripts/enemy.gd
  scripts/tower.gd
  scripts/wave_director.gd
  scripts/quiz_controller.gd
  levels/ch11_band_defense_level.json
  data/questions.sample.json
  data/waves.sample.json
```

### 10.1 `band_defense_root.gd`

职责：

- 初始化主场景。
- 加载 level、questions、waves。
- 创建路径、塔位、HUD、弹窗。
- 管理游戏状态。
- 接收 bridge init。
- 汇总并发送 progress / complete。

状态：

```text
intro -> wave_running -> quiz -> wave_running -> result
```

### 10.2 `wave_director.gd`

职责：

- 根据 `waves.sample.json` 生成敌人。
- 控制波次开始、结束。
- 通知 root 进入答题或结算。

### 10.3 `enemy.gd`

职责：

- 沿路径点移动。
- 维护血量、类型、速度。
- 到达终点时通知漏防。

### 10.4 `tower.gd`

职责：

- 定时寻找范围内敌人。
- 根据塔的 `counterTags` 和敌人的 `threatTag` 计算克制或错配伤害。
- 对敌人造成伤害或减速，并触发轻量反馈标签。
- 支持 level 1 / level 2。

### 10.5 `quiz_controller.gd`

职责：

- 从题库中按模块挑题。
- 渲染题目面板。
- 处理选择、奖励、解锁、错题记录。

## 11. Godot MCP 操作流程

实现阶段优先使用 Godot MCP 做这些验证：

1. 打开或确认当前 Godot 项目。
2. 复制模板并让编辑器打开 `ch11-band-defense/project.godot`。
3. 打开 `res://scenes/main.tscn`。
4. 播放当前场景。
5. 获取运行截图。
6. 获取 Godot 错误日志。
7. 迭代脚本直到场景可运行。

MVP 的“完成”标准以 Godot 编辑器运行通过为准；Web 导出和播放器接入作为后续实现计划中的独立阶段。

## 12. 进度与结算回传

运行中定期回传：

```gdscript
bridge.send_progress(progress, hint, {
  "wave": current_wave,
  "leaks": leaks,
  "stable": link_stability,
  "correct": correct_count,
  "wrong": wrong_count
})
```

结算回传：

```gdscript
bridge.send_complete(host_score, 0, elapsed_ms, {
  "bandScore": band_score,
  "wavesCleared": waves_cleared,
  "leaks": leaks,
  "correct": correct_count,
  "wrong": wrong_count,
  "linkStability": link_stability,
  "shutdown": shutdown
})
```

`stats` 只放数字字段。

分数建议：

```text
bandScore = 3000
          + wavesCleared * 1200
          + correctCount * 500
          + trustedData * 80
          + linkStability * 20
          - leaks * 600
          - wrongCount * 300
```

失败时：

```text
bandScore 上限锁到 3000
```

播放器分数：

```text
hostScore = clamp(round(bandScore / 100), 0, 100)
```

## 13. 测试与验收

本地 Godot 验收：

- 打开主场景无脚本错误。
- 点击开始后第 1 波生成敌人。
- 敌人沿路径移动。
- 建塔后塔会攻击敌人。
- 塔打到克制敌人时伤害明显提高。
- 塔打到错误敌人时伤害明显降低。
- 敌人死亡会增加可信数据或奖励。
- 敌人漏防会增加漏防数并降低稳定度。
- 每波结束会出现答题面板。
- 答对会给能量并解锁对应塔。
- 3 波结束出现胜利结算。
- 漏防达到 5 出现失败结算。
- 结算只发送一次 complete。

代码侧验收：

- 新文件保持在 `packages/edugame/godot/games/ch11-band-defense/` 内。
- 不修改现有 `ch12-solar-survivor` 行为。
- 不手改生成产物 `apps/player/public/manifest.json`。
- 若添加播放器课程入口，必须通过源生成脚本或单独后续计划处理。

## 14. 风险与约束

- Godot MCP 当前连接的是 `ch12-solar-survivor` 项目，实现阶段需要确认能否切换到新项目。
- 如果 MCP 只能操作当前项目，先用文件系统创建工程，再由用户或命令行打开新 `project.godot`。
- 视觉伴侣产生的 `.superpowers/` 文件是讨论辅助产物，不属于游戏源码。
- 第一版题库较小，不能代表正式章节测评质量。
- 灰盒 UI 不代表最终美术风格。

## 15. 后续演进

灰盒 MVP 通过后，再分阶段推进：

1. 扩充第 11 章正式题库和解锁绑定。
2. 增加课程侧知识包注入，减少 Godot 内置题库耦合。
3. 导出 Web 到 `apps/player/public/assets/godot/ch11-band-defense/`。
4. 在课程 manifest 中接入 `modeId: "godot-game"` 关卡。
5. 增加错题模块结算反馈。
6. 逐步替换灰盒为手环、信号、塔和 UI 资产。

## 16. 一句话总结

`手环数据链路防线` 的 MVP 应该先证明一件事：

```text
第 11 章的 IMU、计步、PPG、OLED、低功耗知识，可以被组织成一局可运行的 Godot 塔防复习游戏。
```
