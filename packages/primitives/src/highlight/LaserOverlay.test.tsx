/**
 * Phase G3.7 · ADR-0022 (Y) · LaserOverlay 单元测试
 *
 * 验收维度（按 ADR-0022 §2.2 + 对齐文档 §7.2 风险矩阵 Y-R*）：
 *   - 默认（无 Provider）NOOP：组件渲染 null（零成本，ADR-0022 §2.2 不变量 5）
 *   - laser variant 触发：渲染光核 + 光环
 *   - 非 laser variant（spotlight）：不渲染（与 HighlightOverlay 渲染解耦）
 *   - elementId 找不到对应 DOM：返回 null（fail-soft，对齐 spotlight 行为）
 *   - clear() 后：返回 null
 *   - 颜色注入：current.options.glowColor 透传到 CSS 变量
 */
import { act, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import {
  HighlightProvider,
  LaserOverlay,
  useHighlight,
  type HighlightContextValue,
} from '../highlight';

/** 暴露 useHighlight() 给测试体的小桥（与 Shell 中的 HighlightBridge 同思路） */
function ApiBridge({
  apiRef,
}: {
  apiRef: { current: HighlightContextValue | null };
}) {
  apiRef.current = useHighlight();
  return null;
}

function setup() {
  const apiRef: { current: HighlightContextValue | null } = { current: null };
  // 准备一个真实存在的目标 DOM 元素，便于 LaserOverlay 内部 querySelector 命中
  const target = document.createElement('div');
  target.setAttribute('data-element-id', 'dgb-graphics-led');
  Object.assign(target.style, {
    position: 'absolute',
    left: '100px',
    top: '200px',
    width: '40px',
    height: '40px',
  });
  document.body.appendChild(target);
  // jsdom 不会真的算布局，给 getBoundingClientRect 打 stub
  target.getBoundingClientRect = () =>
    ({ left: 100, top: 200, width: 40, height: 40, right: 140, bottom: 240, x: 100, y: 200, toJSON: () => ({}) }) as DOMRect;

  const utils = render(
    <HighlightProvider>
      <ApiBridge apiRef={apiRef} />
      <LaserOverlay />
    </HighlightProvider>
  );
  return { ...utils, apiRef, target };
}

describe('LaserOverlay · Phase G3.7 · ADR-0022 (Y)', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('默认无 current → 不渲染（零成本契约）', () => {
    setup();
    expect(screen.queryByTestId('dgb-laser-overlay')).toBeNull();
  });

  it('non-laser variant（spotlight）→ LaserOverlay 不接管渲染', () => {
    const { apiRef } = setup();
    act(() => {
      apiRef.current?.spotlight({ elementId: 'dgb-graphics-led' });
    });
    expect(screen.queryByTestId('dgb-laser-overlay')).toBeNull();
  });

  it('laser variant + 已存在 target → 渲染光核 + 光环', async () => {
    const { apiRef } = setup();
    act(() => {
      apiRef.current?.laser({ elementId: 'dgb-graphics-led' });
    });
    // armed 在 requestAnimationFrame 第二帧才置 true，但首帧已经渲染 dom，
    // 测试只关心元素存在 + 子节点结构，不关心位移动画。
    const overlay = screen.getByTestId('dgb-laser-overlay');
    expect(overlay).toBeTruthy();
    expect(overlay.querySelector('.dgb-laser-core')).toBeTruthy();
    expect(overlay.querySelector('.dgb-laser-ring')).toBeTruthy();
  });

  it('options.glowColor → 透传到 --dgb-laser-color CSS var', () => {
    const { apiRef } = setup();
    act(() => {
      apiRef.current?.laser({
        elementId: 'dgb-graphics-led',
        options: { glowColor: '#22c55e' },
      });
    });
    const overlay = screen.getByTestId('dgb-laser-overlay') as HTMLElement;
    // 直接读 inline style 拿 CSS var（jsdom 的 getComputedStyle 对 CSS var 支持有限）
    expect(overlay.style.getPropertyValue('--dgb-laser-color')).toBe('#22c55e');
  });

  it('elementId 不存在 → 不渲染（fail-soft）', () => {
    const { apiRef } = setup();
    act(() => {
      apiRef.current?.laser({ elementId: 'dgb-graphics-not-exist' });
    });
    expect(screen.queryByTestId('dgb-laser-overlay')).toBeNull();
  });

  it('laser → clear() → 不渲染', () => {
    const { apiRef } = setup();
    act(() => {
      apiRef.current?.laser({ elementId: 'dgb-graphics-led' });
    });
    expect(screen.getByTestId('dgb-laser-overlay')).toBeTruthy();
    act(() => {
      apiRef.current?.clear();
    });
    expect(screen.queryByTestId('dgb-laser-overlay')).toBeNull();
  });
});
