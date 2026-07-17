
import type { CSSProperties, ReactNode } from 'react';

interface CommonProps {
  width?: number | string;
  className?: string;
  'data-element-id'?: string;
}

const labelStyle: CSSProperties = {
  fontSize: 10, textAlign: 'center', color: 'gray', marginTop: 2, lineHeight: 1.1,
};

function Container({ width, className, 'data-element-id': elId, children, defaultWidth = 60 }: CommonProps & { children: ReactNode; defaultWidth?: number }) {
  return (
    <div
      className={className}
      style={{ display: 'inline-flex', flexDirection: 'column', alignItems: 'center', width: width ?? defaultWidth }}
      data-element-id={elId}
    >
      {children}
    </div>
  );
}

// ── WokwiBuzzer ──────────────────────────────────────────────
export interface WokwiBuzzerProps extends CommonProps {
  hasSignal?: boolean;
  frequency?: number;
  label?: string;
}

export function WokwiBuzzer({ hasSignal = false, frequency, label = '', ...c }: WokwiBuzzerProps) {
  return (
    <Container {...c} defaultWidth={60}>
      <svg viewBox="0 0 60 60" width="100%" aria-label="蜂鸣器" role="img">
        <circle cx="30" cy="30" r="22" fill="#1a1a1a" stroke="#333" strokeWidth="1.5" />
        <circle cx="30" cy="30" r="18" fill="#262626" />
        <circle cx="30" cy="30" r="3" fill="#000" />
        <text x="42" y="20" fontSize="8" fill="#999" fontFamily="sans-serif">+</text>
        {hasSignal && (
          <>
            <circle cx="30" cy="30" r="22" fill="none" stroke="#3b82f6" strokeWidth="2" opacity="0.6">
              <animate attributeName="r" from="22" to="32" dur="1.2s" repeatCount="indefinite" />
              <animate attributeName="opacity" from="0.6" to="0" dur="1.2s" repeatCount="indefinite" />
            </circle>
            <circle cx="30" cy="30" r="22" fill="none" stroke="#3b82f6" strokeWidth="2" opacity="0.6">
              <animate attributeName="r" from="22" to="32" dur="1.2s" begin="0.6s" repeatCount="indefinite" />
              <animate attributeName="opacity" from="0.6" to="0" dur="1.2s" begin="0.6s" repeatCount="indefinite" />
            </circle>
          </>
        )}
      </svg>
      {(label || frequency) && (
        <div style={labelStyle}>{label}{frequency ? ` ${frequency}Hz` : ''}</div>
      )}
    </Container>
  );
}

// ── Wokwi7Segment ────────────────────────────────────────────
const SEG7_MAP: Record<string, string> = {
  '0': 'abcdef', '1': 'bc', '2': 'abdeg', '3': 'abcdg', '4': 'bcfg',
  '5': 'acdfg', '6': 'acdefg', '7': 'abc', '8': 'abcdefg', '9': 'abcdfg',
  'A': 'abcefg', 'B': 'cdefg', 'C': 'adef', 'D': 'bcdeg', 'E': 'adefg', 'F': 'aefg',
  '-': 'g', ' ': '',
};

export interface Wokwi7SegmentProps extends CommonProps {
  value?: string;
  dp?: boolean;
  color?: string;
}

export function Wokwi7Segment({ value = '0', dp = false, color = 'red', ...c }: Wokwi7SegmentProps) {
  const ch = (value || '0').slice(0, 1).toUpperCase();
  const segs = SEG7_MAP[ch] ?? '';
  const lit = (s: string) => segs.includes(s) ? color : '#3a3a3a';
  return (
    <Container {...c} defaultWidth={50}>
      <svg viewBox="0 0 50 80" width="100%" aria-label={`7段数码管 ${ch}`} role="img">
        <rect x="2" y="2" width="46" height="76" rx="4" fill="#1a1a1a" stroke="#333" />
        {/* a 上 */} <polygon points="10,8 38,8 34,12 14,12" fill={lit('a')} />
        {/* b 右上 */}<polygon points="40,10 40,36 36,32 36,14" fill={lit('b')} />
        {/* c 右下 */}<polygon points="40,42 40,68 36,64 36,46" fill={lit('c')} />
        {/* d 下 */}<polygon points="14,66 34,66 38,70 10,70" fill={lit('d')} />
        {/* e 左下 */}<polygon points="10,42 14,46 14,64 10,68" fill={lit('e')} />
        {/* f 左上 */}<polygon points="10,10 14,14 14,32 10,36" fill={lit('f')} />
        {/* g 中 */}<polygon points="14,38 36,38 38,40 36,42 14,42 12,40" fill={lit('g')} />
        {/* dp 小数点 */}<circle cx="44" cy="70" r="2.2" fill={dp ? color : '#3a3a3a'} />
      </svg>
    </Container>
  );
}

// ── WokwiPotentiometer ───────────────────────────────────────
export interface WokwiPotentiometerProps extends CommonProps {
  value?: number;
  label?: string;
}

