# -*- coding: utf-8 -*-
"""
inject_narration_factory.py

通用 narration 注入工厂。每个 PAGE_ID 提供 NARRATION = {block_id: spec} 字典，
统一通过 apply_to_manifest 写入。

支持的 spec 字段：
  - kind: 'text' | 'code' | 'experiment' | 'mermaid' | 'graphics' | 'animation' | 'digital-human'
  - commentary: { stepScripts: [str], script: str }   (text/code/exp/mermaid/graphics)
  - metadata.teacher: { stepScripts: [str], script: str }   (animation)
  - script: str   (digital-human)

幂等：覆盖已有字段，不重复追加。
"""
from __future__ import annotations
import json, os, sys, re
from typing import Any

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
M = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')
CN = re.compile(r"[\u4e00-\u9fa5]")


def cn_chars(s: str) -> int:
    return len(CN.findall(s or ''))


def apply_to_block(block: dict, spec: dict) -> None:
    """单 block 注入：覆盖 commentary / metadata.teacher / script。"""
    kind = block.get('kind')
    target_kind = spec.get('kind')
    if kind != target_kind:
        return
    if kind == 'animation':
        meta = block.setdefault('metadata', {})
        teacher = dict(spec.get('metadata.teacher') or {})
        old = meta.get('teacher') or {}
        # 保留 steps（视觉摘要），其它字段被覆盖
        if 'steps' in old and 'steps' not in teacher:
            teacher['steps'] = old['steps']
        meta['teacher'] = {**old, **teacher}
        return
    if kind == 'digital-human':
        if spec.get('script'):
            block['script'] = spec['script']
        return
    if 'commentary' in spec:
        existing = block.get('commentary') or {}
        merged = dict(existing)
        merged.update(spec['commentary'])
        block['commentary'] = merged


def apply_to_manifest(m: dict, page_narrations: dict[str, dict[str, dict]]) -> int:
    """遍历 manifest，对每个 (page_id, block_id) 命中 spec 的 block 注入 narration。"""
    n = 0
    for ch in m.get('chapters', []):
        for s in ch.get('sections', []):
            for p in s.get('pages', []):
                pid = p.get('id', '')
                page_spec = page_narrations.get(pid)
                if not page_spec:
                    continue
                for block in p.get('blocks', []):
                    bid = block.get('id', '')
                    block_spec = page_spec.get(bid)
                    if not block_spec:
                        continue
                    apply_to_block(block, block_spec)
                    n += 1
    return n


def estimate_chars(page_narrations: dict[str, dict[str, dict]]) -> dict[str, int]:
    """估算每页 narration 总字数（CN-only）。"""
    out: dict[str, int] = {}
    for pid, page_spec in page_narrations.items():
        total = 0
        for spec in page_spec.values():
            kind = spec.get('kind')
            if kind == 'animation':
                t = spec.get('metadata.teacher') or {}
                ss = t.get('stepScripts') or []
                if ss: total += sum(cn_chars(x) for x in ss)
                else: total += cn_chars(t.get('script') or '')
            elif kind == 'digital-human':
                total += cn_chars(spec.get('script') or '')
            elif 'commentary' in spec:
                c = spec['commentary']
                ss = c.get('stepScripts') or []
                if ss: total += sum(cn_chars(x) for x in ss)
                else: total += cn_chars(c.get('script') or '')
        out[pid] = total
    return out


def run(page_narrations: dict[str, dict[str, dict]], expected_pages: int = -1) -> int:
    """通用入口：估算 + 注入 + 写回 manifest。"""
    estimates = estimate_chars(page_narrations)
    print(f'[INFO] narration 字数估算（仅工厂注入部分）：')
    for pid, c in sorted(estimates.items()):
        print(f'  {pid:20s}  注入 {c:5d} 字')
    with open(M, encoding='utf-8') as f: m = json.load(f)
    n = apply_to_manifest(m, page_narrations)
    print(f'[OK] 注入 {n} 个 block')
    if expected_pages > 0 and len(page_narrations) != expected_pages:
        print(f'[WARN] 期望 {expected_pages} 页，实际 {len(page_narrations)}', file=sys.stderr)
    with open(M, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[DONE] manifest.json {os.path.getsize(M)//1024} KB')
    return n


if __name__ == '__main__':
    print('inject_narration_factory.py · 通用工厂，import 后调 run(NARRATION_DICT)')
    print('单独跑 inject_narration_<page>.py 让内容数据各自独立')
