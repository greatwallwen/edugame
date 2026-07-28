# Ch09 Env Spire

第 9 章环境监测卡牌构筑灰盒 MVP。工程结构沿用 Ch11/Ch12：薄 `main.tscn`、单根控制脚本、本地 JSON 数据、共享 `dgbook_runtime` 和 Godot SceneTree 测试。

## 运行

```powershell
godot --path .
```

## 测试

```powershell
godot --headless --path . -s tests/test_data_contract.gd
godot --headless --path . -s tests/test_card_rules.gd
godot --headless --path . -s tests/test_run_flow.gd
godot --headless --path . -s tests/test_random_robustness.gd
godot --headless --path . -s tests/test_graybox_ui.gd
godot --headless --path . -s tests/test_runtime_integration.gd
godot --headless --path . -s tests/test_node_lab.gd
godot --headless --path . -s tests/test_full_run.gd -- --map=mvp_a
godot --headless --path . -s tests/test_full_run.gd -- --map=mvp_b
godot --headless --path . -s tests/test_full_run.gd -- --map=mvp_c
```

## Web 导出

```powershell
godot --headless --path . --export-release Web
```

导出目标为 `apps/player/public/assets/godot/ch09-env-spire/index.html`。

## 视觉验证

在游戏工程目录运行桌面与移动端原生捕获：

```powershell
godot.cmd --path . -s tests/capture_graybox.gd
godot.cmd --path . -s tests/capture_graybox.gd -- --mobile
```

参考视口分别为 `1280 x 720` 和 `390 x 844`。截图输出到仓库根目录的 `.superpowers/visual-qa/ch09-env-spire`，覆盖普通流程、全部 Boss 阶段、结果页和节点实验室。

Web 导出后，在仓库根目录启动本地预览：

```powershell
python .superpowers/serve_ch09.py 4179
```

普通流程预览：

```text
http://127.0.0.1:4179/index.html
```

节点实验室预览：

```text
http://127.0.0.1:4179/index.html?nodeLab=1
```

## 节点实验室

节点实验室用于单独体验全部普通故障、精英故障、事件、检查点、组件、商店、休整、奖励和 Boss 阶段，不属于课程闯关流程。

本地启动：

```powershell
godot.cmd --path . -- --node-lab
```

Web 预览：

```text
http://127.0.0.1:<preview-port>/index.html?nodeLab=1
```

每次启动节点都会重置稳定度、100预算、牌组和组件。工具栏可切换“基础牌组”和覆盖必需知识标签的“全标签”测试牌组，并可随时重开当前节点或返回目录。
