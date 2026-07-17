"""
inject_key_int_flow.py · 把唯一残留的伪动画 p3-key-int-anim 改造成真实逐步动画

p3-key-int-anim 是 inject_key_int_animation 注入的静态 HTML（无 data-step、不响应
dgb-step），审计判 PURE_STATIC。用 aux_anim_template 的 flow 模板重建它，使其：
  - 带 data-step 分步卡，逐步高亮
  - 响应 postMessage('dgb-step') + 上报 step-change
  - teacher.stepScripts 改为按键中断的逐步精准讲解（替换通用导语）

幂等：直接覆盖该 block 的 src + metadata.teacher。
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
sys.path.insert(0, HERE)
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

from aux_anim_template import build_flow_html  # noqa: E402

MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')
BLOCK_ID = 'p3-key-int-anim'

TITLE = '按键扫描与外部中断流程'
SUBTITLE = 'EXTI 边沿检测 · NVIC 优先级 · 软件消抖'
STEPS = ['按键按下', 'EXTI 检测边沿', 'NVIC 响应中断', '执行中断服务函数', '软件消抖']
METRICS = [
    {'v': 'EXTI', 'l': '边沿检测'},
    {'v': 'NVIC', 'l': '中断优先级'},
    {'v': 'ISR', 'l': '服务函数'},
    {'v': '消抖', 'l': '去机械抖动'},
]
SCRIPTS = [
    '按键按下时引脚电平发生跳变，从高到低或从低到高产生一个边沿',
    '配置为外部中断的引脚，EXTI 线检测到这个边沿就置起挂起标志',
    'NVIC 收到 EXTI 中断请求，按优先级打断主程序跳进中断',
    '进入对应的 EXTI 中断服务函数，先清挂起标志再处理按键逻辑',
    '机械按键有抖动，用延时或状态机消抖，避免一次按下被当成多次',
]


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)
    target = None
    for ch in m['chapters']:
        for s in ch['sections']:
            for p in s['pages']:
                for b in p.get('blocks', []):
                    if b.get('id') == BLOCK_ID:
                        target = b
    if not target:
        print(f'[MISS] {BLOCK_ID} 未找到'); return
    target['format'] = 'html-svg'
    target['src'] = 'inline:' + build_flow_html(
        TITLE, STEPS, SCRIPTS, subtitle=SUBTITLE, metrics=METRICS)
    md = target.setdefault('metadata', {})
    md['engine'] = 'svg'
    md['topic'] = TITLE
    md['teacher'] = {
        'script': '；'.join(SCRIPTS),
        'stepScripts': SCRIPTS,
        'voice': 'Cherry',
        'autoPlay': False,
    }
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[OK] {BLOCK_ID} 已改造为真实逐步流程动画（{len(STEPS)} 步）')


if __name__ == '__main__':
    main()
