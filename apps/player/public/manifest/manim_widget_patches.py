# -*- coding: utf-8 -*-
"""manifest 生成后的 Manim / Widget patch（持久化注入）。

接入：``manifest_builder.py`` 在 ``apply_text_commentary_patches`` 之后调用
      ``apply_manim_widget_patches(manifest)``。

数据来源
========
扫描以下两个目录，按 ``<chapter>/<name>.meta.yaml`` 一一注入：

  - ``materials/<course>/manim/<chapter>/<stem>.meta.yaml``
    构造为 ``kind='animation', format='video-mp4', engine='manim'`` block；
    对应 mp4 资源由 ``scripts/_phase_render_manim.py`` 渲染到
    ``apps/player/public/assets/courses/<course>/animations/manim/<ch>/<stem>.mp4``
  - ``materials/<course>/widgets/<chapter>/<stem>.meta.yaml``
    + 同目录 ``<stem>.html``，构造为 ``kind='widget', widgetType=<...>`` block

为什么独立于 codeflow / text-commentary patches？
------------------------------------------------
- 两者作用于已有 block（注入 commentary / flow），而本 patch **创造新 block**。
- yaml 数据形态不同（manim/widget 有自己的 metadata schema），
  独立模块单一职责，便于阅读与维护。
- 可以安全反复运行（idempotent）：相同 blockId 的注入会原地替换。

设计要点
--------
- **不依赖 template_loader**：直接 yaml.safe_load 旁路文件加载（与 codeflow 同款）。
- **idempotent**：blockId 已存在 → 替换；不存在 → 在 ``insertAfterId``（或 page 末尾）追加。
- **17 final 动画 id 黑名单**：避免污染 H3 双副本（``final_animation_blocks.json``）。
- **可选 patch**：找不到 page / yaml 缺失字段 → 静默跳过（warning 到 stderr，不抛）。
- **不创造新 kind**：注入的 ``kind`` 仍是 ``animation`` / ``widget``，PageRenderer 已支持。
- **TTS 红线**：manim block 必须带 ``metadata.teacher.script`` 非空（与
  ``_assert_tts_coverage.py`` 对齐），缺失则跳过该项并 warning。

返回
----
``apply_manim_widget_patches(manifest) -> tuple[int, int, int]``：
  - manim_applied : 成功注入的 manim animation block 数
  - widget_applied: 成功注入的 widget block 数
  - skipped       : 因数据缺失 / page 找不到 / id 冲突跳过的项数
"""
from __future__ import annotations

import os
import sys
from typing import Any

import yaml


# 17 个 final 动画 id（H3 双副本红线）。本 patch 注入的 id 必须避开这个集合。
_FINAL_ANIM_IDS = frozenset({
    'p1c-anim', 'p1h-anim',
    'p2-ide-anim', 'p2-cl-anim', 'p2gh-anim',
    'p3-led-blink-anim', 'p3-key-int-anim',
    'p4-timer-anim', 'p5-pwm-anim',
    'p6-uart-anim', 'p6-uart-it-anim',
    'p7-adc-anim', 'p8-dac-anim',
    'p9-env-anim',
    'p10-parking-anim', 'p11-band-anim', 'p12-suntrack-anim',
})

# 注入物的 source tag，用于将来 audit / 反向定位
_INJECT_TAG_KEY = '_dgbookInjectSource'
_MANIM_TAG = 'manim-patch'
_WIDGET_TAG = 'widget-patch'


def _repo_root() -> str:
    """返回仓库根（.../DGBook）。本文件位于 apps/player/public/manifest/。"""
    here = os.path.abspath(__file__)
    return os.path.normpath(os.path.join(here, '..', '..', '..', '..', '..'))


def _discover_courses() -> list[str]:
    """返回所有 materials/<course> 目录（绝对路径），不含 _ 开头的内部目录。"""
    root = _repo_root()
    materials = os.path.join(root, 'materials')
    if not os.path.isdir(materials):
        return []
    out: list[str] = []
    for name in sorted(os.listdir(materials)):
        if name.startswith('_'):
            continue
        p = os.path.join(materials, name)
        if os.path.isdir(p):
            out.append(p)
    return out


