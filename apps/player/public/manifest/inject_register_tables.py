#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inject_register_tables.py — Iter-70 T3: 寄存器剖析 block 注入

为关键章节的 ext 页面注入寄存器位字段表 + HAL vs 寄存器对比代码。
正点原子风格：先看寄存器，再看 HAL 封装。

幂等：按 block id 去重。
"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'apps', 'player', 'public'))
MF = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

from manifest.blocks import text_block, code_block, table_block

REG_BLOCKS = [
    # ch3: GPIO CRL/CRH 寄存器
    ("ch3-ext", [
        ("ch3-reg-text", text_block("ch3-reg-text", """\
## 寄存器剖析：GPIO_CRL / GPIO_CRH

每个 GPIO 端口有两个 32 位配置寄存器（CRL 控制 Pin0~7，CRH 控制 Pin8~15），
每个引脚占 4 位（CNF[1:0] + MODE[1:0]）。
""")),
        ("ch3-reg-table", table_block("ch3-reg-table", "GPIO_CRL 位字段（Pin0~7）",
            ["位域", "名称", "值=00", "值=01", "值=10", "值=11"],
            [["[1:0]", "MODE", "输入", "10MHz输出", "2MHz输出", "50MHz输出"],
             ["[3:2]", "CNF(输出)", "推挽", "开漏", "复用推挽", "复用开漏"],
             ["[3:2]", "CNF(输入)", "模拟", "浮空", "上拉/下拉", "保留"]])),
        ("ch3-reg-code", code_block("ch3-reg-code", "c", """\
// 寄存器直写：PA5 推挽输出 50MHz
GPIOA->CRL &= ~(0xF << 20);   // 清除 Pin5 的 4 位
GPIOA->CRL |=  (0x3 << 20);   // MODE=11(50MHz), CNF=00(推挽)

// HAL 库等价写法
GPIO_InitTypeDef gpio = {0};
gpio.Pin   = GPIO_PIN_5;
gpio.Mode  = GPIO_MODE_OUTPUT_PP;
gpio.Speed = GPIO_SPEED_FREQ_HIGH;
HAL_GPIO_Init(GPIOA, &gpio);
""", fname="gpio_register_vs_hal.c", hl=[2, 3, 7, 8, 9])),
    ]),
    # ch4: TIM PSC/ARR/CNT 寄存器
    ("ch4-ext", [
        ("ch4-reg-text", text_block("ch4-reg-text", """\
## 寄存器剖析：TIM_PSC / TIM_ARR / TIM_CNT

定时器三个核心寄存器决定定时周期：
- **PSC**（预分频）：将时钟源分频，计数频率 = f_clk / (PSC+1)
- **ARR**（自动重装载）：计数上限，溢出时产生中断
- **CNT**（计数器）：当前计数值，从 0 递增到 ARR
- 定时周期 = (PSC+1) × (ARR+1) / f_clk
""")),
        ("ch4-reg-table", table_block("ch4-reg-table", "TIM2 关键寄存器",
            ["寄存器", "偏移", "位宽", "说明", "典型值"],
            [["TIM_PSC", "0x28", "16bit", "预分频值(实际分频=PSC+1)", "71(72分频)"],
             ["TIM_ARR", "0x2C", "16/32bit", "自动重装载值", "999(1000计数)"],
             ["TIM_CNT", "0x24", "16/32bit", "当前计数值(只读)", "0~ARR"],
             ["TIM_SR",  "0x10", "16bit", "状态寄存器(UIF溢出标志)", "bit0=UIF"],
             ["TIM_DIER","0x0C", "16bit", "中断使能(UIE更新中断)", "bit0=UIE"]])),
        ("ch4-reg-code", code_block("ch4-reg-code", "c", """\
// 寄存器直写：TIM2 定时 1ms（72MHz 时钟）
RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;  // 使能 TIM2 时钟
TIM2->PSC = 71;    // 72MHz / 72 = 1MHz
TIM2->ARR = 999;   // 1MHz / 1000 = 1kHz = 1ms
TIM2->DIER |= TIM_DIER_UIE;  // 使能更新中断
TIM2->CR1  |= TIM_CR1_CEN;   // 启动计数

// HAL 库等价写法
htim2.Instance = TIM2;
htim2.Init.Prescaler = 71;
htim2.Init.Period = 999;
HAL_TIM_Base_Init(&htim2);
HAL_TIM_Base_Start_IT(&htim2);
""", fname="timer_register_vs_hal.c", hl=[3, 4, 5, 6, 11, 12])),
    ]),
]


def main():
    with open(MF, 'r', encoding='utf-8') as f:
        m = json.load(f)

    added = 0
    for page_id, block_list in REG_BLOCKS:
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

        for bid, block_data in block_list:
            if any(b.get('id') == bid for b in page['blocks']):
                continue
            # 在 summary 之前插入
            insert_pos = len(page['blocks'])
            for i, b in enumerate(page['blocks']):
                if b['kind'] in ('summary', 'finale-challenge'):
                    insert_pos = i
                    break
            page['blocks'].insert(insert_pos, block_data)
            added += 1

    with open(MF, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f"[register] 注入 {added} 个寄存器剖析 block", file=sys.stderr)


if __name__ == '__main__':
    main()
