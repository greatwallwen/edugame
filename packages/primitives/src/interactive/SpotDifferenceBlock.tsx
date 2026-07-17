import { useMemo, useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import './SpotDifferenceBlock.css';

export interface SpotDifferenceBlockProps {
  spec: Extract<InteractiveSpec, { kind: 'spot-difference' }>;
}

/**
 * 找不同互动：左右面板并排展示，用户逐行/逐点选择差异位置。
 * 支持 text 与 image 两种内容类型。
 */
export function SpotDifferenceBlock({ spec }: SpotDifferenceBlockProps) {
  const { prompt, left, right, differences } = spec;
  const total = differences.length;

  const leftLines = useMemo(() => left.content.split('\n'), [left.content]);
  const rightLines = useMemo(() => right.content.split('\n'), [right.content]);
  const maxLines = Math.max(leftLines.length, rightLines.length);

  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [submitted, setSubmitted] = useState(false);

  const diffLineIndices = useMemo(() => {
    const set = new Set<number>();
    for (let i = 0; i < maxLines; i++) {
      if ((leftLines[i] ?? '') !== (rightLines[i] ?? '')) set.add(i);
    }
    return set;
  }, [leftLines, rightLines, maxLines]);

  const toggleLine = (idx: number) => {
    if (submitted) return;
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(idx)) next.delete(idx);
      else next.add(idx);
      return next;
    });
  };

  const correctCount = [...selected].filter((i) => diffLineIndices.has(i)).length;
  const wrongCount = [...selected].filter((i) => !diffLineIndices.has(i)).length;
  const isPerfect = submitted && correctCount === diffLineIndices.size && wrongCount === 0;

  const lineCls = (idx: number) => {
    if (!submitted) return selected.has(idx) ? 'selected' : '';
    if (diffLineIndices.has(idx) && selected.has(idx)) return 'correct';
    if (!diffLineIndices.has(idx) && selected.has(idx)) return 'wrong';
    if (diffLineIndices.has(idx) && !selected.has(idx)) return 'correct';
    return '';
  };

  return (
    <div className="dgb-spotdiff">
      <h4 className="dgb-spotdiff-title">🔍 {prompt}</h4>
      <p className="dgb-spotdiff-hint">共有 {total} 处不同，点击下方行标出差异。</p>
      <div className="dgb-spotdiff-cols">
        <div className="dgb-spotdiff-panel">
          <div className="dgb-spotdiff-label">左侧</div>
          <div className="dgb-spotdiff-content">
            {left.type === 'text' ? (
              Array.from({ length: maxLines }).map((_, i) => (
                <span
                  key={i}
                  className={`dgb-spotdiff-line ${lineCls(i)}`}
                  onClick={() => toggleLine(i)}
                >
                  {leftLines[i] ?? ''}
                </span>
              ))
            ) : (
              <img src={left.content} alt="左侧" style={{ maxWidth: '100%', borderRadius: 6 }} />
            )}
          </div>
        </div>
        <div className="dgb-spotdiff-panel">
          <div className="dgb-spotdiff-label">右侧</div>
          <div className="dgb-spotdiff-content">
            {right.type === 'text' ? (
              Array.from({ length: maxLines }).map((_, i) => (
                <span
                  key={i}
                  className={`dgb-spotdiff-line ${lineCls(i)}`}
                  onClick={() => toggleLine(i)}
                >
                  {rightLines[i] ?? ''}
                </span>
              ))
            ) : (
              <img src={right.content} alt="右侧" style={{ maxWidth: '100%', borderRadius: 6 }} />
            )}
          </div>
        </div>
      </div>
      <div className="dgb-spotdiff-ctrl">
        <button
          className="dgb-spotdiff-btn primary"
          onClick={() => setSubmitted(true)}
          disabled={submitted || selected.size === 0}
        >
          提交
        </button>
        {submitted && (
          <button className="dgb-spotdiff-btn" onClick={() => { setSubmitted(false); setSelected(new Set()); }}>
            重做
          </button>
        )}
      </div>
      {submitted && (
        <div className={`dgb-spotdiff-result ${isPerfect ? 'ok' : 'err'}`}>
          {isPerfect
            ? `🎉 全对！共发现 ${diffLineIndices.size} 处不同。`
            : `发现 ${correctCount}/${diffLineIndices.size} 处正确，误标了 ${wrongCount} 处无关内容。`}
        </div>
      )}
    </div>
  );
}
