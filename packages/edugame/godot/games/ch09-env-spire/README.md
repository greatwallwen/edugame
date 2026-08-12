# Ch09 Env Spire

第 9 章环境监测卡牌构筑游戏。工程结构沿用 Ch11/Ch12：薄 `main.tscn`、共享 `dgbook_runtime`、课程侧教学资产和 Godot SceneTree 测试。

## 代码结构

- `scripts/env_spire_root.gd`：运行状态机、战斗结算、UI 编排和宿主接口；保持单场景入口。
- `scripts/env_spire_run_snapshot.gd`、`env_spire_service_controller.gd`、`env_spire_node_lab_controller.gd`：运行快照、整备室和节点实验室的独立控制边界，根脚本保留兼容入口。
- `scripts/env_spire_*_rules.gd`：卡牌、故障、工程组件和闯关规则。
- `scripts/env_spire_*_presenter.gd`：路线、选择页、教程和局部反馈的展示策略；战斗音效由确定性的程序波形生成。
- `scripts/env_spire_card_view.gd`、`env_spire_combat_visual.gd`、`env_spire_ui_motion.gd`：卡面、战斗视觉和动画队列。
- `scripts/env_spire_start_menu.gd`、`env_spire_codex_view.gd`、`env_spire_codex_progress.gd`：开始菜单、图鉴展示与本地发现进度。
- `scripts/env_spire_run_persistence.gd`、`env_spire_settings_store.gd`、`env_spire_learning_report.gd`：版本化断点续玩、持久化设置和知识结算报告。
- `dev/node_lab.gd`：独立节点实验室与开发者调试工具。

## 运行

```powershell
godot --path .
```

## 交互式教程

正常运行会先进入开始菜单，未完成教程时显示“推荐”，但不会强制进入。用于 QA 的强制入口会忽略已完成记录，但不会删除该记录：

```powershell
godot.cmd --path . -- --tutorial
```

教程自动化验证：

```powershell
godot.cmd --headless --path . -s tests/test_tutorial.gd
```

## 测试

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_card_view.gd
godot.cmd --headless --path . -s tests/test_combat_visuals.gd
godot.cmd --headless --path . -s tests/test_desktop_only.gd
godot.cmd --headless --path . -s tests/test_domain_modules.gd
godot.cmd --headless --path . -s tests/test_component_rules.gd
godot.cmd --headless --path . -s tests/test_persistence_settings.gd
godot.cmd --headless --path . -s tests/test_run_persistence_flow.gd
godot.cmd --headless --path . -s tests/test_learning_report.gd
godot.cmd --headless --path . -s tests/test_tutorial.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_random_robustness.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
godot.cmd --headless --path . -s tests/test_node_lab.gd
godot.cmd --headless --path . -s tests/test_combat_feedback.gd
godot.cmd --headless --path . -s tests/test_presentation_modules.gd
godot.cmd --headless --path . -s tests/test_ui_motion_queue.gd
godot.cmd --headless --path . -s tests/test_codex_progress.gd
godot.cmd --headless --path . -s tests/test_codex_unlocks.gd
godot.cmd --headless --path . -s tests/test_codex_view.gd
godot.cmd --headless --path . -s tests/test_start_menu.gd
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_a
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_b
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_c
```

## Web 导出

在仓库根目录运行标准内容寻址导出：

```powershell
pnpm.cmd godot:web:export ch09-env-spire
```

导出目标为 `apps/player/public/assets/godot/ch09-env-spire/index.html`，工具会同步教学资产、生成带内容哈希的运行文件，并原子更新课程入口。

## 视觉验证

在游戏工程目录运行桌面原生捕获：

```powershell
godot.cmd --path . -s tests/capture_graybox.gd
```

桌面参考视口为 `1280 x 720`。截图输出到仓库根目录的 `.superpowers/visual-qa/ch09-env-spire`，覆盖开始菜单、继续游戏、设置、运行菜单、教程、13 类非 Boss 故障、十个组件规则、六种 Boss 验收规则、六种题型、三类学习报告、结果页和节点实验室。

当前完整桌面流程视频位于 `artifacts/ch09-env-spire/ch09-env-spire-desktop-full-run-with-tutorial.mp4`，包含开始菜单、图鉴、继续游戏、设置、运行菜单、开发者节点实验室、交互式首次教程、正式路线、新增普通/精英故障、Boss 规则和知识结算。普通画面停留约 3 秒，信息密集画面停留约 4-5 秒。

Web 导出后，在仓库根目录启动本地预览：

```powershell
python .superpowers/serve_ch09.py 4179
```

普通流程预览：

```text
http://127.0.0.1:4179/index.html
```

强制教程 QA 预览：

```text
http://127.0.0.1:<preview-port>/index.html?tutorial=1
```

节点实验室预览：

```text
http://127.0.0.1:4179/index.html?nodeLab=1
```

## 节点实验室

节点实验室用于单独体验全部普通故障、精英故障、事件、检查点、组件、整备、奖励和 Boss 阶段，不属于课程闯关流程。它可以强制载入全部六种题型、正确/错误答案结果、13 条非 Boss 故障规则的触发/反制路径，以及六种 Boss 验收规则。

本地启动：

```powershell
godot.cmd --path . -- --node-lab
```

Web 预览：

```text
http://127.0.0.1:<preview-port>/index.html?nodeLab=1
```

每次启动节点都会重置稳定度、牌组和组件。工具栏可切换“基础牌组”和覆盖必需知识标签的“全标签”测试牌组，并可随时重开当前节点或返回目录。

进入具体节点后可通过工具栏的“调试”打开开发者面板：

- 从完整卡牌列表选择一张牌并直接加入当前手牌。
- 从当前手牌删除指定实例，或从当前牌组删除一张同名牌。
- 手动设置玩家稳定度。
- 战斗中按“故障剩余值”设置敌方剩余量；例如目标为 24、剩余值设为 5 时，修复进度会变为 19/24。

这些修改仅存在于当前节点实验室场景；重开节点会恢复测试夹具，不影响正常课程进度。
