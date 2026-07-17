"""
enhance_device_svg.py· 动画器件素材强化

给所有 html-svg iframe 动画的 <style> 块追加器件增强 CSS（不改 SVG 几何，
纯样式叠加，幂等可重跑）：
  - .led    : 真实发光二极管的辉光 + 红色径向高光
  - .res    : 电阻立体描边 + 投影
  - .diode  : 二极管渐变
  - .wire   : 导线微光
  - .dot    : 流动粒子增强辉光
  - .box/.chip : 芯片立体感

用 sentinel 注释 /*DGB-DEVICE-ENH*/ 防重复注入。

用法：python apps/player/public/manifest/enhance_device_svg.py
"""
import json
import os
import sys

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

SENTINEL = '/*DGB-DEVICE-ENH*/'

# 器件增强 CSS（注入到每个动画 iframe 的 </style> 之前）
ENHANCE_CSS = SENTINEL + """
.led{filter:drop-shadow(0 0 6px rgba(185,28,28,.55)) drop-shadow(0 0 14px rgba(252,165,165,.45));}
.led.on,.led[data-on="1"]{filter:drop-shadow(0 0 10px #ef4444) drop-shadow(0 0 22px #fca5a5);}
.res{filter:drop-shadow(0 1px 2px rgba(106,82,176,.4));}
.diode{filter:drop-shadow(0 1px 3px rgba(106,82,176,.45));}
.wire{filter:drop-shadow(0 0 2px rgba(107,114,128,.3));}
.dot{filter:drop-shadow(0 0 8px #10915A) drop-shadow(0 0 16px rgba(16,145,90,.6));}
.box,.chip,.blue,.green,.purple,.amber{filter:drop-shadow(0 2px 4px rgba(15,23,42,.12));}
.irq{filter:drop-shadow(0 0 8px rgba(217,119,6,.7));}
.wave,.cnt,.pwm{filter:drop-shadow(0 1px 3px rgba(14,124,74,.3));}
"""


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    enhanced, skipped, no_style = 0, 0, 0
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                for b in p.get('blocks', []):
                    if b.get('kind') != 'animation' or b.get('format') != 'html-svg':
                        continue
                    src = b.get('src', '') or ''
                    if not src.startswith('inline:'):
                        continue
                    html = src[len('inline:'):]
                    if SENTINEL in html:
                        skipped += 1
                        continue
                    if '</style>' not in html:
                        no_style += 1
                        continue
                    html = html.replace('</style>', ENHANCE_CSS + '</style>', 1)
                    b['src'] = 'inline:' + html
                    enhanced += 1
                    print(f'  [OK] {p["id"]:22s}/{b["id"]}')

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)

    print(f'\n[SUMMARY] 强化={enhanced} 已强化跳过={skipped} 无style={no_style}')


if __name__ == '__main__':
    main()
