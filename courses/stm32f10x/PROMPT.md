# DGBook 课程内容生成 Prompt 约束

> 本文件定义 AI 助手为 DGBook 平台生成课程内容时必须遵循的规范。
> 每门课程复制此文件到自己的目录中，可根据课程特点进行定制。

## 1. 页面结构约束

- 每页 **8-12 个 block**，硬上限 15 个
- 必须包含至少 1 个 `text_block`（主内容）
- 必须包含至少 1 个 `summary_block`（课后总结）
- 互动 block 2-4 个，不超过页面 block 总数的 40%
- **禁止**: 同一页出现 quiz-intro-animation + summary + digital-human 三件套

## 2. 互动题型约束

- 同一页**不重复**使用同种互动题型
- 全课程 flashcard 占所有互动 block 的比例 **≤ 25%**
- 优先使用：matching / ordering / fill-blank / classification
- 每章 ext 页面必须有 1 个 **finale-challenge**（≥2 关）
- finale 每关 2-4 题，时限 60-120 秒

## 3. 章节结构约束

每章必须包含以下页面类型（顺序可调整）：

| 页面类型 | 工厂函数 | 必须 |
|----------|---------|------|
| 引入页 | `build_intro_page()` | ✅ |
| 概念讲解页 | `quick_page()` / 手动 | ✅ |
| 实训工作页 | `build_worksheet_page()` | ✅ |
| 拓展总结页 | `build_extension_page()` | ✅ |
| 进阶代码页 | 手动（code+text） | 推荐 |

## 4. 命名规范

```
Page ID:  p{chapter}-{topic}     例: p3-led-blink, p7-adc
          ch{n}-intro / ch{n}-ext 例: ch3-intro, ch3-ext
Block ID: {pageId}-{kind}        例: p3-led-blink-text, ch4-ext-finale
          {pageId}-{purpose}     例: p3-led-blink-exp, ch3-truth-table
```

## 5. 内容质量约束

- **objectives**: 每章 3-5 个学习目标，标注能力层次（理解/应用/综合）
- **mistakes**: 每章 ext 页面列出 3-4 个常见错误（含排查方法）
- **tips**: 每章 ext 页面列出 3 个进阶技巧
- **flashcard**: 每章 3-5 张知识卡片，问答清晰
- **experiment**: 实验步骤 3-6 步，最后一步设为 checkpoint

## 6. 动画约束

- 每个概念讲解页至少 1 个 animation block
- animation 必须有 `metadata.teacher.stepScripts`（教师播报脚本）
- SVG 动画场景 3-6 帧，每帧有 narration 文本
- 传感器/协议相关页面优先使用 manim 视频动画

## 7. 播报约束

- 每个 text block 必须有 `commentary.script` 或 `commentary.stepScripts`
- 每个 animation block 必须有 `metadata.teacher` 配置
- code block 的 commentary 解释代码关键行（对应 highlightLines）
- 全课程播报覆盖率目标 **100%**

## 8. 寄存器/硬件约束（嵌入式课程专用）

- 对于关键外设章节，ext 页面包含寄存器位字段表（table_block）
- 提供 HAL 库 vs 寄存器直写的对比代码
- 注明参考手册页码或寄存器偏移地址

## 9. 禁止事项

- ❌ 不在 manifest.json 中手写内容（它是构建产物）
- ❌ 不在页面中硬编码服务器地址或 API key
- ❌ 不使用已退役的 block kind（如 `quiz-intro-animation`）
- ❌ 不创建超过 500 行的单个 Python 章节文件
- ❌ 不在 inject 脚本中重复定义 blocks.py 已有的辅助函数
