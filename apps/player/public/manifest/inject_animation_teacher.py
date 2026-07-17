# -*- coding: utf-8 -*-
"""为 manifest 中的 animation block 注入 metadata.teacher。

策略：
- animation.src 若以 'inline:' 开头，解析其中的 <h2>标题</h2> + 紧随的 <p>正文</p>，
  每 (h2, p) 形成一段 stepScript："标题：正文"。
- 聚合成 script（整段口播文字）。
- idempotent：已有 metadata.teacher 的跳过（除非 script 为空）。
- 每段限长 120 字，最多 6 段。
"""
from __future__ import annotations
import json, os, re, sys

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
MANIFEST = os.path.join(ROOT, 'manifest.json')

MAX_STEP = 120
MAX_STEPS = 6

H2_P_RE = re.compile(r'<h2[^>]*>(.*?)</h2>\s*<p[^>]*>(.*?)</p>', re.S | re.I)
TAG_RE = re.compile(r'<[^>]+>')
WS_RE = re.compile(r'\s+')


def _clean(s: str) -> str:
    s = TAG_RE.sub('', s or '')
    s = WS_RE.sub(' ', s).strip()
    return s


def _truncate(s: str, limit: int) -> str:
    s = s.strip()
    return s if len(s) <= limit else s[: max(1, limit - 1)].rstrip() + '…'


# (关键词, 日常例子) —— 主题级（整颗芯片/架构）放前面，让它优先于偶然出现的外设词。
_EXAMPLES: list[tuple[tuple[str, ...], str]] = [
    # —— 主题级（先匹配这一批，动画主题是"单片机是什么"时就不会被正文里的串口/GPIO 误抢）
    (('SoC',), '比如手机主芯片、树莓派那颗大芯片都属于 SoC，能跑操作系统。'),
    (('STM32', 'Cortex', 'ARM', 'MCU', '单片机', '微控制器'),
     '比如你家扫地机器人、空调遥控器里那颗芯片就是这类 MCU。'),
    (('CPU',), '比如电脑主机里那颗 i5/i7 就是 CPU，算力强但要外接内存硬盘。'),
    (('洗衣机', '微波炉', '空调', '家电'), '比如洗衣机主板识别按键、控制电机、显示剩余分钟。'),
    # —— 开发链路级
    (('CubeMX', 'CubeIDE', 'HAL'), '比如在 CubeMX 点几下引脚，就自动生成几十行初始化代码。'),
    (('ST-Link', '下载', '烧录'), '比如插上 ST-Link 四根线，点一下 Download 程序就跑起来了。'),
    (('调试', '断点', '单步'), '比如设一个断点，可以在运行到这一行时停下看每个变量。'),
    # —— 外设级
    (('GPIO', '引脚', '推挽', '开漏'), '比如开发板那颗 LED 就是 GPIO 推挽输出在吸电流。'),
    (('UART', 'USART', '串口'), '比如插上 USB-TTL 后在串口助手里看到的 hello world 就是 UART。'),
    (('TIM', 'Timer', '定时器', 'PWM'), '比如呼吸灯、舵机、小车调速，都是定时器生成 PWM 波。'),
    (('ADC', '模数', '电压采集'), '比如用电位器调亮度，就是 ADC 把模拟电压读成 0-4095 的数。'),
    (('DAC',), '比如蜂鸣器发出一段旋律，就是 DAC 在按时间输出电压序列。'),
    (('I2C', 'SPI'), '比如 OLED 屏幕用 I2C 两根线、SD 卡用 SPI 四根线就能挂上来。'),
    (('DMA',), '比如串口接收一大串数据时让 DMA 自己搬，CPU 就能去干别的。'),
    (('中断', 'NVIC', 'IRQ'), '比如按一下按键瞬间进入中断函数，CPU 正在做的事先暂停。'),
    (('时钟', 'RCC', 'HSE', 'HSI', 'MHz'), '比如把时钟树配到 72MHz，就是给整颗芯片换上更快的心跳。'),
    (('Flash', 'SRAM', '存储'), '比如程序烧进 Flash 掉电不丢，变量放在 SRAM 掉电就消失。'),
]


def _everyday_example(text: str, topic: str = '', seen: set[str] | None = None) -> str:
    """为 step 文本匹配一条贴切的日常例子；命中不到返回空串。

    - 若 topic 能命中主题级关键词（MCU / STM32 / SoC / CPU / 家电），优先用 topic 定基调；
    - 否则回退用 step 文本匹配。
    - 文本已包含"比如/例如/举例"则不追加。
    - seen：已用过的例子不再重复。
    """
    if '比如' in text or '例如' in text or '举例' in text:
        return ''
    seen = seen if seen is not None else set()
    # topic 先行：命中第一组主题级（前 4 组）立即返回，但仅在它还没被用过时
    if topic:
        topic_pool = _EXAMPLES[:4]
        for keys, ex in topic_pool:
            if any(k in topic or k.lower() in topic.lower() for k in keys):
                if ex not in seen:
                    return ex
                break  # topic 命中了但例子重复 → 放弃 topic 走 step 文本
    for keys, ex in _EXAMPLES:
        if ex in seen:
            continue
        if any(k in text or k.lower() in text.lower() for k in keys):
            return ex
    return ''


