import './PrincipleCardsBlock.css';
import type { ReactNode } from 'react';

export interface PrincipleItem {
  /** 卡片标题，例如 "正确性原则"。 */
  title: string;
  /** 卡片正文。 */
  content: ReactNode;
  /** 角标数字，默认按数组索引自动填充 ①②③…。 */
  numeral?: string;
}

export interface PrincipleCardsBlockProps {
  /** 可选的章节标题（放在卡片上方）。 */
  heading?: string;
  items: PrincipleItem[];
  /** Iter-40-E · 卡片排版变体（对标 5G 教材"概念解释"5 张横向编号卡）。
   *  - 'auto'（缺省）：v5 自适应 grid（≥260px 一列，2 卡时强制 2 列）
   *  - 'horizontal-numbered'：横向 1 列宽 N 张等高编号卡，N ≤ 5 时强制 N 列，6+ 时回落 auto
   *  与 5G 教材克制视觉对齐：编号 chip 在卡左上、卡内只放标题 + 1 行说明、横向铺满
   */
  layout?: 'auto' | 'horizontal-numbered';
}

const CIRCLED = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨'];

/**
 * 教材风规则/要点并列卡：参考图中"正确性原则 / 规范性原则"双卡版式。
 * 卡片左上角是绿色圆形数字角标，白底 + 绿边 + 绿色标题。
 *
 * Iter-40-E · 加 layout='horizontal-numbered' 变体：
 *   对标 5G 教材"概念解释 · 5 张横向编号卡"克制版式（参见 docs/iter40-visual-target.md）。
 *   horizontal 模式下卡片更窄、padding 更紧凑、editable 数 5 列等高。
 */
export function PrincipleCardsBlock({ heading, items, layout = 'auto' }: PrincipleCardsBlockProps) {
  const horizontal = layout === 'horizontal-numbered' && items.length <= 5;
  const dataCount = horizontal ? items.length : Math.min(items.length, 4);
  return (
    <section className={`dgb-principle-cards${horizontal ? ' dgb-principle-cards--horizontal' : ''}`}>
      {heading && <div className="dgb-principle-heading">{heading}</div>}
      <div
        className="dgb-principle-grid"
        data-count={dataCount}
        data-layout={horizontal ? 'horizontal' : 'auto'}
      >
        {items.map((it, i) => (
          <article key={i} className="dgb-principle-card">
            <div className="dgb-principle-numeral" aria-hidden>
              {it.numeral ?? CIRCLED[i] ?? `${i + 1}`}
            </div>
            <div className="dgb-principle-card-body">
              <h4 className="dgb-principle-card-title">{it.title}</h4>
              <div className="dgb-principle-card-content">{it.content}</div>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
