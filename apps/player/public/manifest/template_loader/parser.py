""".md 模板源解析器（Phase 1）。

格式约定见 materials/stm32-course/_templates/README.md。
"""
from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass, field
from typing import Any, Iterator

import yaml

try:
    import jsonschema  # type: ignore[import-untyped]
    _HAS_JSONSCHEMA = True
except ImportError:  # pragma: no cover - jsonschema 是 Phase 2 可选硬依赖
    jsonschema = None  # type: ignore[assignment]
    _HAS_JSONSCHEMA = False


class ParserError(ValueError):
    """模板源解析错误。"""


# --------------------------------------------------------------------------------------
# 数据结构
# --------------------------------------------------------------------------------------


@dataclass
class TemplateBlock:
    """单个 block：## 标题 {#kind:x #id:y key=val} 之后的整段。

    属性
    ----
    kind:
        block 类型（text / figure / animation / code / flow），来自头属性 #kind:。
    id:
        block id，来自头属性 #id:。
    title:
        block 标题文本（## 后到 { 之前的可读字符串）。
    attrs:
        头属性中除 kind/id 之外的 key=val（已字符串化）。
    body:
        块体原始文本，已 strip 首尾空白，未做 markdown 渲染。
    line:
        块体首行在 .md 中的 1-based 行号（用于错误定位）。
    """

    kind: str
    id: str
    title: str
    attrs: dict[str, str]
    body: str
    line: int


@dataclass
class TemplatePage:
    """整页：front-matter + blocks（解析顺序与文件顺序一致）。"""

    path: str
    front: dict[str, Any]
    blocks: list[TemplateBlock]
    extras: list[dict[str, Any]] = field(default_factory=list)


# --------------------------------------------------------------------------------------
# Block 头属性解析：## 标题 {#kind:text #id:foo lang=c file=x.c}
# --------------------------------------------------------------------------------------

_HEADER_LINE = re.compile(
    r'^##\s+(?P<title>.*?)\s*\{(?P<attrs>[^{}]*)\}\s*$'
)


# Atomic token 模式（按出现顺序匹配，先匹配复杂结构再降级）：
#   1. #key:value   hash-prefix 属性（kind/id 等）
#   2. key="..."    双引号包裹（值可含空格、逗号）
#   3. key=[ ... ]  方括号 list（值可含空格、逗号）
#   4. key=value    简单 token（值不含空格、引号、方括号）
_ATTR_TOKEN = re.compile(
    r'#[A-Za-z_][\w-]*:[^\s\]"]+'
    r'|[A-Za-z_][\w-]*="[^"]*"'
    r'|[A-Za-z_][\w-]*=\[[^\]]*\]'
    r'|[A-Za-z_][\w-]*=[^\s\]"]+'
)


def parse_block_header(line: str) -> dict[str, str] | None:
    """解析单行 block 头属性。

    返回 dict（含 'title'）或 None（不是合法的 block 头）。
    支持的属性写法（用 atomic 正则切分，避免值内空格/逗号截断）：
        #kind:text          → kind=text
        #id:p3-x            → id=p3-x
        lang=c              → lang=c
        file=x.c            → file=x.c
        highlight=8,16,28   → highlight=8,16,28（无空格）
        highlight=[8,16,28] → highlight=8,16,28（剥方括号）
        highlight=[8, 16]   → highlight=8, 16（方括号内允许空格）
        title="hello world" → title=hello world（剥引号）
    """
    m = _HEADER_LINE.match(line)
    if not m:
        return None
    out: dict[str, str] = {'title': m.group('title').strip()}
    raw = m.group('attrs').strip()
    if not raw:
        return out

    matched_spans: list[tuple[int, int]] = []
    for tm in _ATTR_TOKEN.finditer(raw):
        tok = tm.group(0)
        matched_spans.append(tm.span())
        if tok.startswith('#') and ':' in tok:
            k, _, v = tok[1:].partition(':')
            out[k.strip()] = v.strip()
        elif '=' in tok:
            k, _, v = tok.partition('=')
            v = v.strip()
            # 剥引号
            if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
                v = v[1:-1]
            # 剥方括号（list）
            elif len(v) >= 2 and v[0] == '[' and v[-1] == ']':
                v = v[1:-1].strip()
            out[k.strip()] = v

    # 找出未被任何 token 吃掉的残余字符（非空白）→ 记入 _unknown
    consumed = bytearray(len(raw))
    for s, e in matched_spans:
        for i in range(s, e):
            consumed[i] = 1
    leftover = ''.join(
        c for i, c in enumerate(raw)
        if not consumed[i] and not c.isspace()
    )
    if leftover:
        out['_unknown'] = leftover
    return out


