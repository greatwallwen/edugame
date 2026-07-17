
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import {
  WokwiBuzzer, Wokwi7Segment, WokwiPotentiometer,
  WokwiBreadboardMini, WokwiArduinoUno,
} from '../WokwiExtended';
import { WokwiBlock } from '../WokwiBlock';

describe('Iter-42 D-1 · Wokwi 5 件套扩展', () => {
  it('WokwiBuzzer 渲染 SVG + label + frequency', () => {
    const { container } = render(<WokwiBuzzer label="Buzzer" frequency={2000} hasSignal />);
    expect(container.querySelector('svg')).toBeTruthy();
    expect(container.textContent).toContain('Buzzer');
    expect(container.textContent).toContain('2000Hz');
    // hasSignal 时含 animate 元素（波纹动画）
    expect(container.querySelectorAll('animate').length).toBeGreaterThan(0);
  });

  it('Wokwi7Segment 显示数字 8（全段点亮）', () => {
    const { container } = render(<Wokwi7Segment value="8" color="red" />);
    expect(container.querySelector('svg')).toBeTruthy();
    // 8 的 7 段全亮 + 中段 g：精确 7 个 polygon 着 'red' 色
    const polys = Array.from(container.querySelectorAll('polygon'));
    const litCount = polys.filter((p) => p.getAttribute('fill') === 'red').length;
    expect(litCount).toBe(7);
  });

  it('Wokwi7Segment 显示空格（全段熄）', () => {
    const { container } = render(<Wokwi7Segment value=" " color="green" />);
    const polys = Array.from(container.querySelectorAll('polygon'));
    const litCount = polys.filter((p) => p.getAttribute('fill') === 'green').length;
    expect(litCount).toBe(0);
  });

  it('Wokwi7Segment dp=true 时小数点亮', () => {
    const { container } = render(<Wokwi7Segment value="0" dp color="blue" />);
    // 找小数点 circle（fill 等于 color）
    const dpCircle = Array.from(container.querySelectorAll('circle')).find(
      (el) => el.getAttribute('fill') === 'blue'
    );
    expect(dpCircle).toBeTruthy();
  });

  it('WokwiPotentiometer 显示 value%', () => {
    const { container } = render(<WokwiPotentiometer value={75} label="VR1" />);
    expect(container.textContent).toContain('75%');
    expect(container.textContent).toContain('VR1');
  });

  it('WokwiPotentiometer value 越界自动 clamp 0..100', () => {
    const { container: c1 } = render(<WokwiPotentiometer value={150} />);
    expect(c1.textContent).toContain('100%');
    const { container: c2 } = render(<WokwiPotentiometer value={-20} />);
    expect(c2.textContent).toContain('0%');
  });

  it('WokwiBreadboardMini 渲染 cols × rows 个孔', () => {
    const { container } = render(<WokwiBreadboardMini cols={5} rows={4} />);
    // 每个孔是一个 circle，r=1.6
    const dots = Array.from(container.querySelectorAll('circle')).filter(
      (c) => c.getAttribute('r') === '1.6'
    );
    expect(dots.length).toBe(20);
  });

  it('WokwiArduinoUno highlightPin 引脚高亮', () => {
    const { container } = render(<WokwiArduinoUno highlightPin="13" label="UNO" />);
    expect(container.textContent).toContain('UNO R3');
    expect(container.textContent).toContain('UNO');
    // 找到 13 引脚附近的 rect 应该是金色 #fbbf24
    const rects = Array.from(container.querySelectorAll('rect'));
    const lit = rects.find((r) => r.getAttribute('fill') === '#fbbf24');
    expect(lit).toBeTruthy();
  });

  it('WokwiBlock dispatcher 路由到 buzzer / 7segment / potentiometer / breadboard / arduino-uno', () => {
    const cases: { kind: string; spec: Record<string, unknown> }[] = [
      { kind: 'buzzer', spec: { kind: 'buzzer', frequency: 1000 } },
      { kind: '7segment', spec: { kind: '7segment', value: '5' } },
      { kind: 'potentiometer', spec: { kind: 'potentiometer', value: 30 } },
      { kind: 'breadboard-mini', spec: { kind: 'breadboard-mini', cols: 10, rows: 5 } },
      { kind: 'arduino-uno', spec: { kind: 'arduino-uno', highlightPin: 'A0' } },
    ];
    for (const tc of cases) {
      const { container } = render(
        <WokwiBlock blockId={`b-${tc.kind}`} spec={tc.spec as never} />
      );
      expect(container.querySelector('svg'), `kind=${tc.kind} 应渲染 svg`).toBeTruthy();
      // 顶层 figure 含 data-element-id="dgb-wokwi-{blockId}"
      const fig = container.querySelector('[data-block-id]');
      expect(fig?.getAttribute('data-block-id')).toBe(`b-${tc.kind}`);
    }
  });
});
