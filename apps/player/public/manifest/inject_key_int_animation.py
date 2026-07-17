# -*- coding: utf-8 -*-
"""把 reference/animationHTMLCodes-2026-05-12-09-57-19.html 注入到
p3-key-int 页的 animation block，并同步用剧本里的双语字幕重建 teacher.stepScripts。

幂等：再跑一次会识别指纹并 skip。
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
REPO = os.path.dirname(os.path.dirname(os.path.dirname(ROOT)))
REF_HTML = os.path.join(REPO, 'reference', 'animationHTMLCodes-2026-05-12-09-57-19.html')

FINGERPRINT = 'presentation-container'  # reference HTML 独有的 id，出现即视为已注入


def _retheme(html: str) -> str:
    """把 reference HTML 的冷色替换成教材风暖色，保持与其他动画一致。"""
    color_map = {
        # 背景/舞台
        '#f8f9fa': '#FDF7E6',   # body 外底 → 米黄
        'background: white': 'background: #FFFFFF',  # 白卡
        '#ecf0f1': '#F3EADB',   # 键帽浅灰 → 米黄浅
        '#f1f2f6': '#F3EADB',   # 状态面板底 → 米黄浅
        '#eee': '#D9C9A8',      # 模块边框 → 米色
        '#dfe6e9': '#D9C9A8',   # 连线 → 米色
        '#ddd': '#E5D5B4',      # 负载条底 → 米色浅
        # 文字/主题
        '#2c3e50': '#0E7C4A',   # text-main/cpu → 墨绿
        '#7f8c8d': '#6F665A',   # 次级文字 → 米褐
        # 事件色
        '#3498db': '#0E7C4A',   # 按键 → 墨绿
        '#e74c3c': '#C9A227',   # 信号红 → 琥珀金
        '#2ecc71': '#0E7C4A',   # 成功绿 → 墨绿
        '#e67e22': '#C9A227',   # 橙警 → 琥珀
        '#bdc3c7': '#D9C9A8',   # 按下时灰 → 米色描边
    }
    out = html
    for old, new in color_map.items():
        out = out.replace(old, new)
    return out


def _subtitles_from_html(html: str) -> list[str]:
    """从 runScenario() 里抽取 setSubtitle(cn, en) 的中文字幕，作为 teacher.stepScripts。"""
    pattern = re.compile(
        r'setSubtitle\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)',
        re.MULTILINE,
    )
    return [cn.strip() for cn, _en in pattern.findall(html)]


def main() -> None:
    if not os.path.exists(REF_HTML):
        print(f'[skip] reference not found: {REF_HTML}')
        return
    with open(REF_HTML, 'r', encoding='utf-8') as f:
        html = f.read()
    html = _retheme(html)
    subtitles = _subtitles_from_html(html)
    if not subtitles:
        print('[warn] no setSubtitle found in reference html')

    with open(MANIFEST, 'r', encoding='utf-8') as f:
        m = json.load(f)

    hit = False
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for page in sec.get('pages', []):
                if page.get('id') != 'p3-key-int':
                    continue
                for blk in page.get('blocks', []) or []:
                    if blk.get('kind') != 'animation':
                        continue
                    src = blk.get('src') or ''
                    if FINGERPRINT in src:
                        print('[skip] p3-key-int already uses reference animation')
                        return
                    # 替换 src
                    blk['src'] = 'inline:' + html
                    # 重建 teacher.stepScripts 为双语剧本的中文字幕
                    md = blk.setdefault('metadata', {
                        'topic': page.get('title') or '按键扫描与外部中断',
                        'interactive': True,
                    })
                    md['interactive'] = True
                    teacher = md.setdefault('teacher', {})
                    teacher['script'] = (
                        '这段动画左右对比展示「按键扫描」与「外部中断」两种检测方式，'
                        '左侧 CPU 在不停轮询，右侧只有按键变化时才唤醒 CPU。'
                    )
                    teacher['stepScripts'] = subtitles or teacher.get('stepScripts') or []
                    teacher['voice'] = teacher.get('voice') or 'Cherry'
                    teacher['autoPlay'] = False
                    hit = True

    if not hit:
        print('[skip] p3-key-int not found')
        return
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[ok] injected reference animation into p3-key-int; subtitles={len(subtitles)}')


if __name__ == '__main__':
    main()