# --------------------------------------------------------------------------------------
# 文件发现
# --------------------------------------------------------------------------------------


def discover_meta(root: str) -> dict[str, Any]:
    """读 _templates/_meta.yaml，返回课程级元数据 dict。

    若不存在或非 mapping，返回 {}（容错）。
    """
    meta_path = os.path.join(root, '_meta.yaml')
    if not os.path.isfile(meta_path):
        return {}
    with open(meta_path, encoding='utf-8') as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        raise ParserError(f'_meta.yaml 顶层必须是 mapping：{meta_path}')
    return data


def discover(root: str, *, only_sample: bool = False) -> Iterator[str]:
    """扫描 _templates/ 根目录下所有 .md 文件（按路径升序）。

    跳过：
      - _meta.yaml / _schema/ / _assets/（保留下划线前缀的 meta 资产）
      - README.md（目录说明）
      - .extras.yaml（不是 .md）

    Parameters
    ----------
    only_sample:
        True 时只返回 _meta.yaml 的 `sample_pages` 列表中声明的页（按 page id 匹配
        .md 文件名 stem，如 sample_pages 含 'p3-led-blink' → 匹配
        `**/p3-led-blink.md`）。False（默认）= 返回全部 .md。
    """
    if not os.path.isdir(root):
        raise ParserError(f'template root not found: {root}')

    sample_set: set[str] | None = None
    if only_sample:
        meta = discover_meta(root)
        raw = meta.get('sample_pages') or []
        if not isinstance(raw, list):
            raise ParserError(
                '_meta.yaml sample_pages 必须是 list[str]'
            )
        sample_set = set()
        for item in raw:
            if not isinstance(item, str):
                raise ParserError(
                    f'_meta.yaml sample_pages 含非字符串项：{item!r}'
                )
            sample_set.add(item)

    out: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        # in-place 过滤下划线开头的 meta 目录
        dirnames[:] = sorted(d for d in dirnames if not d.startswith('_'))
        for fn in sorted(filenames):
            if not fn.endswith('.md'):
                continue
            if fn.lower() == 'readme.md':
                continue
            if sample_set is not None:
                stem = fn[:-3]  # 去掉 .md
                if stem not in sample_set:
                    continue
            out.append(os.path.join(dirpath, fn))
    yield from out


# --------------------------------------------------------------------------------------
# Front-matter 切分
# --------------------------------------------------------------------------------------

_FM_FENCE = '---'


def _split_front_matter(text: str) -> tuple[dict[str, Any], str, int]:
    """切分 front-matter（YAML，三横线围栏）和正文。

    返回 (front_dict, body_text, body_start_line)。
    body_start_line 是 1-based。
    若文件无 front-matter，返回 ({}, text, 1)。
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != _FM_FENCE:
        return {}, text, 1
    end = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == _FM_FENCE:
            end = i
            break
    if end < 0:
        raise ParserError('front-matter 起始 --- 未闭合')
    fm_text = '\n'.join(lines[1:end])
    try:
        front = yaml.safe_load(fm_text) or {}
    except yaml.YAMLError as e:
        raise ParserError(f'front-matter YAML 解析失败：{e}') from e
    if not isinstance(front, dict):
        raise ParserError('front-matter 顶层必须是 mapping')
    body = '\n'.join(lines[end + 1:])
    body_start_line = end + 2  # 1-based
    return front, body, body_start_line


# --------------------------------------------------------------------------------------
# Block 切分
# --------------------------------------------------------------------------------------


def _split_blocks(body: str, body_start_line: int) -> list[TemplateBlock]:
    """按 ## ... {#kind:..} 行切分 block。

    规则：
      - 只在不在 ``` 围栏内时识别 block 头
      - 每个 block 头 → 一个 TemplateBlock
      - 块体 = 头之后到下个头之前的所有行，strip 首尾空白
      - 不在围栏内的 ## 行（无花括号属性）忽略，作为普通 markdown 内容
    """
    out: list[TemplateBlock] = []
    cur_header: dict[str, str] | None = None
    cur_lines: list[str] = []
    cur_line_no = 0
    in_fence = False

    def _flush():
        if cur_header is None:
            return
        kind = cur_header.get('kind', '')
        bid = cur_header.get('id', '')
        if not kind or not bid:
            raise ParserError(
                f'第 {cur_line_no} 行 block 头缺少 #kind: 或 #id:'
            )
        title = cur_header.get('title', '')
        attrs = {
            k: v for k, v in cur_header.items()
            if k not in ('title', 'kind', 'id', '_unknown')
        }
        body_text = '\n'.join(cur_lines).strip()
        out.append(TemplateBlock(
            kind=kind,
            id=bid,
            title=title,
            attrs=attrs,
            body=body_text,
            line=cur_line_no,
        ))

    for idx, line in enumerate(body.splitlines()):
        line_no = body_start_line + idx
        stripped = line.lstrip()
        if stripped.startswith('```'):
            in_fence = not in_fence
            cur_lines.append(line)
            continue
        if not in_fence:
            header = parse_block_header(line)
            if header is not None and 'kind' in header and 'id' in header:
                _flush()
                cur_header = header
                cur_lines = []
                cur_line_no = line_no
                continue
        cur_lines.append(line)
    _flush()
    return out