def _load_yaml(path: str) -> dict[str, Any] | None:
    """安全加载 yaml；解析失败 / 顶层非 mapping → 返回 None 并 warning。"""
    try:
        with open(path, encoding='utf-8') as fp:
            data = yaml.safe_load(fp)
    except OSError as exc:
        rel = os.path.relpath(path, _repo_root())
        print(f'[manim_widget_patches] ⚠️  无法打开 {rel}: {exc}', file=sys.stderr)
        return None
    except yaml.YAMLError as exc:
        rel = os.path.relpath(path, _repo_root())
        print(f'[manim_widget_patches] ⚠️  YAML 解析失败 {rel}: {exc}', file=sys.stderr)
        return None
    if not isinstance(data, dict):
        return None
    return data


def _find_page(manifest: dict, page_id: str) -> dict | None:
    for ch in manifest.get('chapters', []):
        for sec in ch.get('sections', []):
            for pg in sec.get('pages', []):
                if pg.get('id') == page_id:
                    return pg
    return None


def _upsert_block(
    page: dict,
    new_block: dict,
    *,
    insert_after_id: str | None = None,
) -> str:
    """同 id 替换；否则在 insert_after_id 之后插入；否则末尾追加。

    返回 'replace' / 'insert' / 'append'。
    """
    blocks: list[dict] = page.setdefault('blocks', [])
    for i, b in enumerate(blocks):
        if b.get('id') == new_block['id']:
            blocks[i] = new_block
            return 'replace'
    if insert_after_id:
        for i, b in enumerate(blocks):
            if b.get('id') == insert_after_id:
                blocks.insert(i + 1, new_block)
                return 'insert'
    blocks.append(new_block)
    return 'append'


# ─── 扫描 manim 源 ────────────────────────────────────────────────
def _discover_manim_metas() -> list[dict[str, Any]]:
    """返回 ``[{course, chapter, stem, meta, src_meta, deploy_mp4_rel, sections}, ...]``。

    扫描每个 ``materials/<course>/manim/<ch_dir>/<stem>.py``，配套
    ``<stem>.meta.yaml`` 必须存在。可选 ``<course>/manim/_generated/<ch>/<stem>.sections.json``
    用来累计 duration（更精确）。
    """
    out: list[dict[str, Any]] = []
    for course_dir in _discover_courses():
        manim_root = os.path.join(course_dir, 'manim')
        if not os.path.isdir(manim_root):
            continue
        course = os.path.basename(course_dir)
        for ch_name in sorted(os.listdir(manim_root)):
            if ch_name.startswith('_'):
                continue
            ch_path = os.path.join(manim_root, ch_name)
            if not os.path.isdir(ch_path):
                continue
            for fn in sorted(os.listdir(ch_path)):
                if not fn.endswith('.py') or fn.startswith('_'):
                    continue
                stem = fn[:-3]
                meta_path = os.path.join(ch_path, f'{stem}.meta.yaml')
                if not os.path.isfile(meta_path):
                    continue
                meta = _load_yaml(meta_path)
                if meta is None:
                    continue
                sections_path = os.path.join(
                    manim_root, '_generated', ch_name, f'{stem}.sections.json',
                )
                sections: list[dict[str, Any]] = []
                if os.path.isfile(sections_path):
                    try:
                        import json as _json
                        with open(sections_path, encoding='utf-8') as fp:
                            sections = _json.load(fp) or []
                    except Exception:  # noqa: BLE001
                        sections = []
                deploy_mp4_rel = (
                    f'./assets/courses/{course}/animations/manim/'
                    f'{ch_name}/{stem}.mp4'
                )
                out.append({
                    'course': course,
                    'chapter': ch_name,
                    'stem': stem,
                    'meta': meta,
                    'src_meta': meta_path,
                    'deploy_mp4_rel': deploy_mp4_rel,
                    'sections': sections,
                })
    return out


# ─── 扫描 widget 源 ───────────────────────────────────────────────
def _discover_widget_metas() -> list[dict[str, Any]]:
    """返回 ``[{course, chapter, stem, meta, src_meta, html_text}, ...]``。

    扫描每个 ``materials/<course>/widgets/<ch_dir>/<stem>.html``，配套
    ``<stem>.meta.yaml`` 必须存在。
    """
    out: list[dict[str, Any]] = []
    for course_dir in _discover_courses():
        widgets_root = os.path.join(course_dir, 'widgets')
        if not os.path.isdir(widgets_root):
            continue
        course = os.path.basename(course_dir)
        for ch_name in sorted(os.listdir(widgets_root)):
            if ch_name.startswith('_'):
                continue
            ch_path = os.path.join(widgets_root, ch_name)
            if not os.path.isdir(ch_path):
                continue
            for fn in sorted(os.listdir(ch_path)):
                if not fn.endswith('.html') or fn.startswith('_'):
                    continue
                stem = fn[:-5]
                meta_path = os.path.join(ch_path, f'{stem}.meta.yaml')
                html_path = os.path.join(ch_path, fn)
                if not os.path.isfile(meta_path):
                    continue
                meta = _load_yaml(meta_path)
                if meta is None:
                    continue
                try:
                    with open(html_path, encoding='utf-8') as fp:
                        html_text = fp.read()
                except OSError as exc:
                    rel = os.path.relpath(html_path, _repo_root())
                    print(
                        f'[manim_widget_patches] ⚠️  无法读 {rel}: {exc}',
                        file=sys.stderr,
                    )
                    continue
                out.append({
                    'course': course,
                    'chapter': ch_name,
                    'stem': stem,
                    'meta': meta,
                    'src_meta': meta_path,
                    'html_text': html_text,
                })
    return out


