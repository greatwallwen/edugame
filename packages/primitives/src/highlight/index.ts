/**
 * Phase G3.4 · @dgbook/blocks/highlight 子模块出口
 * Phase G3.7 · ADR-0022 (Y) · 新增 LaserOverlay（激光指引覆盖层）
 */
export {
  HighlightProvider,
  useHighlight,
  findHighlightTarget,
  type HighlightContextValue,
  type HighlightTarget,
  type HighlightVariant,
  type HighlightOptions,
} from './HighlightController';
export { HighlightOverlay } from './HighlightOverlay';
export { LaserOverlay } from './LaserOverlay';
