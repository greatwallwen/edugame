import './CalloutBlock.css';
import type { ReactNode } from 'react';

export type CalloutKind = 'intro' | 'wrapup' | 'tip' | 'warning';

export interface CalloutBlockProps {
  kind?: CalloutKind;
  title?: string;
  /** Iter-40-E · 嵌套白卡子标题（对标 5G 教材"重点"蓝框内套"导学摘要"白卡）。
   *  非空时，正文外多套一层白底子卡片：上方 subtitle 行 + 下方 children。
   *  缺省时退回 v5 单层版式（直接渲染 children），与旧调用完全兼容。 */
  subtitle?: string;
  children: ReactNode;
  /** 覆盖默认图标。 */
  icon?: ReactNode;
}

const DEFAULT_TITLE: Record<CalloutKind, string> = {
  intro: '导读',
  wrapup: '课堂收束',
  tip: '小贴士',
  warning: '注意',
};

function DefaultIcon({ kind }: { kind: CalloutKind }) {
  // 线稿 SVG，与参考图一致的细描边；不使用实心 emoji
  if (kind === 'wrapup' || kind === 'tip') {
    return (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
        <path d="M9 18h6" />
        <path d="M10 22h4" />
        <path d="M12 2a7 7 0 0 0-4 12.7c.6.6 1 1.5 1 2.3h6c0-.8.4-1.7 1-2.3A7 7 0 0 0 12 2z" />
      </svg>
    );
  }
  if (kind === 'warning') {
    return (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
        <path d="M10.3 3.9 2.7 17a2 2 0 0 0 1.7 3h15.2a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z" />
        <line x1="12" y1="9" x2="12" y2="13" />
        <line x1="12" y1="17" x2="12.01" y2="17" />
      </svg>
    );
  }
  // intro：书本
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    </svg>
  );
}

/**
 * 教材风"导读 / 课堂收束 / 小贴士"通用提示卡。
 * 左侧线稿图标 + 右侧标题 + 段落正文，浅色卡片 + 绿边。
 */
export function CalloutBlock({ kind = 'intro', title, subtitle, children, icon }: CalloutBlockProps) {
  return (
    <aside className={`dgb-callout dgb-callout--${kind}${subtitle ? ' dgb-callout--has-subtitle' : ''}`}>
      <div className="dgb-callout-icon" aria-hidden>
        {icon ?? <DefaultIcon kind={kind} />}
      </div>
      <div className="dgb-callout-body">
        <div className="dgb-callout-title">{title ?? DEFAULT_TITLE[kind]}</div>
        {subtitle ? (
          <div className="dgb-callout-subcard">
            <div className="dgb-callout-subtitle">{subtitle}</div>
            <div className="dgb-callout-content">{children}</div>
          </div>
        ) : (
          <div className="dgb-callout-content">{children}</div>
        )}
      </div>
    </aside>
  );
}
