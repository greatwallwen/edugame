# Godot 游戏共享运行时统一设计

日期：2026-07-16

## 1. 背景

仓库当前包含两个独立的 Godot Web 游戏：

- `ch11-band-defense`：三关九波的塔防游戏，支持诊断、答题、塔解锁和录制演示。
- `ch12-solar-survivor`：180 秒生存游戏，支持外部知识包、答题和升级选择。

两个游戏都通过 `godot_bridge.gd` 与 DGBook 播放器通信，但桥接代码、初始化流程、知识数据加载和结果上报分别维护。随着游戏数量增加，这种复制模式容易导致协议漂移和行为不一致。

## 2. 目标

建立一份标准 Godot 模板和一套同步式共享运行时，使所有游戏共用一致的宿主通信、会话配置、知识数据加载和结果上报能力，同时保证每个 Godot 工程：

- 可以独立打开、预览和导出。
- 不依赖工程目录外的运行时文件。
- 不使用符号链接或跨项目 `res://` 引用。
- 保留自己的玩法状态、素材、数据回退文件和专属扩展。

## 3. 非目标

本轮不包含：

- 重做游戏视觉或修改平衡数值。
- 大规模拆分 Ch11 或 Ch12 的根脚本。
- 开发完整的新游戏脚手架生成器。
- 将通信协议升级到 v2。
- 将课程知识 URL 的网络加载转移到 Godot。

## 4. 目标目录

共享运行时的唯一可信源码位于：

```text
packages/edugame/godot/
├─ shared/
│  └─ dgbook_runtime/
│     ├─ runtime.gd
│     ├─ bridge.gd
│     ├─ protocol.gd
│     ├─ knowledge_provider.gd
│     ├─ session_config.gd
│     └─ result_reporter.gd
├─ template/
├─ games/
│  ├─ ch11-band-defense/
│  └─ ch12-solar-survivor/
└─ tools/
   └─ sync_runtime.mjs
```

同步后，每个游戏包含完整副本：

```text
<game>/
├─ addons/
│  ├─ dgbook_runtime/         # 自动同步，不允许游戏侧修改
│  └─ godot_mcp_enhanced/    # 开发工具，不属于共享运行时
├─ scripts/                   # 游戏自有玩法与 UI
├─ data/                      # 内置回退数据
├─ scenes/
├─ assets/
├─ tests/
└─ dgbook-runtime.lock.json
```

`dgbook-runtime.lock.json` 记录运行时版本、源摘要和受管理文件摘要，用于检查游戏副本是否与共享源码一致。

## 5. 组件职责

### 5.1 `runtime.gd`

游戏使用的唯一公共门面。它组合其他运行时组件，维护宿主生命周期，并向游戏发出标准信号。游戏根脚本不继承复杂的共享基类。

### 5.2 `bridge.gd`

负责：

- 浏览器 `postMessage` 接收与发送。
- 本地 Godot 预览初始化。
- `READY`、`INIT`、`PAUSE`、`RESUME`、`RESET`、`PROGRESS`、`COMPLETE` 和 `LOG` 消息传输。
- 将非标准宿主命令作为自定义命令透传给游戏。

它不处理题库选择、分数计算或游戏状态。

### 5.3 `protocol.gd`

定义 v1 协议版本、标准消息名、基础载荷校验和消息分类。TypeScript 播放器协议保持现有消息名称不变。

### 5.4 `knowledge_provider.gd`

将初始化数据标准化为 `questions`、`upgrades`、`bindings` 和 `concepts`。优先使用播放器已注入的数据；缺失时读取游戏声明的内置 JSON；仍然缺失时返回空集合并记录警告。

浏览器 URL 的获取继续由 React 播放器负责，Godot 不实现第二套 HTTP 加载流程。

### 5.5 `session_config.gd`

从 `DGB_GODOT_INIT` 的 `level` 和 `data` 中提取通用会话参数，包括游戏 ID、时长、失败条件、答题时限和初始状态。未提供的字段保留游戏声明的默认值。

