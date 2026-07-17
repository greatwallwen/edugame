# -*- coding: utf-8 -*-
"""
inject_template_all.py

合并 4 个 inject_template_animations_v{1..4}.py 的 PAGE_BLOCK_SPEC 字典。
"""
from __future__ import annotations
import json, os, sys
from typing import Any

from inject_template_animations    import PAGE_SPECS      as _T1   # type: ignore
from inject_template_animations_v2 import PAGE_BLOCK_SPEC as _T2   # type: ignore
from inject_template_animations_v3 import PAGE_BLOCK_SPEC as _T3   # type: ignore
from inject_template_animations_v4 import PAGE_BLOCK_SPEC as _T4   # type: ignore

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
M = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')


def _normalize_t1(d: dict) -> dict:
    """v1 用 page-id → (block-id, params) 的形式；v2/3/4 用 (page, block) → spec_dict 形式。
    把 v1 normalize 成 v2 格式。"""
    out: dict[tuple[str, str], dict[str, Any]] = {}
    for pid, val in d.items():
        if isinstance(val, tuple) and len(val) == 2:
            bid, params = val
            out[(pid, bid)] = {'name': 'signal-wave', 'params': params}
        elif isinstance(val, dict) and 'name' in val:
            # v2/3/4 格式（容错）
            for bid in ('p4-timer-anim', 'p5-pwm-anim', 'p6-uart-anim'):
                if pid == bid.replace('-anim', ''):
                    out[(pid, bid)] = val
                    break
    return out


def merged_specs() -> dict[tuple[str, str], dict[str, Any]]:
    merged: dict[tuple[str, str], dict[str, Any]] = {}
    # v1 PAGE_SPECS 是 {page-id: (block-id, params)}：normalize
    merged.update(_normalize_t1(_T1))
    # v2/3/4 是 {(page, block): spec_dict}
    for d in (_T2, _T3, _T4):
        for k, v in d.items():
            if k in merged:
                print(f'[WARN] {k} 在多个 batch 重叠', file=sys.stderr)
            merged[k] = v
    return merged


def _nodes_for(spec: dict[str, Any]) -> list[dict[str, Any]]:
    name = spec['name']; p = spec['params']
    if name == 'signal-wave':
        return [{'id': t['id'], 'label': t.get('label','')} for t in p.get('tracks', [])]
    if name == 'fsm':
        return [{'id': st['id'], 'label': st.get('label','')} for st in p.get('states', [])]
    if name == 'sequence-flow':
        return [{'id': a['id'], 'label': a.get('label','')} for a in p.get('actors', [])]
    if name == 'block-pipeline':
        return [{'id': s['id'], 'label': s.get('label','')} for s in p.get('stages', [])]
    if name == 'register-bitfield':
        return [{'id': f['id'], 'label': f.get('label','')} for f in p.get('fields', [])]
    return []


def apply_to_manifest(m: dict[str, Any]) -> int:
    specs = merged_specs()
    n = 0
    for ch in m.get('chapters', []):
        for s in ch.get('sections', []):
            for p in s.get('pages', []):
                pid = p.get('id', '')
                for b in p.get('blocks', []):
                    if b.get('kind') != 'animation':
                        continue
                    spec = specs.get((pid, b.get('id', '')))
                    if not spec:
                        continue
                    meta = b.setdefault('metadata', {})
                    meta['template'] = {
                        'name': spec['name'],
                        'params': spec['params'],
                        'nodes': _nodes_for(spec),
                    }
                    n += 1
    return n


def main() -> int:
    specs = merged_specs()
    print(f'[INFO] 合并 {len(specs)} 个 animation 模板 spec')
    with open(M, encoding='utf-8') as f: m = json.load(f)
    n = apply_to_manifest(m)
    print(f'[OK] 应用 {n} 个 animation 模板')
    if n != 14:
        print(f'[WARN] 期望 14 实际 {n}', file=sys.stderr)
    with open(M, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[DONE] manifest.json {os.path.getsize(M)//1024} KB')
    return 0 if n == 14 else 1


if __name__ == '__main__':
    raise SystemExit(main())