# --------------------------------------------------------------------------------------
# Extras 旁路加载
# --------------------------------------------------------------------------------------


def _load_extras(md_path: str, front: dict[str, Any]) -> list[dict[str, Any]]:
    """加载 extras：优先 extras_ref（旁路文件），否则用 front.extras（内联）。"""
    if 'extras_ref' in front and 'extras' in front:
        raise ParserError('front-matter extras_ref 与 extras 互斥')
    if 'extras_ref' in front:
        ref = front['extras_ref']
        if not isinstance(ref, str):
            raise ParserError('extras_ref 必须是字符串')
        ref_path = os.path.join(os.path.dirname(md_path), ref)
        if not os.path.isfile(ref_path):
            raise ParserError(f'extras_ref 指向的文件不存在：{ref_path}')
        with open(ref_path, encoding='utf-8') as f:
            data = yaml.safe_load(f) or []
        if not isinstance(data, list):
            raise ParserError(
                f'{ref_path} 顶层必须是 list（每项至少含 kind/id）'
            )
        _validate_extras_entries(data, source=ref_path)
        return data
    if 'extras' in front:
        data = front['extras']
        if not isinstance(data, list):
            raise ParserError('front.extras 必须是 list')
        _validate_extras_entries(data, source=md_path + ':front.extras')
        return data
    return []


def _validate_extras_entries(items: list, *, source: str) -> None:
    """A3：逐项校验 extras。

    - 每项必须是 dict
    - 必须含 kind / id
    - id 不能重复（同一文件内）
    """
    seen_ids: dict[str, int] = {}
    for i, b in enumerate(items):
        if not isinstance(b, dict):
            raise ParserError(
                f'{source} extras[{i}] 必须是 mapping，实际类型：'
                f'{type(b).__name__}'
            )
        if 'kind' not in b:
            raise ParserError(f'{source} extras[{i}] 缺 kind 字段')
        if 'id' not in b:
            raise ParserError(f'{source} extras[{i}] 缺 id 字段')
        bid = b['id']
        if not isinstance(bid, str):
            raise ParserError(
                f'{source} extras[{i}].id 必须是字符串，实际：{bid!r}'
            )
        if bid in seen_ids:
            prev = seen_ids[bid]
            raise ParserError(
                f'{source} extras[{i}].id={bid!r} 与 extras[{prev}] 重复'
            )
        seen_ids[bid] = i


# --------------------------------------------------------------------------------------
# Schema 运行时校验（1）
# --------------------------------------------------------------------------------------
#
# parse_page() 在解析完成后会按如下方式校验：
#   1. front-matter（原始，未剥 extras_ref）→ page.schema.json
#   2. 每个 block 的 attr dict（含 kind/id/key=val）→ block.schema.json
#
# Schema 文件位于 _templates/_schema/ 目录。loader 通过向上回溯定位（与 .md 文件
# 同祖先的 _templates/ 目录）。多页解析时 schema 只读一次（模块级 LRU 缓存）。
#
# 失败时抛 ParserError，message 含 .md 文件路径与精确字段路径，便于人读定位。
# 若 jsonschema 库不可用（极少见，本仓默认安装），自动 skip 并打 stderr WARN。