# ─── Block 构造 ───────────────────────────────────────────────────
def _build_manim_block(item: dict[str, Any]) -> dict[str, Any] | None:
    """从 manim meta + sections 构造 ``animation/video-mp4`` block。

    失败（缺字段 / id 黑名单）返回 None 并 warning。
    """
    meta = item['meta']
    block_id = str(meta.get('blockId') or '').strip()
    src_rel = os.path.relpath(item['src_meta'], _repo_root())
    if not block_id:
        print(f'[manim_widget_patches] ⚠️  {src_rel}: blockId 为空', file=sys.stderr)
        return None
    if block_id in _FINAL_ANIM_IDS:
        print(
            f'[manim_widget_patches] ⚠️  {src_rel}: blockId={block_id} 与 17 final 冲突，跳过',
            file=sys.stderr,
        )
        return None

    teacher = dict(meta.get('teacher') or {})
    if not str(teacher.get('script') or '').strip():
        print(
            f'[manim_widget_patches] ⚠️  {src_rel}: teacher.script 空（破 TTS 红线），跳过',
            file=sys.stderr,
        )
        return None

    steps_labels = [s for s in (meta.get('steps') or []) if isinstance(s, str)]
    step_scripts = [s for s in (teacher.get('stepScripts') or []) if isinstance(s, str)]

    total_duration = 0.0
    for s in item.get('sections') or []:
        try:
            total_duration += float(s.get('duration') or 0)
        except (TypeError, ValueError):
            pass
    duration = round(total_duration, 1) if total_duration > 0 else float(meta.get('duration') or 0)

    block: dict[str, Any] = {
        'id': block_id,
        'kind': 'animation',
        'src': item['deploy_mp4_rel'],
        'format': 'video-mp4',
        'metadata': {
            'topic': str(meta.get('topic') or '').strip(),
            'engine': 'manim',
            'quality': str(meta.get('quality') or 'final'),
            'interactive': False,
            'teacher': {
                'voice': str(teacher.get('voice') or 'Cherry'),
                'autoPlay': bool(teacher.get('autoPlay') or False),
                'sceneId': str(teacher.get('sceneId') or f'{block_id}-scene'),
                'script': teacher['script'],
                'steps': steps_labels,
                'stepScripts': step_scripts,
            },
            _INJECT_TAG_KEY: _MANIM_TAG,
        },
    }
    if duration > 0:
        block['metadata']['duration'] = duration
    cl = meta.get('coversLessons')
    if isinstance(cl, list):
        block['metadata']['coversLessons'] = cl
    return block


def _build_widget_block(item: dict[str, Any]) -> dict[str, Any] | None:
    """从 widget meta + html 构造 ``widget`` block。失败返回 None 并 warning。"""
    meta = item['meta']
    src_rel = os.path.relpath(item['src_meta'], _repo_root())
    block_id = str(meta.get('blockId') or '').strip()
    if not block_id:
        print(f'[manim_widget_patches] ⚠️  {src_rel}: blockId 为空', file=sys.stderr)
        return None
    widget_type = str(meta.get('widgetType') or '').strip()
    if widget_type not in {'simulation', 'diagram', 'code', 'game', 'visualization3d'}:
        print(
            f'[manim_widget_patches] ⚠️  {src_rel}: widgetType={widget_type!r} 非法，跳过',
            file=sys.stderr,
        )
        return None
    block: dict[str, Any] = {
        'id': block_id,
        'kind': 'widget',
        'widgetType': widget_type,
        'html': item['html_text'],
        'description': str(meta.get('description') or '').strip(),
        _INJECT_TAG_KEY: _WIDGET_TAG,
    }
    cfg = meta.get('config')
    if isinstance(cfg, dict) and cfg:
        block['config'] = cfg
    actions = meta.get('teacherActions')
    if isinstance(actions, list) and actions:
        block['teacherActions'] = list(actions)
    return block


