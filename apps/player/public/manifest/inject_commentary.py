# -*- coding: utf-8 -*-
"""为 manifest 中的 text / code block 注入 commentary 字幕条数据。

设计原则：
- 字幕条每条不超过 100 字，最多 6 条；整段 script 限长 480 字。
- 文字讲解按 markdown 结构拆：表格转"摘要一句"，emoji 列表每项一句，段落按中文标点再切。
- 代码讲解优先用 block.explanation；否则按 language + filename + 行数生成 2-3 段。
- idempotent：已有且首段 ≤150 字的 commentary 视为合格，跳过；过长的视为脏数据，重写。
"""
from __future__ import annotations
import json, os, re, sys

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
MANIFEST = os.path.join(ROOT, 'manifest.json')

MAX_STEP_LEN = 100     # 每条字幕最多 100 字
MAX_STEPS = 6          # 最多 6 条
MAX_SCRIPT_LEN = 480   # 聚合 script 限长
MIN_LINE_LEN = 6       # 低于这个字数视为噪声，丢掉


def _truncate(s: str, limit: int) -> str:
    s = s.strip()
    if len(s) <= limit:
        return s
    return s[: max(1, limit - 1)].rstrip() + '…'


def _strip_inline(s: str) -> str:
    """去掉行内 markdown 装饰，保留可朗读文字。"""
    s = re.sub(r'`[^`]+`', '', s)
    s = re.sub(r'!\[[^\]]*\]\([^)]*\)', '', s)
    s = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', s)
    s = re.sub(r'[*_~]+', '', s)
    return s.strip()


def _split_by_punct(text: str) -> list[str]:
    if not text:
        return []
    parts = re.split(r'(?<=[。！？!?；;])\s+|(?<=[。！？!?；;])', text)
    return [p.strip() for p in parts if p and p.strip()]


_CH_SKELETON_RE = re.compile(
    r'^\d+(?:\.\d+){1,3}\s+.{1,40}$'
)
_SENTENCE_END = '。！？!?；;'


def _is_chapter_skeleton(line: str) -> bool:
    """识别 '1.1 学习目标' / '1.1.2 MCU / CPU / SoC 三者对比' 这种章节骨架。
    条件：以 X.Y(.Z)(.W) 开头 + 短标题 + 末尾不是句号/问号之类的句末标点。"""
    s = line.strip()
    if not _CH_SKELETON_RE.match(s):
        return False
    return s[-1] not in _SENTENCE_END


def _structured_sentences(md: str) -> list[str]:
    """把 markdown 按结构切成候选句子序列。"""
    if not md:
        return []
    # 去掉 fenced code，避免把代码朗读出来
    md = re.sub(r'```[\s\S]*?```', '\n', md)
    lines = md.split('\n')

    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        # 表格：连续的 `| … |` 行，转成"本表对照 A / B / C"一句
        if line.lstrip().startswith('|'):
            header = line.strip().strip('|')
            headers = [h.strip() for h in header.split('|') if h.strip()]
            j = i + 1
            while j < len(lines) and lines[j].lstrip().startswith('|'):
                j += 1
            if headers:
                summary = '本表对照：' + ' · '.join(headers[:6])
                out.append(_truncate(summary, MAX_STEP_LEN))
            i = j
            continue
        # 空行 / 只剩符号
        stripped = _strip_inline(re.sub(r'^[#>\-\*\+]+\s*', '', line))
        if not stripped:
            i += 1
            continue
        # 标题行：#/## 等 → 如果是纯章节骨架（"1.1 学习目标"），跳过；否则保留
        if line.lstrip().startswith('#') or _is_chapter_skeleton(stripped):
            if not _is_chapter_skeleton(stripped):
                out.append(_truncate(stripped, MAX_STEP_LEN))
            i += 1
            continue
        # emoji 开头的列表项：每行一句
        if re.match(r'^\s*(?:[🏠📱🚗🏥🏭🌐💡🎯⚠️✅❓▶◐☾📖📘🔹•]|\d+[\.\)])', line):
            for seg in _split_by_punct(stripped) or [stripped]:
                if len(seg) >= MIN_LINE_LEN:
                    out.append(_truncate(seg, MAX_STEP_LEN))
            i += 1
            continue
        # 普通段落：累积直到空行，再按标点切
        buf = [stripped]
        i += 1
        while i < len(lines):
            nxt = lines[i].rstrip()
            if not nxt.strip() or nxt.lstrip().startswith(('|', '#', '```')):
                break
            seg = _strip_inline(re.sub(r'^[#>\-\*\+]+\s*', '', nxt))
            if not seg:
                break
            buf.append(seg)
            i += 1
        para = ' '.join(buf)
        for seg in _split_by_punct(para) or [para]:
            if len(seg) >= MIN_LINE_LEN:
                out.append(_truncate(seg, MAX_STEP_LEN))
    # 去重（相邻）
    dedup: list[str] = []
    for s in out:
        if not dedup or dedup[-1] != s:
            dedup.append(s)
    return dedup


