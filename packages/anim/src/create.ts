/**
 * createDriver · AnimDriver 工厂
 *
 * 根据 AnimData.kind 选择对应驱动实现。
 */
import type { AnimDriver, AnimData } from './types';
import { SvgIframeDriver } from './drivers/svg-iframe';
import { ManimDriver } from './drivers/manim';

export function createDriver(data: AnimData): AnimDriver {
  switch (data.kind) {
    case 'svg-iframe':
    case 'html-svg':
      return new SvgIframeDriver(data);
    case 'manim':
    case 'video':
      return new ManimDriver(data);
    default:
      // 未知类型 fallback 到 SvgIframeDriver（向后兼容）
      return new SvgIframeDriver(data);
  }
}
