/**
 * MathBlock.test.tsx — Iter-34 / T3 单测
 *
 * 覆盖：
 *   1. 渲染 LaTeX 公式到 .dgb-math-formula
 *   2. 显示 title / caption
 *   3. inline 模式加 dgb-math-block--inline class
 *   4. LaTeX 源码错误时降级显示原始源码
 */
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MathBlock } from './MathBlock';

const validBlock = {
  id: 'b-math-1',
  kind: 'math' as const,
  latex: 'V = \\frac{N \\times V_{ref}}{2^{bits}}',
  title: 'ADC 采样分压公式',
  caption: 'N=ADC 读数 / Vref=参考电压 / bits=分辨率位数',
  inline: false,
};

describe('MathBlock', () => {
  it('渲染 LaTeX 到 .dgb-math-formula 容器', () => {
    const { container } = render(<MathBlock block={validBlock} />);
    const formula = container.querySelector('.dgb-math-formula');
    expect(formula).toBeInTheDocument();
    // KaTeX 应渲染为 .katex span
    expect(formula?.innerHTML).toContain('katex');
  });

  it('显示 title 和 caption', () => {
    render(<MathBlock block={validBlock} />);
    expect(screen.getByText('ADC 采样分压公式')).toBeInTheDocument();
    expect(screen.getByText(/N=ADC 读数/)).toBeInTheDocument();
  });

  it('inline=true 时加 dgb-math-block--inline class', () => {
    const inlineBlock = { ...validBlock, inline: true };
    const { container } = render(<MathBlock block={inlineBlock} />);
    const fig = container.querySelector('.dgb-math-block');
    expect(fig).toHaveClass('dgb-math-block--inline');
  });

  it('inline=false 时不加 inline class', () => {
    const { container } = render(<MathBlock block={validBlock} />);
    const fig = container.querySelector('.dgb-math-block');
    expect(fig).not.toHaveClass('dgb-math-block--inline');
  });

  it('无 title 时不渲染 h4', () => {
    const noTitle = { ...validBlock, title: undefined };
    const { container } = render(<MathBlock block={noTitle} />);
    expect(container.querySelector('h4')).toBeNull();
  });

  it('无 caption 时不渲染 figcaption', () => {
    const noCaption = { ...validBlock, caption: undefined };
    const { container } = render(<MathBlock block={noCaption} />);
    expect(container.querySelector('figcaption')).toBeNull();
  });

  it('LaTeX 错误时降级显示原始源码（fallbackOnError=true）', () => {
    const badBlock = {
      ...validBlock,
      latex: '\\frac{1', // 未闭合的 \frac 参数 → KaTeX ParseError
    };
    render(<MathBlock block={badBlock} fallbackOnError={true} />);
    expect(screen.getByText('[KaTeX 渲染失败]')).toBeInTheDocument();
    // 错误源码以 pre 形式展示
    expect(screen.getByText('\\frac{1')).toBeInTheDocument();
  });

  it('data-element-id 正确（用于 spotlight 联动）', () => {
    const { container } = render(<MathBlock block={validBlock} />);
    const fig = container.querySelector('[data-element-id="dgb-block-b-math-1"]');
    expect(fig).toBeInTheDocument();
  });
});
