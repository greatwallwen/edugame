/**
 * BitFlipBlock 单测 — Iter-41-A
 *
 * 覆盖：
 *  1. 渲染 8 个 bit cell（高位 bit7 在左，低位 bit0 在右）
 *  2. 初始值正确显示（is-on / is-off 对应 bit）
 *  3. 点击 bit toggle 后值变化正确
 *  4. 提交后判定结果（correct → 100 分，wrong → 0 分）
 *  5. 显示 hex / bin 当前值
 *  6. submitted 后按钮 disabled
 */
import { describe, it, expect, vi } from 'vitest';
import { render, fireEvent, screen } from '@testing-library/react';
import { BitFlipBlock } from '../BitFlipBlock';

const baseSpec = {
  kind: 'bit-flip' as const,
  prompt: '把 PA5 拉高（bit5 = 1）',
  registerName: 'GPIOA->ODR',
  initial: 0,
  target: 0x20, // 0b00100000
  explanation: 'PA5 对应 bit5，OR (1<<5) = 0x20',
};

describe('BitFlipBlock · 寄存器位操作', () => {
  it('渲染 8 个 bit cell + prompt + register name', () => {
    render(<BitFlipBlock spec={baseSpec} />);
    // 8 个 bit cell（按钮）
    const cells = screen.getAllByRole('button').filter((b) =>
      b.className.includes('dgb-bitflip__cell'),
    );
    expect(cells.length).toBe(8);
    // prompt
    expect(screen.getByText(/把 PA5 拉高/)).toBeTruthy();
    // register name
    expect(screen.getByText('GPIOA->ODR')).toBeTruthy();
  });

  it('initial=0 时所有 cell is-off', () => {
    const { container } = render(<BitFlipBlock spec={baseSpec} />);
    const onCells = container.querySelectorAll('.dgb-bitflip__cell.is-on');
    expect(onCells.length).toBe(0);
  });

  it('点击 bit5 cell 后值变成 0x20，匹配 target', () => {
    const { container } = render(<BitFlipBlock spec={baseSpec} />);
    // bit cell 排列：left to right [bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0]
    // 即第 3 个（index 2）是 bit5
    const cells = container.querySelectorAll('.dgb-bitflip__cell');
    fireEvent.click(cells[2]!); // bit5
    // 当前值应该是 0x20
    expect(container.textContent).toContain('0x20');
    // bit5 cell 应 is-on
    expect(cells[2]?.className).toContain('is-on');
  });

  it('提交正确答案触发 onAnswer(true, 100)', () => {
    const onAnswer = vi.fn();
    const { container, getByText } = render(
      <BitFlipBlock spec={baseSpec} onAnswer={onAnswer} />,
    );
    const cells = container.querySelectorAll('.dgb-bitflip__cell');
    fireEvent.click(cells[2]!); // bit5 → 0x20
    fireEvent.click(getByText('提交'));
    expect(onAnswer).toHaveBeenCalledWith(true, 100);
    // 反馈文字
    expect(container.textContent).toContain('正确');
  });

  it('提交错误答案触发 onAnswer(false, 0) + 显示目标值', () => {
    const onAnswer = vi.fn();
    const { container, getByText } = render(
      <BitFlipBlock spec={baseSpec} onAnswer={onAnswer} />,
    );
    fireEvent.click(getByText('提交')); // 不切任何 bit → value=0 ≠ target=0x20
    expect(onAnswer).toHaveBeenCalledWith(false, 0);
    expect(container.textContent).toContain('不对');
    // 显示目标
    expect(container.textContent).toContain('0x20');
  });

  it('提交后 cell disabled，重做后恢复', () => {
    const { container, getByText } = render(<BitFlipBlock spec={baseSpec} />);
    fireEvent.click(getByText('提交'));
    const cells = container.querySelectorAll('.dgb-bitflip__cell');
    cells.forEach((c) => expect(c.hasAttribute('disabled')).toBe(true));
    // 重做按钮出现
    fireEvent.click(getByText('重做'));
    cells.forEach((c) => expect(c.hasAttribute('disabled')).toBe(false));
  });

  it('差异计数：value=0 / target=0x20 时显示"差 1 位"', () => {
    const { container } = render(<BitFlipBlock spec={baseSpec} />);
    // 初始 0，target 0x20，差 1 位
    expect(container.textContent).toContain('差 1 位');
  });
});
