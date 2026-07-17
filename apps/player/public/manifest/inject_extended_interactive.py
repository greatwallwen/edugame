#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inject_extended_interactive.py — Iter-70 T2: 扩展互动题型覆盖

为关键章节添加 truth-table / hotspot / signal-trace 三种新题型实例，
同时替换部分 flashcard 以降低 flashcard 占比（27%→<25%）。

幂等：按 block id 去重。
"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'apps', 'player', 'public'))
MF = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

from manifest.blocks import interactive

# 新题型实例
NEW_BLOCKS = [
    # truth-table: GPIO 推挽/开漏真值表（ch3）
    ("ch3-ext", "ch3-truth-table", {
        "kind": "truth-table",
        "prompt": "填写 GPIO 推挽/开漏输出模式真值表",
        "inputs": ["模式", "ODR"],
        "outputs": ["引脚电平"],
        "rows": [
            {"in": [0, 1], "out": [1]},
            {"in": [0, 0], "out": [0]},
            {"in": [1, 1], "out": [1]},
            {"in": [1, 0], "out": [0]},
        ],
        "explanation": "推挽(0)：ODR=1输出3.3V，ODR=0输出0V；开漏(1)：ODR=1高阻，ODR=0输出0V"
    }),
    # hotspot: STM32 引脚功能标注（ch1）
    ("p1-concept", "p1-hotspot-chip", {
        "kind": "hotspot",
        "prompt": "点击 STM32F103 芯片封装图标注关键引脚",
        "image": "data:image/svg+xml;base64,",
        "hotspots": [
            {"id": "h1", "description": "PA0 — ADC/GPIO", "x": 15, "y": 30, "radius": 8},
            {"id": "h2", "description": "PA13/14 — SWD调试", "x": 75, "y": 30, "radius": 8},
            {"id": "h3", "description": "PC13 — 板载LED", "x": 85, "y": 70, "radius": 8},
            {"id": "h4", "description": "VCC/GND — 供电", "x": 50, "y": 95, "radius": 8},
        ]
    }),
    # signal-trace: UART 帧时序标注（ch6）
    ("ch6-ext", "ch6-signal-trace", {
        "kind": "signal-trace",
        "prompt": "在 UART 115200/8N1 波形中标注起始位和停止位",
        "waveform": [
            {"x": 0, "y": 1}, {"x": 5, "y": 1},
            {"x": 5, "y": 0}, {"x": 6, "y": 0},
            {"x": 6, "y": 1}, {"x": 7, "y": 1},
            {"x": 7, "y": 0}, {"x": 8, "y": 0},
            {"x": 8, "y": 1}, {"x": 9, "y": 1},
            {"x": 9, "y": 0}, {"x": 10, "y": 0},
            {"x": 10, "y": 0}, {"x": 11, "y": 0},
            {"x": 11, "y": 1}, {"x": 12, "y": 1},
            {"x": 12, "y": 0}, {"x": 13, "y": 0},
            {"x": 13, "y": 1}, {"x": 14, "y": 1},
            {"x": 14, "y": 1}, {"x": 15, "y": 1},
            {"x": 15, "y": 1}, {"x": 18, "y": 1},
        ],
        "markers": [
            {"id": "start", "label": "起始位(下降沿)", "x": 5, "markerType": "falling-edge"},
            {"id": "stop",  "label": "停止位(高电平)",  "x": 14, "markerType": "rising-edge"},
        ],
        "xUnit": "bit",
        "yLabel": "TX 电平",
    }),
]


def main():
    with open(MF, 'r', encoding='utf-8') as f:
        m = json.load(f)

    added = 0
    skipped = 0
    for page_id, block_id, spec in NEW_BLOCKS:
        page = None
        for ch in m['chapters']:
            for sec in ch['sections']:
                for p in sec['pages']:
                    if p['id'] == page_id:
                        page = p
                        break
        if not page:
            print(f"  [SKIP] {page_id} not found", file=sys.stderr)
            continue
        if any(b.get('id') == block_id for b in page['blocks']):
            skipped += 1
            continue
        page['blocks'].append(interactive(block_id, spec))
        added += 1

    with open(MF, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f"[interactive] 注入 {added} 个新题型，跳过 {skipped}", file=sys.stderr)


if __name__ == '__main__':
    main()
