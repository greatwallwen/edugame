"""
inject_aux_anim.py· 给辅助页注入知识点流程动画

把 aux_anim_data 的每页流程，经 aux_anim_template 生成 html-svg 动画 block，
插入对应页面（幂等：按 blockId 去重）。随后 generate_page_actions 会自动为
animation block 生成 speak + anim-step 联动（讲解逐步驱动动画）。

ws 页：插在 experiment 之后、interactive 之前（先看流程再做实训再练习）。
code 页：插在末尾 interactive 之前。

用法：python apps/player/public/manifest/inject_aux_anim.py
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
from aux_anim_data import AUX_ANIM_DATA  # noqa: E402

MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')


def make_anim_block(pid: str, cfg: dict) -> dict:
    html = build_flow_html(
        cfg['title'], cfg['steps'], cfg['scripts'],
        subtitle=cfg.get('subtitle', ''), metrics=cfg.get('metrics'),
    )
    return {
        'id': f'{pid}-flow-anim',
        'kind': 'animation',
        'format': 'html-svg',
        'src': 'inline:' + html,
        'metadata': {
            'topic': cfg['title'],
            'engine': 'svg',
            'quality': 'final',
            'teacher': {
                'script': '；'.join(cfg['scripts']),
                'stepScripts': cfg['scripts'],
                'voice': 'Cherry',
                'autoPlay': False,
            },
        },
    }


def insert_pos(blocks: list[dict]) -> int:
    # experiment 之后优先；否则第一个 interactive 之前；否则末尾
    for i, b in enumerate(blocks):
        if b.get('kind') == 'experiment':
            return i + 1
    for i, b in enumerate(blocks):
        if b.get('kind') == 'interactive':
            return i
    return len(blocks)


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)
    pages = {p['id']: p for ch in m['chapters'] for s in ch['sections'] for p in s['pages']}

    added, skipped, missing, updated = 0, 0, 0, 0
    for pid, cfg in AUX_ANIM_DATA.items():
        page = pages.get(pid)
        if not page:
            print(f'  [MISS] {pid} 不存在')
            missing += 1
            continue
        blocks = page.setdefault('blocks', [])
        bid = f'{pid}-flow-anim'
        existing = next((b for b in blocks if b.get('id') == bid), None)
        if existing is not None:
            #   防止被 inject_animation_teacher 的通用导语覆盖），并刷新 html。
            fresh = make_anim_block(pid, cfg)
            existing['src'] = fresh['src']
            existing['metadata'] = fresh['metadata']
            print(f'  [UPD] {pid}: 刷新流程动画讲解 {bid}（{len(cfg["scripts"])} 段）')
            updated += 1
            continue
        blocks.insert(insert_pos(blocks), make_anim_block(pid, cfg))
        print(f'  [OK] {pid}: 注入流程动画 {bid}（{len(cfg["steps"])} 步）')
        added += 1

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'\n[SUMMARY] 注入={added} 刷新={updated} 跳过={skipped} 缺页={missing}')


if __name__ == '__main__':
    main()
