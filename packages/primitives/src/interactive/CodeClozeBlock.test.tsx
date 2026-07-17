/**
 * CodeClozeBlock.test.tsx — Iter-34 / T-CD 单测
 *
 * 覆盖：
 *   1. 模板按 {{blank-id}} 切片渲染（多 blank 在不同位置）
 *   2. 输入校验 normalized（去首尾空格）
 *   3. 输入校验 exact（严格相等）
 *   4. 多答案接受（accepted 数组）
 *   5. 提交后展示对错反馈
 *   6. onAnswer 回调正确触发（correct + score）
 *   7. 重做按钮重置状态
 */
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { CodeClozeBlock } from './CodeClozeBlock';

const normalizedSpec = {
  kind: 'code-cloze' as const,
  prompt: '填写 GPIO 写引脚 API',
  language: 'c' as const,
  template: 'HAL_GPIO_WritePin({{port}}, {{pin}}, {{state}});',
  blanks: [
    { id: 'port', accepted: ['GPIOA', 'GPIOB'] },
    { id: 'pin', accepted: ['GPIO_PIN_5'] },
    { id: 'state', accepted: ['GPIO_PIN_SET', 'GPIO_PIN_RESET', '1', '0'] },
  ],
  validate: 'normalized' as const,
};

describe('CodeClozeBlock', () => {
  it('按 {{blank-id}} 切片渲染 3 个 input', () => {
    render(<CodeClozeBlock spec={normalizedSpec} />);
    const inputs = screen.getAllByRole('textbox');
    expect(inputs).toHaveLength(3);
    expect(inputs[0]!).toHaveAttribute('data-blank-id', 'port');
    expect(inputs[1]!).toHaveAttribute('data-blank-id', 'pin');
    expect(inputs[2]!).toHaveAttribute('data-blank-id', 'state');
  });

  it('显示 prompt', () => {
    render(<CodeClozeBlock spec={normalizedSpec} />);
    expect(screen.getByText('填写 GPIO 写引脚 API')).toBeInTheDocument();
  });

  it('全填后提交按钮可点，未填时禁用', () => {
    render(<CodeClozeBlock spec={normalizedSpec} />);
    const submit = screen.getByRole('button', { name: '提交' });
    expect(submit).toBeDisabled();

    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0]!, { target: { value: 'GPIOA' } });
    fireEvent.change(inputs[1]!, { target: { value: 'GPIO_PIN_5' } });
    fireEvent.change(inputs[2]!, { target: { value: 'GPIO_PIN_SET' } });
    expect(submit).not.toBeDisabled();
  });

  it('全对时 onAnswer(true, 100)', () => {
    const onAnswer = vi.fn();
    render(<CodeClozeBlock spec={normalizedSpec} onAnswer={onAnswer} />);
    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0]!, { target: { value: 'GPIOA' } });
    fireEvent.change(inputs[1]!, { target: { value: 'GPIO_PIN_5' } });
    fireEvent.change(inputs[2]!, { target: { value: 'GPIO_PIN_SET' } });
    fireEvent.click(screen.getByRole('button', { name: '提交' }));
    expect(onAnswer).toHaveBeenCalledWith(true, 100);
  });

  it('部分对时 score 为答对比例 × 100', () => {
    const onAnswer = vi.fn();
    render(<CodeClozeBlock spec={normalizedSpec} onAnswer={onAnswer} />);
    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0]!, { target: { value: 'GPIOA' } });        // 对
    fireEvent.change(inputs[1]!, { target: { value: 'WRONG' } });        // 错
    fireEvent.change(inputs[2]!, { target: { value: 'GPIO_PIN_SET' } }); // 对
    fireEvent.click(screen.getByRole('button', { name: '提交' }));
    expect(onAnswer).toHaveBeenCalledWith(false, 67); // 2/3 = 66.67 → 67
  });

  it('normalized 校验去首尾空格', () => {
    const onAnswer = vi.fn();
    render(<CodeClozeBlock spec={normalizedSpec} onAnswer={onAnswer} />);
    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0]!, { target: { value: '  GPIOA  ' } });
    fireEvent.change(inputs[1]!, { target: { value: 'GPIO_PIN_5' } });
    fireEvent.change(inputs[2]!, { target: { value: '\tGPIO_PIN_SET\n' } });
    fireEvent.click(screen.getByRole('button', { name: '提交' }));
    expect(onAnswer).toHaveBeenCalledWith(true, 100);
  });

  it('exact 校验严格相等（带空格判错）', () => {
    const onAnswer = vi.fn();
    const exactSpec = { ...normalizedSpec, validate: 'exact' as const };
    render(<CodeClozeBlock spec={exactSpec} onAnswer={onAnswer} />);
    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0]!, { target: { value: ' GPIOA' } });  // 带前导空格 → 错
    fireEvent.change(inputs[1]!, { target: { value: 'GPIO_PIN_5' } });
    fireEvent.change(inputs[2]!, { target: { value: 'GPIO_PIN_SET' } });
    fireEvent.click(screen.getByRole('button', { name: '提交' }));
    expect(onAnswer).toHaveBeenCalledWith(false, 67);
  });

  it('多答案接受（任一 accepted 命中即对）', () => {
    const onAnswer = vi.fn();
    render(<CodeClozeBlock spec={normalizedSpec} onAnswer={onAnswer} />);
    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0]!, { target: { value: 'GPIOB' } });        // 第二个 accepted
    fireEvent.change(inputs[1]!, { target: { value: 'GPIO_PIN_5' } });
    fireEvent.change(inputs[2]!, { target: { value: '0' } });            // 第四个 accepted
    fireEvent.click(screen.getByRole('button', { name: '提交' }));
    expect(onAnswer).toHaveBeenCalledWith(true, 100);
  });

  it('提交后展示对错反馈 li', () => {
    render(<CodeClozeBlock spec={normalizedSpec} />);
    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0]!, { target: { value: 'GPIOA' } });
    fireEvent.change(inputs[1]!, { target: { value: 'WRONG' } });
    fireEvent.change(inputs[2]!, { target: { value: 'GPIO_PIN_SET' } });
    fireEvent.click(screen.getByRole('button', { name: '提交' }));
    // 错误项显示正确答案
    expect(screen.getByText(/正确答案：GPIO_PIN_5/)).toBeInTheDocument();
  });

  it('重做按钮重置状态', () => {
    render(<CodeClozeBlock spec={normalizedSpec} />);
    const inputs = screen.getAllByRole('textbox');
    fireEvent.change(inputs[0]!, { target: { value: 'GPIOA' } });
    fireEvent.change(inputs[1]!, { target: { value: 'GPIO_PIN_5' } });
    fireEvent.change(inputs[2]!, { target: { value: 'GPIO_PIN_SET' } });
    fireEvent.click(screen.getByRole('button', { name: '提交' }));
    fireEvent.click(screen.getByRole('button', { name: '重做' }));
    // 重置后 input 值清空，提交按钮重新出现
    const inputsAfter = screen.getAllByRole('textbox');
    expect(inputsAfter[0]!).toHaveValue('');
    expect(screen.getByRole('button', { name: '提交' })).toBeInTheDocument();
  });
});
