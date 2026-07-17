/**
 * Shell 辅助小组件：WelcomeBubble / ProgressRing / HighlightBridge
 *
 * 从 Shell.tsx 抽出以压缩主文件行数。
 */
import { useEffect, useState } from 'react';
import { useHighlight, type HighlightContextValue } from '@dgbook/blocks';

/** AI 助教首次进入打字机欢迎语 */
export function WelcomeBubble({ text }: { text: string }) {
  const [displayed, setDisplayed] = useState('');
  const [done, setDone] = useState(false);
  useEffect(() => {
    setDisplayed('');
    setDone(false);
    let i = 0;
    const interval = setInterval(() => {
      i++;
      setDisplayed(text.slice(0, i));
      if (i >= text.length) { setDone(true); clearInterval(interval); }
    }, 28);
    return () => clearInterval(interval);
  }, [text]);

  return (
    <div style={{ margin: '8px 0 10px' }}>
      <div style={{
        background: 'var(--dg-color-surface-muted, #f1f5f9)',
        border: '1px solid var(--dg-color-surface-border, #e2e8f0)',
        borderRadius: '12px',
        padding: '10px 14px',
        fontSize: 12.5,
        lineHeight: 1.6,
        color: 'var(--dg-color-text-primary, #0f172a)',
        animation: 'dgb-bubble-in 0.35s ease both',
      }}>
        {displayed}
        {!done && (
          <span style={{
            display: 'inline-block', width: 2, height: '1em',
            background: 'var(--dg-color-brand-500, #0ea5e9)',
            verticalAlign: 'text-bottom', marginLeft: 2,
            animation: 'dgb-cursor-blink 0.8s step-end infinite',
          }} />
        )}
      </div>
    </div>
  );
}

/** 环形进度图 */
export function ProgressRing({ pct }: { pct: number }) {
  const r = 36;
  const c = 2 * Math.PI * r;
  const offset = c - (pct / 100) * c;
  return (
    <svg width="84" height="84" viewBox="0 0 84 84">
      <circle cx="42" cy="42" r={r} fill="none" stroke="var(--dg-color-surface-border)" strokeWidth="6" />
      <circle
        cx="42" cy="42" r={r} fill="none"
        stroke="var(--dg-color-brand-500)"
        strokeWidth="6"
        strokeLinecap="round"
        strokeDasharray={c}
        strokeDashoffset={offset}
        transform="rotate(-90 42 42)"
        style={{ transition: 'stroke-dashoffset 0.6s ease' }}
      />
    </svg>
  );
}

/**
 * HighlightBridge: Shell 主体在 <HighlightProvider> 之外，无法直接 useHighlight()。
 * 通过本桥接组件（挂在 Provider 之内）把 API 写入 Shell 持有的 ref。
 */
export function HighlightBridge({
  apiRef,
}: {
  apiRef: { current: HighlightContextValue | null };
}) {
  const api = useHighlight();
  useEffect(() => {
    apiRef.current = api;
    return () => { apiRef.current = null; };
  }, [api, apiRef]);
  return null;
}