# 具体举例/品牌词/计量单位等"高信息量"信号 —— 评分时加分
_VALUE_KEYWORDS = [
    'STM32', 'GD32', 'AT32', 'HC32', 'ARM', 'Cortex', 'Intel', 'AVR', 'PIC',
    'MCU', 'CPU', 'SoC', 'FPGA', 'MHz', 'GHz', 'KB', 'MB', 'Flash', 'SRAM',
    'GPIO', 'UART', 'USART', 'SPI', 'I2C', 'ADC', 'DAC', 'PWM', 'DMA',
    'HAL', 'CubeMX', 'CubeIDE', 'ST-Link', 'Keil', 'IAR',
    '洗衣机', '微波炉', '空调', '手机', '汽车', '医疗', '工业',
    '例如', '比如', '举例', '案例',
]
_DIGIT_RE = re.compile(r'\d+')
_EMOJI_RE = re.compile(
    '['
    '\U0001F300-\U0001F9FF'
    '\U00002600-\U000027BF'
    ']'
)


def _score_sentence(s: str) -> int:
    """给候选字幕评分；越高越优先保留。"""
    score = 0
    if _DIGIT_RE.search(s):
        score += 2
    if _EMOJI_RE.search(s):
        score += 1
    for kw in _VALUE_KEYWORDS:
        if kw in s:
            score += 2
            break  # 一句里命中多个品牌词也只加一次，避免 overflow
    # 句长在 20-80 之间最佳
    n = len(s)
    if 20 <= n <= 80:
        score += 1
    elif n < 12:
        score -= 1
    # 骨架式摘要降权
    if s.startswith('本表对照') or s.startswith('项目') or s.endswith('：'):
        score -= 3
    # 含"能够"/"掌握"/"了解"这种目标式表述但无实体词，降权
    if re.search(r'(能够|掌握|了解|理解|区分|说出|完成)$', s):
        score -= 1
    return score


def _is_skeleton_summary(s: str) -> bool:
    """'本表对照：A · B · C' 这种纯表头摘要，或者以冒号结尾 **且** 不含任何
    高价值关键词的半截标题。含品牌词/数字/具体名词的冒号结尾句不算骨架。"""
    if not s:
        return True
    if s.startswith('本表对照'):
        return True
    if not s.rstrip().endswith(('：', ':')):
        return False
    # 以冒号结尾 —— 只有同时不含任何实体词/数字/emoji 才算骨架
    if _DIGIT_RE.search(s) or _EMOJI_RE.search(s):
        return False
    return not any(kw in s for kw in _VALUE_KEYWORDS)


def _pick_by_value(candidates: list[str], limit: int) -> list[str]:
    """按价值评分挑 limit 条，结果按原 markdown 出现顺序重新排列。

    硬过滤：候选数 > limit 时，'本表对照…' 与以'：'结尾的半截标题一律剔除。
    如果过滤后候选不够 limit，再把骨架句按分数回填。
    """
    if not candidates:
        return []
    primary = [s for s in candidates if not _is_skeleton_summary(s)]
    leftover = [s for s in candidates if _is_skeleton_summary(s)]
    pool = primary if len(primary) >= limit or not leftover else primary + leftover
    if len(pool) <= limit:
        return pool
    # 带原始索引 + 分数，按 (score desc, idx asc) 排
    orig_idx = {id(s): i for i, s in enumerate(candidates)}
    indexed = [(orig_idx[id(s)], s, _score_sentence(s)) for s in pool]
    indexed.sort(key=lambda x: (-x[2], x[0]))
    picked = sorted(indexed[:limit], key=lambda x: x[0])
    return [s for _, s, _ in picked]


