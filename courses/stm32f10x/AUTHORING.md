# 课程内容组织指南

> 本指南说明如何组织一门 DGBook 课程的资产。

## 目录结构

```
courses/your-course/
├── course.yaml              # 课程元数据
├── PROMPT.md                # AI 生成约束
├── README.md                # 课程说明
├── chapters/                # 章节内容（Python DSL）
│   ├── ch01.py
│   ├── ch02_ch03.py
│   └── ...
├── inject/                  # 课程特定注入脚本
│   ├── inject_narration_*.py
│   ├── inject_sensor_animations.py
│   └── ...
├── assets/                  # 课程素材
│   ├── animations/          # SVG 动画模板
│   ├── videos/              # Manim 视频
│   ├── images/              # 图片素材
│   └── data/                # 数据文件（JSON）
└── tests/                   # 课程内容测试
    └── test_chapters.py
```

## 章节内容编写（chapters/*.py）

使用 Python DSL 定义章节结构。每个文件对应 1-2 章内容。

### 示例：ch01.py

```python
from manifest.blocks import page, text_block, animation_block, quiz
from manifest.factories import quick_page, build_intro_page

def chapter_1():
    """第1章：单片机概论"""
    return {
        "id": "ch1",
        "title": "认识单片机",
        "sections": [
            {
                "id": "main",
                "title": "核心内容",
                "pages": [
                    build_intro_page("ch1-intro", "第1章 认识单片机", [...]),
                    
                    quick_page(
                        "p1-concept",
                        "1.1 单片机概念",
                        blocks=[
                            text_block("p1-concept-text", "什么是单片机..."),
                            animation_block("p1-concept-anim", "单片机演进", [...]),
                            quiz("p1-concept-quiz", "single-choice", {...}),
                        ]
                    ),
                    
                    # 更多页面...
                ]
            }
        ]
    }
```

### 核心工具函数

| 函数 | 用途 | 示例 |
|------|------|------|
| `quick_page()` | 快速创建页面 | 适合简单讲解页 |
| `build_intro_page()` | 章节导览页 | 每章开头 |
| `build_worksheet_page()` | 实训工作页 | 动手实践 |
| `build_extension_page()` | 拓展总结页 | 每章末尾 |
| `text_block()` | 文本块 | 主内容 |
| `code_block()` | 代码块 | 示例代码 |
| `animation_block()` | 动画块 | SVG 动画 |
| `quiz()` | 互动题 | 15 种题型 |

## 课程特定注入脚本（inject/）

对于需要批量注入或后处理的内容（如播报、FAQ、动画），使用 inject 脚本。

### 示例：inject/inject_sensor_animations.py

```python
#!/usr/bin/env python3
import json, sys, os

# 定义要注入的动画
ANIMATIONS = [
    ("p9-i2c-proto", "p9-i2c-anim", _rich_anim_block(...)),
    # 更多动画...
]

def main():
    with open('manifest.json', 'r', encoding='utf-8') as f:
        m = json.load(f)
    
    for page_id, block_id, block_data in ANIMATIONS:
        # 查找页面并注入/替换 block
        ...
    
    with open('manifest.json', 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)

if __name__ == '__main__':
    main()
```

### 注入脚本最佳实践

1. **幂等性**：重复运行安全（检查 block ID 去重）
2. **原子性**：失败时不破坏 manifest.json
3. **日志**：输出注入/跳过的 block 数量
4. **替换而非追加**：检测到同 ID block 时替换而非跳过

## 课程素材（assets/）

### 动画素材（assets/animations/）

- SVG 模板：可参数化的 SVG 文件
- Manim 脚本：Python 动画生成脚本
- 富动画 HTML：使用 `_rich_anim_block()` 生成

### 数据文件（assets/data/）

- 题库 JSON：互动题数据
- 配置 JSON：课程特定配置

## 构建流程

```bash
# 1. 生成基础 manifest
python apps/player/public/gen_manifest_main.py

# 2. 运行课程特定 inject 管线
python apps/player/public/manifest/inject_all.py --continue-on-error

# 3. 构建 capabilities
python apps/player/public/manifest/build_capabilities.py

# 4. Schema 验证
pnpm -F @dgbook/player exec vitest run src/playback/manifest-schema.test.ts

# 5. 构建前端
pnpm build

# 6. 部署
python apps/player/public/deploy/deploy_step1.py
```

## 课程测试（tests/）

为关键内容编写测试：

```python
def test_chapter_structure():
    """验证章节结构完整性"""
    from chapters.ch01 import chapter_1
    ch = chapter_1()
    assert ch['id'] == 'ch1'
    assert len(ch['sections']) > 0
    # 更多断言...

def test_animation_coverage():
    """验证动画覆盖率"""
    # 审计所有页面的动画 block
    ...
```

## 参考示例

完整示例见 `courses/stm32f10x/`（STM32 单片机课程）。