def _parse_inline_html(src: str, topic: str = '') -> list[str]:
    if not src.startswith('inline:'):
        return []
    html = src[len('inline:'):]
    steps: list[str] = []
    seen: set[str] = set()
    for m in H2_P_RE.finditer(html):
        h2 = _clean(m.group(1))
        p = _clean(m.group(2))
        if not h2 and not p:
            continue
        step = f'{h2}：{p}' if h2 and p else (h2 or p)
        # 第一段用 topic 级主题例子；后续段走 step 文本匹配，避开已用过的
        use_topic = topic if not steps else ''
        ex = _everyday_example(step, use_topic, seen)
        if ex and len(step) + 1 + len(ex) <= MAX_STEP:
            step = f'{step} {ex}'
            seen.add(ex)
        steps.append(_truncate(step, MAX_STEP))
        if len(steps) >= MAX_STEPS:
            break
    return steps


def _fallback_from_topic(topic: str) -> list[str]:
    if not topic:
        return []
    intro = f'下面这段动画围绕"{topic}"展开，共 4 个场景。'
    body = '跟随画面节奏观察每一个关键词，并把它们串成一句完整的因果链。'
    tip = '如果觉得某一幕信息太多，可以点击右下角朗读按钮让讲解逐句读给你听。'
    return [intro, body, tip]


def _build_teacher(block: dict) -> dict | None:
    src = block.get('src') or ''
    metadata = block.get('metadata') or {}
    topic = (metadata.get('topic') or '').strip()
    steps = _parse_inline_html(src, topic)
    if not steps:
        steps = _fallback_from_topic(topic)
    if not steps:
        return None
    script_head = f'这段动画讲的是"{topic}"。' if topic else '这段动画分几幕介绍核心概念。'
    script = script_head + ' ' + ' '.join(steps)
    return {
        'script': _truncate(script, 600),
        'stepScripts': steps,
        'voice': 'Cherry',
        'autoPlay': False,
    }


def main():
    with open(MANIFEST, 'r', encoding='utf-8') as f:
        m = json.load(f)
    added = rewritten = skipped = 0
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for page in sec.get('pages', []):
                for blk in page.get('blocks', []) or []:
                    if blk.get('kind') != 'animation':
                        continue
                    #   注入"逐卡精准讲解"（与卡片内容一一对应），不能被本脚本的通用
                    #   <h2><p> 解析/导语 fallback 覆盖（flow 模板用 <div> 无 h2，会退化成
                    #   3 句导语，导致讲解与画面脱节）。按 id 后缀跳过。
                    #   p3-key-int-anim 同理（已改造为 flow 模板，teacher 由 inject_key_int_flow 注）。
                    _bid = str(blk.get('id') or '')
                    if _bid.endswith('-flow-anim') or _bid == 'p3-key-int-anim':
                        skipped += 1
                        continue
                    metadata = blk.setdefault('metadata', {'topic': blk.get('id') or 'animation', 'interactive': False})
                    existing = metadata.get('teacher')
                    has_content = bool(existing) and bool((existing.get('script') or '').strip() or existing.get('stepScripts'))
                    # 已有内容 → 决定是否需要重建
                    if has_content:
                        steps_now = (existing.get('stepScripts') or []) if isinstance(existing, dict) else []
                        has_examples = any(
                            isinstance(s, str) and ('比如' in s or '例如' in s or '举例' in s)
                            for s in steps_now
                        )
                        # 主题级 topic 但 **第 1 段**（topic 级段）的例子却是外设级 → 不贴合，重建
                        topic = (metadata.get('topic') or '').strip()
                        topic_is_subject = any(k in topic for k in (
                            '单片机', 'MCU', 'CPU', 'SoC', '概念', '发展历程', '架构', '历史',
                        ))
                        subject_markers = (
                            '扫地机器人', '空调遥控器', '洗衣机主板', '手机主芯片',
                            '树莓派', 'i5/i7', '电脑主机',
                        )
                        first = steps_now[0] if steps_now and isinstance(steps_now[0], str) else ''
                        mismatch = (
                            topic_is_subject and '比如' in first
                            and not any(m in first for m in subject_markers)
                        )
                        # 同一例子在 ≥2 段内重复出现 → 不够生动，重建以走去重逻辑
                        def _example_tail(s: str) -> str:
                            i = s.find('比如')
                            return s[i:] if i >= 0 else ''
                        tails = [_example_tail(s) for s in steps_now if isinstance(s, str)]
                        tails = [t for t in tails if t]
                        repeated = len(tails) != len(set(tails))
                        if has_examples and not mismatch and not repeated:
                            skipped += 1
                            continue
                    teacher = _build_teacher(blk)
                    if not teacher:
                        continue
                    metadata['teacher'] = teacher
                    if existing is not None:
                        rewritten += 1
                    else:
                        added += 1
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'animation.teacher: added={added}, rewritten={rewritten}, skipped={skipped}')


if __name__ == '__main__':
    main()