# ─── 入口：apply_manim_widget_patches(manifest) ───────────────────
def apply_manim_widget_patches(manifest: dict) -> tuple[int, int, int]:
    """注入 manim animation block + widget block。

    返回 ``(manim_applied, widget_applied, skipped)``：
      - manim_applied : 成功 upsert 的 manim block 数（含 replace 与 insert/append）
      - widget_applied: 成功 upsert 的 widget block 数
      - skipped       : 因数据缺失 / page 找不到 / id 黑名单跳过的项数

    page 定位规则：
      - meta.pageHint 必填（page id），找不到 → 跳过 + warning
      - manim 默认插在原 ``<pageId>-anim`` 之后（便于"原型 → manim 加深"对照）
      - widget 默认插在 page 中最后一个 interactive block 之后
    """
    manim_applied = 0
    widget_applied = 0
    skipped = 0

    # ─ Manim 注入 ─
    for item in _discover_manim_metas():
        block = _build_manim_block(item)
        if block is None:
            skipped += 1
            continue
        page_hint = str(item['meta'].get('pageHint') or '').strip()
        if not page_hint:
            print(
                f'[manim_widget_patches] ⚠️  {os.path.relpath(item["src_meta"], _repo_root())}: '
                f'pageHint 为空',
                file=sys.stderr,
            )
            skipped += 1
            continue
        page = _find_page(manifest, page_hint)
        if page is None:
            print(
                f'[manim_widget_patches] ⚠️  page {page_hint!r} 未找到，跳过 manim {block["id"]}',
                file=sys.stderr,
            )
            skipped += 1
            continue
        anim_old = f'{page_hint}-anim'
        _upsert_block(page, block, insert_after_id=anim_old)
        manim_applied += 1

    # ─ Widget 注入 ─
    for item in _discover_widget_metas():
        block = _build_widget_block(item)
        if block is None:
            skipped += 1
            continue
        page_hint = str(item['meta'].get('pageHint') or '').strip()
        if not page_hint:
            print(
                f'[manim_widget_patches] ⚠️  {os.path.relpath(item["src_meta"], _repo_root())}: '
                f'pageHint 为空',
                file=sys.stderr,
            )
            skipped += 1
            continue
        page = _find_page(manifest, page_hint)
        if page is None:
            print(
                f'[manim_widget_patches] ⚠️  page {page_hint!r} 未找到，跳过 widget {block["id"]}',
                file=sys.stderr,
            )
            skipped += 1
            continue
        last_inter: str | None = None
        for b in page.get('blocks') or []:
            if b.get('kind') == 'interactive':
                last_inter = str(b.get('id') or '') or last_inter
        _upsert_block(page, block, insert_after_id=last_inter)
        widget_applied += 1

    return manim_applied, widget_applied, skipped


# CLI 自检：python -m manifest.manim_widget_patches
if __name__ == '__main__':
    import json

    try:
        sys.stdout.reconfigure(encoding='utf-8')  # type: ignore[attr-defined]
    except (AttributeError, ValueError):
        pass
    manim = _discover_manim_metas()
    widgets = _discover_widget_metas()
    print(f'manim metas : {len(manim)}')
    for m in manim:
        bid = (m['meta'] or {}).get('blockId')
        ph = (m['meta'] or {}).get('pageHint')
        print(f'  - {m["course"]}/{m["chapter"]}/{m["stem"]}  blockId={bid}  pageHint={ph}')
    print(f'widget metas: {len(widgets)}')
    for w in widgets:
        bid = (w['meta'] or {}).get('blockId')
        ph = (w['meta'] or {}).get('pageHint')
        print(f'  - {w["course"]}/{w["chapter"]}/{w["stem"]}  blockId={bid}  pageHint={ph}')

    mf_path = os.path.join(_repo_root(), 'apps', 'player', 'public', 'manifest.json')
    if os.path.isfile(mf_path):
        with open(mf_path, encoding='utf-8') as fp:
            mf = json.load(fp)
        m_n, w_n, sk = apply_manim_widget_patches(mf)
        print(f'apply result: manim={m_n}  widget={w_n}  skipped={sk}')
    else:
        print(f'(skip apply test: manifest.json not found at {mf_path})')
