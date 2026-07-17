"""
build_gallery.py

构建「元素画廊」页（id=gallery），把每种 interactive kind 各取一个代表实例
集中呈现，作为样板教材的全量元素展示 + 渲染测试 + 未来教材组件目录。

策略：从现有页面里挑每种 interactive kind 的第一个实例，深拷贝改 id 后
      塞进一个新章 appendix-gallery / section / page。配上文字说明 block。

幂等：每次删除旧 appendix-gallery 章再重建。

用法：python apps/player/public/manifest/build_gallery.py
"""
import copy
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

try:
    from gallery_demo_specs import DEMO_SPECS  # noqa: E402
except Exception:
    DEMO_SPECS = {}

INTERACTIVE_LABELS = {
    'fill-blank': '拖拽填空', 'matching': '连线配对', 'ordering': '排序闯关',
    'classification': '分类归纳', 'memory-match': '记忆配对',
    'flashcard': '闪卡复习', 'bit-flip': '寄存器位翻转',
    'spot-difference': '找不同', 'hotspot': '热点点击', 'code-cloze': '代码填空',
    'single-choice': '单选题', 'multiple-choice': '多选题', 'true-false': '判断题',
    'timed-quiz': '计时快答', 'slider-estimate': '滑块估值', 'sequence-builder': '流程拼装',
    'truth-table': '真值表填写', 'base-converter': '进制转换', 'register-config': '寄存器配置器',
    'waveform-tuner': '波形调节器', 'parameter-match': '参数匹配',
    'hotspot-sequence': '顺序点击', 'drag-label': '标签配位',
}


def iter_pages(m, skip_gallery=True):
    for ch in m.get('chapters', []):
        if skip_gallery and ch.get('id') == GALLERY_CHAPTER_ID:
            continue
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                yield p


def pick_interactive_samples(m):
    """每种 interactive kind 取第一个实例，深拷贝并改唯一 id。
    现有页面未使用的 kind 用 DEMO_SPECS 内置实例补全（保证画廊全展示 ≥20 种）。"""
    seen = {}
    for p in iter_pages(m):
        for b in p.get('blocks', []):
            if b.get('kind') != 'interactive':
                continue
            ik = (b.get('spec') or {}).get('kind')
            if ik and ik not in seen:
                clone = copy.deepcopy(b)
                clone['id'] = f'gallery-{ik}'
                seen[ik] = clone
    # 补全：教材页未使用的题型用内置 demo 实例
    for ik, spec in DEMO_SPECS.items():
        if ik not in seen:
            seen[ik] = {'id': f'gallery-{ik}', 'kind': 'interactive', 'spec': copy.deepcopy(spec)}
    return seen


def build_gallery_blocks(samples):
    blocks = []
    intro = {
        'id': 'gallery-intro', 'kind': 'text',
        'markdown': (
            '# 元素画廊 · 互动组件目录\n\n'
            '本页集中呈现样板教材支持的全部互动游戏类型，每种各一个实例，'
            '用于完整测试与未来教材的组件参考。所有游戏共享统一的得分、连击与'
            '胜利庆祝底座（game-kit）。'
        ),
    }
    blocks.append(intro)
    for ik in sorted(samples.keys()):
        label = INTERACTIVE_LABELS.get(ik, ik)
        blocks.append({
            'id': f'gallery-label-{ik}', 'kind': 'text',
            'markdown': f'## {label}（`{ik}`）',
        })
        blocks.append(samples[ik])
    return blocks


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    samples = pick_interactive_samples(m)
    blocks = build_gallery_blocks(samples)

    page = {
        'id': 'gallery', 'title': '元素画廊', 'template': 'T-concept',
        'blocks': blocks,
        'lesson': {
            'objectives': ['浏览全部互动组件类型', '理解统一的游戏底座体验'],
            'prerequisites': [], 'estimatedMinutes': 10,
            'difficulty': 'beginner', 'tags': ['gallery', 'reference'],
        },
        'actions': [],
    }
    section = {'id': 'appendix-gallery-sec', 'title': '元素画廊', 'pages': [page]}
    chapter = {
        'id': GALLERY_CHAPTER_ID, 'title': '附录 · 元素画廊',
        'overview': '样板教材全部互动元素的集中展示与测试目录。',
        'pagesRange': [1, 1],
        'sections': [section],
    }

    # 幂等：移除旧画廊章
    m['chapters'] = [ch for ch in m.get('chapters', []) if ch.get('id') != GALLERY_CHAPTER_ID]
    m['chapters'].append(chapter)

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)

    print(f'[gallery] 画廊页已构建，互动样本 {len(samples)} 种：{sorted(samples.keys())}')
    print(f'[gallery] 访问 ?page=gallery')


if __name__ == '__main__':
    main()
