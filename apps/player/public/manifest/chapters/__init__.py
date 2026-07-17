# -*- coding: utf-8 -*-
"""
chapters 子包 — 课程资产分离重定向

章节内容源文件已迁移到 courses/stm32f10x/chapters/。
通过 sys.path 注入使章节文件仍能找到 manifest.blocks 和 gen_manifest.py。
"""
import sys
import os

# 1. 让章节文件能 import manifest.* 模块
_CHAPTERS_DIR = os.path.dirname(os.path.abspath(__file__))  # manifest/chapters/
_MANIFEST_DIR = os.path.dirname(_CHAPTERS_DIR)               # manifest/
_PUBLIC_DIR = os.path.dirname(_MANIFEST_DIR)                  # public/
for _p in [_PUBLIC_DIR, _MANIFEST_DIR]:
    if _p not in sys.path:
        sys.path.insert(0, _p)

# 2. 在 courses/stm32f10x/chapters/ 中注入 _PUBLIC_DIR
#    这样章节文件的 _os.path.dirname(...) 三层计算路径仍然指向 public/
_COURSE_CHAPTERS = os.path.abspath(os.path.join(
    os.path.dirname(__file__), '..', '..', '..', '..', '..', 'courses', 'stm32f10x', 'chapters'
))
if _COURSE_CHAPTERS not in sys.path:
    sys.path.insert(0, _COURSE_CHAPTERS)

# 3. 重要：在 courses/stm32f10x/chapters/ 里放一个符号文件让路径计算兼容
#    不修改章节源文件，而是在运行时 monkey-patch __file__ 路径
#    ↓ 实际上更简单：让章节从这里加载但欺骗它 __file__ 指向原位置
import importlib.util

_ORIGINAL_CHAPTERS_DIR = _CHAPTERS_DIR  # manifest/chapters/（伪装目标）

_MODULES = [
    'ch01', 'ch02_ch03', 'ch04_ch05', 'ch06_ch07', 'ch08_ch09', 'ch10_ch12',
    'course_metadata', 'extras', 'intros_extensions', 'worksheets',
]

for _mod_name in _MODULES:
    _course_file = os.path.join(_COURSE_CHAPTERS, f'{_mod_name}.py')
    if not os.path.isfile(_course_file):
        continue
    # 加载时伪装 __file__ 路径为原始位置（让三层 dirname 计算正确）
    _fake_file = os.path.join(_ORIGINAL_CHAPTERS_DIR, f'{_mod_name}.py')
    spec = importlib.util.spec_from_file_location(
        f'manifest.chapters.{_mod_name}', _course_file,
        submodule_search_locations=[]
    )
    if spec and spec.loader:
        _mod = importlib.util.module_from_spec(spec)
        # 关键：覆盖 __file__ 让路径计算兼容
        _mod.__file__ = _fake_file
        sys.modules[f'manifest.chapters.{_mod_name}'] = _mod
        globals()[_mod_name] = _mod
        try:
            spec.loader.exec_module(_mod)
        except Exception as e:
            # 加载失败时静默，让后续的硬编码 import 兜底
            del sys.modules[f'manifest.chapters.{_mod_name}']
            del globals()[_mod_name]
