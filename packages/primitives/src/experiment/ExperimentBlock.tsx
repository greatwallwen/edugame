import { useState } from 'react';
import './ExperimentBlock.css';

interface ExperimentStep {
  order: number;
  title: string;
  description: string;
  code?: string;
  checkpoint?: boolean;
}

export interface ExperimentBlockProps {
  title: string;
  steps: ExperimentStep[];
  expectedResult?: string;
  troubleshooting?: string[];
}

export function ExperimentBlock({ title, steps, expectedResult, troubleshooting }: ExperimentBlockProps) {
  const [done, setDone] = useState<Set<number>>(new Set());
  const [showTs, setShowTs] = useState(false);

  const progress = Math.round((done.size / steps.length) * 100);

  return (
    <div className="dgb-experiment">
      <div className="dgb-experiment-head">
        <span className="dgb-experiment-badge">🧪 实验</span>
        <span className="dgb-experiment-title">{title}</span>
        <span className="dgb-experiment-progress">{done.size} / {steps.length} 步</span>
      </div>
      <div className="dgb-experiment-bar-outer">
        <div className="dgb-experiment-bar-inner" style={{ width: `${progress}%` }} />
      </div>
      <ol className="dgb-experiment-steps">
        {steps.map((s) => {
          const isDone = done.has(s.order);
          return (
            <li key={s.order} className={`dgb-experiment-step ${isDone ? 'done' : ''}`}>
              <button
                type="button"
                className="dgb-experiment-check"
                onClick={() => {
                  setDone((cur) => {
                    const n = new Set(cur);
                    if (n.has(s.order)) n.delete(s.order); else n.add(s.order);
                    return n;
                  });
                }}
                aria-label={isDone ? '标记未完成' : '标记完成'}
              >
                {isDone ? '✓' : s.order}
              </button>
              <div className="dgb-experiment-body">
                <strong className="dgb-experiment-step-title">{s.title}</strong>
                <p className="dgb-experiment-step-desc">{s.description}</p>
                {s.code ? (
                  <pre className="dgb-experiment-code"><code>{s.code}</code></pre>
                ) : null}
                {s.checkpoint && !isDone ? (
                  <span className="dgb-experiment-checkpoint">⏸ 检查点：完成此步再继续</span>
                ) : null}
              </div>
            </li>
          );
        })}
      </ol>
      {expectedResult ? (
        <div className="dgb-experiment-result">
          <strong>预期现象：</strong>
          {expectedResult}
        </div>
      ) : null}
      {troubleshooting && troubleshooting.length > 0 ? (
        <div className="dgb-experiment-ts">
          <button type="button" className="dgb-experiment-ts-toggle" onClick={() => setShowTs((s) => !s)}>
            {showTs ? '▾' : '▸'} 故障排查 ({troubleshooting.length} 条)
          </button>
          {showTs ? (
            <ul className="dgb-experiment-ts-list">
              {troubleshooting.map((t, i) => (
                <li key={i} className="dgb-experiment-ts-item">
                  <span className="dgb-experiment-ts-solution">{t}</span>
                </li>
              ))}
            </ul>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
