# Godot Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复两个 Godot 游戏已确认的星级、重复上报、暂停和 `maxLeaks` 缺陷。

**Architecture:** 协议哨兵与上报生命周期在共享运行时统一修复；游戏规则和宿主配置应用留在各游戏根脚本。共享文件修改后通过同步工具分发到模板与两个游戏。

**Tech Stack:** Godot 4 / GDScript、Node.js 同步工具、Vitest、Godot Web exporter

## Global Constraints

- 星级由播放器现有 `starThresholds` 逻辑推导。
- 不修改两个游戏现有分数公式。
- 所有改动保持未提交状态。

---

### Task 1: 共享运行时星级与上报生命周期

**Files:**
- Modify: `packages/edugame/godot/shared/dgbook_runtime/bridge.gd`
- Modify: `packages/edugame/godot/shared/dgbook_runtime/runtime.gd`
- Modify: `packages/edugame/godot/template/tests/test_runtime_primitives.gd`

**Interfaces:**
- Produces: `DGBRuntime.begin_attempt() -> bool`
- Produces: completion payload without `stars` when input is `-1`

- [ ] 在 primitive test 中监听 `outbound_payload`，断言 `send_complete(80)` 的消息不含 `stars`。
- [ ] 在 primitive test 中断言 `begin_attempt()` 无会话时返回 false；初始化后完成、begin_attempt、再次完成均成功。
- [ ] 运行模板测试并确认新增断言失败。
- [ ] 让 `bridge.gd` 仅在 `stars >= 0` 时写入 `stars`，并在 `runtime.gd` 实现仅对有效会话重新激活 reporter 的 `begin_attempt()`。
- [ ] 同步共享运行时，重新运行模板测试并确认通过。

### Task 2: Ch11 星级、重开、暂停与 maxLeaks

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Modify: `packages/edugame/godot/games/ch11-band-defense/tests/test_runtime_integration.gd`

**Interfaces:**
- Consumes: `DGBRuntime.begin_attempt() -> bool`
- Produces: `max_leaks: int` populated from session config

- [ ] 扩展集成测试：注入 `maxLeaks: 2`，断言实例值为 2；断言根节点为可暂停模式；完成一局后执行内部重开并断言第二次完成成功；第二次泄漏触发结束。
- [ ] 运行 Ch11 集成测试并确认新增断言失败。
- [ ] 根节点改为 `PROCESS_MODE_PAUSABLE`，应用 `config.max_leaks`，完成时使用默认星级，实际开始新局时调用 `runtime.begin_attempt()`，所有泄漏阈值使用 `max_leaks`。
- [ ] 重新运行 Ch11 集成测试并确认通过。

### Task 3: Ch12 星级与重开

**Files:**
- Modify: `packages/edugame/godot/games/ch12-solar-survivor/scripts/solar_survivor_root.gd`
- Modify: `packages/edugame/godot/games/ch12-solar-survivor/tests/test_runtime_integration.gd`

**Interfaces:**
- Consumes: `DGBRuntime.begin_attempt() -> bool`

- [ ] 扩展集成测试：完成一局、内部 `_reset_run()`、再次完成，断言两次均被 reporter 接受。
- [ ] 运行 Ch12 集成测试并确认新增断言失败。
- [ ] `_reset_run()` 调用 `runtime.begin_attempt()`，完成调用不再传固定 0 星。
- [ ] 重新运行 Ch12 集成测试并确认通过。

### Task 4: 全量回归与 Web 导出

**Files:**
- Refresh: `apps/player/public/assets/godot/ch11-band-defense/*`
- Refresh: `apps/player/public/assets/godot/ch12-solar-survivor/*`

- [ ] 运行 `pnpm godot:runtime:check`、`@dgbook/game` 全部 Vitest 与 typecheck。
- [ ] 运行 Ch11 全部 GDScript/Python 测试与主场景冒烟。
- [ ] 运行 Ch12 全部 GDScript 测试与主场景冒烟。
- [ ] 分别执行 `godot --headless --path <game> --export-release Web`。
- [ ] 检查两个 PCK 包含共享运行时、不含旧桥接路径，HTML 记录大小与实际 PCK 一致。
- [ ] 检查 `git status` 并确认没有提交或推送。