### 5.6 `result_reporter.gd`

统一处理：

- 进度限制在 `0..1`。
- 分数限制在 `0..100`。
- 耗时和统计字段规范化。
- 完成消息幂等，单局最多提交一次。
- 未初始化或已完成后的非法上报产生警告。

## 6. 公共接口

游戏通过组合方式接入：

```gdscript
var runtime := DGBRuntime.new()

func _ready() -> void:
    runtime.setup({
        "game_id": "ch11-band-defense",
        "fallback_questions": "res://data/questions.sample.json",
        "fallback_upgrades": "",
        "fallback_bindings": ""
    })
    runtime.initialized.connect(_on_session_initialized)
    runtime.pause_requested.connect(_on_pause)
    runtime.resume_requested.connect(_on_resume)
    runtime.reset_requested.connect(_reset_game)
    runtime.custom_command_received.connect(_on_custom_command)
    add_child(runtime)
```

游戏只通过门面上报：

```gdscript
runtime.report_progress(progress, hint, stats)
runtime.complete(score, stars, stats)
runtime.log_info(message)
runtime.log_warning(message)
```

初始化信号返回标准化会话字典：

```text
session
├─ game_id
├─ level
├─ config
│  ├─ duration_sec
│  ├─ max_faults / max_leaks
│  ├─ question_time_sec
│  └─ initial_state
├─ knowledge
│  ├─ questions
│  ├─ upgrades
│  ├─ bindings
│  └─ concepts
└─ source
   ├─ external
   ├─ embedded
   └─ local_preview
```

## 7. 生命周期与数据流

共享运行时只管理宿主生命周期：

```text
BOOTING → READY → RUNNING ⇄ PAUSED → FINISHED
                    ↑
                   RESET
```

Ch11 的菜单、关卡、波次和答题状态，以及 Ch12 的 `PLAYING / QUESTION / FINISHED` 阶段仍由各自游戏管理。

标准数据流：

1. Godot Web 启动，运行时发送 `DGB_GODOT_READY`。
2. 播放器获取课程侧知识文件。
3. 播放器发送 `DGB_GODOT_INIT`。
4. 运行时校验协议版本和 `gameId`。
5. 运行时解析会话配置和知识数据。
6. 运行时发出 `initialized(session)`。
7. 游戏消费标准化会话并开始运行。
8. 游戏通过运行时发送进度和完成结果。

本地直接运行 Godot 时，运行时生成 `local_preview` 会话并使用游戏内置回退数据。

## 8. 协议与扩展

第一阶段保持以下 v1 消息不变：

- `DGB_GODOT_READY`
- `DGB_GODOT_INIT`
- `DGB_GODOT_PAUSE`
- `DGB_GODOT_RESUME`
- `DGB_GODOT_RESET`
- `DGB_GODOT_PROGRESS`
- `DGB_GODOT_COMPLETE`
- `DGB_GODOT_LOG`

共享运行时遇到非标准宿主命令时发出 `custom_command_received(type, payload)`。Ch11 在游戏侧识别 `DGB_GODOT_RECORDING_DEMO`，避免将录制功能写入通用协议。

## 9. 容错策略

- 不支持的协议版本拒绝初始化并发送错误日志。
- `gameId` 不匹配时拒绝初始化，防止错误关卡控制错误游戏。
- 外部知识数据缺失或格式无效时使用内置回退数据。
- 回退文件缺失时返回空集合并记录警告，不让运行时崩溃。
- 非法消息被忽略并记录可诊断日志。
- 暂停时桥接节点使用 `PROCESS_MODE_ALWAYS`，仍可接收恢复和重置命令。
- `complete()` 幂等，重复调用不重复提交成绩。
- 重置后清空完成锁和本局上报状态，但保留已解析的会话配置。

## 10. 同步工具

仓库提供两条标准命令：

