
import { describe, it, expect } from 'vitest';
import { render, fireEvent } from '@testing-library/react';
import { WokwiLED } from '../WokwiLED';
import { WokwiResistor } from '../WokwiResistor';
import { WokwiPushbutton } from '../WokwiPushbutton';
import { WokwiBlock } from '../WokwiBlock';

describe('WokwiLED · SVG 渲染', () => {
  it('默认关灯：渲染 svg 但不含发光层', () => {
    const { container } = render(<WokwiLED color="red" />);
    const svg = container.querySelector('svg');
    expect(svg).not.toBeNull();
    expect(container.querySelector('.dgb-wokwi-led-light')).toBeNull();
  });

  it('value=true 时出现发光层 ellipse', () => {
    const { container } = render(<WokwiLED color="green" value={true} />);
    const lightLayer = container.querySelector('.dgb-wokwi-led-light');
    expect(lightLayer).not.toBeNull();
    // 发光层包含 3 个 ellipse（外层光晕 / 中心点 / 中层）
    expect(lightLayer?.querySelectorAll('ellipse').length).toBe(3);
  });

  it('label 不为空时渲染文字', () => {
    const { getByText } = render(<WokwiLED label="LED1" />);
    expect(getByText('LED1')).toBeTruthy();
  });

  it('未知 color 走 fallback：lightColor 等于 color 字符串本身', () => {
    const { container } = render(<WokwiLED color="#ff00aa" value={true} />);
    const ellipses = container.querySelectorAll('.dgb-wokwi-led-light ellipse');
    // 第 0 个外层 ellipse 的 fill 应为 #ff00aa（lightColors 表查不到时 fallback）
    expect(ellipses[0]?.getAttribute('fill')).toBe('#ff00aa');
  });
});

describe('WokwiResistor · 色环计算', () => {
  it('1000Ω = 棕(1) + 黑(0) + 红(2 = 10^2 倍率)', () => {
    const { container } = render(<WokwiResistor value="1000" />);
    // base=10, exponent=2 → band1=#8F4814（rect）, band2=#000000（path）, band3=#FB0000（path）
    const colored = container.querySelectorAll('svg path[fill], svg rect[fill]');
    const fills = Array.from(colored).map((p) => p.getAttribute('fill'));
    expect(fills).toContain('#8F4814'); // band1 棕
    expect(fills).toContain('#000000'); // band2 黑
    expect(fills).toContain('#FB0000'); // band3 红
  });

  it('220Ω = 红(2) + 红(2) + 棕(1 = 10^1 倍率)', () => {
    const { container } = render(<WokwiResistor value="220" />);
    const colored = container.querySelectorAll('svg path[fill], svg rect[fill]');
    const fills = Array.from(colored).map((p) => p.getAttribute('fill'));
    // band1（rect）+ band2（path）都是红 #FB0000
    expect(fills.filter((f) => f === '#FB0000').length).toBeGreaterThanOrEqual(2);
    // band3 = 棕（10^1）
    expect(fills).toContain('#8F4814');
  });

  it('value 为数字也能正确解析', () => {
    const { container } = render(<WokwiResistor value={4700} />);
    const svg = container.querySelector('svg');
    expect(svg?.getAttribute('aria-label')).toBe('4700Ω resistor');
  });
});

describe('WokwiPushbutton · 交互', () => {
  it('默认 aria-pressed=false', () => {
    const { container } = render(<WokwiPushbutton color="red" label="K1" />);
    const btn = container.querySelector('button');
    expect(btn?.getAttribute('aria-pressed')).toBe('false');
  });

  it('pointer down 后 aria-pressed=true（非受控模式）', () => {
    const { container } = render(<WokwiPushbutton color="blue" />);
    const btn = container.querySelector('button')!;
    fireEvent.pointerDown(btn);
    expect(btn.getAttribute('aria-pressed')).toBe('true');
    fireEvent.pointerUp(btn);
    expect(btn.getAttribute('aria-pressed')).toBe('false');
  });

  it('受控模式：pressed prop 决定状态，pointer 不改变', () => {
    const { container, rerender } = render(<WokwiPushbutton pressed={true} />);
    const btn = container.querySelector('button')!;
    expect(btn.getAttribute('aria-pressed')).toBe('true');
    fireEvent.pointerUp(btn);
    expect(btn.getAttribute('aria-pressed')).toBe('true');
    rerender(<WokwiPushbutton pressed={false} />);
    expect(btn.getAttribute('aria-pressed')).toBe('false');
  });
});

describe('WokwiBlock · 分发器 + G3 协议', () => {
  it('spec.kind=led 时渲染 WokwiLED + 注入 data-element-id', () => {
    const { container } = render(
      <WokwiBlock blockId="b1" spec={{ kind: 'led', color: 'red', value: true }} caption="状态指示灯" />,
    );
    const span = container.querySelector('[data-wokwi-kind="led"]');
    expect(span).not.toBeNull();
    expect(span?.getAttribute('data-element-id')).toBe('dgb-wokwi-b1');
    expect(container.textContent).toContain('状态指示灯');
  });

  it('spec.kind=resistor 时渲染 WokwiResistor', () => {
    const { container } = render(
      <WokwiBlock blockId="r1" spec={{ kind: 'resistor', value: '4700' }} title="限流电阻" />,
    );
    expect(container.querySelector('[data-wokwi-kind="resistor"]')).not.toBeNull();
    expect(container.textContent).toContain('限流电阻');
  });

  it('spec.kind=pushbutton 时渲染 WokwiPushbutton', () => {
    const { container } = render(
      <WokwiBlock blockId="k1" spec={{ kind: 'pushbutton', color: 'green', label: 'KEY1' }} />,
    );
    expect(container.querySelector('[data-wokwi-kind="pushbutton"]')).not.toBeNull();
  });
});
