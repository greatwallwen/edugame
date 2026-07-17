import { useMemo, useState, useCallback } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { useSound } from '../game-kit';
import './FillBlankBlock.css';

export interface FillBlankBlockProps {
  spec: Extract<InteractiveSpec, { kind: 'fill-blank' }>;
}

interface Blank { idx: number; answer: string; hint?: string; }

/** Fisher-Yates 洗牌 */
function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = a[i]!; a[i] = a[j]!; a[j] = tmp;
  }
  return a;
}

/**
 * 拖拽词块填空游戏
 * 把裸输入框升级为「拖拽词块到投放槽」的可玩交互：
 *   - 词库区：所有答案打乱成可拖拽词块（一题多空时互为干扰项）
 *   - 填空区：blank 变成投放槽，支持拖拽 + 点击两种放置方式
 *   - 即时反馈：放对槽变绿弹入✓，放错抖动红闪并弹回
 *   - 游戏性：实时得分 + 连击 combo + 全对撒花庆祝
 */
export function FillBlankBlock({ spec }: FillBlankBlockProps) {
  const blanks = useMemo(() => {
    const out: Blank[] = [];
    let i = 0;
    for (const seg of spec.segments) {
      if (typeof seg === 'object' && seg.blank) out.push({ idx: i++, answer: seg.answer, hint: seg.hint });
    }
    return out;
  }, [spec]);

  // 词库：每个 blank 对应一个词块（含重复答案，互为干扰项），打乱顺序
  const initialPool = useMemo(() => {
    return shuffle(blanks.map((b, i) => ({ id: `tok-${i}`, answer: b.answer })));
  }, [blanks]);

  // placed[blankIdx] = token.answer | null
  const [placed, setPlaced] = useState<Record<number, string | null>>({});
  const [pool, setPool] = useState(initialPool);
  const [picked, setPicked] = useState<string | null>(null);     // 点击模式选中的词
  const [wrongIdx, setWrongIdx] = useState<number | null>(null); // 抖动反馈
  const [score, setScore] = useState(0);
  const [combo, setCombo] = useState(0);
  const { play } = useSound();

  const allCorrect = blanks.length > 0 &&
    blanks.every((b) => (placed[b.idx] ?? '').toLowerCase() === b.answer.toLowerCase());

  // 放置逻辑：词块 answer 放到 blank idx 的槽
  const place = useCallback((answer: string, blankIdx: number) => {
    const blank = blanks.find((b) => b.idx === blankIdx);
    if (!blank) return;
    const correct = answer.toLowerCase() === blank.answer.toLowerCase();
    if (correct) {
      setPlaced((cur) => ({ ...cur, [blankIdx]: answer }));
      // 只移除一个匹配该答案的词块（重复答案场景下保留其余）
      setPool((cur) => { const k = cur.findIndex((t) => t.answer === answer); return k < 0 ? cur : cur.filter((_, j) => j !== k); });
      setPicked(null);
      play('correct');
      setCombo((c) => { const nc = c + 1; setScore((s) => s + 10 + nc * 2); return nc; });
    } else {
      setWrongIdx(blankIdx);
      setCombo(0);
      setPicked(null);
      play('wrong');
      window.setTimeout(() => setWrongIdx(null), 500);
    }
  }, [blanks, play]);

  // 从槽取回词块
  const recall = useCallback((blankIdx: number) => {
    const answer = placed[blankIdx];
    if (!answer) return;
    setPlaced((cur) => ({ ...cur, [blankIdx]: null }));
    setPool((cur) => [...cur, { id: `tok-r-${blankIdx}-${Date.now()}`, answer }]);
  }, [placed]);

  const reset = useCallback(() => {
    setPlaced({}); setPool(initialPool); setPicked(null);
    setWrongIdx(null); setScore(0); setCombo(0);
  }, [initialPool]);

  return (
    <div className="dgb-fillblank-game">
      <div className="dgb-fbg-head">
        <span className="dgb-fbg-badge">🎯 拖拽填空</span>
        {spec.prompt ? <span className="dgb-fbg-prompt">{spec.prompt}</span> : null}
        <span className="dgb-fbg-stats">
          <span className="dgb-fbg-score">得分 {score}</span>
          {combo > 1 ? <span className="dgb-fbg-combo">🔥 连击 ×{combo}</span> : null}
        </span>
      </div>

      <div className="dgb-fbg-body">
        {(() => {
          let bi = -1;
          return spec.segments.map((seg, i) => {
            if (typeof seg === 'string') return <span key={i} className="dgb-fbg-text">{seg}</span>;
            bi += 1;
            const b = blanks[bi];
            if (!b) return null;
            const val = placed[b.idx] ?? null;
            const isWrong = wrongIdx === b.idx;
            return (
              <span
                key={i}
                className={`dgb-fbg-slot ${val ? 'filled' : ''} ${isWrong ? 'wrong' : ''} ${picked ? 'droppable' : ''}`}
                title={b.hint}
                onDragOver={(e) => { e.preventDefault(); }}
                onDrop={(e) => { e.preventDefault(); const a = e.dataTransfer.getData('text/plain'); if (a) place(a, b.idx); }}
                onClick={() => { if (val) { recall(b.idx); } else if (picked) { place(picked, b.idx); } }}
              >
                {val ? <span className="dgb-fbg-slot-val">{val} <span className="dgb-fbg-slot-x">×</span></span>
                     : <span className="dgb-fbg-slot-ph">{picked ? '放这里' : '▭'}</span>}
              </span>
            );
          });
        })()}
      </div>

      {pool.length > 0 ? (
        <div className="dgb-fbg-pool">
          {pool.map((t) => (
            <button
              key={t.id}
              type="button"
              draggable
              className={`dgb-fbg-token ${picked === t.answer ? 'picked' : ''}`}
              onDragStart={(e) => { e.dataTransfer.setData('text/plain', t.answer); e.dataTransfer.effectAllowed = 'move'; }}
              onClick={() => setPicked((p) => (p === t.answer ? null : t.answer))}
            >
              {t.answer}
            </button>
          ))}
        </div>
      ) : null}

      {allCorrect ? (
        <div className="dgb-fbg-win">
          <span className="dgb-fbg-win-text">🎉 全部正确！最终得分 {score}</span>
          <button type="button" className="dgb-fbg-reset" onClick={reset}>再玩一次</button>
          <span className="dgb-fbg-confetti" aria-hidden>
            {Array.from({ length: 12 }).map((_, k) => <i key={k} style={{ '--d': `${k * 0.08}s`, '--x': `${(k - 6) * 18}px` } as React.CSSProperties} />)}
          </span>
        </div>
      ) : (
        <div className="dgb-fbg-actions">
          <span className="dgb-fbg-hint">拖动下方词块到空格，或点击词块再点空格</span>
          <button type="button" className="dgb-fbg-reset" onClick={reset}>重置</button>
        </div>
      )}
    </div>
  );
}