```text
pnpm godot:runtime:sync
pnpm godot:runtime:check
```

`sync`：

- 将共享源码复制到每个登记游戏的 `addons/dgbook_runtime/`。
- 只覆盖共享运行时目录。
- 更新 `dgbook-runtime.lock.json`。
- 输出同步游戏、运行时版本和文件数量。

`check`：

- 不写文件。
- 比较共享源码、游戏副本和锁文件摘要。
- 发现缺失、过期或被游戏侧修改的共享文件时返回非零状态。
- 不检查游戏自有的 `scripts/`、`data/` 和 `assets/`。

同步工具使用 Node.js，以复用仓库现有 pnpm 工具链并保持跨平台执行。

## 11. 迁移方案

### 阶段 A：建立共享运行时

实现共享组件、同步工具、版本锁和契约测试。合并两份现有桥接脚本并同步到两个游戏。此阶段不改变玩法逻辑。

### 阶段 B：迁移 Ch12

Ch12 已支持外部知识包，因此先用于验证运行时：

- 用 `DGBRuntime` 替换本地桥接初始化。
- 将知识数据回退逻辑迁入 `KnowledgeProvider`。
- 保留现有玩法阶段、敌人、UI 和升级逻辑。
- 验证迁移前后的完成结果与统计字段一致。

### 阶段 C：迁移 Ch11

- 用 `DGBRuntime` 替换本地桥接。
- 将三关题库和波次保留为内置回退数据。
- 允许播放器注入题库、波次或后续知识包。
- 将录制命令接到自定义命令信号。
- 保留现有菜单、塔防、诊断和答题逻辑。
- 不在本阶段拆分根脚本。

Ch11 初期默认仍可使用内置数据；课程侧外部数据准备完成后再切换默认来源。

### 阶段 D：更新模板

两个现有游戏稳定后更新 `godot/template`，使其包含：

```text
template/
├─ addons/dgbook_runtime/
├─ scenes/main.tscn
├─ scripts/game_root.gd
├─ data/questions.sample.json
├─ levels/example_level.json
├─ tests/test_runtime_contract.gd
└─ README.md
```

本阶段只维护可复制模板，不开发完整生成器。

## 12. 测试策略

### 12.1 共享运行时

测试 Web 与本地初始化、协议校验、知识数据优先级、暂停恢复、重置、数值归一化、完成幂等、自定义命令和非法消息处理。

### 12.2 同步工具

测试首次同步、重复同步幂等、过期副本检测、游戏侧误改检测，以及确保同步不会覆盖游戏自有目录。

### 12.3 Ch11 回归

- 三关九波可完整运行。
- 塔、敌人、诊断、答题和解锁结果不变。
- 内置题库回退有效。
- 录制演示仍可使用。
- 完成消息只发送一次。

### 12.4 Ch12 回归

- 180 秒流程、异常敌人、答题和升级不变。
- 外部知识包和内置回退都可运行。
- 暂停恢复后计时正确。
- 正常完成和故障停机统计不变。

### 12.5 验收层级

每阶段至少执行：

1. `pnpm godot:runtime:sync`
2. `pnpm godot:runtime:check`
3. 两个项目的 GDScript 解析检查
4. 两个主场景的无头冒烟运行
5. 现有游戏专项测试
6. 浏览器 iframe 的 `READY → INIT → PROGRESS → COMPLETE` 冒烟验证

## 13. 完成标准

满足以下条件后视为本轮统一完成：

- 共享桥接、协议、知识加载和结果上报只有一份可信源码。
- 两个游戏中的运行时副本可通过 `check` 验证一致。
- 两个游戏可以在不访问共享源码目录的情况下独立打开和导出。
- Ch11 与 Ch12 的现有核心玩法和结果统计通过回归测试。
- Ch12 继续支持外部知识包，Ch11 同时支持外部注入和内置回退。
- 标准模板使用同一共享运行时和接入接口。
