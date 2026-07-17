# -*- coding: utf-8 -*-
"""manifest 生成后的「模板化动画」patch（Phase G2 / ADR-0017 · stub 通路）。

本模块对应 ADR-0017 §2.1 路线 C 的最小通路：在 `manifest_builder.py` 末段
（紧随 manim/widget patches）之后扫描以下目录：

    materials/<course>/anims/<chapter>/<stem>.meta.yaml

将其转换为 `kind='animation', format='html-svg'` 且
`metadata.template = { name, params, nodes? }` 的 block，按 `pageHint`
注入到对应 page。运行时由 PageRenderer.AnimationBlock → TemplateAnimationRenderer
（ADR-0017 §2.3）渲染。

红线（G2.5）
-----------
- 本阶段**只搭骨架，不创建任何 yaml**。`materials/<course>/anims/` 目录
  不存在或为空时，函数静默返回 `(0, 0)`。manifest 字节零变化、sha256 不变。
- 第一份真实 yaml 落地是单独的"sha256 变更项"（见 ADR-0017 §4 注），
  需要走 ADR / retro 报告流程，不在 G2.0~G2.6 范围内。

设计要点
--------
- **idempotent**：blockId 已存在 → 替换；不存在 → 在 `insertAfterId`（或 page 末尾）追加。
- **17 final 动画黑名单**：与 `manim_widget_patches` 同款保护，避免污染 H3 双副本。
- **TTS 红线**：模板 block 必须带 `metadata.teacher.script` 非空，
  缺失则跳过该项并 warning，不抛。
- **不创造新 kind**：注入的 kind 仍是 `animation`，PageRenderer 已支持。
- **可选 patch**：找不到 page / yaml 缺失字段 → 静默跳过 + warning。

返回
----
``apply_template_animation_patches(manifest) -> tuple[int, int]``：
  - applied : 成功注入的 template animation block 数
  - skipped : 因数据缺失 / page 找不到 / id 冲突跳过的项数
"""
from __future__ import annotations

import os
import sys
from typing import Any

import yaml


def _repo_root() -> str:
    """定位仓库根：apps/player/public/manifest/ → ../../../../"""
    here = os.path.abspath(os.path.dirname(__file__))
    return os.path.abspath(os.path.join(here, '..', '..', '..', '..'))


def _materials_dir(course: str = 'stm32-course') -> str:
    return os.path.join(_repo_root(), 'materials', course, 'anims')


# 17 final 动画 id 黑名单（与 manim_widget_patches 对齐，避免污染 H3 invariant）
_FINAL_ANIM_BLOCKLIST: set[str] = {
    'p1c-anim', 'p2-cl-anim', 'p3-led-blink-anim', 'p3-key-int-anim',
    'p4-timer-anim', 'p5-pwm-anim', 'p6-uart-anim', 'p7-adc-anim',
    'p8-spi-anim', 'p9-i2c-anim', 'p10-can-anim', 'p11-iwdg-anim',
    'p12-rtc-anim', 'p13-flash-anim', 'p14-dma-anim', 'p15-low-power-anim',
    'p16-bootloader-anim',
}


def _discover_template_metas(course: str = 'stm32-course') -> list[dict[str, Any]]:
    """扫描 materials/<course>/anims/<chapter>/*.meta.yaml。

    目录不存在或为空时返回空列表（G2.5 stub 默认行为）。
    """
    root = _materials_dir(course)
    if not os.path.isdir(root):
        return []
    out: list[dict[str, Any]] = []
    for ch in sorted(os.listdir(root)):
        ch_dir = os.path.join(root, ch)
        if not os.path.isdir(ch_dir):
            continue
        for name in sorted(os.listdir(ch_dir)):
            if not name.endswith('.meta.yaml'):
                continue
            src_meta = os.path.join(ch_dir, name)
            try:
                with open(src_meta, 'r', encoding='utf-8') as f:
                    meta = yaml.safe_load(f) or {}
            except Exception as e:
                print(f'[template_animation_patches] ⚠️  读取失败 {src_meta}: {e}',
                      file=sys.stderr)
                continue
            stem = name[:-len('.meta.yaml')]
            out.append({
                'src_meta': src_meta,
                'chapter': ch,
                'stem': stem,
                'meta': meta,
            })
    return out


