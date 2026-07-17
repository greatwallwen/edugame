"""
build_capabilities.py

为样板教材生成「能力清单」(capabilities) 顶层字段 + 元素画廊页 (gallery)。

战略目标（为未来教材准备）：
  - capabilities：声明本教材用到的所有元素能力（block/interactive/animation/action）。
    这是「能力清单底座」。未来教材抽取 = 声明 capabilities 子集，
    validate_capabilities.py 校验"实际用的能力 ⊆ 声明的能力"。
  - gallery 页：把每种元素类型各取一个代表实例，集中呈现，用于：
    ① 样板教材全量展示所有元素 ② 完整测试渲染 ③ 未来教材开发者的组件目录。

幂等：每次重算 capabilities + 重建 gallery 章（id=appendix-gallery）。

用法：
  python apps/player/public/manifest/build_capabilities.py
"""
import copy
import json
import os
import sys
from collections import OrderedDict
from datetime import datetime, timezone

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

GALLERY_CHAPTER_ID = 'appendix-gallery'
GALLERY_PAGE_ID = 'gallery'


def iter_pages(m):
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                yield ch, sec, p


def scan_capabilities(m):
    """扫描全 manifest，统计实际用到的能力维度。"""
    block_kinds = OrderedDict()
    interactive_kinds = OrderedDict()
    anim_formats = OrderedDict()
    action_types = OrderedDict()
    for ch, sec, p in iter_pages(m):
        #   （与 validate_capabilities 口径一致：画廊展示什么 = 平台声明支持什么）。
        for b in p.get('blocks', []):
            k = b.get('kind', '?')
            block_kinds[k] = block_kinds.get(k, 0) + 1
            if k == 'interactive':
                ik = (b.get('spec') or {}).get('kind', '?')
                interactive_kinds[ik] = interactive_kinds.get(ik, 0) + 1
            if k == 'animation':
                f = b.get('format', '?')
                anim_formats[f] = anim_formats.get(f, 0) + 1
        for a in p.get('actions', []):
            t = a.get('type', '?')
            action_types[t] = action_types.get(t, 0) + 1
    return {
        'blockKinds': block_kinds,
        'interactiveKinds': interactive_kinds,
        'animationFormats': anim_formats,
        'playbackActions': action_types,
    }


def build_capabilities_field(scan):
    """把统计转成 capabilities 声明字段（含计数，便于审计 + 抽取参考）。"""
    return {
        'schemaVersion': 1,
        'role': 'reference-master',  # 样板教材：全量；未来教材 role=derived 并声明子集
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'blockKinds': list(scan['blockKinds'].keys()),
        'interactiveKinds': list(scan['interactiveKinds'].keys()),
        'animationFormats': list(scan['animationFormats'].keys()),
        'playbackActions': list(scan['playbackActions'].keys()),
        'counts': {
            'blockKinds': scan['blockKinds'],
            'interactiveKinds': scan['interactiveKinds'],
            'animationFormats': scan['animationFormats'],
            'playbackActions': scan['playbackActions'],
        },
    }


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    scan = scan_capabilities(m)
    m['capabilities'] = build_capabilities_field(scan)

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)

    print('[capabilities] 写入 manifest.capabilities：')
    print(f"  blockKinds       = {m['capabilities']['blockKinds']}")
    print(f"  interactiveKinds = {m['capabilities']['interactiveKinds']}")
    print(f"  animationFormats = {m['capabilities']['animationFormats']}")
    print(f"  playbackActions  = {m['capabilities']['playbackActions']}")


if __name__ == '__main__':
    main()
