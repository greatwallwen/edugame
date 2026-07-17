# -*- coding: utf-8 -*-
"""
DGBook Manifest 生成包

包结构：
  manifest/
    blocks.py           – 建块辅助函数（text_block, code_block, …）
    svgs.py             – 内联 SVG 图形生成
    factories.py        – DRY 工厂（build_intro_page, build_extension_page, build_worksheet_page）
    quizzes.py          – 题库（build_quizzes）
    chapters/
      ch01.py … ch12.py – 各章节页面生成
      worksheets.py     – 所有实训工作页
      extras.py         – 额外子页面
    manifest_builder.py – main() 组装入口
"""
