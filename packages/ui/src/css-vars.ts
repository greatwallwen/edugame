/**
 * tokens → CSS custom properties
 *
 * 用法：
 *   import { cssVarsStyle, cssVar } from '@dgbook/ui';
 *   <div style={cssVarsStyle}>...</div>        // 注入一次（通常在 root）
 *   color: var(--dg-brand-500)                 // 直接在 CSS 中引用
 *
 * 命名规则：`--dg-<group>-<key>`，小写连字符。
 */

import { colors, fonts, layout } from './tokens';

type Dict = Record<string, string | number>;

function flatten(prefix: string, obj: Dict, out: Dict): Dict {
  for (const [k, v] of Object.entries(obj)) {
    const name = `${prefix}-${k}`.toLowerCase();
    if (typeof v === 'object' && v !== null) {
      flatten(name, v as Dict, out);
    } else {
      out[name] = v as string | number;
    }
  }
  return out;
}

const flat = {
  ...flatten('--dg-color', colors as unknown as Dict, {}),
  ...flatten('--dg-font', fonts as unknown as Dict, {}),
  ...flatten('--dg-layout', layout as unknown as Dict, {}),
};

export const cssVars: Record<string, string> = Object.fromEntries(
  Object.entries(flat).map(([k, v]) => [k, typeof v === 'number' ? `${v}px` : String(v)]),
);

/** 已是平键名的 style 对象；消费方可直接铺到 JSX style 上（React 会把 --xxx 视作 var）。 */
export const cssVarsStyle = cssVars;

export function cssVar(name: string): string {
  return `var(${name})`;
}
