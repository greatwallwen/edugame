"""
generate_page_actions.py

为 manifest 全部 page 自动生成 page.actions（spotlight + speak 微电影序列），
让 PageActionRunner 接管所有页的播报，淘汰 BlockPlaybackEngine 模式 A。

规则（奥卡姆，最小复杂度）：
  - 每个 SPEAKABLE block 按 stepScripts 拆段：N 段 stepScripts → N 个 [spotlight, speak] 对
  - 没 stepScripts 但有 commentary.script / metadata.teacher.script → 1 段
  - graphics/mermaid block 含 nodes 时：前 min(len(nodes), len(steps)) 段绑定节点级
    elementId = dgb-{kind}-{node.id}；剩余段绑 dgb-block-{block.id}
  - Wokwi：dgb-wokwi-{block.id}
  - 默认（含 text/code/callout/info-table/principles/summary/experiment/digital-human/interactive/widget）：
    dgb-block-{block.id}
  - animation block：speak 用 metadata.teacher.stepScripts，spotlight 用
    dgb-anim-step-{N}（生产 Shell.tsx 已识别此协议派 dgb-step iframe message）

跳过的 kind（纯视觉 / 已有非线性互动 / 大段元数据）：
  - finale-challenge（独立交互卡，自带 onClick）
  - quiz-intro-animation（视觉装饰）
  - mindmap（视觉，已有 stepScripts 也太短不值得）

幂等：每次覆盖 page.actions（注入新版本）；用 hash 探测，相同跳过。

用法：
  python apps/player/public/manifest/generate_page_actions.py
"""
import hashlib
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')
PUBLIC = os.path.join(ROOT, 'apps', 'player', 'public')


def load_video_subtitles(block):
    """为 manim 视频 block 生成"视频时间轴字幕"。

    数据源（优先级）：
      1. sibling 的 <name>.sections.json：每段 {name, duration}
         → 字幕文案=section name；时间点=各段 duration 累加（0-based 起始）。
         这是与画面最精确对齐的来源。
      2. 回退：metadata.teacher.stepScripts 按视频估计时长均分（无 sections 时）。

    返回 list[{'t': float, 'text': str}]，无数据时返回 []。
    """
    src = block.get('src') or ''
    # src 形如 ./assets/.../led_blink.mp4 → led_blink.sections.json
    subs = []
    if src.endswith('.mp4') or src.endswith('.webm'):
        rel = src.lstrip('./')
        base = os.path.splitext(os.path.join(PUBLIC, rel))[0]
        sec_path = base + '.sections.json'
        if os.path.exists(sec_path):
            try:
                with open(sec_path, encoding='utf-8') as f:
                    sections = json.load(f)
                t = 0.0
                for s in sections:
                    name = (s.get('name') or '').strip()
                    if name:
                        subs.append({'t': round(t, 2), 'text': name})
                    try:
                        t += float(s.get('duration') or 0)
                    except (TypeError, ValueError):
                        t += 3.0
                if subs:
                    return subs
            except Exception:
                pass
    # 回退：stepScripts 均分
    teacher = (block.get('metadata') or {}).get('teacher') or {}
    steps = [s for s in (teacher.get('stepScripts') or []) if isinstance(s, str) and s.strip()]
    if steps:
        try:
            dur = float((block.get('metadata') or {}).get('duration') or 0)
        except (TypeError, ValueError):
            dur = 0.0
        per = (dur / len(steps)) if dur > 0 else 4.0
        return [{'t': round(i * per, 2), 'text': s} for i, s in enumerate(steps)]
    return []


# 哪些 block 值得朗读（与 apps/player/src/playback/blockToSpeech.ts SPEAKABLE_KINDS 对齐）
SPEAKABLE = {
    'text', 'code', 'animation', 'callout', 'info-table',
    'principles', 'summary', 'digital-human', 'interactive', 'widget',
    'graphics', 'mermaid', 'wokwi-element', 'experiment',
}

# 完全跳过的 kind
SKIP = {'finale-challenge', 'quiz-intro-animation', 'mindmap'}


def get_steps(block):
    """从 block 抽 stepScripts 列表。优先 commentary.stepScripts，
    其次 metadata.teacher.stepScripts，再次 commentary.script / teacher.script。"""
    cm = block.get('commentary') or {}
    if isinstance(cm.get('stepScripts'), list) and cm['stepScripts']:
        return [s for s in cm['stepScripts'] if isinstance(s, str) and s.strip()]
    teacher = (block.get('metadata') or {}).get('teacher') or {}
    if isinstance(teacher.get('stepScripts'), list) and teacher['stepScripts']:
        return [s for s in teacher['stepScripts'] if isinstance(s, str) and s.strip()]
    if isinstance(cm.get('script'), str) and cm['script'].strip():
        return [cm['script'].strip()]
    if isinstance(teacher.get('script'), str) and teacher['script'].strip():
        return [teacher['script'].strip()]
    # interactive 用 spec.prompt 兜底
    spec = block.get('spec') or {}
    if isinstance(spec.get('prompt'), str) and spec['prompt'].strip():
        return [spec['prompt'].strip()]
    # callout 用 markdown
    if isinstance(block.get('markdown'), str) and block['markdown'].strip():
        first_line = block['markdown'].split('\n', 1)[0].strip().lstrip('#').strip()
        return [first_line] if first_line else []
    # Wokwi 元件兜底：用 caption 或 spec.label 生成 1 段简介
    kind = block.get('kind')
    if kind == 'wokwi-element':
        caption = block.get('caption')
        if isinstance(caption, str) and caption.strip():
            return [caption.strip()]
        spec_kind = (spec.get('kind') if isinstance(spec, dict) else None) or ''
        spec_label = (spec.get('label') if isinstance(spec, dict) else None) or ''
        if spec_kind == 'led':
            return [f'这是 LED 发光二极管，标号 {spec_label or "PA5"}。']
        if spec_kind == 'resistor':
            return ['这是限流电阻，把工作电流压在安全范围。']
        if spec_kind == 'pushbutton':
            return ['这是按键，按下导通电路。']
        return [block.get('title') or '元件展示']
    # graphics / mermaid 没 stepScripts 但有 nodes：用 nodes 描述生成
    if kind in ('graphics', 'mermaid') and isinstance(block.get('nodes'), list):
        nodes = block['nodes']
        if nodes:
            out = []
            for n in nodes:
                desc = n.get('description') or n.get('label') or n.get('id', '')
                if desc:
                    out.append(desc)
            if out:
                return out
    return []


