/**
 * MathBlock — KaTeX 数学公式块（Iter-34 / T3，Iter-33 阶段二识别的缺口）
 *
 * 用途：嵌入式 / 物理 / 数学课程的核心公式专区。
 *   嵌入式典型：ADC 分压 V = (N × Vref) / 2^bits
 *              定时器频率 f_TIM = f_clk / ((PSC+1) × (ARR+1))
 *
 * 与 text 内 markdown 数学的差异：
 *   - text 是文本流里的小公式
 *   - MathBlock 是块级独立公式（display 模式）+ 标题 + 解释 caption
 *
 * 渲染策略：
 *   - 同步用 katex.renderToString → innerHTML（依赖 katex CSS 全局加载）
 *   - 不引入 react-katex 包装层（避免无谓重渲）
 *
 * 注：调用方需自行加载 katex CSS（例如在 player main.tsx 引入
 *     'katex/dist/katex.min.css'），本组件不内嵌避免重复样式。
 */
import { useMemo } from 'react';
import katex from 'katex';
import type { MathBlock as MathBlockSpec } from '@dgbook/types';
import './MathBlock.css';

export interface MathBlockProps {
  block: MathBlockSpec;
  /** 是否启用错误边界（渲染失败时显示原始 LaTeX 源码 + 红色提示）*/
  fallbackOnError?: boolean;
}

export function MathBlock({ block, fallbackOnError = true }: MathBlockProps) {
  const { html, error } = useMemo(() => {
    try {
      const rendered = katex.renderToString(block.latex, {
        displayMode: !block.inline,
        // 永远抛错由我们 catch；用户端用 fallbackOnError 决定是否降级 UI
        throwOnError: true,
        strict: 'warn',
        trust: false,
        output: 'html',
      });
      return { html: rendered, error: null as string | null };
    } catch (e) {
      if (!fallbackOnError) throw e;
      const msg = e instanceof Error ? e.message : String(e);
      return { html: null, error: msg };
    }
  }, [block.latex, block.inline, fallbackOnError]);

  if (error) {
    return (
      <div className="dgb-math-block dgb-math-block--error" data-testid="math-block-error">
        <div className="dgb-math-error-label">[KaTeX 渲染失败]</div>
        <pre className="dgb-math-error-source">{block.latex}</pre>
        <div className="dgb-math-error-msg">{error}</div>
      </div>
    );
  }

  return (
    <figure
      className={`dgb-math-block${block.inline ? ' dgb-math-block--inline' : ''}`}
      data-testid="math-block"
      data-element-id={`dgb-block-${block.id}`}
    >
      {block.title && <h4 className="dgb-math-title">{block.title}</h4>}
      <div className="dgb-math-formula" dangerouslySetInnerHTML={{ __html: html ?? '' }} />
      {block.caption && <figcaption className="dgb-math-caption">{block.caption}</figcaption>}
    </figure>
  );
}
