/**
 * FinaleStage · 题目渲染 + onComplete 桥接
 *
 * 设计：
 *   - 不复用 packages/primitives/src/interactive 现有组件（它们没有 onComplete 回调，
 *     侵入面太大）；改为 finale 内部自渲染，schema 仍复用 InteractiveSpec / QuizSpec。
 *   - Iter-23 新增 classification / memory-match / spot-difference 三类
 *     ——把"全屏挑战"从"基本题"扩到"游戏感强"的多样化题型。
 *   - 已支持的题型：
 *       quiz: single-choice / multiple-choice / true-false / fill-blank
 *       interactive: matching / ordering / classification / memory-match / spot-difference
 *   - 提交时调用 onAnswer(correct, timeUsedMs)；reducer 负责加分 / 扣 HP。
 */
import { useEffect, useMemo, useState } from 'react';
import type {
  FinaleQuestion,
  FinaleQuestionSpec,
} from './types';

export interface FinaleStageProps {
  question: FinaleQuestion;
  questionStartedAt: number;
  /** 当前题目序号（1-based，用于显示 "题 1/3"） */
  index: number;
  total: number;
  onAnswer: (correct: boolean, timeUsedMs: number) => void;
  /** 已答（feedback 相位）— 锁住交互 */
  locked: boolean;
}

export function FinaleStage({
  question,
  questionStartedAt,
  index,
  total,
  onAnswer,
  locked,
}: FinaleStageProps) {
  const submit = (correct: boolean) => {
    if (locked) return;
    const timeUsedMs = Math.max(0, Date.now() - questionStartedAt);
    onAnswer(correct, timeUsedMs);
  };

  return (
    <div className="dgb-finale-question">
      <div className="dgb-finale-question__meta">
        <span>
          第 {index} / {total} 题
        </span>
        <span
          className={`dgb-finale-question__diff is-${question.difficulty}`}
          aria-label={`难度 ${question.difficulty}`}
        >
          {question.difficulty}
        </span>
        {question.hint && locked ? (
          <span style={{ marginLeft: 'auto', opacity: 0.8 }}>💡 {question.hint}</span>
        ) : null}
      </div>
      <div className="dgb-finale-question__body">
        <QuestionRenderer
          spec={question.spec}
          locked={locked}
          onSubmit={submit}
          key={question.id}
        />
      </div>
    </div>
  );
}

/* ───────────── 题型分发 ───────────── */

