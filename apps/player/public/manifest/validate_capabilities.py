"""
validate_capabilities.py

抽取机制守门：校验 manifest 实际使用的元素能力 ⊆ capabilities 声明。

未来教材抽取流程：
  1. 新教材在 manifest.capabilities 声明它要用的能力子集（role=derived）
  2. 本脚本扫描新教材实际用到的 block/interactive/animation/action
  3. 若实际用了未声明的能力 → 报错退出码 1（防止抽取越界）

样板教材（role=reference-master）：capabilities 即全量，自然全部通过。

用法：python apps/player/public/manifest/validate_capabilities.py
退出码：0=通过；1=发现未声明能力；2=manifest 缺 capabilities 字段
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
GALLERY_CHAPTER_ID = 'appendix-gallery'


def scan_used(m):
    bk, ik, af, at = set(), set(), set(), set()
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                for b in p.get('blocks', []):
                    k = b.get('kind', '?')
                    bk.add(k)
                    if k == 'interactive':
                        ik.add((b.get('spec') or {}).get('kind', '?'))
                    if k == 'animation':
                        af.add(b.get('format', '?'))
                for a in p.get('actions', []):
                    at.add(a.get('type', '?'))
    return bk, ik, af, at


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    cap = m.get('capabilities')
    if not cap:
        print('[validate] ❌ manifest 缺 capabilities 字段，先跑 build_capabilities.py', file=sys.stderr)
        return 2

    bk, ik, af, at = scan_used(m)
    checks = [
        ('blockKinds', bk, set(cap.get('blockKinds', []))),
        ('interactiveKinds', ik, set(cap.get('interactiveKinds', []))),
        ('animationFormats', af, set(cap.get('animationFormats', []))),
        ('playbackActions', at, set(cap.get('playbackActions', []))),
    ]
    violations = []
    for name, used, declared in checks:
        extra = used - declared - {'?'}
        if extra:
            violations.append(f'  {name}: 使用了未声明的能力 {sorted(extra)}')

    if violations:
        print('[validate] ❌ 发现越界能力（实际使用 ⊄ capabilities 声明）：', file=sys.stderr)
        for v in violations:
            print(v, file=sys.stderr)
        return 1

    print(f"[validate] ✓ 能力一致性通过 · role={cap.get('role')}")
    print(f"  block={len(bk)} interactive={len(ik)} anim={len(af)} action={len(at)} 种，均在声明内")
    return 0


if __name__ == '__main__':
    sys.exit(main())
