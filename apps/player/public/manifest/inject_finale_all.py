# -*- coding: utf-8 -*-
"""
inject_finale_all.py

把 4 个 inject_finale_extend_v{1..4}.py 的 PAGE_FINALES 字典合并到一个
单一入口，避免每次推广都需要"按时间序列依次跑 4 个脚本"。

设计：
  - import 各自的 PAGE_FINALES 字典（不复制 spec 数据，避免双源漂移）
  - 合并去重后单次 apply，幂等
  - 旧 4 个 inject_finale_extend_v*.py 仍可独立跑（向后兼容），但生产路径走本文件

幂等：按 page.id 删 legacy outro + finale-challenge → 在 dh 之前插入。
"""
from __future__ import annotations
import json, os, sys
from typing import Any

# 复用 4 个 batch 的 PAGE_FINALES（绝不双写 spec）
from inject_finale_extend    import PAGE_FINALES as _F1   # type: ignore
from inject_finale_extend_v2 import PAGE_FINALES as _F2   # type: ignore
from inject_finale_extend_v3 import PAGE_FINALES as _F3   # type: ignore
from inject_finale_extend_v4 import PAGE_FINALES as _F4   # type: ignore

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
M = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')


def merged_finales() -> dict[str, dict[str, Any]]:
    """合并 4 个批次的 PAGE_FINALES。重叠 page id 由后者覆盖前者（按时间序）。"""
    merged: dict[str, dict[str, Any]] = {}
    for d in (_F1, _F2, _F3, _F4):
        for k, v in d.items():
            if k in merged:
                # 同一页被两个 batch 同时定义 — 报警告（不应发生）
                print(f'[WARN] {k} 在多个 batch 重叠，使用最新版本', file=sys.stderr)
            merged[k] = v
    return merged


def apply_to_manifest(m: dict[str, Any]) -> int:
    PAGE_FINALES = merged_finales()
    n = 0
    for ch in m.get('chapters', []):
        for s in ch.get('sections', []):
            for p in s.get('pages', []):
                pid = p.get('id', '')
                spec = PAGE_FINALES.get(pid)
                if not spec:
                    continue
                blocks = [
                    b for b in p.get('blocks', [])
                    if b.get('kind') not in ('quiz-intro-animation', 'summary', 'finale-challenge')
                ]
                dh_idx = next((i for i, b in enumerate(blocks) if b.get('kind') == 'digital-human'), None)
                if dh_idx is not None:
                    blocks.insert(dh_idx, spec)
                else:
                    blocks.append(spec)
                p['blocks'] = blocks
                n += 1
    return n


def main() -> int:
    fin = merged_finales()
    print(f'[INFO] 合并 {len(fin)} 页 finale: {sorted(fin.keys())}')
    with open(M, encoding='utf-8') as f:
        m = json.load(f)
    n = apply_to_manifest(m)
    print(f'[OK] 应用 {n} 页 finale')
    if n != 12:
        print(f'[WARN] 期望 12 实际 {n}', file=sys.stderr)
    with open(M, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[DONE] manifest.json {os.path.getsize(M)//1024} KB')
    return 0 if n == 12 else 1


if __name__ == '__main__':
    raise SystemExit(main())
