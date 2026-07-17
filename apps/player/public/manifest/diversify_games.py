"""
diversify_games.py · 课后游戏多样化

策略：每页保留最多 1 个 flashcard，多余的按轮换序列转换：
  flashcard → fill-blank → memory-match → ordering (循环)

转换规则（保留知识内容，只改呈现形式）：
  flashcard → fill-blank:  front→含空prompt, back→answer
  flashcard → memory-match: cards→pairs (front↔back)
  flashcard → ordering:    cards→按序排列items
"""
import json, os, sys
from copy import deepcopy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

# 轮换目标类型
ROTATION = ['fill-blank', 'memory-match', 'ordering']


def flashcard_to_fill_blank(spec):
    """flashcard → fill-blank: 把 card.front 变挖空题"""
    cards = spec.get('cards', [])
    segments = []
    for i, c in enumerate(cards):
        if i > 0:
            segments.append('\n')
        q = c.get('front', '')
        a = c.get('back', '')
        # "问题？" → "问题？答案是 ___"
        segments.append(f"{q}  答案是 ")
        segments.append({'blank': True, 'answer': a, 'hint': '请填写'})
        segments.append('。')
    return {
        'kind': 'fill-blank',
        'prompt': spec.get('prompt', '📝 填写关键知识点'),
        'segments': segments,
    }


def flashcard_to_memory_match(spec):
    """flashcard → memory-match: cards → pairs"""
    cards = spec.get('cards', [])
    pairs = []
    for c in cards[:8]:  # 翻牌最多 8 对
        pairs.append({
            'id': c.get('id', f"m{len(pairs)}"),
            'front': c.get('front', ''),
            'back': c.get('back', ''),
        })
    return {
        'kind': 'memory-match',
        'prompt': spec.get('prompt', '🃏 翻牌配对：匹配问题与答案').replace('翻转卡片', '翻牌配对'),
        'pairs': pairs,
    }


def flashcard_to_ordering(spec):
    """flashcard → ordering: cards 变排序题（按原始顺序为正确答案）"""
    cards = spec.get('cards', [])
    items = []
    for i, c in enumerate(cards[:6]):  # 排序最多 6 项
        text = c.get('front', '') + ' — ' + c.get('back', '')
        items.append({'id': c.get('id', f"o{i}"), 'text': text})
    correct_order = [it['id'] for it in items]
    return {
        'kind': 'ordering',
        'prompt': spec.get('prompt', '⏱️ 按逻辑顺序排列').replace('翻转卡片', '按顺序排列'),
        'items': items,
        'correctOrder': correct_order,
    }


CONVERTERS = {
    'fill-blank': flashcard_to_fill_blank,
    'memory-match': flashcard_to_memory_match,
    'ordering': flashcard_to_ordering,
}


def main():
    with open(MANIFEST, 'r', encoding='utf-8') as f:
        m = json.load(f)

    total_converted = 0
    rotation_idx = 0  # 全局轮换索引，保证跨页面也不重复

    for ch in m['chapters']:
        ch_title = ch.get('title', '')[:20]
        for sec in ch['sections']:
            for p in sec['pages']:
                pid = p.get('id', '')
                blocks = p.get('blocks', [])

                # 找出所有 flashcard interactive
                fc_indices = []
                for i, b in enumerate(blocks):
                    if b.get('kind') == 'interactive':
                        if b.get('spec', {}).get('kind') == 'flashcard':
                            fc_indices.append(i)

                if len(fc_indices) <= 1:
                    continue  # 0-1 个 flashcard，不需要转换

                # 保留第一个 flashcard，转换其余的
                for fc_idx in fc_indices[1:]:
                    target_kind = ROTATION[rotation_idx % len(ROTATION)]
                    rotation_idx += 1

                    b = blocks[fc_idx]
                    old_spec = b.get('spec', {})
                    converter = CONVERTERS[target_kind]
                    new_spec = converter(deepcopy(old_spec))
                    b['spec'] = new_spec
                    total_converted += 1
                    print(f"  ✓ [{ch_title}] {pid}/{b['id']}: flashcard → {target_kind}")

    if total_converted == 0:
        print("[OK] 无需转换")
        return

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False)
    print(f"\n[OK] 共转换 {total_converted} 个 flashcard → 多样化游戏类型")


if __name__ == '__main__':
    main()
