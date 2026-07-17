# -*- coding: utf-8 -*-
"""
blocks.py — 建块辅助函数（DGBook manifest primitive builders）

所有函数均返回符合 manifest v4 schema 的 dict。
无外部依赖，可被 chapters/*.py 和 factories.py 直接 import。
"""
import textwrap, inspect


def text_block(bid, md):
    return {"id": bid, "kind": "text", "markdown": inspect.cleandoc(md)}


def code_block(bid, lang, code, fname=None, hl=None):
    b = {"id": bid, "kind": "code", "language": lang, "code": textwrap.dedent(code)}
    if fname: b["filename"] = fname
    if hl:   b["highlightLines"] = hl
    return b


def mindmap_block(bid, root):
    return {"id": bid, "kind": "mindmap", "root": root}


def anim_block(bid, topic, scenes):
    from manifest.svgs import mk_anim
    return {"id": bid, "kind": "animation",
            "src": f"inline:{mk_anim(topic, scenes)}",
            "format": "html-svg",
            "metadata": {"topic": topic, "duration": len(scenes) * 5}}


def intro_block(bid, qref, title, sub, itype="circuit"):
    from manifest.svgs import mk_intro
    return {"id": bid, "kind": "quiz-intro-animation",
            "animationSrc": mk_intro(title, sub),
            "triggerIcon": "🏆", "quizRef": qref, "introType": itype}


def summary_block(bid, pts, qs):
    return {"id": bid, "kind": "summary", "keyPoints": pts, "reviewQuestions": qs}


def dh_block(bid, script, faq):
    return {"id": bid, "kind": "digital-human", "script": script, "faq": faq,
            "avatarState": "explaining", "ttsEnabled": True}


def matching(bid, prompt, pairs):
    return {"id": bid, "kind": "interactive",
            "spec": {"kind": "matching", "prompt": prompt,
                     "pairs": [{"left": l, "right": r} for l, r in pairs]}}


def classification(bid, prompt, cats, items):
    return {"id": bid, "kind": "interactive",
            "spec": {"kind": "classification", "prompt": prompt,
                     "categories": [{"id": k, "label": v} for k, v in cats.items()],
                     "items": [{"id": x[0], "text": x[1], "correctCategory": x[2]} for x in items]}}


def ordering(bid, prompt, items):
    item_list = [{"id": f"o{i}", "text": t} for i, t in enumerate(items)]
    correct = [f"o{i}" for i in range(len(items))]
    return {"id": bid, "kind": "interactive",
            "spec": {"kind": "ordering", "prompt": prompt,
                     "items": item_list, "correctOrder": correct}}


def flashcard(bid, prompt, cards):
    return {"id": bid, "kind": "interactive",
            "spec": {"kind": "flashcard", "prompt": prompt,
                     "cards": [{"id": f"fc{i}", "front": f, "back": b}
                                for i, (f, b) in enumerate(cards)]}}


def interactive(bid, spec):
    """通用互动 helper：直接传完整 spec，支持任意题型
    （bit-flip / code-cloze / timed-quiz / signal-trace 等 24 种）。"""
    return {"id": bid, "kind": "interactive", "spec": spec}


def memory_match(bid, prompt, pairs):
    return {"id": bid, "kind": "interactive",
            "spec": {"kind": "memory-match", "prompt": prompt,
                     "pairs": [{"id": f"mm{i}", "front": f, "back": b}
                                for i, (f, b) in enumerate(pairs)]}}


def fill_blank(bid, prompt, segs):
    return {"id": bid, "kind": "interactive",
            "spec": {"kind": "fill-blank", "prompt": prompt, "segments": segs}}


def hotspot(bid, prompt, img_b64, spots):
    return {"id": bid, "kind": "interactive",
            "spec": {"kind": "hotspot", "prompt": prompt, "image": img_b64,
                     "hotspots": [{"id": f"h{i}", "description": d, "x": x, "y": y, "radius": r}
                                   for i, (d, x, y, r) in enumerate(spots)]}}


def table_block(bid, cap, headers, rows):
    return {"id": bid, "kind": "table", "caption": cap, "headers": headers, "rows": rows}


def experiment_block(bid, title, steps, result="按步骤操作后设备应有预期响应"):
    return {"id": bid, "kind": "experiment", "title": title, "steps": steps,
            "expectedResult": result, "troubleshooting": []}


