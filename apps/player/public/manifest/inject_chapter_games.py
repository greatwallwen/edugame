"""
inject_chapter_games.py · 章节个性化课后互动游戏（源头持久化）

为 36 个内容较少的页面（intro/ext/ws/code）注入章节特化的互动游戏，
每页补到 >= 3 个互动。内容按章节知识点个性化（GPIO/定时器/PWM/UART/ADC...各不同）。

数据源：chapter_games_data.json（74 个互动 spec，36 页）
幂等：按 blockId 去重，已存在则跳过。

加入 inject_all 管线，每次 cicd --gen 自动应用，确保部署时不丢失。
"""
import json
import os
import sys

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')
DATA = os.path.join(HERE, 'chapter_games_data.json')

# 插入位置：最后一个 interactive 之后；无 interactive 则在 code/experiment/finale/dh/summary 之前
INSERT_BEFORE = {'code', 'experiment', 'finale-challenge', 'digital-human', 'summary'}


def main():
    games = json.load(open(DATA, encoding='utf-8'))
    m = json.load(open(MANIFEST, encoding='utf-8'))
    added = 0
    for ch in m['chapters']:
        for s in ch['sections']:
            for p in s['pages']:
                pid = p['id']
                if pid not in games:
                    continue
                existing = {b['id'] for b in p.get('blocks', [])}
                # 找插入位置
                last_i = -1
                for i, b in enumerate(p['blocks']):
                    if b.get('kind') == 'interactive':
                        last_i = i
                if last_i < 0:
                    last_i = len(p['blocks']) - 1
                    for i, b in enumerate(p['blocks']):
                        if b.get('kind') in INSERT_BEFORE:
                            last_i = i - 1
                            break
                offset = 0
                for item in games[pid]:
                    if item['id'] in existing:
                        continue
                    block = {'id': item['id'], 'kind': 'interactive', 'spec': item['spec']}
                    p['blocks'].insert(last_i + 1 + offset, block)
                    offset += 1
                    added += 1
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[chapter-games] 注入个性化互动: {added} 个（36 页补到 >=3 互动）')


if __name__ == '__main__':
    main()
