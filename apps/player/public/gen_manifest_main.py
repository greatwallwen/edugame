# -*- coding: utf-8 -*-
"""
gen_manifest_main.py — manifest 全量构建入口（Iter-61 重建 · 方案 B）

历史背景：本文件曾退役，导致 cicd.py step_gen 跳过从零重建，
只能在已有 manifest.json 基线上增量 inject。重建后支持全新 clone 一键构建。

职责：调 manifest_builder.main() 从 chapters 工厂组装完整 manifest.json，
随后 cicd 的 inject_all / generate_page_actions / build_gallery 在其上增量。

用法：python apps/player/public/gen_manifest_main.py
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)


def main():
    from manifest.manifest_builder import main as build_main
    build_main()


if __name__ == '__main__':
    main()