export function WokwiPotentiometer({ value = 50, label = '', ...c }: WokwiPotentiometerProps) {
  const v = Math.max(0, Math.min(100, value));
  // 旋钮转角：-135° 到 +135°（对应 0..100），中点 0°
  const angle = -135 + (v / 100) * 270;
  return (
    <Container {...c} defaultWidth={64}>
      <svg viewBox="0 0 64 64" width="100%" aria-label="电位器" role="img">
        <rect x="6" y="6" width="52" height="52" rx="6" fill="#3b82f6" stroke="#1e3a8a" strokeWidth="1.5" />
        <circle cx="32" cy="32" r="20" fill="#0f172a" stroke="#000" />
        <line x1="32" y1="32" x2={32 + 16 * Math.sin(angle * Math.PI / 180)} y2={32 - 16 * Math.cos(angle * Math.PI / 180)}
              stroke="#fff" strokeWidth="2.5" strokeLinecap="round" />
        <text x="32" y="60" fontSize="7" fill="#fff" textAnchor="middle" fontFamily="sans-serif">{v}%</text>
      </svg>
      {label && <div style={labelStyle}>{label}</div>}
    </Container>
  );
}

// ── WokwiBreadboardMini ──────────────────────────────────────
export interface WokwiBreadboardMiniProps extends CommonProps {
  cols?: number;
  rows?: number;
}

export function WokwiBreadboardMini({ cols = 17, rows = 10, ...c }: WokwiBreadboardMiniProps) {
  const w = 14 + cols * 8;
  const h = 14 + rows * 8;
  const dots: ReactNode[] = [];
  for (let r = 0; r < rows; r++) {
    for (let cc = 0; cc < cols; cc++) {
      dots.push(<circle key={`${r}-${cc}`} cx={11 + cc * 8} cy={11 + r * 8} r="1.6" fill="#1f2937" />);
    }
  }
  return (
    <Container {...c} defaultWidth={Math.max(120, w)}>
      <svg viewBox={`0 0 ${w} ${h}`} width="100%" aria-label="小面包板" role="img">
        <rect x="0" y="0" width={w} height={h} rx="4" fill="#fef3c7" stroke="#d97706" strokeWidth="1.5" />
        {dots}
      </svg>
    </Container>
  );
}

// ── WokwiArduinoUno ──────────────────────────────────────────
export interface WokwiArduinoUnoProps extends CommonProps {
  highlightPin?: string;
  label?: string;
}

const UNO_TOP_PINS = ['SCL', 'SDA', 'AREF', 'GND', '13', '12', '11', '10', '9', '8'];
const UNO_BOTTOM_PINS = ['7', '6', '5', '4', '3', '2', '1', '0', 'A0', 'A1', 'A2', 'A3', 'A4', 'A5'];

export function WokwiArduinoUno({ highlightPin, label = '', ...c }: WokwiArduinoUnoProps) {
  const pinFill = (p: string) => highlightPin === p ? '#fbbf24' : '#94a3b8';
  return (
    <Container {...c} defaultWidth={200}>
      <svg viewBox="0 0 200 110" width="100%" aria-label="Arduino UNO" role="img">
        <rect x="4" y="14" width="192" height="82" rx="4" fill="#0e7c4a" stroke="#0a5a35" strokeWidth="1.5" />
        {/* USB */}<rect x="0" y="22" width="14" height="18" fill="#9ca3af" stroke="#6b7280" />
        {/* DC */}<circle cx="6" cy="64" r="6" fill="#1f2937" />
        {/* MCU */}<rect x="80" y="48" width="40" height="14" fill="#1f2937" rx="1" />
        <text x="100" y="59" fontSize="6" fill="#fff" textAnchor="middle" fontFamily="sans-serif">ATmega328P</text>
        {/* 顶部排针 */}
        {UNO_TOP_PINS.map((p, i) => (
          <g key={`t-${p}`}>
            <rect x={20 + i * 17} y="14" width="14" height="6" fill={pinFill(p)} stroke="#475569" strokeWidth="0.4" />
            <text x={27 + i * 17} y="12" fontSize="4" fill="#fff" textAnchor="middle" fontFamily="sans-serif">{p}</text>
          </g>
        ))}
        {/* 底部排针 */}
        {UNO_BOTTOM_PINS.slice(0, Math.min(11, UNO_BOTTOM_PINS.length)).map((p, i) => (
          <g key={`b-${p}`}>
            <rect x={16 + i * 16} y="90" width="13" height="6" fill={pinFill(p)} stroke="#475569" strokeWidth="0.4" />
            <text x={22 + i * 16} y="106" fontSize="4" fill="#fff" textAnchor="middle" fontFamily="sans-serif">{p}</text>
          </g>
        ))}
        <text x="160" y="56" fontSize="7" fill="#fff" fontFamily="sans-serif" fontWeight="bold">UNO R3</text>
      </svg>
      {label && <div style={labelStyle}>{label}</div>}
    </Container>
  );
}