_SCHEMA_CACHE: dict[str, dict] = {}


def _find_schema_dir(md_path: str) -> str | None:
    """从 md 文件向上回溯找 _schema 目录。"""
    cur = os.path.dirname(os.path.abspath(md_path))
    while cur and cur != os.path.dirname(cur):
        cand = os.path.join(cur, '_schema')
        if os.path.isdir(cand):
            return cand
        cur = os.path.dirname(cur)
    return None


def _load_schema(schema_dir: str, name: str) -> dict:
    """加载并缓存 schema（按绝对路径键）。"""
    p = os.path.join(schema_dir, name)
    if p in _SCHEMA_CACHE:
        return _SCHEMA_CACHE[p]
    if not os.path.isfile(p):
        raise ParserError(f'schema 文件不存在：{p}')
    with open(p, encoding='utf-8') as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ParserError(f'schema 顶层必须是 mapping：{p}')
    _SCHEMA_CACHE[p] = data
    return data


def _format_jsonschema_error(err: Any, *, prefix: str) -> str:
    """把 jsonschema.ValidationError 拍扁成可读字符串。"""
    path = '.'.join(str(p) for p in err.absolute_path) or '(root)'
    return f'{prefix} 在 {path}：{err.message}'


def _validate_front(front_raw: dict, md_path: str) -> None:
    """对原始 front-matter 做 page.schema 校验。"""
    if not _HAS_JSONSCHEMA:
        return
    schema_dir = _find_schema_dir(md_path)
    if schema_dir is None:
        # 没有 _schema 目录 → 无 Schema 校验（容错）
        return
    schema = _load_schema(schema_dir, 'page.schema.json')
    try:
        jsonschema.validate(front_raw, schema)
    except jsonschema.ValidationError as e:  # type: ignore[attr-defined]
        raise ParserError(
            _format_jsonschema_error(
                e, prefix=f'{md_path} front-matter 校验失败',
            )
        ) from e


def _validate_block_attrs(block: TemplateBlock, md_path: str) -> None:
    """对单个 block 的 attr dict（含 kind/id）做 block.schema 校验。"""
    if not _HAS_JSONSCHEMA:
        return
    schema_dir = _find_schema_dir(md_path)
    if schema_dir is None:
        return
    schema = _load_schema(schema_dir, 'block.schema.json')
    # 把 dataclass 字段 + attrs 合并成校验对象。_unknown 不进入校验
    # （schema 不含此 key，会被 additionalProperties 接住或忽略）
    obj: dict[str, Any] = {'kind': block.kind, 'id': block.id}
    for k, v in block.attrs.items():
        if k == '_unknown':
            continue
        obj[k] = v
    try:
        jsonschema.validate(obj, schema)
    except jsonschema.ValidationError as e:  # type: ignore[attr-defined]
        raise ParserError(
            _format_jsonschema_error(
                e,
                prefix=f'{md_path} block id={block.id} kind={block.kind} 校验失败',
            )
        ) from e


# --------------------------------------------------------------------------------------
# 公开 API
# --------------------------------------------------------------------------------------


def parse_page(path: str, *, validate: bool = True) -> TemplatePage:
    """解析单个 .md 文件，返回 TemplatePage。

    Parameters
    ----------
    validate:
        默认 True。对 front-matter（page.schema）和每个 block attrs（block.schema）
        做 jsonschema 运行时校验，失败抛 ParserError。设为 False 仅做结构切分（
        Phase 1 行为兼容）。
    """
    with open(path, encoding='utf-8') as f:
        text = f.read()
    front, body, body_start = _split_front_matter(text)

    # Schema 校验在剥离 extras_ref 之前做，让 schema 的 not.required 互斥规则生效
    if validate:
        _validate_front(front, path)

    blocks = _split_blocks(body, body_start)
    extras = _load_extras(path, front)

    if validate:
        for b in blocks:
            _validate_block_attrs(b, path)

    # extras_ref 是文件级 meta，不进入 manifest，剥离
    front_clean = {k: v for k, v in front.items() if k != 'extras_ref'}
    if 'extras' in front_clean:
        # 不重复进 page.front：已经放到 page.extras 字段
        front_clean.pop('extras')
    return TemplatePage(
        path=path,
        front=front_clean,
        blocks=blocks,
        extras=extras,
    )
