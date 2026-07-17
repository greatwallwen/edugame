"""manifest 生成后的 text-commentary patch（2 · 数据补全工具链）。

接入：manifest_builder.py 在 apply_codeflow_patches 之后调用
      apply_text_commentary_patches(manifest)。

数据来源
========
扫描 materials/<course>/_templates/<chapter>/*.extras.yaml，挑出
其中 ``kind: text-commentary-patch`` 的 entry，把 ``commentary``
（含 ``script`` 单串 与/或 ``stepScripts`` 多段）注入到 manifest 中
``target_id`` 指向的 block。

为什么独立于 codeflow_patches？
--------------------------------
- codeflow_patches 仅作用于 ``kind=='code'`` 的 block，且会同时注入 ``flow``。
- text_commentary_patches 作用于 **任意 SPEAKABLE block**，专补
  ``commentary``，是 2 把 79 个哑巴 block 拉回朗读链路的工具。
- 拆分两个 patch 类型让 yaml 语义保持单一职责，便于阅读 / diff / 维护。

设计要点
--------
- **不依赖 template_loader**：直接 yaml.safe_load 旁路文件。
- **可选 patch**：找不到 target 时静默跳过（与 codeflow_patches.py 一致）。
- **idempotent**：重复运行结果一致。
- **不覆盖既有 stepScripts**：若 target 已有 ``commentary.stepScripts``，
  yaml 中的 ``stepScripts`` 不会覆盖；仅当原值为空/缺失时才注入。
  ``script`` 同理（已有不动）。这保证 final_animation / codeflow 既有的
  step 同步数据不被 text patch 误伤。
- **不创造新 kind**：注入后 block kind 不变，只是多了 ``commentary`` 字段，
  blockToSpeech 自动会在 stepScripts 缺失时回退到 commentary.script。

YAML 示例
---------
.. code-block:: yaml

    - kind: text-commentary-patch
      target_id: p3-led-blink-text
      commentary:
        script: |
          LED 闪烁是嵌入式入门的第一课。我们看这页正文：LED 必须串联 220Ω 限流电阻
          才能保护它不被烧毁；电路连接是 PA5 → 220Ω → LED 正极 → LED 负极 → GND。
"""
from __future__ import annotations

import glob
import os
import sys
from typing import Any

import yaml


_PATCH_KIND = 'text-commentary-patch'

# 与 apps/player/src/playback/blockToSpeech.ts 的 SPEAKABLE_KINDS 对齐。
# 不在此集合内的 kind 即使被 patch 命中也会跳过，避免给 graphics/video/table
# 等"设计静音"的 block 注入无意义 commentary。
_SPEAKABLE_KINDS = frozenset({
    'text', 'code', 'animation', 'callout', 'info-table',
    'principles', 'summary', 'experiment', 'digital-human',
    'interactive', 'section-intro', 'mindmap',
})


def _repo_root() -> str:
    # 本文件位于 apps/player/public/manifest/，仓库根 = 上 4 层。
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), '..', '..', '..', '..')
    )


def discover_template_roots() -> list[str]:
    """发现所有 materials/<course>/_templates 目录（仓库相对路径）。

    与 codeflow_patches.discover_template_roots 行为一致：
      1) 环境变量 DGBOOK_TEMPLATE_ROOTS（分号或冒号分隔）；
      2) glob materials/*/_templates（排除 _ 开头的内部目录）。
    """
    env = os.environ.get('DGBOOK_TEMPLATE_ROOTS', '').strip()
    if env:
        sep = ';' if ';' in env else ':'
        return [p.strip() for p in env.split(sep) if p.strip()]

    root = _repo_root()
    materials = os.path.join(root, 'materials')
    if not os.path.isdir(materials):
        return []
    out: list[str] = []
    for name in sorted(os.listdir(materials)):
        if name.startswith('_'):
            continue
        candidate = os.path.join(materials, name, '_templates')
        if os.path.isdir(candidate):
            out.append(os.path.relpath(candidate, root).replace('\\', '/'))
    return out


def _iter_patch_entries() -> list[dict[str, Any]]:
    """扫所有 extras.yaml，返回 ``kind: text-commentary-patch`` 的 entry 列表。"""
    out: list[dict[str, Any]] = []
    root = _repo_root()
    for tpl_root in discover_template_roots():
        abs_root = tpl_root if os.path.isabs(tpl_root) else os.path.join(root, tpl_root)
        if not os.path.isdir(abs_root):
            continue
        pattern = os.path.join(abs_root, '**', '*.extras.yaml')
        for ex_path in glob.glob(pattern, recursive=True):
            try:
                with open(ex_path, encoding='utf-8') as fp:
                    items = yaml.safe_load(fp)
            except OSError as exc:
                rel = os.path.relpath(ex_path, root)
                print(
                    f'[text_commentary_patches] ⚠️  无法打开 {rel}: {exc}',
                    file=sys.stderr,
                )
                continue
            except yaml.YAMLError as exc:
                rel = os.path.relpath(ex_path, root)
                mark = getattr(exc, 'problem_mark', None)
                loc = (
                    f' (line {mark.line + 1}, col {mark.column + 1})'
                    if mark is not None else ''
                )
                problem = getattr(exc, 'problem', str(exc))
                print(
                    f'[text_commentary_patches] ⚠️  YAML 解析失败 {rel}{loc}: '
                    f'{problem} —— 该文件中的 patch 全部被跳过',
                    file=sys.stderr,
                )
                continue
            if not isinstance(items, list):
                continue
            for item in items:
                if not isinstance(item, dict):
                    continue
                if item.get('kind') != _PATCH_KIND:
                    continue
                tagged = dict(item)
                tagged['_source'] = os.path.relpath(ex_path, root)
                out.append(tagged)
    return out


