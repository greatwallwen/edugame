/**
 * Phase G3.4 · HighlightController
 *
 * 统一的"按 elementId 朗读高亮"入口。设计要点：
 *   - React Context，无外部状态库（不引入 zustand，避免 OpenMAIC 强耦合）
 *   - 选择器统一走 [data-element-id="dgb-{kind}-{id}"]
 *   - 当前只暴露 spotlight / glow / pulse / clear 四个原语，未来再扩
 *   - Overlay 自身负责 DOM 测量；本控制器只管"当前高亮目标"语义
 */
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';

// Phase G3.7 · ADR-0022 (Y) · 在既有三 variant 之上新增 'laser'。
//   - laser 由 LaserOverlay 单独消费（不进 HighlightOverlay），保持渲染解耦
//   - 与 spotlight/glow/pulse 是互斥变体；切换 variant = 切换覆盖层
export type HighlightVariant = 'spotlight' | 'glow' | 'pulse' | 'laser';

export interface HighlightOptions {
  /** spotlight 周边遮罩颜色（默认 rgba(0,0,0,0.55)） */
  color?: string;
  /** spotlight dim 强度，0~1（默认 0.55） */
  dimness?: number;
  /** 自动清除时间，0 / undefined 表示不自动清除 */
  durationMs?: number;
  /** glow / pulse 主色（默认 #ffd166） */
  glowColor?: string;
}

export interface HighlightTarget {
  /** 目标 element id，对应 [data-element-id="dgb-{kind}-{id}"] */
  elementId: string;
  variant?: HighlightVariant;
  options?: HighlightOptions;
}

export interface HighlightContextValue {
  current: HighlightTarget | null;
  spotlight: (target: Omit<HighlightTarget, 'variant'> & { variant?: 'spotlight' }) => void;
  glow: (target: Omit<HighlightTarget, 'variant'> & { variant?: 'glow' }) => void;
  pulse: (target: Omit<HighlightTarget, 'variant'> & { variant?: 'pulse' }) => void;
  /** Phase G3.7 · ADR-0022 (Y) · 激光指引（飞入轨迹 + 呼吸光环），LaserOverlay 单独消费 */
  laser: (target: Omit<HighlightTarget, 'variant'> & { variant?: 'laser' }) => void;
  show: (target: HighlightTarget) => void;
  clear: () => void;
}

const HighlightContext = createContext<HighlightContextValue | null>(null);

/** 顶层 Provider。Shell.tsx / 嵌入式 <DGBookPlayer /> 外层包裹一次即可。 */
export function HighlightProvider({ children }: { children: ReactNode }) {
  const [current, setCurrent] = useState<HighlightTarget | null>(null);
  const timerRef = useRef<number | null>(null);

  const clearTimer = useCallback(() => {
    if (timerRef.current != null) {
      window.clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const clear = useCallback(() => {
    clearTimer();
    setCurrent(null);
  }, [clearTimer]);

  const show = useCallback(
    (target: HighlightTarget) => {
      clearTimer();
      const variant = target.variant ?? 'spotlight';
      const merged: HighlightTarget = { ...target, variant };
      setCurrent(merged);
      const dur = merged.options?.durationMs;
      if (dur && dur > 0) {
        timerRef.current = window.setTimeout(() => {
          timerRef.current = null;
          setCurrent(null);
        }, dur);
      }
    },
    [clearTimer]
  );

  const spotlight = useCallback<HighlightContextValue['spotlight']>(
    (t) => show({ ...t, variant: 'spotlight' }),
    [show]
  );
  const glow = useCallback<HighlightContextValue['glow']>(
    (t) => show({ ...t, variant: 'glow' }),
    [show]
  );
  const pulse = useCallback<HighlightContextValue['pulse']>(
    (t) => show({ ...t, variant: 'pulse' }),
    [show]
  );
  const laser = useCallback<HighlightContextValue['laser']>(
    (t) => show({ ...t, variant: 'laser' }),
    [show]
  );

  const value = useMemo<HighlightContextValue>(
    () => ({ current, spotlight, glow, pulse, laser, show, clear }),
    [current, spotlight, glow, pulse, laser, show, clear]
  );

  return <HighlightContext.Provider value={value}>{children}</HighlightContext.Provider>;
}

/** 业务侧 hook：在 Provider 外调用会拿到一个 no-op 实现，不抛错。 */
export function useHighlight(): HighlightContextValue {
  const ctx = useContext(HighlightContext);
  if (ctx) return ctx;
  return NOOP;
}

const NOOP: HighlightContextValue = {
  current: null,
  spotlight: () => {},
  glow: () => {},
  pulse: () => {},
  laser: () => {},
  show: () => {},
  clear: () => {},
};

/** 给业务（PageRenderer / BlockPlaybackEngine 等）调用：根据 elementId 找 DOM。
 *
 * 对 dgb-anim-step-N 类 elementId（在 iframe 内部，主文档 querySelector
 * 搜不到），回退到最近的 animation block 外层容器 `.dgb-anim-html-frame` 的父元素，
 * 确保 HighlightOverlay 仍能画 spotlight + scrollIntoView。
 */
export function findHighlightTarget(elementId: string): HTMLElement | SVGElement | null {
  if (!elementId) return null;
  if (typeof document === 'undefined') return null;
  try {
    const sel = `[data-element-id="${elementId.replace(/"/g, '\\"')}"]`;
    const el = document.querySelector<HTMLElement | SVGElement>(sel);
    if (el) return el;

    if (/^dgb-anim-step-\d+$/.test(elementId)) {
      // 尝试找 animation iframe 的父级 block（data-element-id 前缀为 dgb-block-*-anim*）
      const iframe = document.querySelector<HTMLIFrameElement>('iframe.dgb-anim-html-frame');
      if (iframe) {
        // 向上找到带 data-element-id 的 block 容器
        const blockWrap = iframe.closest<HTMLElement>('[data-element-id]');
        if (blockWrap) return blockWrap;
        // 再退：iframe 的直接父元素
        if (iframe.parentElement) return iframe.parentElement;
      }
    }

    return null;
  } catch {
    return null;
  }
}
