
import type { CSSProperties } from 'react';

const bandColors: Record<number, string> = {
  [-2]: '#C3C7C0', // Silver
  [-1]: '#F1D863', // Gold
  0: '#000000',
  1: '#8F4814',
  2: '#FB0000',
  3: '#FC9700',
  4: '#FCF800',
  5: '#00B800',
  6: '#0000FF',
  7: '#A803D6',
  8: '#808080',
  9: '#FCFCFC',
};

export interface WokwiResistorProps {
  /** 电阻值（Ω）：可传字符串或数字 */
  value?: string | number;
  /** 显示标签（外部 caption；本组件不内置 label，与 wokwi-resistor 自定义元素一致） */
  className?: string;
  /** Phase G3 · 让 ActionRunner 能高亮 */
  'data-element-id'?: string;
}

function breakValue(value: number): [number, number] {
  if (value === 0) return [0, 0];
  const exponent =
    value >= 1e10 ? 9
    : value >= 1e9 ? 8
    : value >= 1e8 ? 7
    : value >= 1e7 ? 6
    : value >= 1e6 ? 5
    : value >= 1e5 ? 4
    : value >= 1e4 ? 3
    : value >= 1e3 ? 2
    : value >= 1e2 ? 1
    : value >= 1e1 ? 0
    : value >= 1 ? -1
    : -2;
  const base = Math.round(value / 10 ** exponent);
  return [Math.round(base % 100), exponent];
}

const containerStyle: CSSProperties = { display: 'inline-block' };

const BODY_PATH =
  'm4.6918 0c-1.0586 0-1.9185 0.67468-1.9185 1.5022 0 0.82756 0.85995 1.4978 1.9185 1.4978 0.4241 0 0.81356-0.11167 1.1312-0.29411h4.0949c0.31802 0.18313 0.71075 0.29411 1.1357 0.29411 1.0586 0 1.9185-0.67015 1.9185-1.4978 0-0.8276-0.85995-1.5022-1.9185-1.5022-0.42499 0-0.81773 0.11098-1.1357 0.29411h-4.0949c-0.31765-0.18244-0.7071-0.29411-1.1312-0.29411z';

export function WokwiResistor({
  value = '1000',
  className,
  ...rest
}: WokwiResistorProps) {
  const numValue = typeof value === 'number' ? value : parseFloat(value);
  const safe = Number.isFinite(numValue) && numValue >= 0 ? numValue : 0;
  const [base, exponent] = breakValue(safe);
  const band1Color = bandColors[Math.floor(base / 10)] ?? '#000000';
  const band2Color = bandColors[base % 10] ?? '#000000';
  const band3Color = bandColors[exponent] ?? '#000000';

  return (
    <span
      className={className}
      style={containerStyle}
      data-element-id={rest['data-element-id']}
      data-wokwi-kind="resistor"
    >
      <svg
        width="62"
        height="12"
        version="1.1"
        viewBox="0 0 15.645 3"
        xmlns="http://www.w3.org/2000/svg"
        aria-label={`${safe}Ω resistor`}
        role="img"
      >
        <defs>
          <linearGradient
            id="dgb-wokwi-resistor-grad"
            x2="0"
            y1="22.332"
            y2="38.348"
            gradientTransform="matrix(.14479 0 0 .14479 -23.155 -4.0573)"
            gradientUnits="userSpaceOnUse"
            spreadMethod="reflect"
          >
            <stop stopColor="#323232" offset="0" />
            <stop stopColor="#fff" stopOpacity=".42268" offset="1" />
          </linearGradient>
          <clipPath id="dgb-wokwi-resistor-clip">
            <path d={BODY_PATH} />
          </clipPath>
        </defs>
        <rect y="1.1759" width="15.558" height=".63826" fill="#aaa" />
        <g strokeWidth=".14479" fill="#d5b597">
          <path d={BODY_PATH} />
          <path d={BODY_PATH} fill="url(#dgb-wokwi-resistor-grad)" opacity=".44886" />
          <rect
            x="4"
            y="0"
            width="1"
            height="3"
            fill={band1Color}
            clipPath="url(#dgb-wokwi-resistor-clip)"
          />
          <path d="m6 0.29411v2.4117h0.96v-2.4117z" fill={band2Color} />
          <path d="m7.8 0.29411v2.4117h0.96v-2.4117z" fill={band3Color} />
          <rect
            x="10.69"
            y="0"
            width="1"
            height="3"
            fill="#F1D863"
            clipPath="url(#dgb-wokwi-resistor-clip)"
          />
        </g>
      </svg>
    </span>
  );
}