def _find_block(manifest: dict, block_id: str) -> dict | None:
    """在 manifest 中按 id 找任意 block（不限制 kind）。"""
    for ch in manifest.get('chapters', []) or []:
        for sec in ch.get('sections', []) or []:
            for pg in sec.get('pages', []) or []:
                for b in pg.get('blocks') or []:
                    if b.get('id') == block_id:
                        return b


def _is_nonempty_string(v: Any) -> bool:
    return isinstance(v, str) and bool(v.strip())


def _is_nonempty_string_list(v: Any) -> bool:
    return (
        isinstance(v, list)
        and len(v) > 0
        and any(_is_nonempty_string(s) for s in v)
    )


def apply_text_commentary_patches(manifest: dict) -> tuple[int, int, int]:
    """注入 commentary 到对应 block。

    返回 (matched, skipped, ignored)：
      - matched：成功 patch 的 block 数（至少注入了一项 script/stepScripts）
      - skipped：因 target_id 找不到对应 block 而跳过的 patch 数
      - ignored：找到了 block 但 kind 不是 SPEAKABLE，或既有数据已存在拒绝覆盖

    注入策略（保护既有 step 同步数据）：
      - 若 yaml 提供 stepScripts 且 target 既有 stepScripts 非空 → 不动 target
        （final_animation / codeflow 已注入的优先，避免被纯文 patch 覆盖）。
      - 若 yaml 提供 script 且 target 既有 script / stepScripts 非空 → 不动 target。
      - 否则注入对应字段。

    2 设计意图：text-commentary-patch 是\"哑巴 block 拉回朗读链路\"
    的最小工具，**保守不覆盖**保证可重复运行。
    """
    matched = 0
    skipped = 0
    ignored = 0

    for patch in _iter_patch_entries():
        target_id = patch.get('target_id')
        if not isinstance(target_id, str) or not target_id:
            skipped += 1
            continue
        target = _find_block(manifest, target_id)
        if target is None:
            skipped += 1
            continue
        if target.get('kind') not in _SPEAKABLE_KINDS:
            ignored += 1
            continue

        commentary_in = patch.get('commentary')
        if not isinstance(commentary_in, dict):
            ignored += 1
            continue

        # 取 target 既有 commentary（没有则建空 dict）
        existing = target.get('commentary')
        existing = dict(existing) if isinstance(existing, dict) else {}

        any_change = False

        # stepScripts 优先级最高：若 patch 给了且 target 还没非空数组，则注入。
        in_steps = commentary_in.get('stepScripts')
        if _is_nonempty_string_list(in_steps):
            cur_steps = existing.get('stepScripts')
            if not _is_nonempty_string_list(cur_steps):
                existing['stepScripts'] = list(in_steps)
                any_change = True

        # script 兜底：若 patch 给了且 target 既无非空 script 也无非空 stepScripts，
        # 则注入（避免覆盖任何已有朗读源）。
        in_script = commentary_in.get('script')
        if _is_nonempty_string(in_script):
            has_step = _is_nonempty_string_list(existing.get('stepScripts'))
            has_script = _is_nonempty_string(existing.get('script'))
            if not has_step and not has_script:
                existing['script'] = in_script
                any_change = True

        # 其它键（如 voice / lang / hint）：补全式注入，不覆盖
        for k, v in commentary_in.items():
            if k in ('script', 'stepScripts'):
                continue
            if k not in existing:
                existing[k] = v
                any_change = True

        if any_change:
            target['commentary'] = existing
            matched += 1
        else:
            ignored += 1

    return matched, skipped, ignored


# CLI 自检：python -m manifest.text_commentary_patches
if __name__ == '__main__':
    import json
    import sys

    sys.stdout.reconfigure(encoding='utf-8')  # type: ignore[attr-defined]
    roots = discover_template_roots()
    print(f'discovered {len(roots)} template root(s):')
    for r in roots:
        print(f'  - {r}')
    entries = _iter_patch_entries()
    print(f'discovered {len(entries)} text-commentary-patch entr(ies)')
    for e in entries:
        target = e.get('target_id')
        comm = e.get('commentary') or {}
        n_step = len(comm.get('stepScripts') or [])
        has_script = bool((comm.get('script') or '').strip())
        print(
            f'  - target_id={target!r:<28} '
            f'step={n_step}  script={has_script}  '
            f'source={e.get("_source")}'
        )

    mf_path = os.path.join(_repo_root(), 'apps', 'player', 'public', 'manifest.json')
    if os.path.isfile(mf_path):
        with open(mf_path, encoding='utf-8') as fp:
            mf = json.load(fp)
        m, s, i = apply_text_commentary_patches(mf)
        print(f'apply result: matched={m}  skipped={s}  ignored={i}')
    else:
        print(f'(skip apply test: manifest.json not found at {mf_path})')
