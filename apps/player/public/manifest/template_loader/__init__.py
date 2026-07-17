"""DGBook 模板源解析层（Phase 1）。

职责：
  - discover(root)：扫描 _templates/ 下的 .md 文件
  - parse_page(path)：解析单个 .md，返回 TemplatePage（front-matter + blocks）
  - 仅做结构切分，不调用任何渲染器/不写 manifest

不做：
  - 不写文件、不修改主链路 manifest.json
  - 不解析 animation 的 inline HTML（H3 由 final_animation_blocks.json 唯一控制）
  - 不强行模板化 interactive / experiment 等 8 类 block（走 extras 旁路）

调用方：
  - scripts/_phase1_preview_from_materials.py（preview-only diff）
  - archive/scripts/_phase1_test_parser.py（已归档；当年的 snapshot 测试）
"""
from .parser import (
    TemplatePage,
    TemplateBlock,
    discover,
    discover_meta,
    parse_page,
    parse_block_header,
    ParserError,
)

__all__ = [
    'TemplatePage',
    'TemplateBlock',
    'discover',
    'discover_meta',
    'parse_page',
    'parse_block_header',
    'ParserError',
]