def step(n, title, desc, code="", chk=False):
    return {"order": n, "title": title, "description": desc, "code": code, "checkpoint": chk}


def waveform_block(bid, title, ch):
    return {"id": bid, "kind": "waveform", "title": title, "channels": ch}


def page(pid, title, blocks, objectives=None, minutes=20, difficulty="beginner", tags=None):
    """页面工厂：构造符合 manifest v4 PageSchema 的 dict。"""
    p = {"id": pid, "title": title, "template": "T-concept", "blocks": blocks}
    if objectives or minutes or difficulty or tags:
        p["lesson"] = {
            "objectives": objectives or [title],
            "estimatedMinutes": minutes,
            "difficulty": difficulty,
            "tags": tags or [],
        }
    return p


def mermaid_block(bid, title=None, diagram_type="flowchart", source="", nodes=None, commentary=None):
    """Mermaid 流程图 block（first-class，与 ADR-0014 / G1.3 协议对齐）。

    chapters/*.py 中保留对此 helper 的 import；Iter-15 决策不主动注入新 mermaid block，
    但保留函数以兼容历史调用（ch02_ch03.py L657、ch06_ch07.py L403 等）。
    """
    b = {"id": bid, "kind": "mermaid", "source": source, "diagramType": diagram_type}
    if title: b["title"] = title
    if nodes: b["nodes"] = nodes
    if commentary: b["commentary"] = commentary
    return b


# ─────────────────────────────────────────────────────────────────────────────
# M10 · Finale Challenge —— 全屏游戏化挑战 block + helpers
#
# 与 quiz / interactive 的关键差异：finale-challenge 表达"多关递进 + HP/combo
# /计时 + 视听反馈 + 全屏沉浸"的复合挑战外壳，内部题目复用 InteractiveSpec
# | QuizSpec。schema 详见 packages/types/src/manifest.ts。
# ─────────────────────────────────────────────────────────────────────────────


def fq_quiz_single(qid, stem, options, answer, score=100, difficulty="easy", hint=None):
    """Finale 题：单选（quiz/single-choice）。options=[(id,label), ...]"""
    q = {
        "id": qid,
        "scoreBase": score,
        "difficulty": difficulty,
        "spec": {
            "type": "quiz",
            "data": {
                "id": qid,
                "kind": "single-choice",
                "stem": stem,
                "options": [{"id": oid, "label": lab} for oid, lab in options],
                "answer": answer,
            },
        },
    }
    if hint: q["hint"] = hint
    return q


def fq_quiz_multi(qid, stem, options, answers, score=120, difficulty="medium", hint=None):
    """Finale 题：多选（quiz/multiple-choice）。answers 为 id 列表。"""
    q = {
        "id": qid,
        "scoreBase": score,
        "difficulty": difficulty,
        "spec": {
            "type": "quiz",
            "data": {
                "id": qid,
                "kind": "multiple-choice",
                "stem": stem,
                "options": [{"id": oid, "label": lab} for oid, lab in options],
                "answer": list(answers),
            },
        },
    }
    if hint: q["hint"] = hint
    return q


def fq_quiz_tf(qid, stem, answer, score=80, difficulty="easy", hint=None):
    """Finale 题：判断（quiz/true-false）。"""
    q = {
        "id": qid,
        "scoreBase": score,
        "difficulty": difficulty,
        "spec": {
            "type": "quiz",
            "data": {
                "id": qid,
                "kind": "true-false",
                "stem": stem,
                "answer": bool(answer),
            },
        },
    }
    if hint: q["hint"] = hint
    return q


def fq_quiz_fill(qid, stem, answers, placeholder="___", score=120, difficulty="medium", hint=None):
    """Finale 题：填空（quiz/fill-blank）。answers=可接受答案列表。"""
    q = {
        "id": qid,
        "scoreBase": score,
        "difficulty": difficulty,
        "spec": {
            "type": "quiz",
            "data": {
                "id": qid,
                "kind": "fill-blank",
                "stem": stem,
                "placeholder": placeholder,
                "answers": list(answers),
            },
        },
    }
    if hint: q["hint"] = hint
    return q


def fq_int_matching(qid, prompt, pairs, score=120, difficulty="medium", hint=None):
    """Finale 题：连线（interactive/matching）。pairs=[(left,right), ...]"""
    q = {
        "id": qid,
        "scoreBase": score,
        "difficulty": difficulty,
        "spec": {
            "type": "interactive",
            "data": {
                "kind": "matching",
                "prompt": prompt,
                "pairs": [{"left": l, "right": r} for l, r in pairs],
            },
        },
    }
    if hint: q["hint"] = hint
    return q


