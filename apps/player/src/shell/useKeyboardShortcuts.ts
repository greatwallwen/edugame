/**
 * useKeyboardShortcuts · Iter-53 块级导航收口
 *
 * Space / ←/→ / Esc 路由：
 *   - Space：togglePause / start
 *   - ←/→：本页内容块前进/后退（gotoPrevBlock/gotoNextBlock，首末块溢出相邻页）
 *   - Esc：stop
 *
 * 输入框 / 可编辑元素聚焦时不响应。
 */
import { useEffect } from 'react';
import type { MutableRefObject } from 'react';
import type { PageActionRunner } from '@dgbook/playback';

export interface KeyboardShortcutsDeps {
  enabled: boolean;
  activeIdx: number;
  pages: ReadonlyArray<{ id: string }>;
  setActive: (id: string) => void;
  /** page.actions 模式启动 / 恢复 PageActionRunner */
  startPlay: () => void;
  actionsRunnerRef: MutableRefObject<PageActionRunner | null>;
  /** 块级导航（←/→ 与底部按钮共用） */
  gotoPrevBlock: () => void;
  gotoNextBlock: () => void;
}

export function useKeyboardShortcuts(deps: KeyboardShortcutsDeps): void {
  const {
    enabled, activeIdx, pages, setActive, startPlay, actionsRunnerRef,
    gotoPrevBlock, gotoNextBlock,
  } = deps;

  useEffect(() => {
    if (!enabled) return;
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target) {
        const tag = target.tagName?.toLowerCase();
        if (tag === 'input' || tag === 'textarea' || target.isContentEditable) return;
      }

      const runner = actionsRunnerRef.current;

      if (e.code === 'Space') {
        e.preventDefault();
        if (runner) {
          runner.togglePause();
          return;
        }
        startPlay();
      } else if (e.code === 'ArrowLeft') {
        e.preventDefault();
        gotoPrevBlock();
      } else if (e.code === 'ArrowRight') {
        e.preventDefault();
        gotoNextBlock();
      } else if (e.code === 'Escape') {
        if (runner) {
          e.preventDefault();
          runner.stop();
        }
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [enabled, activeIdx, pages, setActive, startPlay, actionsRunnerRef, gotoPrevBlock, gotoNextBlock]);
}