function QuestionRenderer({
  spec,
  locked,
  onSubmit,
}: {
  spec: FinaleQuestionSpec;
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  if (spec.type === 'quiz') {
    const q = spec.data;
    if (q.kind === 'single-choice') {
      return <SingleChoiceQ stem={q.stem} options={q.options} answer={q.answer} locked={locked} onSubmit={onSubmit} />;
    }
    if (q.kind === 'multiple-choice') {
      return <MultipleChoiceQ stem={q.stem} options={q.options} answer={q.answer} locked={locked} onSubmit={onSubmit} />;
    }
    if (q.kind === 'true-false') {
      return <TrueFalseQ stem={q.stem} answer={q.answer} locked={locked} onSubmit={onSubmit} />;
    }
    if (q.kind === 'fill-blank') {
      return (
        <FillBlankQuizQ
          stem={q.stem}
          placeholder={q.placeholder}
          answers={q.answers}
          caseSensitive={(q as { caseSensitive?: boolean }).caseSensitive}
          locked={locked}
          onSubmit={onSubmit}
        />
      );
    }
  }
  if (spec.type === 'interactive') {
    const i = spec.data;
    if (i.kind === 'matching') {
      return <MatchingQ pairs={i.pairs} prompt={i.prompt} locked={locked} onSubmit={onSubmit} />;
    }
    if (i.kind === 'ordering') {
      return <OrderingQ items={i.items} correctOrder={i.correctOrder} prompt={i.prompt} locked={locked} onSubmit={onSubmit} />;
    }
    if (i.kind === 'classification') {
      return (
        <ClassificationQ
          categories={i.categories}
          items={i.items}
          prompt={i.prompt}
          locked={locked}
          onSubmit={onSubmit}
        />
      );
    }
    if (i.kind === 'memory-match') {
      return <MemoryMatchQ pairs={i.pairs} prompt={i.prompt} locked={locked} onSubmit={onSubmit} />;
    }
    if (i.kind === 'spot-difference') {
      return (
        <SpotDifferenceQ
          prompt={i.prompt}
          left={i.left}
          right={i.right}
          differences={i.differences}
          locked={locked}
          onSubmit={onSubmit}
        />
      );
    }
    if (i.kind === 'hotspot') {
      return (
        <HotspotQ
          prompt={i.prompt}
          image={i.image}
          hotspots={i.hotspots}
          locked={locked}
          onSubmit={onSubmit}
        />
      );
    }
  }
  // 给个 "跳过该题"按钮，按错处理；当真用到时再补题型组件（奥卡姆）。
  const unsupportedKind = spec.type === 'quiz' ? spec.data.kind : spec.data.kind;
  return (
    <div className="dgb-finale-quiz" data-kind="unsupported">
      <div className="dgb-finale-quiz__stem" style={{ color: '#1a2233' }}>
        ⚠ 暂不支持的题型：<code>{unsupportedKind}</code>
      </div>
      <div className="dgb-finale-quiz__options">
        <button
          type="button"
          className="dgb-finale-quiz__option"
          onClick={() => !locked && onSubmit(false)}
          disabled={locked}
        >
          <span>跳过此题（计为错）</span>
        </button>
      </div>
    </div>
  );
}

/* ───────────── Quiz: single-choice ───────────── */

function SingleChoiceQ({
  stem,
  options,
  answer,
  locked,
  onSubmit,
}: {
  stem: string;
  options: { id: string; label?: string; text?: string }[];
  answer: string;
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  // 单选：点选项即提交（不再需要提交按钮 — 游戏化更顺）
  // locked 时锁住交互；显示对错高亮则交给上层 verdict 反馈
  const [picked, setPicked] = useState<string | null>(null);
  const choose = (id: string) => {
    if (locked || picked) return; // 已选过就锁，避免双触发
    setPicked(id);
    onSubmit(id === answer);
  };
  // 键盘 1/2/3/4 数字键直选快捷键
  useEffect(() => {
    if (locked) return;
    const handler = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      const idx = Number(e.key) - 1;
      const target = options[idx];
      if (target && idx >= 0 && idx < options.length) {
        e.preventDefault();
        choose(target.id);
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locked, picked, options]);
  return (
    <div className="dgb-finale-quiz">
      <div className="dgb-finale-quiz__stem">{stem}</div>
      <div className="dgb-finale-quiz__options">
        {options.map((opt, i) => {
          const cls = ['dgb-finale-quiz__option'];
          if (picked === opt.id) cls.push('is-selected');
          if (locked && opt.id === answer) cls.push('is-correct');
          if (locked && picked === opt.id && opt.id !== answer) cls.push('is-wrong');
          return (
            <button
              key={opt.id}
              type="button"
              className={cls.join(' ')}
              disabled={locked || !!picked}
              onClick={() => choose(opt.id)}
              aria-keyshortcuts={String(i + 1)}
            >
              <span className="dgb-finale-quiz__option-key">
                {String.fromCharCode(65 + i)}
              </span>
              <span>{opt.label ?? opt.text ?? ''}</span>
            </button>
          );
        })}
      </div>
      <div className="dgb-finale-quiz__hint" aria-hidden="true">
        💡 直接点选项 · 或按 1/2/3/4 数字键
      </div>
    </div>
  );
}

/* ───────────── Quiz: multiple-choice ───────────── */

function MultipleChoiceQ({
  stem,
  options,
  answer,
  locked,
  onSubmit,
}: {
  stem: string;
  options: { id: string; label?: string; text?: string }[];
  answer: string[];
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const toggle = (id: string) => {
    if (locked) return;
    setPicked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };
  const submit = () => {
    if (picked.size === 0) return;
    const sortedPick = Array.from(picked).sort().join(',');
    const sortedAns = [...answer].sort().join(',');
    onSubmit(sortedPick === sortedAns);
  };
  // 键盘快捷键：1/2/3/4 toggle 选项，Enter 提交
  useEffect(() => {
    if (locked) return;
    const handler = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      const idx = Number(e.key) - 1;
      const target = options[idx];
      if (target && idx >= 0 && idx < options.length) {
        e.preventDefault();
        toggle(target.id);
        return;
      }
      if (e.key === 'Enter') {
        e.preventDefault();
        submit();
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locked, picked, options]);
  return (
    <div className="dgb-finale-quiz">
      <div className="dgb-finale-quiz__stem">{stem} <span style={{ fontWeight: 400, color: '#64748b', fontSize: 13 }}>（多选）</span></div>
      <div className="dgb-finale-quiz__options">
        {options.map((opt, i) => {
          const cls = ['dgb-finale-quiz__option'];
          if (picked.has(opt.id)) cls.push('is-selected');
          if (locked && answer.includes(opt.id)) cls.push('is-correct');
          if (locked && picked.has(opt.id) && !answer.includes(opt.id)) cls.push('is-wrong');
          return (
            <button
              key={opt.id}
              type="button"
              className={cls.join(' ')}
              disabled={locked}
              onClick={() => toggle(opt.id)}
              aria-keyshortcuts={String(i + 1)}
            >
              <span className="dgb-finale-quiz__option-key">
                {String.fromCharCode(65 + i)}
              </span>
              <span>{opt.label ?? opt.text ?? ''}</span>
            </button>
          );
        })}
      </div>
      <button
        type="button"
        className="dgb-finale-quiz__submit"
        disabled={picked.size === 0 || locked}
        onClick={submit}
      >
        提交（Enter）
      </button>
      <div className="dgb-finale-quiz__hint" aria-hidden="true">
        💡 多选：1/2/3/4 切换 · Enter 提交
      </div>
    </div>
  );
}
/* ───────────── Quiz: true-false ───────────── */

function TrueFalseQ({
  stem,
  answer,
  locked,
  onSubmit,
}: {
  stem: string;
  answer: boolean;
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  // 判断题：点即提交（不再需要提交按钮）
  const [picked, setPicked] = useState<boolean | null>(null);
  const choose = (v: boolean) => {
    if (locked || picked !== null) return;
    setPicked(v);
    onSubmit(v === answer);
  };
  // 键盘快捷键：1/T → 对，2/F → 错
  useEffect(() => {
    if (locked) return;
    const handler = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if (e.key === '1' || e.key === 't' || e.key === 'T') {
        e.preventDefault();
        choose(true);
      } else if (e.key === '2' || e.key === 'f' || e.key === 'F') {
        e.preventDefault();
        choose(false);
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locked, picked]);
  return (
    <div className="dgb-finale-quiz">
      <div className="dgb-finale-quiz__stem">{stem}</div>
      <div className="dgb-finale-quiz__options">
        {[true, false].map((v) => {
          const cls = ['dgb-finale-quiz__option'];
          if (picked === v) cls.push('is-selected');
          if (locked && v === answer) cls.push('is-correct');
          if (locked && picked === v && v !== answer) cls.push('is-wrong');
          return (
            <button
              key={String(v)}
              type="button"
              className={cls.join(' ')}
              disabled={locked || picked !== null}
              onClick={() => choose(v)}
              aria-keyshortcuts={v ? '1 T' : '2 F'}
            >
              <span className="dgb-finale-quiz__option-key">{v ? '✓' : '✗'}</span>
              <span>{v ? '对' : '错'}</span>
            </button>
          );
        })}
      </div>
      <div className="dgb-finale-quiz__hint" aria-hidden="true">
        💡 点选项即提交 · 或按 T/F、1/2
      </div>
    </div>
  );
}

/* ───────────── Quiz: fill-blank ───────────── */

function FillBlankQuizQ({
  stem,
  placeholder,
  answers,
  caseSensitive,
  locked,
  onSubmit,
}: {
  stem: string;
  placeholder: string;
  answers: string[];
  caseSensitive?: boolean;
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  const [val, setVal] = useState('');
  const submit = () => {
    if (!val.trim()) return;
    const norm = caseSensitive ? val.trim() : val.trim().toLowerCase();
    const ok = answers.some((a) => (caseSensitive ? a : a.toLowerCase()) === norm);
    onSubmit(ok);
  };

  // placeholder 字段是"填写提示"(如"只填整数")，不应拿来切分题干——
  // 否则提示文字与题干不匹配时 split 失败、input 不渲染、题目无法作答。
  const BLANK_RE = /_{2,}|＿{2,}|▢+|□+/;
  let parts = stem.split(BLANK_RE);
  // 兜底：题干里没有空位标记时，仍在末尾给一个输入框，保证可作答。
  if (parts.length < 2) parts = [stem, ''];
  return (
    <div className="dgb-finale-quiz">
      <div className="dgb-finale-quiz__stem">
        {parts.map((p, i) => (
          <span key={i}>
            {p}
            {i < parts.length - 1 ? (
              <input
                type="text"
                className="dgb-finale-quiz__option"
                style={{
                  display: 'inline-block',
                  width: 160,
                  padding: '6px 10px',
                  margin: '0 6px',
                  fontSize: 15,
                }}
                value={val}
                placeholder={placeholder}
                disabled={locked}
                onChange={(e) => setVal(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') submit();
                }}
                aria-label="填空"
              />
            ) : null}
          </span>
        ))}
      </div>
      {locked ? (
        <div style={{ fontSize: 13, color: '#64748b' }}>
          答案：{answers.join(' / ')}
        </div>
      ) : null}
      <button
        type="button"
        className="dgb-finale-quiz__submit"
        disabled={!val.trim() || locked}
        onClick={submit}
      >
        提交
      </button>
    </div>
  );
}


/* ───────────── Interactive: matching（点击配对） ───────────── */

function MatchingQ({
  pairs,
  prompt,
  locked,
  onSubmit,
}: {
  pairs: { left: string; right: string }[];
  prompt?: string;
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  const lefts = useMemo(
    () => pairs.map((p, i) => ({ id: `L${i}`, text: p.left, expectedRightId: `R${i}` })),
    [pairs],
  );
  // 右侧打乱
  const rights = useMemo(() => {
    const arr = pairs.map((p, i) => ({ id: `R${i}`, text: p.right }));
    const seed = pairs.map((p) => p.left + '|' + p.right).join('§');
    let h = 0;
    for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) | 0;
    const out = [...arr];
    for (let i = out.length - 1; i > 0; i--) {
      h = (h * 9301 + 49297) % 233280;
      const j = Math.abs(h) % (i + 1);
      [out[i], out[j]] = [out[j]!, out[i]!];
    }
    return out;
  }, [pairs]);

  const [activeLeft, setActiveLeft] = useState<string | null>(null);
  const [picks, setPicks] = useState<Record<string, string>>({}); // L → R
  const handleLeft = (lid: string) => {
    if (locked) return;
    setActiveLeft((cur) => (cur === lid ? null : lid));
  };
  const handleRight = (rid: string) => {
    if (locked || !activeLeft) return;
    setPicks((prev) => {
      const next = { ...prev };
      // 如果该 R 已被另一个 L 选中，先解除
      for (const k of Object.keys(next)) {
        if (next[k] === rid) delete next[k];
      }
      next[activeLeft] = rid;
      return next;
    });
    setActiveLeft(null);
  };
  const allDone = lefts.every((l) => picks[l.id]);
  const submit = () => {
    const ok = lefts.every((l) => picks[l.id] === l.expectedRightId);
    onSubmit(ok);
  };
  return (
    <div className="dgb-finale-quiz">
      {prompt ? <div className="dgb-finale-quiz__stem">{prompt}</div> : null}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {lefts.map((l) => {
            const cls = ['dgb-finale-quiz__option'];
            if (activeLeft === l.id) cls.push('is-selected');
            if (locked) {
              const ok = picks[l.id] === l.expectedRightId;
              cls.push(ok ? 'is-correct' : 'is-wrong');
            }
            return (
              <button
                key={l.id}
                type="button"
                className={cls.join(' ')}
                disabled={locked}
                onClick={() => handleLeft(l.id)}
              >
                <span>{l.text}</span>
                {picks[l.id] ? (
                  <span style={{ marginLeft: 'auto', opacity: 0.6, fontSize: 12 }}>
                    →{' '}
                    {rights.find((r) => r.id === picks[l.id])?.text ?? ''}
                  </span>
                ) : null}
              </button>
            );
          })}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {rights.map((r) => {
            const used = Object.values(picks).includes(r.id);
            const cls = ['dgb-finale-quiz__option'];
            if (used) cls.push('is-selected');
            return (
              <button
                key={r.id}
                type="button"
                className={cls.join(' ')}
                disabled={locked}
                onClick={() => handleRight(r.id)}
              >
                <span>{r.text}</span>
              </button>
            );
          })}
        </div>
      </div>
      <button
        type="button"
        className="dgb-finale-quiz__submit"
        disabled={!allDone || locked}
        onClick={submit}
      >
        提交
      </button>
    </div>
  );
}

/* ───────────── Interactive: ordering（拖拽 + 键盘热键 + 点击上下） ───────────── */

function OrderingQ({
  items,
  correctOrder,
  prompt,
  locked,
  onSubmit,
}: {
  items: { id: string; text: string }[];
  correctOrder: string[];
  prompt?: string;
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  // 初始打乱（基于 correctOrder 反向）
  const [order, setOrder] = useState<{ id: string; text: string }[]>(() => {
    const initial = [...items];
    const seed = correctOrder.join('|');
    let h = 0;
    for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) | 0;
    for (let i = initial.length - 1; i > 0; i--) {
      h = (h * 9301 + 49297) % 233280;
      const j = Math.abs(h) % (i + 1);
      [initial[i], initial[j]] = [initial[j]!, initial[i]!];
    }
    return initial;
  });
  const [dragIdx, setDragIdx] = useState<number | null>(null);
  const [overIdx, setOverIdx] = useState<number | null>(null);
  const [focusIdx, setFocusIdx] = useState<number>(0);

  const move = (idx: number, dir: -1 | 1) => {
    if (locked) return;
    setOrder((prev) => {
      const next = [...prev];
      const target = idx + dir;
      if (target < 0 || target >= next.length) return prev;
      [next[idx], next[target]] = [next[target]!, next[idx]!];
      return next;
    });
    // 跟随焦点
    setFocusIdx((cur) => (cur === idx ? Math.max(0, Math.min(order.length - 1, idx + dir)) : cur));
  };

  const moveTo = (from: number, to: number) => {
    if (locked || from === to) return;
    setOrder((prev) => {
      const next = [...prev];
      const [it] = next.splice(from, 1);
      if (it) next.splice(to, 0, it);
      return next;
    });
    setFocusIdx(to);
  };

  const submit = () => {
    const ok = order.map((x) => x.id).join(',') === correctOrder.join(',');
    onSubmit(ok);
  };

  useEffect(() => {
    if (locked) return;
    const handler = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (e.altKey) move(focusIdx, -1);
        else setFocusIdx((cur) => Math.max(0, cur - 1));
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (e.altKey) move(focusIdx, 1);
        else setFocusIdx((cur) => Math.min(order.length - 1, cur + 1));
      } else if (e.key === 'Enter') {
        // 锁住前回车提交（提供与 quiz 相同的快捷键体验）
        e.preventDefault();
        submit();
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locked, focusIdx, order]);

  return (
    <div className="dgb-finale-quiz" data-kind="ordering">
      {prompt ? <div className="dgb-finale-quiz__stem">{prompt}</div> : null}
      <div style={{ fontSize: 11, opacity: 0.55, marginBottom: 6 }}>
        拖拽 / Alt+↑↓ 移动当前行 / Enter 提交
      </div>
      <div className="dgb-finale-quiz__options">
        {order.map((it, idx) => {
          const cls = ['dgb-finale-quiz__option'];
          if (locked) {
            const ok = it.id === correctOrder[idx];
            cls.push(ok ? 'is-correct' : 'is-wrong');
          } else if (focusIdx === idx) {
            cls.push('is-selected');
          }
          if (overIdx === idx && dragIdx !== null && dragIdx !== idx) {
            cls.push('is-dropover');
          }
          return (
            <div
              key={it.id}
              className={cls.join(' ')}
              tabIndex={locked ? -1 : 0}
              onFocus={() => setFocusIdx(idx)}
              draggable={!locked}
              onDragStart={(e) => {
                if (locked) return;
                setDragIdx(idx);
                try {
                  e.dataTransfer.effectAllowed = 'move';
                  e.dataTransfer.setData('text/plain', String(idx));
                } catch {/* noop */}
              }}
              onDragOver={(e) => {
                if (locked || dragIdx === null) return;
                e.preventDefault();
                if (overIdx !== idx) setOverIdx(idx);
              }}
              onDragLeave={() => {
                if (overIdx === idx) setOverIdx(null);
              }}
              onDrop={(e) => {
                if (locked || dragIdx === null) return;
                e.preventDefault();
                moveTo(dragIdx, idx);
                setDragIdx(null);
                setOverIdx(null);
              }}
              onDragEnd={() => {
                setDragIdx(null);
                setOverIdx(null);
              }}
              style={{
                cursor: locked ? 'default' : 'grab',
                opacity: dragIdx === idx ? 0.5 : 1,
              }}
            >
              <span className="dgb-finale-quiz__option-key">{idx + 1}</span>
              <span style={{ flex: 1, userSelect: 'none' }}>{it.text}</span>
              <button
                type="button"
                onClick={(e) => { e.stopPropagation(); move(idx, -1); }}
                disabled={locked || idx === 0}
                aria-label="上移"
                style={{ border: 'none', background: 'transparent', fontSize: 18, cursor: 'pointer', padding: '4px 8px' }}
              >
                ↑
              </button>
              <button
                type="button"
                onClick={(e) => { e.stopPropagation(); move(idx, 1); }}
                disabled={locked || idx === order.length - 1}
                aria-label="下移"
                style={{ border: 'none', background: 'transparent', fontSize: 18, cursor: 'pointer', padding: '4px 8px' }}
              >
                ↓
              </button>
            </div>
          );
        })}
      </div>
      <button
        type="button"
        className="dgb-finale-quiz__submit"
        disabled={locked}
        onClick={submit}
      >
        提交
      </button>
    </div>
  );
}

/* ───────────── Interactive: classification（点选词条投入分组桶） ───────────── */
/**
 * 把 items 分到 categories；不依赖 HTML5 drag（移动端也能玩），
 * 改用"先点 item → 再点 category"两步交互；桌面上等价于轻量拖放。
 */
function ClassificationQ({
  categories,
  items,
  prompt,
  locked,
  onSubmit,
}: {
  categories: { id: string; label: string }[];
  items: { id: string; text: string; correctCategory: string }[];
  prompt?: string;
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  const [assignments, setAssignments] = useState<Record<string, string>>({});
  const [activeItem, setActiveItem] = useState<string | null>(null);
  const pickItem = (id: string) => {
    if (locked) return;
    setActiveItem((cur) => (cur === id ? null : id));
  };
  const dropTo = (catId: string) => {
    if (locked || !activeItem) return;
    setAssignments((prev) => ({ ...prev, [activeItem]: catId }));
    setActiveItem(null);
  };
  const unassign = (id: string) => {
    if (locked) return;
    setAssignments((prev) => {
      const n = { ...prev };
      delete n[id];
      return n;
    });
  };
  const allAssigned = items.every((it) => assignments[it.id]);
  const submit = () => {
    const ok = items.every((it) => assignments[it.id] === it.correctCategory);
    onSubmit(ok);
  };
  const remaining = items.filter((it) => !assignments[it.id]);
  return (
    <div className="dgb-finale-quiz" data-kind="classification">
      {prompt ? <div className="dgb-finale-quiz__stem">{prompt}</div> : null}
      <div className="dgb-finale-quiz__options" style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
        {remaining.map((it) => (
          <button
            key={it.id}
            type="button"
            className={`dgb-finale-quiz__option${activeItem === it.id ? ' is-selected' : ''}`}
            disabled={locked}
            onClick={() => pickItem(it.id)}
            style={{ flex: '0 1 auto' }}
          >
            <span>{it.text}</span>
          </button>
        ))}
        {remaining.length === 0 ? (
          <span style={{ opacity: 0.55, fontSize: 13 }}>词条已全部分配，点"提交"判定</span>
        ) : null}
      </div>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: `repeat(${Math.min(categories.length, 3)}, 1fr)`,
          gap: 12,
        }}
      >
        {categories.map((cat) => {
          const inCat = items.filter((it) => assignments[it.id] === cat.id);
          return (
            <div
              key={cat.id}
              className="dgb-finale-quiz__option"
              style={{ flexDirection: 'column', alignItems: 'stretch', gap: 6,
                cursor: activeItem ? 'pointer' : 'default', minHeight: 96, padding: '10px 12px' }}
              onClick={() => dropTo(cat.id)}
            >
              <div style={{ fontWeight: 600, fontSize: 13, opacity: 0.85 }}>{cat.label}</div>
              {inCat.length === 0 ? (
                <div style={{ opacity: 0.4, fontSize: 12 }}>（点选上方词条投入此组）</div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                  {inCat.map((it) => {
                    const ok = locked ? it.correctCategory === assignments[it.id] : null;
                    return (
                      <div
                        key={it.id}
                        style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13,
                          padding: '4px 8px', borderRadius: 6,
                          background: ok === true ? 'rgba(74, 222, 128, 0.16)'
                            : ok === false ? 'rgba(248, 113, 113, 0.16)'
                            : 'rgba(255, 255, 255, 0.08)' }}
                      >
                        <span style={{ flex: 1 }}>{it.text}</span>
                        {!locked ? (
                          <button
                            type="button"
                            onClick={(e) => { e.stopPropagation(); unassign(it.id); }}
                            style={{ border: 'none', background: 'transparent', cursor: 'pointer', opacity: 0.6, fontSize: 13 }}
                            aria-label="取出"
                          >×</button>
                        ) : null}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>
      <button
        type="button"
        className="dgb-finale-quiz__submit"
        disabled={!allAssigned || locked}
        onClick={submit}
      >
        提交
      </button>
    </div>
  );
}

/* ───────────── Interactive: memory-match（翻牌找对） ───────────── */
/**
 * 经典翻牌：每对 pair 拆成 front 卡 + back 卡 共 2N 张，
 *   - 点击未翻开的卡 → 翻开
 *   - 一次只能开 2 张；同 pair.id → 留下；不同 → 1.2s 自动盖回
 *   - 全部配对完成 → onSubmit(true)
 * 出错次数计入 mistakes（暂不影响判定，留作未来 hint）
 */
function MemoryMatchQ({
  pairs,
  prompt,
  locked,
  onSubmit,
}: {
  pairs: { id: string; front: string; back: string }[];
  prompt?: string;
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  type Card = { key: string; pairId: string; text: string; side: 'front' | 'back' };
  const cards = useMemo<Card[]>(() => {
    const flat: Card[] = [];
    for (const p of pairs) {
      flat.push({ key: `${p.id}-f`, pairId: p.id, text: p.front, side: 'front' });
      flat.push({ key: `${p.id}-b`, pairId: p.id, text: p.back,  side: 'back'  });
    }
    // 稳定洗牌（基于 pairs 内容 hash）
    const seed = pairs.map((p) => p.id + p.front + p.back).join('§');
    let h = 0;
    for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) | 0;
    const out = [...flat];
    for (let i = out.length - 1; i > 0; i--) {
      h = (h * 9301 + 49297) % 233280;
      const j = Math.abs(h) % (i + 1);
      [out[i], out[j]] = [out[j]!, out[i]!];
    }
    return out;
  }, [pairs]);

  const [matched, setMatched] = useState<Set<string>>(new Set());
  const [opened, setOpened] = useState<string[]>([]); // card.key 0~2
  const [mistakes, setMistakes] = useState(0);
  const [reportedDone, setReportedDone] = useState(false);

  const flip = (key: string) => {
    if (locked) return;
    if (opened.length >= 2) return;
    const card = cards.find((c) => c.key === key);
    if (!card || matched.has(card.pairId) || opened.includes(key)) return;
    const next = [...opened, key];
    setOpened(next);
    if (next.length === 2) {
      const a = cards.find((c) => c.key === next[0])!;
      const b = cards.find((c) => c.key === next[1])!;
      if (a.pairId === b.pairId) {
        // 配对成功
        window.setTimeout(() => {
          setMatched((prev) => new Set([...prev, a.pairId]));
          setOpened([]);
        }, 350);
      } else {
        setMistakes((m) => m + 1);
        window.setTimeout(() => setOpened([]), 1200);
      }
    }
  };

  // 全部配对 → 自动提交
  useEffect(() => {
    if (reportedDone) return;
    if (matched.size === pairs.length && pairs.length > 0) {
      setReportedDone(true);
      // 留 400ms 让最后一对绿光留底
      const t = window.setTimeout(() => onSubmit(true), 400);
      return () => window.clearTimeout(t);
    }
    // 锁住但未完成 → 视为外层 timeout，按错处理
    if (locked && matched.size < pairs.length) {
      setReportedDone(true);
      const t = window.setTimeout(() => onSubmit(false), 0);
      return () => window.clearTimeout(t);
    }
  }, [matched.size, pairs.length, locked, reportedDone, onSubmit]);

  const cols = pairs.length <= 4 ? 4 : 5;
  return (
    <div className="dgb-finale-quiz" data-kind="memory-match">
      {prompt ? <div className="dgb-finale-quiz__stem">{prompt}</div> : null}
      <div style={{ fontSize: 12, opacity: 0.65, marginBottom: 8 }}>
        翻牌配对 · 已配 {matched.size}/{pairs.length} · 翻错 {mistakes}
      </div>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: `repeat(${cols}, 1fr)`,
          gap: 8,
        }}
      >
        {cards.map((c) => {
          const isMatched = matched.has(c.pairId);
          const isOpen = isMatched || opened.includes(c.key);
          return (
            <button
              key={c.key}
              type="button"
              className="dgb-finale-quiz__option"
              disabled={locked || isMatched}
              onClick={() => flip(c.key)}
              style={{
                minHeight: 72,
                justifyContent: 'center',
                textAlign: 'center',
                fontSize: 13,
                background: isMatched
                  ? 'rgba(74, 222, 128, 0.18)'
                  : isOpen
                  ? 'rgba(56, 189, 248, 0.18)'
                  : 'rgba(255,255,255,0.06)',
              }}
              aria-label={isOpen ? c.text : '未翻开的卡'}
            >
              <span style={{ opacity: isOpen ? 1 : 0.35 }}>
                {isOpen ? c.text : '✦'}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

/* ───────────── Interactive: spot-difference（左对照右，勾出差异） ───────────── */
/**
 * 文本版"找不同"：左侧反例 vs 右侧正例并排，
 *   - 玩家从 differences 列表（题目预定义）中勾出"实际确实是差异"的项
 *   - 全选才算对（题目作者保证 differences 列表是完整且只列了真差异）
 *   - 不支持 image 类型的视觉点击（schema 留有 coords，未来再补 SVG 圈选）
 */
function SpotDifferenceQ({
  prompt,
  left,
  right,
  differences,
  locked,
  onSubmit,
}: {
  prompt: string;
  left: { type: 'text' | 'image'; content: string };
  right: { type: 'text' | 'image'; content: string };
  differences: { description: string; coords?: [number, number] }[];
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  const [picked, setPicked] = useState<Set<number>>(new Set());
  // 干扰项：基础 + 题目特定迷惑词，让"全选"不是必胜
  const decoys = useMemo<string[]>(
    () => [
      '左侧使用了变量声明，右侧没有',
      '注释字数不同',
      '函数名拼写不同',
      '左侧多了一个换行',
    ],
    [],
  );
  // 选项 = 真差异 + 干扰项；稳定洗牌
  const options = useMemo<{ idx: number; text: string; isReal: boolean }[]>(() => {
    const real = differences.map((d, i) => ({ idx: i, text: d.description, isReal: true }));
    const fake = decoys.map((t, i) => ({ idx: 1000 + i, text: t, isReal: false }));
    const all = [...real, ...fake];
    const seed = all.map((x) => x.text).join('§');
    let h = 0;
    for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) | 0;
    const out = [...all];
    for (let i = out.length - 1; i > 0; i--) {
      h = (h * 9301 + 49297) % 233280;
      const j = Math.abs(h) % (i + 1);
      [out[i], out[j]] = [out[j]!, out[i]!];
    }
    return out;
  }, [differences, decoys]);
  const toggle = (idx: number) => {
    if (locked) return;
    setPicked((prev) => {
      const n = new Set(prev);
      if (n.has(idx)) n.delete(idx);
      else n.add(idx);
      return n;
    });
  };
  const submit = () => {
    // 全部真差异都选中、且无干扰项被错选 → 对
    const realIdxs = options.filter((o) => o.isReal).map((o) => o.idx);
    const allReal = realIdxs.every((i) => picked.has(i));
    const noFake = [...picked].every((i) => i < 1000);
    onSubmit(allReal && noFake);
  };
  const renderPanel = (label: string, panel: { type: 'text' | 'image'; content: string }) => {
    if (panel.type === 'image') {
      return (
        <figure style={{ margin: 0 }}>
          <figcaption style={{ fontSize: 12, opacity: 0.7, marginBottom: 4 }}>{label}</figcaption>
          <img src={panel.content} alt={label} style={{ width: '100%', borderRadius: 6 }} />
        </figure>
      );
    }
    return (
      <div>
        <div style={{ fontSize: 12, opacity: 0.7, marginBottom: 4 }}>{label}</div>
        <pre
          style={{
            margin: 0,
            padding: '10px 12px',
            fontSize: 12,
            lineHeight: 1.55,
            background: 'rgba(15, 23, 42, 0.55)',
            borderRadius: 6,
            overflow: 'auto',
            maxHeight: 240,
            color: '#e6f0ff',
            whiteSpace: 'pre-wrap',
          }}
        >
          <code>{panel.content}</code>
        </pre>
      </div>
    );
  };
  return (
    <div className="dgb-finale-quiz" data-kind="spot-difference">
      <div className="dgb-finale-quiz__stem">{prompt}</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
        {renderPanel('反面教材 ✗', left)}
        {renderPanel('工程范本 ✓', right)}
      </div>
      <div style={{ fontSize: 12, opacity: 0.7, marginBottom: 6 }}>
        勾选所有"反面教材确实违反工程铁律"的差异（混入了干扰项）：
      </div>
      <div className="dgb-finale-quiz__options">
        {options.map((o) => {
          const isPicked = picked.has(o.idx);
          const cls = ['dgb-finale-quiz__option'];
          if (isPicked) cls.push('is-selected');
          if (locked) {
            if (o.isReal && isPicked) cls.push('is-correct');
            if (o.isReal && !isPicked) cls.push('is-wrong');
            if (!o.isReal && isPicked) cls.push('is-wrong');
          }
          return (
            <button
              key={o.idx}
              type="button"
              className={cls.join(' ')}
              disabled={locked}
              onClick={() => toggle(o.idx)}
            >
              <span style={{ marginRight: 8 }}>{isPicked ? '☑' : '☐'}</span>
              <span>{o.text}</span>
            </button>
          );
        })}
      </div>
      <button
        type="button"
        className="dgb-finale-quiz__submit"
        disabled={locked || picked.size === 0}
        onClick={submit}
      >
        提交
      </button>
    </div>
  );
}

/* ───────────── Interactive: hotspot（图上找点） ───────────── */
/**
 * 图上点热区：底图（image=URL 或 data URI）+ N 个圆形热区，
 *   - 点击圆区半径内 → 命中该 hotspot（永久标记）
 *   - 命中数 == 总数 → onSubmit(true)；锁住但未命中完 → onSubmit(false)
 *   - 视觉：未命中是脉冲圈，命中变实心 + 序号
 */
function HotspotQ({
  prompt,
  image,
  hotspots,
  locked,
  onSubmit,
}: {
  prompt: string;
  image: string;
  hotspots: { id: string; description: string; x: number; y: number; radius: number }[];
  locked: boolean;
  onSubmit: (correct: boolean) => void;
}) {
  const [found, setFound] = useState<Set<string>>(new Set());
  const [reportedDone, setReportedDone] = useState(false);

  const click = (id: string) => {
    if (locked || found.has(id)) return;
    setFound((prev) => new Set([...prev, id]));
  };

  useEffect(() => {
    if (reportedDone) return;
    if (found.size === hotspots.length && hotspots.length > 0) {
      setReportedDone(true);
      const t = window.setTimeout(() => onSubmit(true), 400);
      return () => window.clearTimeout(t);
    }
    if (locked && found.size < hotspots.length) {
      setReportedDone(true);
      const t = window.setTimeout(() => onSubmit(false), 0);
      return () => window.clearTimeout(t);
    }
  }, [found.size, hotspots.length, locked, reportedDone, onSubmit]);

  return (
    <div className="dgb-finale-quiz" data-kind="hotspot">
      <div className="dgb-finale-quiz__stem">{prompt}</div>
      <div style={{ fontSize: 12, opacity: 0.65, marginBottom: 8 }}>
        在图中点击 {hotspots.length} 个关键位置 · 已找 {found.size}/{hotspots.length}
      </div>
      <div
        style={{
          position: 'relative',
          display: 'inline-block',
          maxWidth: '100%',
          margin: '0 auto',
          background: 'rgba(15, 23, 42, 0.4)',
          borderRadius: 8,
          padding: 8,
        }}
      >
        <img
          src={image}
          alt="热点图"
          style={{ display: 'block', maxWidth: '100%', borderRadius: 4, userSelect: 'none' }}
          draggable={false}
        />
        {hotspots.map((h, i) => {
          const isFound = found.has(h.id);
          return (
            <button
              key={h.id}
              type="button"
              disabled={locked || isFound}
              onClick={() => click(h.id)}
              title={isFound ? h.description : '点击此处'}
              style={{
                position: 'absolute',
                left: h.x - h.radius,
                top: h.y - h.radius,
                width: h.radius * 2,
                height: h.radius * 2,
                borderRadius: '50%',
                cursor: locked || isFound ? 'default' : 'crosshair',
                border: isFound
                  ? '2px solid rgba(74, 222, 128, 0.95)'
                  : '2px dashed rgba(56, 189, 248, 0.7)',
                background: isFound
                  ? 'rgba(74, 222, 128, 0.32)'
                  : 'rgba(56, 189, 248, 0.08)',
                color: '#fff',
                fontWeight: 700,
                fontSize: 13,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                animation: isFound ? 'none' : 'dgb-hotspot-pulse 1.6s ease-in-out infinite',
              }}
              aria-label={isFound ? `已找到：${h.description}` : `热点 ${i + 1}`}
            >
              {isFound ? i + 1 : ''}
            </button>
          );
        })}
      </div>
      {locked ? null : (
        <div style={{ fontSize: 12, opacity: 0.6, marginTop: 8 }}>
          全部找完会自动提交；超时按已找数量判定。
        </div>
      )}
      {found.size > 0 ? (
        <ul style={{ marginTop: 8, fontSize: 12, opacity: 0.85 }}>
          {hotspots
            .filter((h) => found.has(h.id))
            .map((h, i) => (
              <li key={h.id} style={{ marginBottom: 2 }}>
                ✓ {i + 1}. {h.description}
              </li>
            ))}
        </ul>
      ) : null}
    </div>
  );
}
