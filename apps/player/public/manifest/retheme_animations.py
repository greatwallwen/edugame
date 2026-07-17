# -*- coding: utf-8 -*-
"""把 manifest 里所有 animation.src inline HTML 的冷科技风配色
精确替换为教材风（墨绿 #0E7C4A / 米黄 #FDF7E6 / 米褐正文 #3F3A33）。

只替换明确的十六进制色值 token，不触碰 HTML 结构与文字内容。
幂等：重复跑不会把已替换过的教材风色再替换。
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

# 旧冷色 → 新教材风（都用小写匹配，case-insensitive 替换）
COLOR_MAP: dict[str, str] = {
    # 背景
    '#f1f5f9': '#FDF7E6',  # body 外底 → 米黄纸面
    '#f8fafc': '#FFFFFF',  # stage 白底
    '#e2e8f0': '#D9C9A8',  # stage 描边 → 米色
    '#def':    '#F3EADB',  # 偶现的浅蓝淡色
    # 文字
    '#1e293b': '#0E7C4A',  # h2 深墨 → 墨绿
    '#475569': '#3F3A33',  # p 正文灰 → 米褐
    # 进度条渐变（冷蓝 → 紫 ⇒ 墨绿 → 琥珀金）
    '#0ea5e9': '#0E7C4A',
    '#8b5cf6': '#C9A227',
}

# 顺序很重要：先替换 4/5 位 hex 前缀匹配 6 位 hex 的情况（防止 #0ea5e9 被 #0ea 破坏）。
# 这里 COLOR_MAP key 都是精确 3/6 位 token，不互为前缀，直接用 lookahead 做边界。
BOUNDARY = r'(?![0-9a-fA-F])'


def retheme_html(html: str) -> tuple[str, int]:
    """返回 (新 html, 替换次数)。"""
    total = 0
    out = html
    for old, new in COLOR_MAP.items():
        pattern = re.compile(re.escape(old) + BOUNDARY, re.IGNORECASE)
        out, n = pattern.subn(new, out)
        total += n
    return out, total


def main() -> None:
    with open(MANIFEST, 'r', encoding='utf-8') as f:
        m = json.load(f)
    touched_blocks = 0
    total_repl = 0
    inline_total = 0
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for page in sec.get('pages', []):
                for blk in page.get('blocks', []) or []:
                    if blk.get('kind') != 'animation':
                        continue
                    src = blk.get('src') or ''
                    if not src.startswith('inline:'):
                        continue
                    inline_total += 1
                    html = src[len('inline:'):]
                    new_html, n = retheme_html(html)
                    if n > 0:
                        blk['src'] = 'inline:' + new_html
                        touched_blocks += 1
                        total_repl += n
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(
        f'retheme_animations: inline_total={inline_total}, '
        f'touched_blocks={touched_blocks}, total_replacements={total_repl}'
    )


if __name__ == '__main__':
    main()
