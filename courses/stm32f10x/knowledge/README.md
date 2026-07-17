# STM32F10x 课程知识包

本目录用于存放课程知识内容，避免把题库、概念解释和章节知识点写死在游戏引擎或 Godot 工程里。

## 目录职责

- `*.questions.json`：课程题库，按章节或游戏主题组织。
- `*.upgrades.json`：课程知识点对应的升级选项，可被不同游戏复用或改写。
- `../game-bindings/*.binding.json`：把课程模块映射到某个游戏的升级、反馈和结算标签。

## 设计原则

```text
Godot / 游戏引擎负责“怎么玩”
课程知识包负责“考什么”
binding 负责“知识点如何变成游戏效果”
```

当前示例：

```text
ch12-solar-survivor.questions.json
ch12-solar-survivor.upgrades.json
../game-bindings/ch12-solar-survivor.binding.json
```

播放器会读取这些文件，并在 `DGB_GODOT_INIT` 中注入给 Godot Web 游戏。

