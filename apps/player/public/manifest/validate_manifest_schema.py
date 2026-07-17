"""
validate_manifest_schema.py · 轻量 manifest 关键字段校验（构建期守门）

不复刻完整 zod schema，只拦本轮踩过的高频错误：
  - animation.metadata.engine 必须 ∈ 合法枚举（曾误填 'html-svg' 致整站加载失败）
  - block.kind 必须 ∈ 已知集合
  - interactive.spec.kind 必须 ∈ 已知题型

退出码：0 通过；1 发现非法字段。
用法：python apps/player/public/manifest/validate_manifest_schema.py
"""
import json
import os
import sys

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

# 与 packages/types 的枚举保持一致
VALID_ENGINE = {'svg', 'threejs', 'manim', 'lottie', 'css', 'html-canvas'}
VALID_INTERACTIVE = {
    'matching', 'fill-blank', 'spot-difference', 'ordering', 'classification',
    'hotspot', 'memory-match', 'flashcard', 'code-cloze', 'bit-flip',
    'single-choice', 'multiple-choice', 'true-false', 'timed-quiz', 'slider-estimate',
    'sequence-builder', 'truth-table', 'base-converter', 'register-config',
    'waveform-tuner', 'parameter-match', 'hotspot-sequence', 'drag-label',
    'signal-trace',
    'register-decoder',
}


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    errors = []
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                for b in p.get('blocks', []):
                    bid = b.get('id', '?')
                    if b.get('kind') == 'animation':
                        eng = (b.get('metadata') or {}).get('engine')
                        if eng is not None and eng not in VALID_ENGINE:
                            errors.append(f'{p["id"]}/{bid}: 非法 engine={eng!r}（合法 {sorted(VALID_ENGINE)}）')
                    if b.get('kind') == 'interactive':
                        ik = (b.get('spec') or {}).get('kind')
                        if ik is not None and ik not in VALID_INTERACTIVE:
                            errors.append(f'{p["id"]}/{bid}: 非法 interactive kind={ik!r}')

    if errors:
        print('[schema] ❌ 发现非法字段：', file=sys.stderr)
        for e in errors:
            print('   ' + e, file=sys.stderr)
        return 1
    print('[schema] ✓ manifest 关键字段校验通过（engine / interactive kind）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