def _find_page(manifest: dict[str, Any], page_hint: str) -> dict[str, Any] | None:
    for ch in manifest.get('chapters', []) or []:
        for sec in ch.get('sections', []) or []:
            for p in sec.get('pages', []) or []:
                if p.get('id') == page_hint:
                    return p
    return None


def _build_template_block(item: dict[str, Any]) -> dict[str, Any] | None:
    """yaml meta → animation block（metadata.template 路径）。"""
    meta = item['meta'] or {}
    block_id = str(meta.get('blockId') or '').strip()
    if not block_id:
        print(f'[template_animation_patches] ⚠️  {os.path.relpath(item["src_meta"], _repo_root())}: '
              f'blockId 为空', file=sys.stderr)
        return None
    if block_id in _FINAL_ANIM_BLOCKLIST:
        print(f'[template_animation_patches] ⚠️  {block_id} 在 17 final 黑名单内，跳过',
              file=sys.stderr)
        return None
    template = meta.get('template') or {}
    if not isinstance(template, dict):
        print(f'[template_animation_patches] ⚠️  {block_id}: template 字段非 dict',
              file=sys.stderr)
        return None
    name = str(template.get('name') or '').strip()
    if not name:
        print(f'[template_animation_patches] ⚠️  {block_id}: template.name 为空',
              file=sys.stderr)
        return None
    params = template.get('params')
    if not isinstance(params, dict):
        print(f'[template_animation_patches] ⚠️  {block_id}: template.params 非 dict',
              file=sys.stderr)
        return None
    teacher = (meta.get('teacher') or {}) if isinstance(meta.get('teacher'), dict) else {}
    script = str(teacher.get('script') or '').strip()
    if not script:
        print(f'[template_animation_patches] ⚠️  {block_id}: teacher.script 为空（TTS 红线）',
              file=sys.stderr)
        return None

    block: dict[str, Any] = {
        'id': block_id,
        'kind': 'animation',
        'src': str(meta.get('src') or 'inline:<!-- template -->'),
        'format': 'html-svg',
        'metadata': {
            'topic': str(meta.get('topic') or '').strip() or block_id,
            'engine': 'svg',
            'quality': str(meta.get('quality') or 'final'),
            'interactive': bool(meta.get('interactive') or False),
            'teacher': {
                'voice': str(teacher.get('voice') or 'Cherry'),
                'autoPlay': bool(teacher.get('autoPlay') or False),
                'sceneId': str(teacher.get('sceneId') or f'{block_id}-scene'),
                'script': script,
                'steps': list(teacher.get('steps') or []),
                'stepScripts': list(teacher.get('stepScripts') or []),
            },
            'template': {
                'name': name,
                'params': params,
            },
        },
    }
    nodes = template.get('nodes')
    if isinstance(nodes, list) and nodes:
        block['metadata']['template']['nodes'] = nodes
    return block


def _upsert_block(page: dict[str, Any], block: dict[str, Any],
                  insert_after_id: str | None = None) -> None:
    blocks = page.setdefault('blocks', [])
    for i, existing in enumerate(blocks):
        if existing.get('id') == block['id']:
            blocks[i] = block
            return
    if insert_after_id:
        for i, existing in enumerate(blocks):
            if existing.get('id') == insert_after_id:
                blocks.insert(i + 1, block)
                return
    blocks.append(block)


def apply_template_animation_patches(manifest: dict[str, Any]) -> tuple[int, int]:
    """G2.5 stub 入口：扫描并注入 template animation blocks。

    本阶段无 yaml 时返回 (0, 0)，manifest 字节不变。
    """
    applied = 0
    skipped = 0
    for item in _discover_template_metas():
        block = _build_template_block(item)
        if block is None:
            skipped += 1
            continue
        page_hint = str((item['meta'] or {}).get('pageHint') or '').strip()
        if not page_hint:
            print(f'[template_animation_patches] ⚠️  {os.path.relpath(item["src_meta"], _repo_root())}: '
                  f'pageHint 为空', file=sys.stderr)
            skipped += 1
            continue
        page = _find_page(manifest, page_hint)
        if page is None:
            print(f'[template_animation_patches] ⚠️  page {page_hint!r} 未找到，跳过 '
                  f'{block["id"]}', file=sys.stderr)
            skipped += 1
            continue
        insert_after = (item['meta'] or {}).get('insertAfterId')
        _upsert_block(page, block,
                      insert_after_id=str(insert_after) if insert_after else None)
        applied += 1
    return applied, skipped
