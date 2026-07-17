# -*- coding: utf-8 -*-
"""路径 B 第 2 步：把 final_animation_blocks.json 中的 17 个 final 动画注入到
manifest_builder 生成的 manifest 中。

调用时机：manifest_builder.main() 在写出 manifest.json 前，
应调用 apply_final_animations(manifest)，按 block.id 整体覆盖动画 block。

为什么不直接把 inline HTML 塞进各章节 .py：
- 17 个 inline HTML 总计约 180 KB，硬编码会污染章节模块；
- 数据与生成器解耦，方便 Playwright/QA 后再补回；
- 修改动画时只改 manifest.json，跑 _export_final_animation_blocks.py 即可同步。
"""
from __future__ import annotations
import copy
import json
import os
import sys
from typing import Any

_DIR = os.path.dirname(os.path.abspath(__file__))
_DATA_FILE = os.path.join(_DIR, 'final_animation_blocks.json')


def _load_data() -> dict[str, Any]:
    if not os.path.exists(_DATA_FILE):
        raise FileNotFoundError(
            f'final_animation_blocks.json 不存在: {_DATA_FILE}\n'
            f'请先运行: python scripts/_export_final_animation_blocks.py'
        )
    with open(_DATA_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)


def apply_final_animations(manifest: dict) -> dict:
    """按 block.id 把 final_animation_blocks.json 里的 animation block
    覆盖到 manifest 中。

    返回统计字典：{replaced, missing_in_manifest, missing_in_data}
    """
    data = _load_data()
    finals = data.get('animations') or {}
    by_id: dict[str, dict] = {aid: item['block'] for aid, item in finals.items()}

    replaced = 0
    seen_ids: set[str] = set()
    seen_anim_ids_in_manifest: set[str] = set()

    for ch in manifest.get('chapters', []):
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                blocks = p.get('blocks', [])
                for i, b in enumerate(blocks):
                    if b.get('kind') != 'animation':
                        continue
                    aid = b.get('id')
                    if not aid:
                        continue
                    seen_anim_ids_in_manifest.add(aid)
                    if aid in by_id:
                        # 整块替换：保留生成器原 page 上下文，但 animation 数据全部以
                        # final 数据为准。深拷贝防止后续步骤修改污染数据源缓存。
                        blocks[i] = copy.deepcopy(by_id[aid])
                        replaced += 1
                        seen_ids.add(aid)

    missing_in_manifest = sorted(set(by_id) - seen_ids)
    # data 里未出现 = 数据源里有，但生成器没产出对应 animation block id
    missing_in_data = sorted(seen_anim_ids_in_manifest - set(by_id))

    print(f'[final_animations] 覆盖完成: {replaced}/{len(by_id)} '
          f'(数据源 final 数={len(by_id)})', file=sys.stderr)
    if missing_in_manifest:
        print('[final_animations][WARN] 数据源中但生成 manifest 未匹配的 anim id:',
              file=sys.stderr)
        for aid in missing_in_manifest:
            ctx = finals.get(aid, {})
            print(f'  · {aid} (pageId={ctx.get("pageId")}, '
                  f'chapterId={ctx.get("chapterId")})', file=sys.stderr)
    if missing_in_data:
        print('[final_animations][INFO] 生成器产出但数据源未覆盖的 anim id '
              '(将保持生成器默认):',
              file=sys.stderr)
        for aid in missing_in_data:
            print(f'  · {aid}', file=sys.stderr)

    return {
        'replaced': replaced,
        'data_total': len(by_id),
        'missing_in_manifest': missing_in_manifest,
        'missing_in_data': missing_in_data,
    }


if __name__ == '__main__':
    # 自检：直接读 manifest.json 跑一遍并打印统计（不写回文件）
    pub = os.path.dirname(_DIR)
    mf = os.path.join(pub, 'manifest.json')
    with open(mf, 'r', encoding='utf-8') as f:
        m = json.load(f)
    stats = apply_final_animations(m)
    print('self-check stats:', stats)
