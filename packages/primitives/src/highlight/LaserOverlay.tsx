/**
 * Phase G3.7 · LaserOverlay
 *
 * ADR-0022 选项 Y · 从 OpenMAIC LaserOverlay 借鉴**视觉与交互概念**，CSS-only 重写。
 *
 * 与 OpenMAIC 实现的差异（详见 docs/architecture/openmaic-playback-alignment.md §7.2）：
 *   - DGBook 上下文是滚动文档而非 16:9 幻灯片，所以坐标用 viewport 坐标 + position:fixed
 *     （对应 HighlightOverlay/spotlight 的 inset:0 全屏铺）
 *   - 不依赖 framer-motion / motion；用 CSS transition + keyframes
 *   - 元素 ID 协议沿用 DGBook `dgb-{kind}-{nodeId}`（ADR-0015）
 *   - 无障碍：prefers-reduced-motion 时跳过飞行入场，直接落点
 *
 * 视觉规格：
 *   - 入场轨迹：从视口"距目标最远的角"以 cubic-bezier(0.22, 1, 0.36, 1) 滑入 0.5s
 *   - 光核：12px 圆点 + 外发光（box-shadow + drop-shadow filter）
 *   - 呼吸光环：1.5s 周期 scale 1→2.8 + opacity 0.6→0；repeatDelay 0.3s
 *   - 退场：opacity 0 0.25s（由 useHighlight clear / variant 切换触发）
 *
 * 渲染契约：
 *   - 仅 useHighlight().current.variant === 'laser' 时渲染本组件
 *   - 复用 useHighlight + findHighlightTarget；不重新发明 DOM 测量
 */
import { useEffect, useRef, useState } from 'react';
import { useHighlight, findHighlightTarget } from './HighlightController';
import './LaserOverlay.css';

interface CenterPoint {
  /** viewport 坐标（CSS px） */
  x: number;
  y: number;
}

const DEFAULT_COLOR = '#ff3b30';

export function LaserOverlay() {
  const { current } = useHighlight();
  const [center, setCenter] = useState<CenterPoint | null>(null);
  /** 标志：true 时跳过入场过渡（首次未挂载到 DOM 前就把 left/top 设到起点） */
  const [armed, setArmed] = useState(false);
  const rafRef = useRef<number | null>(null);

  const isLaser = !!current && (current.variant ?? '') === 'laser';

  useEffect(() => {
    if (!isLaser || !current) {
      setCenter(null);
      setArmed(false);
      return;
    }
    const el = findHighlightTarget(current.elementId);
    if (!el) {
      setCenter(null);
      setArmed(false);
      return;
    }

    const measure = () => {
      const r = el.getBoundingClientRect();
      setCenter({ x: r.left + r.width / 2, y: r.top + r.height / 2 });
    };

    const scheduleMeasure = () => {
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      rafRef.current = requestAnimationFrame(() => {
        rafRef.current = null;
        measure();
      });
    };

    measure();
    // 第二帧才打开 armed，让首次 render 把 left/top 渲染在起点（视口最远角），
    // 第二帧 armed=true 触发 transition 飞向中心。
    const id = window.requestAnimationFrame(() => setArmed(true));

    const ro = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(scheduleMeasure) : null;
    ro?.observe(el);
    if (ro && typeof document !== 'undefined') ro.observe(document.documentElement);
    window.addEventListener('scroll', scheduleMeasure, { passive: true, capture: true });
    window.addEventListener('resize', scheduleMeasure, { passive: true });

    return () => {
      window.cancelAnimationFrame(id);
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      ro?.disconnect();
      window.removeEventListener('scroll', scheduleMeasure, true);
      window.removeEventListener('resize', scheduleMeasure);
    };
  }, [isLaser, current]);

  if (!isLaser || !current || !center) return null;

  const color = current.options?.glowColor ?? DEFAULT_COLOR;

  // 起点：视口 4 角中距离目标最远的角（对标 OpenMAIC startPos 思想，但坐标用 px 而非百分比）
  const W = typeof window !== 'undefined' ? window.innerWidth : 1280;
  const H = typeof window !== 'undefined' ? window.innerHeight : 720;
  const startX = center.x > W / 2 ? -32 : W + 32;
  const startY = center.y > H / 2 ? -32 : H + 32;

  // armed=false 第一帧：渲染在起点；armed=true：transition 滑向 center
  const liveX = armed ? center.x : startX;
  const liveY = armed ? center.y : startY;

  return (
    <div
      className="dgb-laser-overlay"
      aria-hidden
      data-testid="dgb-laser-overlay"
      style={{
        left: `${liveX}px`,
        top: `${liveY}px`,
        ['--dgb-laser-color' as string]: color,
      }}
    >
      <div className="dgb-laser-ring" />
      <div className="dgb-laser-core" />
    </div>
  );
}
