#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inject_base.py — inject 脚本路径解耦基类

所有 inject 脚本继承此基类，统一路径计算逻辑，
使脚本无论从 manifest/ 还是 courses/xxx/inject/ 目录运行都能正确找到文件。

用法：
    from manifest.inject_base import InjectBase

    class MyInject(InjectBase):
        def run(self, m):
            # m 是 manifest dict
            page = self.find_page(m, 'p3-led-blink')
            if page:
                self.upsert_block(page, my_block)
            return m

    if __name__ == '__main__':
        MyInject().execute()
"""
import json
import os
import sys


class InjectBase:
    """inject 脚本基类，提供统一的路径计算和 manifest 操作"""

    def __init__(self):
        # 自动计算项目根目录和 manifest 路径
        self._script_file = os.path.abspath(sys.argv[0]) if sys.argv[0] else __file__
        self.ROOT = self._find_root()
        self.MANIFEST_PATH = os.path.join(
            self.ROOT, 'apps', 'player', 'public', 'manifest.json'
        )
        # 确保 manifest 模块可导入
        public_dir = os.path.join(self.ROOT, 'apps', 'player', 'public')
        if public_dir not in sys.path:
            sys.path.insert(0, public_dir)

    def _find_root(self):
        """向上查找项目根目录（含 pnpm-workspace.yaml 或 README.md）"""
        d = os.path.dirname(self._script_file)
        for _ in range(10):
            if os.path.isfile(os.path.join(d, 'pnpm-workspace.yaml')):
                return d
            if os.path.isfile(os.path.join(d, 'README.md')) and os.path.isdir(os.path.join(d, 'apps')):
                return d
            parent = os.path.dirname(d)
            if parent == d:
                break
            d = parent
        # 回退：假设在项目子目录中
        return os.path.abspath(os.path.join(os.path.dirname(self._script_file), '..', '..', '..', '..'))

    def load_manifest(self):
        """加载 manifest.json"""
        with open(self.MANIFEST_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)

    def save_manifest(self, m):
        """保存 manifest.json"""
        with open(self.MANIFEST_PATH, 'w', encoding='utf-8') as f:
            json.dump(m, f, ensure_ascii=False, indent=2)

    def find_page(self, m, page_id):
        """根据 page_id 查找页面"""
        for ch in m.get('chapters', []):
            for sec in ch.get('sections', []):
                for p in sec.get('pages', []):
                    if p.get('id') == page_id:
                        return p
        return None

    def find_all_pages(self, m):
        """返回所有页面的迭代器"""
        for ch in m.get('chapters', []):
            for sec in ch.get('sections', []):
                for p in sec.get('pages', []):
                    yield p

    def upsert_block(self, page, block_data, position='after_text'):
        """插入或替换 block（按 id 去重）
        
        position: 'after_text' | 'before_summary' | 'end' | int
        返回: True 表示新增，False 表示替换
        """
        bid = block_data.get('id')
        # 检查是否已存在
        for i, b in enumerate(page['blocks']):
            if b.get('id') == bid:
                page['blocks'][i] = block_data
                return False
        # 计算插入位置
        if position == 'after_text':
            idx = 1
            for i, b in enumerate(page['blocks']):
                if b['kind'] == 'text':
                    idx = i + 1
                    break
        elif position == 'before_summary':
            idx = len(page['blocks'])
            for i, b in enumerate(page['blocks']):
                if b['kind'] in ('summary', 'finale-challenge'):
                    idx = i
                    break
        elif isinstance(position, int):
            idx = position
        else:
            idx = len(page['blocks'])
        page['blocks'].insert(idx, block_data)
        return True

    def run(self, m):
        """子类实现：修改 manifest 并返回"""
        raise NotImplementedError

    def execute(self):
        """入口：加载 → 运行 → 保存"""
        m = self.load_manifest()
        m = self.run(m)
        self.save_manifest(m)
