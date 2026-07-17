import './InfoTableBlock.css';
import type { ReactNode } from 'react';

export interface InfoTableRow {
  /** 行左侧的 pill 标签文本，例如 "任务背景" / "任务目标" / "知识要点"。 */
  label: string;
  /** 行正文（支持富文本节点或简单字符串）。 */
  value: ReactNode;
  /** pill 色调。默认走主色，可指定 warm / neutral 以区分语义。 */
  tone?: 'primary' | 'warm' | 'neutral';
  /** 可选小图标（React 节点，建议 14×14 的 SVG）。 */
  icon?: ReactNode;
}

export interface InfoTableBlockProps {
  title?: string;
  rows: InfoTableRow[];
  /** 放在表格顶部的一段说明性文字（可选）。 */
  intro?: string;
}

/**
 * 教材风"任务描述"表格：
 * 每行左列是圆角 pill 标签，右列是长段文字。
 * 对齐参考图"任务背景 / 任务目标 / 知识要点"版式。
 */
export function InfoTableBlock({ title, rows, intro }: InfoTableBlockProps) {
  return (
    <section className="dgb-info-table">
      {title && <div className="dgb-info-table-title">{title}</div>}
      {intro && <p className="dgb-info-table-intro">{intro}</p>}
      <dl className="dgb-info-table-list">
        {rows.map((row, i) => (
          <div
            key={i}
            className={`dgb-info-table-row dgb-info-table-row--${row.tone ?? 'primary'}`}
          >
            <dt className="dgb-info-table-label">
              {row.icon && <span className="dgb-info-table-icon" aria-hidden>{row.icon}</span>}
              <span>{row.label}</span>
            </dt>
            <dd className="dgb-info-table-value">{row.value}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