def fq_int_ordering(qid, prompt, items, score=140, difficulty="medium", hint=None):
    """Finale 题：排序（interactive/ordering）。items=正确顺序的文本列表。"""
    item_list = [{"id": f"o{i}", "text": t} for i, t in enumerate(items)]
    correct = [f"o{i}" for i in range(len(items))]
    q = {
        "id": qid,
        "scoreBase": score,
        "difficulty": difficulty,
        "spec": {
            "type": "interactive",
            "data": {
                "kind": "ordering",
                "prompt": prompt,
                "items": item_list,
                "correctOrder": correct,
            },
        },
    }
    if hint: q["hint"] = hint
    return q


def finale_stage(sid, title, questions, time_limit_sec=60, subtitle=None, pass_threshold=0.6):
    s = {
        "id": sid,
        "title": title,
        "questions": questions,
        "timeLimitSec": time_limit_sec,
        "passThreshold": pass_threshold,
    }
    if subtitle: s["subtitle"] = subtitle
    return s


def finale_challenge_block(
    bid,
    title,
    stages,
    intro=None,
    boss_stage_index=None,
    hp_max=3,
    bgm_track="tense",
    trigger_label="挑战测验",
    trigger_icon="🏆",
):
    """Finale Challenge block：全屏游戏化最后挑战。

    参数:
        bid: block id
        title: 挑战标题（HUD + 入口卡显示）
        stages: 关卡列表（finale_stage(...) 返回值组成的 list）
        intro: 入场旁白 / 副标题
        boss_stage_index: Boss 关索引；缺省 = 最后一关
        hp_max: HP 上限（1-10）
        bgm_track: 'tense' | 'epic' | 'calm'
        trigger_label / trigger_icon: 入口卡文案与图标
    """
    b = {
        "id": bid,
        "kind": "finale-challenge",
        "title": title,
        "stages": stages,
        "hpMax": hp_max,
        "bgmTrack": bgm_track,
        "triggerLabel": trigger_label,
        "triggerIcon": trigger_icon,
    }
    if intro: b["intro"] = intro
    if boss_stage_index is not None: b["bossStageIndex"] = boss_stage_index
    return b


# ─── M11 子-A · narration helpers（链式包裹，便于 chapters 直接在调用点注入播报） ───
#
# 这两个 helper 与 inject_narration_*.py 中的"按 id 注入"是互补的两条路径：
#   - with_teacher / with_commentary：在 chapters 调用点同步注入（适合一处一个 block）
#   - inject_narration_*.apply_to_pages / apply_to_manifest：批量注入（适合数据量大、复用）
# 两者都不破坏 SPEAKABLE 字段约定（与 apps/player/src/playback/blockToSpeech.ts 对齐）。

def with_teacher(anim_blk, *, script=None, step_scripts=None,
                 voice="Cherry", auto_play=False, scene_id=None, steps=None):
    """把 teacher narration 写入 animation block 的 metadata.teacher 字段。

    blockToSpeech 提取顺序：metadata.teacher.stepScripts 优先 → metadata.teacher.script。
    """
    if anim_blk.get("kind") != "animation":
        return anim_blk  # 无声拒绝，避免误用
    meta = anim_blk.setdefault("metadata", {})
    teacher = dict(meta.get("teacher") or {})
    if script: teacher["script"] = script
    if step_scripts: teacher["stepScripts"] = list(step_scripts)
    if voice: teacher.setdefault("voice", voice)
    teacher.setdefault("autoPlay", auto_play)
    if scene_id: teacher["sceneId"] = scene_id
    if steps: teacher["steps"] = list(steps)
    meta["teacher"] = teacher
    return anim_blk


def with_commentary(blk, *, script=None, step_scripts=None):
    """把 commentary 写入 text/code/experiment/mermaid/graphics block。

    blockToSpeech 提取顺序：commentary.stepScripts 优先 → commentary.script。
    """
    if blk.get("kind") not in ("text", "code", "experiment", "mermaid", "graphics"):
        return blk
    c = dict(blk.get("commentary") or {})
    if step_scripts: c["stepScripts"] = list(step_scripts)
    if script: c["script"] = script
    blk["commentary"] = c
    return blk
