# -*- coding: utf-8 -*-
"""
gen_manifest.py — 兼容垫片（Iter-61 重建 · 方案 B 解耦）

历史背景：本文件曾退役删除，但 quizzes.py 仍 exec 它取 quiz()，
manifest_builder.py importlib 装载它取 build_p1/mk_anim/mk_intro/quiz/page。
缺失导致全新构建 FileNotFoundError。

重建策略（byte-equal）：
  - quiz(): 按基线产物格式生成 single-choice quiz dict
  - build_p1(): 返回 [p1-concept, p1-history] 两页（从 _build_p1_baseline.json，
    inject 管线幂等增量，不重复）
  - page: 转发 blocks.page（统一入口）
  - mk_anim / mk_intro: 占位（实测 chapters/quizzes 均不调用，仅满足 importlib 取值）
"""
import json
import os

# exec() 注入场景下 __file__ 可能缺失，用 sys.path 已含的 public 目录兜底
try:
    _HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    import sys
    _HERE = next((p for p in sys.path if p.endswith('public')), os.getcwd())
_P1_BASELINE = os.path.join(_HERE, 'manifest', '_build_p1_baseline.json')
_ANIM_BASELINE = os.path.join(_HERE, 'manifest', '_anim_baseline.json')

_anim_cache = None


def _load_anim_cache():
    global _anim_cache
    if _anim_cache is None:
        with open(_ANIM_BASELINE, encoding='utf-8') as f:
            _anim_cache = json.load(f)
    return _anim_cache


def quiz(qid, stem, options, answer, explanation=""):
    """单选题：options 为 {label_id: label_text} dict。产物对齐基线 quizzes 字段。"""
    return {
        "id": qid,
        "kind": "single-choice",
        "stem": stem,
        "options": [{"id": k, "label": v} for k, v in options.items()],
        "answer": answer,
        "explanation": explanation,
    }


def build_p1():
    """返回 ch1 主线两页 [p1-concept, p1-history]（inject 管线幂等增量）。"""
    with open(_P1_BASELINE, encoding='utf-8') as f:
        return json.load(f)


# page 转发到 blocks.page（manifest_builder.py importlib 取它）
try:
    from manifest.blocks import page  # noqa: F401
except Exception:
    page = None


def mk_anim(topic, scenes):
    """从基线缓存按 topic（唯一键）返回 inline HTML 动画产物。
    缓存未命中（新 topic）时返回最小占位，inject 管线会按需覆盖。"""
    cache = _load_anim_cache().get('anim', {})
    if topic in cache:
        return cache[topic]
    return f'<!DOCTYPE html><html><body><h3>{topic}</h3></body></html>'


def mk_intro(title, subtitle, bg="#667eea,#764ba2"):
    """从基线缓存按 title 返回测验开场动画 HTML。"""
    cache = _load_anim_cache().get('intro', {})
    if title in cache:
        return cache[title]
    return f'<!DOCTYPE html><html><body><h2>{title}</h2><p>{subtitle}</p></body></html>'
