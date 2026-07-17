import './FigurePairBlock.css';
import type { ReactNode } from 'react';

export interface FigureItem {
  /** 题注编号，例如 "图1-1"。 */
  no?: string;
  /** 题注文字，例如 "连接示意图"。 */
  caption?: string;
  /** 图片 URL；若同时提供 slot 则优先渲染 slot。 */
  src?: string;
  /** 自定义媒体节点（SVG / iframe / react-children），用于放动画或代码截图等。 */
  slot?: ReactNode;
  /** 图片替代文字。 */
  alt?: string;
}

export interface FigurePairBlockProps {
  items: [FigureItem] | [FigureItem, FigureItem];
}

/**
 * 教材风"原理图 + 实物图"并列卡：
 * - 左右两张 figure 卡片，各自 media + caption
 * - 支持 1 图或 2 图模式
 * - slot 优先级高于 src，用于放动画 iframe / 代码块 / 自定义组件
 */
export function FigurePairBlock({ items }: FigurePairBlockProps) {
  return (
    <div className="dgb-figure-pair" data-count={items.length}>
      {items.map((fig, i) => (
        <figure key={i} className="dgb-figure-pair-item">
          <div className="dgb-figure-pair-media">
            {fig.slot ? (
              <div className="dgb-figure-pair-slot">{fig.slot}</div>
            ) : fig.src ? (
              <img src={fig.src} alt={fig.alt ?? fig.caption ?? ''} loading="lazy" />
            ) : null}
          </div>
          {(fig.no || fig.caption) && (
            <figcaption className="dgb-figure-pair-caption">
              {fig.no && <span className="dgb-figure-pair-caption-no">{fig.no}</span>}
              <span className="dgb-figure-pair-caption-text">{fig.caption}</span>
            </figcaption>
          )}
        </figure>
      ))}
    </div>
  );
}
