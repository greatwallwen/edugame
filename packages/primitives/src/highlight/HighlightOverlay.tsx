/**
 * HighlightOverlay — 对标 OpenMAIC SpotlightOverlay
 *
 * 用 framer-motion AnimatePresence 实现：
 *   - 入场：scaleX/Y 缩聚 + fade in（0.35s）
 *   - 退场：scale 收缩 + fade out
 *   - 位置移动：framer-motion 自动 tween left/top/width（标题切换时方框平滑滑动）
 *
 * 三种 spotlight 目标：
 *   - dgb-block-{id}：整块高亮走 CSS class（.dgb-block-spotlight），本组件 return null
 *   - dgb-text-{bid}-s{N}：标题级方框（framer-motion 动画）
 *   - dgb-graphics-/dgb-mermaid-/dgb-anim-：节点级 SVG mask（保留旧逻辑）
 */
import { useEffect, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useHighlight, findHighlightTarget } from './HighlightController';
import './HighlightOverlay.css';

interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

const DEFAULT_PADDING = 8;
const DEFAULT_RADIUS = 10;
const DEFAULT_DIM_COLOR = 'rgba(15, 23, 42, 0.15)';
const DEFAULT_GLOW_COLOR = '#ffd166';

/** OpenMAIC 同款 ease 曲线 */
const EASE_SPRING = [0.16, 1, 0.3, 1] as const;

export function HighlightOverlay() {
  const { current } = useHighlight();
  const [rect, setRect] = useState<Rect | null>(null);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    if (!current) {
      setRect(null);
      return;
    }
    const el = findHighlightTarget(current.elementId);
    if (!el) {
      setRect(null);
      return;
    }

    // scrollIntoView：仅在 current 切换时滚动一次
    if (typeof window !== 'undefined') {
      const r = el.getBoundingClientRect();
      const outOfView = r.bottom < 0 || r.top > window.innerHeight ||
        r.right < 0 || r.left > window.innerWidth;
      if (outOfView && typeof el.scrollIntoView === 'function') {
        try {
          el.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'center' });
        } catch { /* ignore */ }
      }
    }

    const measure = () => {
      const r = el.getBoundingClientRect();
      setRect({ x: r.left, y: r.top, width: r.width, height: r.height });
    };

    const scheduleMeasure = () => {
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      rafRef.current = requestAnimationFrame(() => {
        rafRef.current = null;
        measure();
      });
    };

    measure();

    const ro = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(scheduleMeasure) : null;
    ro?.observe(el);
    if (ro && typeof document !== 'undefined') ro.observe(document.documentElement);

    window.addEventListener('scroll', scheduleMeasure, { passive: true, capture: true });
    window.addEventListener('resize', scheduleMeasure, { passive: true });

    return () => {
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      ro?.disconnect();
      window.removeEventListener('scroll', scheduleMeasure, true);
      window.removeEventListener('resize', scheduleMeasure);
    };
  }, [current]);

  const variant = current?.variant ?? 'spotlight';
  const opt = current?.options ?? {};
  const isTextSpotlight = current?.elementId?.startsWith('dgb-text-') ?? false;
  const isBlockSpotlight = current?.elementId?.startsWith('dgb-block-') ?? false;
  const isActive = !!current && !!rect;

  // ── dgb-block-：走 CSS class，不渲染 overlay ──
  if (isBlockSpotlight) return null;

  // ── dgb-text-：framer-motion 标题级方框（对标 OpenMAIC SpotlightOverlay）──
  return (
    <>
      <AnimatePresence mode="wait">
        {isActive && isTextSpotlight && variant === 'spotlight' && rect && (
          <motion.div
            key={`hl-${current!.elementId}`}
            className="dgb-hl-overlay dgb-hl-heading-spotlight"
            aria-hidden
            initial={{ opacity: 0, scale: 0.82 }}
            animate={{
              opacity: 1,
              scale: 1,
              left: rect.x - 10,
              top: rect.y - 4,
              width: rect.width + 20,
              height: rect.height + 8,
            }}
            exit={{ opacity: 0, scale: 0.92 }}
            transition={{ duration: 0.35, ease: EASE_SPRING }}
            style={{
              position: 'fixed',
              borderRadius: 8,
              pointerEvents: 'none',
              zIndex: 9999,
              transformOrigin: 'left center',
            }}
          />
        )}
      </AnimatePresence>

      {/* ── 节点级 SVG mask（graphics/mermaid/anim-step）── */}
      {isActive && !isTextSpotlight && !isBlockSpotlight && variant === 'spotlight' && rect &&
        !(typeof window !== 'undefined' && rect.height > window.innerHeight * 0.6) && (
        <NodeSpotlightSVG rect={rect} current={current!} opt={opt} />
      )}

      {/* ── glow / pulse ── */}
      {isActive && (variant === 'glow' || variant === 'pulse') && rect && (
        <div
          className={`dgb-hl-overlay dgb-hl-overlay-${variant}`}
          aria-hidden
          style={{
            ['--dgb-hl-color' as string]: opt.glowColor ?? DEFAULT_GLOW_COLOR,
            left: rect.x - DEFAULT_PADDING,
            top: rect.y - DEFAULT_PADDING,
            width: rect.width + DEFAULT_PADDING * 2,
            height: rect.height + DEFAULT_PADDING * 2,
            borderRadius: DEFAULT_RADIUS,
          }}
        />
      )}
    </>
  );
}

/** 节点级 SVG mask spotlight（graphics/mermaid/anim 专用） */
function NodeSpotlightSVG({ rect, current, opt }: { rect: Rect; current: { elementId: string }; opt: Partial<{ color: string; dimness: number; glowColor: string; durationMs: number }> }) {
  const dimColor = opt.color ?? DEFAULT_DIM_COLOR;
  const dimness = typeof opt.dimness === 'number' ? Math.max(0, Math.min(1, opt.dimness)) : null;
  const fill = dimness != null ? `rgba(15, 23, 42, ${dimness})` : dimColor;
  const px = rect.x, py = rect.y, pw = rect.width, ph = rect.height;

  return (
    <motion.svg
      className="dgb-hl-overlay dgb-hl-overlay-spotlight"
      aria-hidden
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.3 }}
    >
      <defs>
        <mask id="dgb-hl-spotlight-mask">
          <rect width="100%" height="100%" fill="white" />
          <motion.rect
            fill="black"
            initial={{ x: px - 8, y: py - 8, width: pw + 16, height: ph + 16, rx: 12 }}
            animate={{ x: px - 2, y: py - 2, width: pw + 4, height: ph + 4, rx: 8 }}
            transition={{ duration: 0.5, ease: EASE_SPRING }}
          />
        </mask>
      </defs>
      <rect width="100%" height="100%" fill={fill} mask="url(#dgb-hl-spotlight-mask)" />
      <motion.rect
        fill="none"
        stroke="rgba(255,255,255,0.7)"
        strokeWidth={1.2}
        style={{ vectorEffect: 'non-scaling-stroke' } as React.CSSProperties}
        initial={{ x: px - 4, y: py - 4, width: pw + 8, height: ph + 8, opacity: 0, rx: 10 }}
        animate={{ x: px - 2, y: py - 2, width: pw + 4, height: ph + 4, opacity: 1, rx: 8 }}
        transition={{ duration: 0.45, delay: 0.05, ease: EASE_SPRING }}
      />
    </motion.svg>
  );
}
