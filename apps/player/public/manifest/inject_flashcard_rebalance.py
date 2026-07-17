#!/usr/bin/env python3
"""
inject_flashcard_rebalance.py — 将最短的 flashcard 替换为 ordering，确保占比 ≤ 25%

幂等：每次运行检查当前占比，仅在超标时替换。
"""
import json, sys, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MF = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')


def main():
    with open(MF, 'r', encoding='utf-8') as f:
        m = json.load(f)

    total_int = 0
    fc_count = 0
    for ch in m['chapters']:
        for sec in ch['sections']:
            for page in sec['pages']:
                for b in page['blocks']:
                    if b['kind'] == 'interactive':
                        total_int += 1
                        if b.get('spec', {}).get('kind') == 'flashcard':
                            fc_count += 1

    if total_int == 0:
        return

    target_max = int(total_int * 0.25)
    need_replace = max(0, fc_count - target_max)

    if need_replace == 0:
        pct = fc_count / total_int * 100
        print(f"[flashcard] {fc_count}/{total_int}={pct:.1f}% ≤ 25%, 无需替换", file=sys.stderr)
        return

    replaced = 0
    for ch in m['chapters']:
        if replaced >= need_replace:
            break
        for sec in ch['sections']:
            if replaced >= need_replace:
                break
            for page in sec['pages']:
                if replaced >= need_replace:
                    break
                for b in page['blocks']:
                    if replaced >= need_replace:
                        break
                    if b['kind'] != 'interactive':
                        continue
                    spec = b.get('spec', {})
                    if spec.get('kind') != 'flashcard':
                        continue
                    cards = spec.get('cards', [])
                    if len(cards) <= 3:
                        items = [c['front'] for c in cards]
                        b['spec'] = {
                            'kind': 'ordering',
                            'prompt': spec.get('prompt', '请按正确顺序排列'),
                            'items': [{'id': f'o{j}', 'text': t} for j, t in enumerate(items)],
                            'correctOrder': [f'o{j}' for j in range(len(items))],
                        }
                        replaced += 1

    with open(MF, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)

    new_fc = fc_count - replaced
    pct = new_fc / total_int * 100
    print(f"[flashcard] 替换 {replaced} 个, {new_fc}/{total_int}={pct:.1f}%", file=sys.stderr)


if __name__ == '__main__':
    main()
