# Godot 双游戏发布与宿主缺陷修复设计

## 背景

Ch11 手环数据链路防线与 Ch12 太阳能追光小游戏当前主流程测试通过，但复查发现发布产物、缓存、播放器宿主和 Ch11 统计仍有一组可复现缺陷。本轮按已确认的优先级修复，所有改动只保留在本地工作区。

## 目标

1. 让 Godot Web 导出成为可重复、可验证的流程，不再累积旧 PCK 与本地日志。
2. 用 PCK 内容哈希同时刷新 iframe HTML 和实际 PCK 请求，消除版本错配。
3. 让玩家端按游戏统计字段展示正确的分数名称、原始游戏分和星级。
4. 每次 iframe 生命周期只发送一次初始化消息。
5. Ch12 Web 包排除编辑器插件、测试和审计内容。
6. Ch11 泄漏预警和已清波次数跟随真实配置与进度。
7. 在宿主协议边界拒绝结构错误或非有限数值消息。

## 方案

### 可重复发布

新增 Node 发布工具，游戏配置使用白名单。工具先验证输出目录位于 `apps/player/public/assets/godot/<game>` 下，再删除并重建该游戏的生成目录，然后调用 Godot Web 导出。导出后计算 `index.pck` 的 SHA-256 前 12 位并修改 `index.html`：

- `GODOT_CONFIG.fileSizes` 的 PCK 键改为 `index.pck?v=<hash>`；
- `engine.startGame` 显式传入相同的 `mainPack`。

这样浏览器请求的真实 PCK 也带内容版本，而不是只刷新外层 HTML。工具还会同步课程源码、游戏 level JSON 和当前 public manifest 中对应的 iframe URL，保证入口 HTML 使用同一哈希。发布测试通过临时目录覆盖清理边界、哈希注入与入口同步。

### 玩家结果展示

抽取纯函数生成结果展示模型。`stats.bandScore` 显示“手环分”，`stats.solarScore` 显示“追光分”，其他 Godot 游戏回退为“得分”。Godot 结果也显示统一的三星结果，详情只展示实际存在的统计字段。

### 单次初始化

iframe `load` 只重置连接状态，不发送 INIT。收到可信来源的 `DGB_GODOT_READY` 后，通过一次性 gate 认领本轮初始化；重复 READY 不再触发第二次知识包加载或 INIT。iframe 重新加载时重置 gate。

### 导出内容

Ch12 的 Web preset 使用与 Ch11 对齐的排除规则，排除 MCP 插件、配置、测试和 visual-audit。测试静态验证两个 preset，最终再检查实际 PCK 内容。

### Ch11 统计

泄漏警告阈值由 `max_leaks` 计算，保留默认 8 次上限时第 5 次开始预警，并确保较小上限时能在失败前预警。`wavesCleared` 统计所有已完整清除的波次；中途崩溃不计当前未完成波，成功完成则计入最终波。

### 协议边界

按消息类型验证必填字段、可选字段和数值有限性；星级只允许 0 到 3 的整数。结果归一化函数自身也做防御性回退，避免直接调用时产生 `NaN` 或非法星级。

## 验证标准

- 两个导出目录只含当前 Web 导出需要的文件，无哈希孤儿 PCK 和本地服务器日志。
- iframe URL 哈希、HTML `mainPack` 哈希与当前 PCK SHA-256 前 12 位一致。
- Ch12 PCK 不含 `addons/godot_mcp_enhanced`、`tests`、`visual-audit` 或 MCP 配置。
- `@dgbook/game` 测试和类型检查通过，播放器生产构建通过。
- Ch11/Ch12 Godot 测试通过，公共 runtime 同步检查通过。

