"""
inject_wokwi_d1.py

把 D-1 的 5 件 Wokwi 教学元件按 milestone 设定接入对应页：

  arduino-uno      → p1-history / p1-concept   章首"STM32 == UNO 同思想"
  breadboard-mini  → p2-gpio-hal               面包板 + LED + 电阻装配
  7segment         → p3-led-blink              "把 LED 换数码管"扩展
  buzzer           → p5-pwm                    PWM 占空比 → 蜂鸣器频率
  potentiometer    → p7-adc                    旋钮 → ADC 读数

每页新增 1 个 wokwi-element block；page.actions 由后续
generate_page_actions.py 重跑时自动覆盖（block kind=wokwi-element 在
SPEAKABLE 集合内，spotlight 会绑到 dgb-wokwi-{block.id}）。

幂等：每次按 block.id 去重；存在则跳过。
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

# 元件配置：每条 (page_id, block_id, kind, spec_overrides, title, caption)
ELEMENTS = [
    (
        'p1-history',
        'p1-history-wokwi-uno',
        'arduino-uno',
        {'label': 'STM32 同思想'},
        'Arduino UNO（同思想参照）',
        'STM32F103 与 UNO 一脉相承：MCU + GPIO + 串口 + ISP 烧录，思想完全可迁移。',
    ),
    (
        'p1-concept',
        'p1-concept-wokwi-uno',
        'arduino-uno',
        {'label': '概念图示'},
        'Arduino UNO 概念图',
        '从 UNO 看 STM32：内核更强、引脚更多、外设更全，但开发心智一致。',
    ),
    (
        'p2-gpio-hal',
        'p2-gpio-hal-wokwi-breadboard',
        'breadboard-mini',
        {'rows': 17, 'cols': 10},
        '17×10 面包板（mini）',
        '把 LED + 限流电阻插到 mini 面包板上：横向供电轨 + 纵向元件孔。',
    ),
    (
        'p3-led-blink',
        'p3-led-blink-wokwi-7seg',
        '7segment',
        {'value': '8', 'showDp': True},
        '七段数码管（扩展）',
        '把 LED 换成 7-Segment：每段一个 GPIO，dp 单独控制小数点。',
    ),
    (
        'p5-pwm',
        'p5-pwm-wokwi-buzzer',
        'buzzer',
        {'hasSignal': True},
        '蜂鸣器（PWM 驱动）',
        'PWM 占空比 → 蜂鸣器音强；切换占空比即可改变响度。',
    ),
    (
        'p7-adc',
        'p7-adc-wokwi-pot',
        'potentiometer',
        {'value': 50},
        '旋钮电位器（ADC 输入）',
        '旋钮 0~100% → ADC 读数 0~4095，分辨率 12 bit。',
    ),
    # Sprint 3 新增：扩展 wokwi 集成到更多实验页面
    (
        'p4-timer',
        'p4-timer-wokwi-led',
        'led',
        {'color': 'red'},
        'LED 灯（定时器驱动）',
        '定时器中断每 500ms 翻转 GPIO，实现 LED 周期闪烁（不用 Delay 阻塞）。',
    ),
    (
        'p6-uart',
        'p6-uart-wokwi-serial',
        'serial-monitor',
        {},
        '串口监视器',
        'UART 发送的数据会实时显示在串口监视器中，双向通信利器。',
    ),
    (
        'p8-dac',
        'p8-dac-wokwi-speaker',
        'speaker',
        {},
        '扬声器（DAC 驱动）',
        'DAC 输出模拟电压 → 扬声器播放声音，正弦波表生成音调。',
    ),
]


def find_page(manifest, page_id):
    for ch in manifest.get('chapters', []):
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                if p.get('id') == page_id:
                    return p
    return None


def make_block(block_id, kind, spec_overrides, title, caption):
    spec = {'kind': kind, **(spec_overrides or {})}
    return {
        'id': block_id,
        'kind': 'wokwi-element',
        'spec': spec,
        'title': title,
        'caption': caption,
    }


def main():
    if not os.path.isfile(MANIFEST):
        print(f'[FAIL] manifest 不存在：{MANIFEST}')
        sys.exit(1)
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    added = 0
    skipped = 0
    missing_pages = []
    for page_id, block_id, kind, spec_overrides, title, caption in ELEMENTS:
        page = find_page(m, page_id)
        if page is None:
            missing_pages.append(page_id)
            continue
        blocks = page.setdefault('blocks', [])
        if any(b.get('id') == block_id for b in blocks):
            skipped += 1
            continue
        blocks.append(make_block(block_id, kind, spec_overrides, title, caption))
        added += 1

    if missing_pages:
        print(f'[WARN] 以下页未找到，跳过：{missing_pages}')

    if added == 0 and skipped > 0:
        print(f'[OK] 全部已注入（{skipped}/{len(ELEMENTS)}），无变更')
        return

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[OK] 注入 {added} 个，跳过 {skipped} 个（已存在），共 {len(ELEMENTS)} 元件')


if __name__ == '__main__':
    main()