def _commentary_for_text(block: dict) -> dict | None:
    md = block.get('markdown') or ''
    if not md.strip() or len(md.strip()) < 12:
        return None
    all_steps = _structured_sentences(md)
    if not all_steps:
        return None
    steps = _pick_by_value(all_steps, MAX_STEPS)
    script = _truncate(' '.join(steps), MAX_SCRIPT_LEN)
    return {
        'sourceType': 'text',
        'speaker': '文字讲师',
        'script': script,
        'stepScripts': steps if len(steps) >= 2 else None,
    }


def _code_intro(block: dict) -> str:
    lang = (block.get('language') or '代码').lower()
    filename = block.get('filename') or ''
    lang_map = {
        'c': 'C 代码',
        'cpp': 'C++ 代码',
        'python': 'Python 代码',
        'asm': '汇编代码',
        'arm-asm': 'ARM 汇编',
        'makefile': 'Makefile',
        'sh': 'Shell 脚本',
        'bash': 'Shell 脚本',
    }
    display = lang_map.get(lang, f'{lang.upper()} 代码' if lang else '示例代码')
    if filename and filename.lower() != lang:
        return f'这段 {display}（{filename}）'
    return f'这段 {display}'


def _split_code_lines(code: str) -> list[tuple[int, str]]:
    """返回 [(1-based line number, raw line)] 列表，跳过纯空白行。"""
    out: list[tuple[int, str]] = []
    for i, ln in enumerate(code.split('\n')):
        if ln.strip():
            out.append((i + 1, ln))
    return out


