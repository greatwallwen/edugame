#!/usr/bin/env python3
"""
inject_fix_anim_duration.py — 修复所有 duration < 15 秒的动画

规则：
- 有 stepScripts 的动画: duration = max(15, steps * 5)
- 无 stepScripts 的大型动画: duration = 20

幂等：每次运行重新计算。
"""
import json, sys, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MF = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')


def main():
    with open(MF, 'r', encoding='utf-8') as f:
        m = json.load(f)

    fixed = 0
    for ch in m['chapters']:
        for sec in ch['sections']:
            for p in sec['pages']:
                for b in p['blocks']:
                    if b['kind'] != 'animation' or b.get('format') != 'html-svg':
                        continue
                    metadata = b.get('metadata', {})
                    duration = metadata.get('duration', 0)
                    teacher = metadata.get('teacher', {})
                    steps = len(teacher.get('stepScripts', []))

                    if duration < 15:
                        new_dur = max(15, steps * 5) if steps > 0 else 20
                        metadata['duration'] = new_dur
                        b['metadata'] = metadata
                        fixed += 1

    with open(MF, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f"[fix-duration] 修复 {fixed} 个短动画", file=sys.stderr)


if __name__ == '__main__':
    main()
