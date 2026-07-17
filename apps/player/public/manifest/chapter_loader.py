# -*- coding: utf-8 -*-
"""
chapter_loader.py — 1 · 动态 chapter 加载器

读取 materials/<course>/_templates/_meta.yaml 中的 `build_modules` 段，
按声明顺序 importlib 加载章节模块，并把每个模块导出的工厂函数收集进
返回的 dict，供 manifest_builder.py 使用。

设计目标
--------
1. 加新章节 / 拆分章节模块时只改 _meta.yaml；零 Python 代码改动。
2. 容错：_meta.yaml 缺失 / build_modules 缺失 / yaml 库不存在 → 优雅返回 None，
   manifest_builder.py 回退到 Phase 6 硬编码 import 行为。
3. 不依赖第三方包：优先用标准库 yaml，没有就用极简 yaml 解析器
   （build_modules 段格式固定，正则即可）。

返回结构
--------
load_chapter_factories(course_id) -> dict[str, callable] | None
  例如：{
    "build_p1_goals_page":  <function>,
    "build_p2_gpio_hal_page": <function>,
    "build_p2_pages": <function>,
    ...
  }
None 表示加载失败，调用方应回退到硬编码。
"""
from __future__ import annotations
import os
import re
import sys
import importlib
from typing import Optional, Dict, Callable, List


# 仓库根定位：本文件位于 apps/player/public/manifest/chapter_loader.py
_THIS_FILE = os.path.abspath(__file__)
_MANIFEST_DIR = os.path.dirname(_THIS_FILE)
_PUBLIC_DIR = os.path.dirname(_MANIFEST_DIR)
_PLAYER_DIR = os.path.dirname(_PUBLIC_DIR)
_APPS_DIR = os.path.dirname(_PLAYER_DIR)
_REPO_ROOT = os.path.dirname(_APPS_DIR)


def _meta_path_for(course_id: str) -> Optional[str]:
    """已知 course_id → _templates/_meta.yaml 绝对路径。"""
    # 约定：materials/<dir>/_templates/_meta.yaml，dir 与 course_id 不必同名，
    # 故扫描所有 materials/*/_templates/_meta.yaml 找匹配。
    materials = os.path.join(_REPO_ROOT, 'materials')
    if not os.path.isdir(materials):
        return None
    for entry in sorted(os.listdir(materials)):
        candidate = os.path.join(materials, entry, '_templates', '_meta.yaml')
        if os.path.isfile(candidate):
            text = _read_text(candidate)
            if text and _meta_course_id(text) == course_id:
                return candidate
    return None


def _read_text(path: str) -> Optional[str]:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()
    except OSError:
        return None


def _meta_course_id(text: str) -> Optional[str]:
    m = re.search(r'^course_id\s*:\s*(\S+)\s*$', text, re.MULTILINE)
    return m.group(1).strip() if m else None


def _parse_build_modules(text: str) -> Optional[List[dict]]:
    """极简 yaml 解析：只懂 _meta.yaml 里 `build_modules:` 这一段固定格式。

    可识别：
        build_modules:
          - module: manifest.chapters.ch01
            functions: [build_p1_goals_page, build_p2_gpio_hal_page]
          - module: manifest.chapters.ch02_ch03
            functions: [build_p2_pages, build_p3_pages]

    遇任何意外格式 → 返回 None，调用方回退。
    """
    # 1. 找 build_modules: 段；段尾以下一项零缩进的 yaml key 或 EOF 为界
    block_match = re.search(
        r'^build_modules\s*:\s*\n(.*?)(?=\n[a-zA-Z_][\w\-]*\s*:|\Z)',
        text,
        re.DOTALL | re.MULTILINE,
    )
    if not block_match:
        return None
    block = block_match.group(1)

    items: List[dict] = []
    cur: Optional[dict] = None
    for raw in block.splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith('#'):
            continue
        # 新条目： "  - module: foo.bar"
        m = re.match(r'^\s*-\s*module\s*:\s*([\w\.]+)\s*$', line)
        if m:
            if cur is not None:
                items.append(cur)
            cur = {'module': m.group(1), 'functions': []}
            continue
        # functions: [a, b, c]
        m = re.match(r'^\s*functions\s*:\s*\[(.*)\]\s*$', line)
        if m and cur is not None:
            funcs = [s.strip() for s in m.group(1).split(',') if s.strip()]
            cur['functions'] = funcs
            continue
        # 其它格式忽略，但不放弃整段
    if cur is not None:
        items.append(cur)

    if not items:
        return None
    # 校验：每条都得有 module + 非空 functions
    for it in items:
        if not it.get('module') or not it.get('functions'):
            return None
    return items


def load_chapter_factories(course_id: str = 'stm32-f103') -> Optional[Dict[str, Callable]]:
    """主入口：按 _meta.yaml 动态加载章节工厂函数。

    返回 None 表示失败，调用方应回退到硬编码 import 路径。
    """
    meta = _meta_path_for(course_id)
    if not meta:
        return None
    text = _read_text(meta)
    if not text:
        return None
    modules = _parse_build_modules(text)
    if not modules:
        return None

    factories: Dict[str, Callable] = {}
    for entry in modules:
        modname = entry['module']
        try:
            mod = importlib.import_module(modname)
        except Exception as e:
            print(f'[chapter_loader] ⚠️  import {modname} 失败: {e}',
                  file=sys.stderr)
            return None
        for fname in entry['functions']:
            fn = getattr(mod, fname, None)
            if not callable(fn):
                print(f'[chapter_loader] ⚠️  {modname}.{fname} 不是 callable',
                      file=sys.stderr)
                return None
            factories[fname] = fn

    print(
        f'[chapter_loader] ✓ 动态加载 {len(modules)} 模块 / '
        f'{len(factories)} 工厂函数（_meta.yaml 驱动）',
        file=sys.stderr,
    )
    return factories
