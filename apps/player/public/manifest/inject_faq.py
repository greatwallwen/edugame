# -*- coding: utf-8 -*-
"""从每页的 commentary.stepScripts / animation.teacher.stepScripts / block 标题
自动生成 4-6 条 FAQ，补充到 digital-human block.faq。

策略：
- 保留已有的手写 FAQ（不覆盖）
- 从 stepScripts 里提取关键词，生成"XXX 是什么？"/"为什么 XXX？"等问题
- 每页最多 6 条，已有 ≥4 条则 skip
- 幂等：生成的 FAQ 带 _auto=true 标记，重跑时先清掉旧 auto 再重生成

"""
from __future__ import annotations
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
MANIFEST = os.path.join(ROOT, 'manifest.json')

MAX_FAQ = 6
MIN_FAQ = 4  # 已有 >= MIN_FAQ 条则 skip

# 问题模板：(关键词正则, 问题模板)
_Q_TEMPLATES = [
    (r'(中断|EXTI|IRQ|NVIC)', '中断和轮询有什么区别？'),
    (r'(GPIO|引脚|推挽|开漏)', 'GPIO 推挽输出和开漏输出分别用在什么场景？'),
    (r'(UART|串口|USART)', 'UART 通信中波特率不匹配会出现什么问题？'),
    (r'(TIM|定时器|PWM)', 'PWM 占空比是怎么控制输出功率的？'),
    (r'(ADC|模数|采样)', 'ADC 采样率和分辨率分别影响什么？'),
    (r'(DMA|直接内存)', 'DMA 传输和 CPU 搬运数据有什么本质区别？'),
    (r'(I2C|SPI|总线)', 'I2C 和 SPI 各自适合哪类外设？'),
    (r'(时钟|RCC|HSE|HSI|PLL)', '时钟树配置错误会导致什么现象？'),
    (r'(Flash|SRAM|存储)', '程序变量放在 SRAM 里，掉电后数据会怎样？'),
    (r'(HAL|CubeMX|库函数)', 'HAL 库和寄存器直接操作各有什么优缺点？'),
    (r'(单片机|MCU|微控制器)', '单片机和普通电脑 CPU 的核心区别是什么？'),
    (r'(STM32|Cortex|ARM)', 'STM32 系列里 F1/F4/H7 的主要区别是什么？'),
    (r'(SoC|片上系统)', 'SoC 和 MCU 的主要区别是什么？'),
    (r'(调试|断点|ST-Link)', '没有 ST-Link 的情况下如何调试 STM32？'),
    (r'(消抖|抖动|按键)', '按键消抖为什么不能只靠硬件电容解决？'),
    (r'(中断服务|ISR|回调)', '中断服务函数里为什么不能做耗时操作？'),
    (r'(DAC|数模)', 'DAC 输出的模拟电压精度受哪些因素影响？'),
    (r'(低功耗|睡眠|STOP)', 'STM32 进入 STOP 模式后如何被唤醒？'),
]


def _extract_keywords(steps: list[str]) -> str:
    """把所有 stepScripts 拼成一段文本，用于关键词匹配。"""
    return ' '.join(s for s in steps if isinstance(s, str))


def _gen_faq(steps: list[str], existing_q: set[str]) -> list[dict]:
    """根据 stepScripts 生成 FAQ 列表（不含已有问题）。"""
    text = _extract_keywords(steps)
    result = []
    for pattern, q in _Q_TEMPLATES:
        if q in existing_q:
            continue
        if re.search(pattern, text):
            # 从 steps 里找最相关的一段作为答案
            ans = next(
                (s for s in steps if isinstance(s, str) and re.search(pattern, s)),
                ''
            )
            # 截断到 120 字
            ans = ans[:120].rstrip('，。；') + ('。' if ans and not ans.endswith('。') else '')
            result.append({'q': q, 'a': ans, '_auto': True})
            existing_q.add(q)
        if len(result) >= MAX_FAQ:
            break
    return result


def main() -> None:
    with open(MANIFEST, 'r', encoding='utf-8') as f:
        m = json.load(f)

    added_total = skipped_total = 0
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for page in sec.get('pages', []):
                blocks = page.get('blocks') or []
                dh = next((b for b in blocks if b.get('kind') == 'digital-human'), None)
                if not dh:
                    continue

                # 收集所有 stepScripts
                all_steps: list[str] = []
                for b in blocks:
                    if b.get('kind') == 'text' and b.get('commentary'):
                        all_steps += (b['commentary'].get('stepScripts') or [])
                    elif b.get('kind') == 'code' and b.get('commentary'):
                        all_steps += (b['commentary'].get('stepScripts') or [])
                    elif b.get('kind') == 'animation':
                        t = (b.get('metadata') or {}).get('teacher') or {}
                        all_steps += (t.get('stepScripts') or [])

                if not all_steps:
                    skipped_total += 1
                    continue

                # 现有 FAQ（保留手写，清掉旧 auto）
                existing = dh.get('faq') or []
                manual = [q for q in existing if not q.get('_auto')]
                existing_q = {q['q'] for q in manual if isinstance(q.get('q'), str)}

                if len(manual) >= MIN_FAQ:
                    skipped_total += 1
                    continue

                new_faq = _gen_faq(all_steps, existing_q)
                need = MIN_FAQ - len(manual)
                dh['faq'] = manual + new_faq[:need]
                added_total += len(new_faq[:need])

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'faq_inject: added={added_total}, skipped={skipped_total}')


if __name__ == '__main__':
    main()
