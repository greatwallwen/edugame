# Godot 教学资产发布与回滚

Ch11、Ch12 的教学题目、升级项和课程绑定以 `courses/stm32f10x/` 下的 JSON 为唯一权威来源。Web 播放器加载课程侧资源后，通过 `DGB_GODOT_INIT` 注入 Godot。

本地 Godot 工程中的 `data/*.local.json` 是自动生成的编辑器预览副本，不是生产 Web 版的兜底数据；这些文件会被 Web 导出预设排除。

## 同步与检查

修改课程侧 JSON 后执行：

```powershell
node packages/edugame/godot/tools/sync_teaching_assets.mjs sync
node packages/edugame/godot/tools/sync_teaching_assets.mjs check
```

同步命令会完成三件事：

1. 更新播放器公开目录中的课程资源。
2. 更新 Godot 本地预览副本和锁文件。
3. 按资源内容哈希更新课程入口、关卡样例和播放器清单中的 URL。

## 失败行为

外部教学资源无法下载或 JSON 结构错误时，播放器不会发送 INIT，也不会让游戏以空题库启动。界面会显示错误并提供“重试加载教学资源”。

## 回滚步骤

1. 恢复目标课程 JSON 的上一份已知可用内容。
2. 重新运行 `sync` 和 `check`。
3. 重新导出对应 Web 游戏。
4. 在浏览器中完成一次 INIT、答题和结算验证。

不要通过 `knowledgeSource: embedded` 或浏览器 localStorage 切回 PCK 内题库；生产 PCK 已不包含教学 JSON。