def target_id_for(block, idx):
    """给 idx 段 spotlight 算 elementId。

    text block：dgb-text-{bid}-s{idx}，框住对应的 h2/h3 标题。
    TextBlock.tsx 只给 h2/h3 编号（不给 p），所以 s{idx} 对应第 idx 个标题。
    如果标题数量不够，fallback 到 dgb-block-{bid}（整块高亮）。
    """
    kind = block.get('kind')
    bid = block.get('id', '')
    if kind == 'wokwi-element':
        return f'dgb-wokwi-{bid}'
    if kind == 'animation':
        return f'dgb-anim-step-{idx + 1}'
    if kind in ('graphics', 'mermaid'):
        nodes = block.get('nodes') or []
        if idx < len(nodes):
            n = nodes[idx]
            prefix = 'dgb-graphics' if kind == 'graphics' else 'dgb-mermaid'
            return f'{prefix}-{n.get("id", "")}'
    # text block：指向第 idx 个 h2/h3 标题
    if kind == 'text':
        md = block.get('markdown', '')
        # 计算 markdown 中的 h2/h3 数量
        heading_count = sum(1 for line in md.split('\n')
                          if line.startswith('## ') or line.startswith('### '))
        if idx < heading_count:
            return f'dgb-text-{bid}-s{idx}'
        # 标题不够：fallback 到整块
        return f'dgb-block-{bid}'
    # 所有其他 block：整块 spotlight
    return f'dgb-block-{bid}'


def make_actions_for_page(page):
    """生成一页的 page.actions。返回 list[dict]。

    Iter-68 · 5G 教材风格：严格按 page.blocks 原始顺序逐块播报。
    每个 SPEAKABLE block 按其 stepScripts 拆出 spotlight + speak 对。
    text block 整块高亮（dgb-block-{bid}），不拆段落。
    """
    actions = []
    seq = [0]
    page_id = page.get('id', 'p')

    def emit_block(block):
        kind = block.get('kind')
        if kind in SKIP or kind not in SPEAKABLE:
            return
        steps = get_steps(block)
        if not steps:
            return

        #   生成 play-video action，携带"视频时间轴字幕"（来自 sections.json 的
        #   name+duration），播放器按 video.currentTime 逐句切字幕（与画面对齐），
        #   ended 后继续 cursor。先 spotlight 让视频块高亮+滚动到位，再 play-video。
        fmt = block.get('format')
        if kind == 'animation' and fmt in ('video-mp4', 'video-webm'):
            bid = block.get('id')
            subs = load_video_subtitles(block)
            seq[0] += 1
            actions.append({
                'id': f'{page_id}-act-{seq[0]:03d}-sp',
                'type': 'spotlight',
                'targetId': f'dgb-block-{bid}',
            })
            pv = {
                'id': f'{page_id}-act-{seq[0]:03d}-pv',
                'type': 'play-video',
                'targetId': f'dgb-block-{bid}',
            }
            if subs:
                pv['subtitles'] = subs
            seq[0] += 1
            pv['id'] = f'{page_id}-act-{seq[0]:03d}-pv'
            actions.append(pv)
            return
        for i, text in enumerate(steps):
            tid = target_id_for(block, i)
            seq[0] += 1
            actions.append({
                'id': f'{page_id}-act-{seq[0]:03d}-sp',
                'type': 'spotlight',
                'targetId': tid,
            })
            seq[0] += 1
            actions.append({
                'id': f'{page_id}-act-{seq[0]:03d}-sk',
                'type': 'speak',
                'text': text[:600],
                'blockId': block.get('id'),
            })

    blocks = page.get('blocks', [])
    # Iter-68 · 5G 教材风格：严格按 page.blocks 原始顺序播报，
    # 不再把 wokwi/graphics/animation 提前。教材阅读顺序 = 播报顺序。
    for b in blocks:
        emit_block(b)
    return actions


def hash_actions(actions):
    return hashlib.sha1(json.dumps(actions, ensure_ascii=False, sort_keys=True).encode()).hexdigest()[:8]


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    overwritten, skipped, kept_actions = 0, 0, 0
    for ch in m.get('chapters', []):

        if ch.get('id') == 'appendix-gallery':
            continue
        for sec in ch.get('sections', []):
            for p in sec.get('pages', []):
                acts = make_actions_for_page(p)
                if not acts:
                    skipped += 1
                    continue
                # 幂等：哈希一致跳过
                old = p.get('actions') or []
                if old and hash_actions(old) == hash_actions(acts):
                    kept_actions += 1
                    continue
                p['actions'] = acts
                overwritten += 1
                print(f'  [OK] {p["id"]:30s} actions={len(acts)//2:3d} 段（{len(acts)} actions）')

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)

    print(f'\n[SUMMARY] 新写={overwritten} · 已最新跳过={kept_actions} · 无内容跳过={skipped}')
    print(f'[OK] manifest 已写回 {MANIFEST}')


if __name__ == '__main__':
    main()
