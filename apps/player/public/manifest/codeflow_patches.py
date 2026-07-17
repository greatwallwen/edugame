"""manifest 生成后的 code-flow patch（路径 C）。

接入：manifest_builder.py 在 apply_followup_patches 之后调用
      apply_codeflow_patches(manifest)。

数据来源
========
扫描 materials/<course>/_templates/<chapter>/*.extras.yaml，挑出
其中 ``kind: code-flow-patch`` 的 entry，把 ``flow`` + ``commentary``
注入到 manifest 中 ``target_id`` 指向的 code block。

设计要点
--------
- **不依赖 template_loader**：直接 yaml.safe_load 旁路文件，0 解析风险。
- **可选 patch**：找不到 target 或 yaml 文件时静默跳过（与 followup_patches.py 同风格）。
- **idempotent**：重复运行结果一致；同 page 的多个 patch 各自针对独立 code block。
- **不创造新 kind**：注入后 code block 仍是 ``kind: code``，只是多了
  可选字段 ``flow`` / ``commentary``，老的 PageRenderer 直接忽略即可。
"""
from __future__ import annotations

import glob
import os
from typing import Any

import yaml


# （如 python-ml-course / iot-course）无需改代码；可用环境变量
# DGBOOK_TEMPLATE_ROOTS=path1;path2 覆盖（分号或冒号分隔）。
_PATCH_KIND = 'code-flow-patch'


def _repo_root() -> str:
    # 本文件位于 apps/player/public/manifest/，仓库根 = 上 4 层。
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), '..', '..', '..', '..')
    )


def discover_template_roots() -> list[str]:
    """发现所有 materials/<course>/_templates 目录（仓库相对路径）。

    优先级：
      1) 环境变量 DGBOOK_TEMPLATE_ROOTS（分号或冒号分隔，绝对或相对仓库根）；
      2) glob materials/*/_templates（排除 _ 开头的内部目录如 _sample / _template）。

    Phase 5 抽象化关键：新增课程 `materials/<x>-course/_templates` 自动被认。
    """
    env = os.environ.get('DGBOOK_TEMPLATE_ROOTS', '').strip()
    if env:
        # 分号优先（Windows 风），冒号次之（Unix 风）
        sep = ';' if ';' in env else ':'
        items = [p.strip() for p in env.split(sep) if p.strip()]
        return items

    root = _repo_root()
    materials = os.path.join(root, 'materials')
    if not os.path.isdir(materials):
        return []
    out: list[str] = []
    for name in sorted(os.listdir(materials)):
        # 跳过 _sample / _template 这种内部脚手架目录
        if name.startswith('_'):
            continue
        candidate = os.path.join(materials, name, '_templates')
        if os.path.isdir(candidate):
            out.append(os.path.relpath(candidate, root).replace('\\', '/'))
    return out


def _iter_patch_entries() -> list[dict[str, Any]]:
    """扫所有 extras.yaml，返回 ``kind: code-flow-patch`` 的 entry 列表。

    Phase 5 抽象化：模板根目录通过 ``discover_template_roots()`` 自动发现，
    支持任意 ``materials/<course>/_templates``。
    """
    out: list[dict[str, Any]] = []
    root = _repo_root()
    for tpl_root in discover_template_roots():
        # tpl_root 可能是绝对路径（DGBOOK_TEMPLATE_ROOTS 显式给）或相对路径
        abs_root = tpl_root if os.path.isabs(tpl_root) else os.path.join(root, tpl_root)
        if not os.path.isdir(abs_root):
            continue
        pattern = os.path.join(abs_root, '**', '*.extras.yaml')
        for ex_path in glob.glob(pattern, recursive=True):
            try:
                with open(ex_path, encoding='utf-8') as fp:
                    items = yaml.safe_load(fp)
            except (OSError, yaml.YAMLError):
                continue
            if not isinstance(items, list):
                continue
            for item in items:
                if not isinstance(item, dict):
                    continue
                if item.get('kind') != _PATCH_KIND:
                    continue
                # 标注来源便于调试
                tagged = dict(item)
                tagged['_source'] = os.path.relpath(ex_path, root)
                out.append(tagged)
    return out


def _find_code_block(manifest: dict, block_id: str) -> dict | None:
    for ch in manifest.get('chapters', []):
        for sec in ch.get('sections', []):
            for pg in sec.get('pages', []):
                for b in pg.get('blocks') or []:
                    if b.get('kind') == 'code' and b.get('id') == block_id:
                        return b
    return None


def apply_codeflow_patches(manifest: dict) -> tuple[int, int]:
    """注入 flow + commentary 到对应 code block。

    返回 (matched, skipped)：
      - matched：成功 patch 的 code block 数
      - skipped：因 target_id 找不到对应 code block 而跳过的 patch 数
    """
    matched = 0
    skipped = 0
    for patch in _iter_patch_entries():
        target_id = patch.get('target_id')
        if not isinstance(target_id, str) or not target_id:
            skipped += 1
            continue
        target = _find_code_block(manifest, target_id)
        if target is None:
            skipped += 1
            continue
        flow = patch.get('flow')
        commentary = patch.get('commentary')
        if isinstance(flow, dict):
            target['flow'] = flow
        if isinstance(commentary, dict):
            # 不覆盖：若 manifest 既有 commentary（来自章节模块），merge stepScripts。
            existing = target.get('commentary')
            if isinstance(existing, dict):
                merged = dict(existing)
                for k, v in commentary.items():
                    merged.setdefault(k, v)
                target['commentary'] = merged
            else:
                target['commentary'] = commentary
        matched += 1
    return matched, skipped


# CLI 自检：python -m manifest.codeflow_patches
if __name__ == '__main__':
    import json
    import sys

    sys.stdout.reconfigure(encoding='utf-8')  # type: ignore[attr-defined]
    roots = discover_template_roots()
    print(f'discovered {len(roots)} template root(s):')
    for r in roots:
        print(f'  - {r}')
    entries = _iter_patch_entries()
    print(f'discovered {len(entries)} code-flow-patch entr(ies)')
    for e in entries:
        print(
            f'  - id={e.get("id")!r:<28} '
            f'target_id={e.get("target_id")!r:<22} '
            f'source={e.get("_source")}'
        )

    mf_path = os.path.join(_repo_root(), 'apps', 'player', 'public', 'manifest.json')
    if os.path.isfile(mf_path):
        with open(mf_path, encoding='utf-8') as fp:
            mf = json.load(fp)
        m, s = apply_codeflow_patches(mf)
        print(f'apply result: matched={m}  skipped={s}')
    else:
        print(f'(skip apply test: manifest.json not found at {mf_path})')
