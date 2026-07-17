/**
 * SignalTraceBlock — 信号时序描点互动（第 24 种题型）
 *
 * 学生在 SVG 波形图上点击标记关键时刻，系统判定是否命中目标位置。
 * 适配场景：EXTI 边沿检测、UART 起始位、PWM 占空比切换、ADC 采样时刻等。
 */
import { useState, useRef, useCallback, useMemo } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { GameStat, GameWinBanner } from '../game-kit';
import './SignalTraceBlock.css';

type SignalTraceSpec = Extract<InteractiveSpec, { kind: 'signal-trace' }>;

const MARKER_COLORS = ['#ef4444', '#f59e0b', '#10b981', '#3b82f6', '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16'];

export function SignalTraceBlock({ spec }: { spec: SignalTraceSpec }) {
  const [placed, setPlaced] = useState<Record<string, number>>({});
  const [submitted, setSubmitted] = useState(false);
  const [activeMarker, setActiveMarker] = useState<string | null>(null);
  const svgRef = useRef<SVGSVGElement>(null);

  const xMin = Math.min(...spec.waveform.map(p => p.x));
  const xMax = Math.max(...spec.waveform.map(p => p.x));
  const xRange = xMax - xMin || 1;

  const W = 600, H = 160, PAD = 40;
  const plotW = W - PAD * 2, plotH = H - PAD * 2;

  const toSvgX = useCallback((x: number) => PAD + ((x - xMin) / xRange) * plotW, [xMin, xRange, plotW]);
  const toSvgY = useCallback((y: number) => PAD + plotH - y * plotH, [plotH]);
  const fromSvgX = useCallback((sx: number) => xMin + ((sx - PAD) / plotW) * xRange, [xMin, xRange, plotW]);

  const pathD = useMemo(() => {
    return spec.waveform.map((p, i) => {
      const cmd = i === 0 ? 'M' : 'L';
      return `${cmd}${toSvgX(p.x).toFixed(1)},${toSvgY(p.y).toFixed(1)}`;
    }).join(' ');
  }, [spec.waveform, toSvgX, toSvgY]);

  const handleSvgClick = useCallback((e: React.MouseEvent<SVGSVGElement>) => {
    if (submitted || !activeMarker) return;
    const svg = svgRef.current;
    if (!svg) return;
    const rect = svg.getBoundingClientRect();
    const sx = e.clientX - rect.left;
    const dataX = fromSvgX(sx * (W / rect.width));
    setPlaced(prev => ({ ...prev, [activeMarker]: dataX }));
    // 自动切下一个未标记的
    const next = spec.markers.find(m => m.id !== activeMarker && !(m.id in placed) && m.id !== activeMarker);
    setActiveMarker(next?.id ?? null);
  }, [submitted, activeMarker, fromSvgX, spec.markers, placed]);

  const results = useMemo(() => {
    if (!submitted) return null;
    return spec.markers.map(m => {
      const px = placed[m.id];
      if (px == null) return { ...m, correct: false, placed: null as number | null };
      const tol = m.tolerance ?? xRange * 0.03;
      return { ...m, correct: Math.abs(px - m.x) <= tol, placed: px };
    });
  }, [submitted, spec.markers, placed, xRange]);

  const allPlaced = spec.markers.every(m => m.id in placed);
  const score = results ? results.filter(r => r.correct).length : 0;

  return (
    <div className="dgb-signal-trace-wrapper">
      <p className="dgb-signal-trace-prompt">{spec.prompt}</p>
      {submitted && <GameStat score={score} combo={0} />}
      <div className="dgb-signal-trace">
        <div className="dgb-signal-trace-markers">
          {spec.markers.map((m, i) => {
            const color = MARKER_COLORS[i % MARKER_COLORS.length]!;
            const isPlaced = m.id in placed;
            const isActive = activeMarker === m.id;
            const result = results?.find(r => r.id === m.id);
            return (
              <button
                key={m.id}
                type="button"
                className={`dgb-signal-trace-chip ${isActive ? 'active' : ''} ${isPlaced ? 'placed' : ''} ${result ? (result.correct ? 'correct' : 'wrong') : ''}`}
                style={{ '--chip-color': color } as React.CSSProperties}
                onClick={() => !submitted && setActiveMarker(m.id)}
                disabled={submitted}
              >
                <span className="dgb-signal-trace-chip-dot" />
                {m.label}
                {m.markerType && <span className="dgb-signal-trace-chip-type">
                  {m.markerType === 'rising-edge' ? '↑' : m.markerType === 'falling-edge' ? '↓' : m.markerType === 'sample' ? '◇' : m.markerType === 'trigger' ? '⚡' : '•'}
                </span>}
              </button>
            );
          })}
        </div>

        <svg ref={svgRef} viewBox={`0 0 ${W} ${H}`} className="dgb-signal-trace-svg" onClick={handleSvgClick}>
          {/* Grid lines */}
          {Array.from({ length: 5 }, (_, i) => {
            const x = PAD + (i / 4) * plotW;
            return <line key={`g${i}`} x1={x} y1={PAD} x2={x} y2={PAD + plotH} stroke="#e2e8f0" strokeWidth={0.5} />;
          })}
          <line x1={PAD} y1={PAD + plotH} x2={PAD + plotW} y2={PAD + plotH} stroke="#94a3b8" strokeWidth={1} />
          <line x1={PAD} y1={PAD} x2={PAD} y2={PAD + plotH} stroke="#94a3b8" strokeWidth={1} />
          {/* Waveform */}
          <path d={pathD} fill="none" stroke="#3b82f6" strokeWidth={2} />
          {/* Placed markers */}
          {spec.markers.map((m, i) => {
            const px = placed[m.id];
            if (px == null) return null;
            const sx = toSvgX(px);
            const color = MARKER_COLORS[i % MARKER_COLORS.length]!;
            const result = results?.find(r => r.id === m.id);
            return (
              <g key={m.id}>
                <line x1={sx} y1={PAD} x2={sx} y2={PAD + plotH} stroke={color} strokeWidth={1.5} strokeDasharray="4 2" />
                <circle cx={sx} cy={PAD - 8} r={6} fill={result ? (result.correct ? '#10b981' : '#ef4444') : color} />
                <text x={sx} y={PAD - 4} textAnchor="middle" fontSize={8} fill="white" fontWeight="bold">{i + 1}</text>
                {result && !result.correct && (
                  <line x1={toSvgX(m.x)} y1={PAD} x2={toSvgX(m.x)} y2={PAD + plotH} stroke="#10b981" strokeWidth={1} strokeDasharray="2 2" opacity={0.6} />
                )}
              </g>
            );
          })}
          {/* Axis labels */}
          {spec.xUnit && <text x={PAD + plotW} y={H - 4} textAnchor="end" fontSize={10} fill="#64748b">{spec.xUnit}</text>}
          {spec.yLabel && <text x={4} y={PAD + plotH / 2} textAnchor="start" fontSize={9} fill="#64748b" transform={`rotate(-90, 12, ${PAD + plotH / 2})`}>{spec.yLabel}</text>}
        </svg>

        {activeMarker && !submitted && (
          <p className="dgb-signal-trace-hint">点击波形图上的位置标记「{spec.markers.find(m => m.id === activeMarker)?.label}」</p>
        )}

        <div className="dgb-signal-trace-actions">
          {!submitted && <button type="button" className="dgb-signal-trace-submit" disabled={!allPlaced} onClick={() => setSubmitted(true)}>提交判定</button>}
        </div>

        {submitted && spec.explanation && <p className="dgb-signal-trace-explanation">{spec.explanation}</p>}
      </div>
      {submitted && <GameWinBanner show={submitted} text={`${score}/${spec.markers.length} 正确`} onReplay={() => { setPlaced({}); setSubmitted(false); setActiveMarker(null); }} />}
    </div>
  );
}
