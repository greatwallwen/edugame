import './WaveformBlock.css';

interface SignalTrace {
  name: string;
  type: 'digital' | 'analog';
  data: (0 | 1 | number)[];
  color?: string;
}

export interface WaveformBlockProps {
  title?: string;
  timeScale?: string;
  signals: SignalTrace[];
}

export function WaveformBlock({ title, timeScale, signals }: WaveformBlockProps) {
  const maxSamples = Math.max(...signals.map((s) => s.data.length), 1);
  const colors = ['#0E7C4A', '#B0872B', '#0A5132', '#8A5A2B', '#0F766E'];

  return (
    <figure className="dgb-wave">
      {title ? <figcaption className="dgb-wave-cap">{title}</figcaption> : null}
      <div className="dgb-wave-chart">
        <svg viewBox={`0 0 ${maxSamples * 12 + 60} ${signals.length * 50 + 20}`} preserveAspectRatio="xMidYMid meet">
          {/* Grid */}
          {Array.from({ length: signals.length + 1 }, (_, i) => (
            <line key={`h${i}`} x1="50" y1={10 + i * 50} x2={maxSamples * 12 + 50} y2={10 + i * 50} className="dgb-wave-grid" />
          ))}
          {Array.from({ length: Math.min(maxSamples, 20) }, (_, i) => (
            <line key={`v${i}`} x1={50 + i * 12} y1="10" x2={50 + i * 12} y2={signals.length * 50 + 10} className="dgb-wave-grid" />
          ))}

          {signals.map((sig, si) => {
            const yBase = 10 + si * 50 + 25;
            const color = sig.color || colors[si % colors.length];
            const pts: string[] = [];
            for (let i = 0; i < sig.data.length; i++) {
              const x = 50 + i * 12;
              if (sig.type === 'digital') {
                const v = sig.data[i] as 0 | 1;
                const y = yBase - (v === 1 ? 18 : -8);
                if (i > 0) {
                  const prev = sig.data[i - 1] as 0 | 1;
                  const prevY = yBase - (prev === 1 ? 18 : -8);
                  pts.push(`L ${x} ${prevY} L ${x} ${y}`);
                } else {
                  pts.push(`M ${x} ${y}`);
                }
              } else {
                const v = sig.data[i] as number;
                const y = yBase - v * 15;
                pts.push(i === 0 ? `M ${x} ${y}` : `L ${x} ${y}`);
              }
            }
            return (
              <g key={sig.name}>
                <text x="46" y={yBase + 4} textAnchor="end" className="dgb-wave-label">{sig.name}</text>
                <path d={pts.join(' ')} fill="none" stroke={color} strokeWidth="2" />
                {sig.type === 'analog' && (
                  <path d={`${pts.join(' ')} L ${50 + (sig.data.length - 1) * 12} ${yBase} L 50 ${yBase} Z`} fill={color} fillOpacity="0.12" stroke="none" />
                )}
              </g>
            );
          })}

          {timeScale ? (
            <text x={maxSamples * 6 + 50} y={signals.length * 50 + 18} textAnchor="middle" className="dgb-wave-xlabel">{timeScale}</text>
          ) : null}
        </svg>
      </div>
    </figure>
  );
}
