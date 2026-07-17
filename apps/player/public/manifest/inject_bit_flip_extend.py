"""
inject_bit_flip_extend.py

把 4 道 bit-flip 题（覆盖 ch4-ch7 关键寄存器）批量注入 manifest：
  - p4-timer    : TIM CR1.CEN     (bit0=1 → 0x01)        启动向上计数
  - p5-pwm      : TIM CCMR1.OC1M  (bit4-6=110 → 0x60)    PWM mode 1
  - p6-uart-it  : USART CR1.RXNEIE(bit5=1 → 0x20)        使能接收中断
  - p7-adc      : ADC CR2.ADON+CONT(bit0|bit1 → 0x03)    连续转换模式

target 限制在 0-255（与 InteractiveBitFlipSchema 一致），
所以全部挑寄存器低字节字段（避免 STM32 32-bit register 高位溢出）。

幂等：按 block id 去重，已存在则跳过。

用法：
  python apps/player/public/manifest/inject_bit_flip_extend.py
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

# 4 道题（page_id, anchor_after, block）
TASKS = [
    {
        "page_id": "p4-timer",
        "anchor_after": None,  # 没找到锚点就追加到末尾
        "block": {
            "id": "p4-timer-bitflip",
            "kind": "interactive",
            "spec": {
                "kind": "bit-flip",
                "prompt": "启动定时器：把 TIMx CR1.CEN（bit0）置 1，开启向上计数。",
                "registerName": "TIMx->CR1 (low byte)",
                "initial": 0,
                "target": 1,  # bit0=1
                "explanation": "CEN（Counter ENable）位于 TIMx CR1 bit0，置 1 后定时器开始计数。"
                               "DIR=bit4 默认 0 表示向上计数（CNT 0→ARR 循环）。",
                "bitLabels": ["CEN", "UDIS", "URS", "OPM", "DIR", "CMS0", "CMS1", "ARPE"],
            },
        },
    },
    {
        "page_id": "p5-pwm",
        "anchor_after": None,
        "block": {
            "id": "p5-pwm-bitflip",
            "kind": "interactive",
            "spec": {
                "kind": "bit-flip",
                "prompt": "配置 PWM mode 1：把 CCMR1.OC1M[2:0] 设为 110（bit4=0, bit5=1, bit6=1）。",
                "registerName": "TIMx->CCMR1 (low byte)",
                "initial": 0,
                "target": 0x60,  # 0b01100000
                "explanation": "OC1M[2:0]=110 是 PWM mode 1：CNT < CCR1 时输出有效电平，"
                               "CNT >= CCR1 时输出无效。最常用的边沿对齐 PWM 配置。",
                "bitLabels": ["CC1S0", "CC1S1", "OC1FE", "OC1PE", "OC1M0", "OC1M1", "OC1M2", "OC1CE"],
            },
        },
    },
    {
        "page_id": "p6-uart-it",
        "anchor_after": None,
        "block": {
            "id": "p6-uart-it-bitflip",
            "kind": "interactive",
            "spec": {
                "kind": "bit-flip",
                "prompt": "使能 UART 接收中断：把 CR1.RXNEIE（bit5）置 1，让 RXNE 触发 NVIC。",
                "registerName": "USART->CR1 (low byte)",
                "initial": 0,
                "target": 0x20,  # bit5=1
                "explanation": "RXNEIE = RXNE Interrupt Enable，CR1 bit5。"
                               "置 1 后接收数据寄存器非空（RXNE=1）会拉中断线，"
                               "结合 NVIC 即可触发 USARTx_IRQHandler。",
                "bitLabels": ["SBK", "RWU", "RE", "TE", "IDLEIE", "RXNEIE", "TCIE", "TXEIE"],
            },
        },
    },
    {
        "page_id": "p7-adc",
        "anchor_after": None,
        "block": {
            "id": "p7-adc-bitflip",
            "kind": "interactive",
            "spec": {
                "kind": "bit-flip",
                "prompt": "进入连续转换模式：把 CR2.ADON（bit0）和 CR2.CONT（bit1）都置 1。",
                "registerName": "ADC->CR2 (low byte)",
                "initial": 0,
                "target": 0x03,  # bit0|bit1
                "explanation": "ADON 唤醒 ADC（首次置 1 仅唤醒，再置 1 才真正启动转换）。"
                               "CONT=1 进入连续模式，转换完一次后自动重新启动，"
                               "适合做实时电压监测、PID 反馈等。",
                "bitLabels": ["ADON", "CONT", "CAL", "RSTCAL", "RSV4", "RSV5", "RSV6", "RSV7"],
            },
        },
    },
]


def find_page(manifest, page_id):
    for ch in manifest.get('chapters', []):
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                if p.get('id') == page_id:
                    return p
    return None


def inject():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    injected = 0
    skipped = 0
    for task in TASKS:
        page = find_page(m, task['page_id'])
        if not page:
            print(f"[FAIL] page {task['page_id']} not found", file=sys.stderr)
            sys.exit(1)
        blocks = page.setdefault('blocks', [])
        existing_ids = {b.get('id') for b in blocks}
        if task['block']['id'] in existing_ids:
            print(f"[SKIP] {task['block']['id']} 已存在")
            skipped += 1
            continue
        # 简化：追加到末尾（学生在做完讲解后再做位翻转题，尾部位置最合适）
        blocks.append(task['block'])
        print(f"[OK]   注入 {task['block']['id']} → {task['page_id']} (target=0x{task['block']['spec']['target']:02X})")
        injected += 1

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f"\n[SUMMARY] injected={injected}, skipped={skipped}, manifest 已写回")


if __name__ == '__main__':
    inject()