def _highlight_lines_for_steps(code: str, n_steps: int, hints: list[str]) -> list[list[int]]:
    """按段数均分代码非空行号给每段讲解。

    hints[i] 是关键词数组，若代码中能命中关键词，优先把命中行划给 step i；
    否则用均分回退。
    """
    if n_steps <= 0:
        return []
    indexed = _split_code_lines(code)
    if not indexed:
        return [[] for _ in range(n_steps)]
    total = len(indexed)
    # 先按 hints 抓"特征行"
    step_lines: list[list[int]] = [[] for _ in range(n_steps)]
    if hints and len(hints) == n_steps:
        for s_idx, kws in enumerate(hints):
            for ln_no, raw in indexed:
                low = raw.lower()
                if any(kw in low for kw in kws):
                    step_lines[s_idx].append(ln_no)
    # 没命中或命中过少 → 均分非空行
    for s_idx in range(n_steps):
        if len(step_lines[s_idx]) < 1:
            chunk = max(1, total // n_steps)
            start = min(s_idx * chunk, total - 1)
            end = total if s_idx == n_steps - 1 else min((s_idx + 1) * chunk, total)
            step_lines[s_idx] = [indexed[k][0] for k in range(start, end)]
    return step_lines


def _commentary_for_code(block: dict) -> dict | None:
    code = block.get('code') or ''
    if not code.strip():
        return None
    lines = [ln for ln in code.split('\n') if ln.strip()]
    line_count = len(lines)
    explanation = (block.get('explanation') or '').strip()
    if explanation:
        sents = [_truncate(s, MAX_STEP_LEN) for s in _split_by_punct(explanation)[:MAX_STEPS]]
        if sents and len(sents) >= 2:
            hl = _highlight_lines_for_steps(code, len(sents), [])
            return {
                'sourceType': 'code',
                'speaker': '代码讲师',
                'script': _truncate(explanation, MAX_SCRIPT_LEN),
                'stepScripts': sents,
                'highlightLines': hl,
            }
    # 兜底：生动一点，按"开篇 → 结构 → 关注点"三段
    intro = _code_intro(block)
    s1 = f'{intro}一共 {line_count} 行，是本节的核心示例。'
    # 扫描一下是否出现典型符号，给出更具体的"关注点"
    src = code.lower()
    if 'hal_gpio' in src or 'gpio' in src:
        s2 = '重点观察 GPIO 初始化结构体字段的填法，以及时钟使能宏放在哪一行。'
        hint_step2 = ['gpio', 'rcc']
    elif 'uart' in src or 'usart' in src:
        s2 = '重点观察 UART 的波特率、数据位、停止位怎么配，以及中断回调在哪里。'
        hint_step2 = ['uart', 'usart', 'baud']
    elif 'timer' in src or 'tim' in src:
        s2 = '重点观察定时器预分频与自动重装值的取值，以及中断/PWM 通道的开启位置。'
        hint_step2 = ['tim', 'prescaler', 'period', 'pwm']
    elif 'adc' in src:
        s2 = '重点观察 ADC 通道选择、采样时间与转换触发方式，结果寄存器读取在哪里。'
        hint_step2 = ['adc', 'channel', 'sample']
    elif 'while' in src and ('main' in src or 'void main' in src):
        s2 = '重点观察 main 的初始化顺序，以及 while(1) 循环里的轮询/事件处理逻辑。'
        hint_step2 = ['init', 'while', 'main']
    else:
        s2 = '重点观察关键函数的参数、返回值，以及和硬件直接交互的寄存器/宏在哪一行出现。'
        hint_step2 = []
    s3 = '建议对照上方原理图与寄存器表，边读边想"这一行实际在操作哪一块硬件"。'
    steps = [_truncate(s1, MAX_STEP_LEN), _truncate(s2, MAX_STEP_LEN), _truncate(s3, MAX_STEP_LEN)]
    # 段 0: 开头若干行（含 include / 宏 / 函数签名）；段 1: 关注点；段 2: 末尾收束
    hints = [['#include', 'void ', 'int ', 'static '], hint_step2, ['return', '}']]
    hl = _highlight_lines_for_steps(code, 3, hints)
    return {
        'sourceType': 'code',
        'speaker': '代码讲师',
        'script': _truncate(' '.join(steps), MAX_SCRIPT_LEN),
        'stepScripts': steps,
        'highlightLines': hl,
    }


_CODE_OLD_FINGERPRINTS = (
    '请重点关注函数定义、关键宏与外设寄存器',
    '对应到前面的原理图理解每一步要做什么',
)


def _needs_rewrite(existing: dict, kind: str | None = None) -> bool:
    """判断已有 commentary 是否脏；脏的重写。

    kind='code' 时额外要求必须带 highlightLines（v6.1 新增），否则重写以补齐。
    """
    if not isinstance(existing, dict):
        return True
    steps = existing.get('stepScripts') or []
    if steps and isinstance(steps, list):
        if any(isinstance(s, str) and len(s) > 150 for s in steps):
            return True
        # 纯章节骨架行（如 "1.1 学习目标"）占据字幕槽位 —— 脏，重写
        if any(isinstance(s, str) and _is_chapter_skeleton(s) for s in steps):
            return True
        # 只要出现 "本表对照…" 或以 '：'/':' 结尾的半截摘要 → 脏，重写走硬过滤
        if kind == 'text' and any(isinstance(s, str) and _is_skeleton_summary(s) for s in steps):
            return True
    script = existing.get('script') or ''
    if isinstance(script, str) and len(script) > MAX_SCRIPT_LEN + 100:
        return True
    # 代码：带旧模板指纹一律重写（为了跑新的 GPIO/UART/Timer 智能分支）
    blob = script + ' ' + ' '.join(s for s in steps if isinstance(s, str))
    if any(fp in blob for fp in _CODE_OLD_FINGERPRINTS):
        return True
    # v6.1：代码讲解必须带 highlightLines 才算合格（行联动前置条件）
    if kind == 'code' and steps and len(steps) >= 2:
        hl = existing.get('highlightLines')
        if not (isinstance(hl, list) and len(hl) == len(steps) and all(isinstance(x, list) and x for x in hl)):
            return True
    return False


def main():
    with open(MANIFEST, 'r', encoding='utf-8') as f:
        m = json.load(f)
    text_added = code_added = skipped = rewritten = 0
    for ch in m.get('chapters', []):
        for sec in ch.get('sections', []):
            for page in sec.get('pages', []):
                for blk in page.get('blocks', []) or []:
                    kind = blk.get('kind')
                    if kind not in ('text', 'code'):
                        continue
                    existing = blk.get('commentary')
                    if existing and not _needs_rewrite(existing, kind):
                        skipped += 1
                        continue
                    spec = _commentary_for_text(blk) if kind == 'text' else _commentary_for_code(blk)
                    if not spec:
                        continue
                    spec = {k: v for k, v in spec.items() if v is not None}
                    was_rewrite = existing is not None
                    blk['commentary'] = spec
                    if was_rewrite:
                        rewritten += 1
                    elif kind == 'text':
                        text_added += 1
                    else:
                        code_added += 1
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'commentary: text_new={text_added}, code_new={code_added}, rewritten={rewritten}, skipped={skipped}')


if __name__ == '__main__':
    main()
