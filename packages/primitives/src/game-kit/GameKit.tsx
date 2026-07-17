import { motion, AnimatePresence } from 'framer-motion';
import { triggerSmallConfetti } from '../utils/confetti';
import { useEffect, useRef, useState } from 'react';
import './game-kit.css';

/**
 * GameStat · Iter-49 P3 · 统一的得分 / 连击徽章（放在游戏头部右侧）
 * Iter-52 P4 · 增即时反馈：得分增加时自动飘出 "+N"，连击命中里程碑(3/5/8/12)
 *   时飘出 "🔥 连击 ×N"。零 API 改动——所有用 GameStat 的游戏自动获得。
 */
const COMBO_MILESTONES = [3, 5, 8, 12, 16, 20];

export function GameStat({ score, combo }: { score: number; combo: number }) {
  const prevScore = useRef(score);
  const [floats, setFloats] = useState<{ id: number; text: string; kind: string }[]>([]);
  const seq = useRef(0);

  useEffect(() => {
    const delta = score - prevScore.current;
    prevScore.current = score;
    const popups: { id: number; text: string; kind: string }[] = [];
    if (delta > 0) popups.push({ id: ++seq.current, text: `+${delta}`, kind: 'gain' });
    if (COMBO_MILESTONES.includes(combo)) {
      popups.push({ id: ++seq.current, text: `🔥 连击 ×${combo}`, kind: 'combo' });
    }
    if (popups.length === 0) return;
    setFloats((f) => [...f, ...popups]);
    const ids = popups.map((p) => p.id);
    const t = setTimeout(() => setFloats((f) => f.filter((x) => !ids.includes(x.id))), 1100);
    return () => clearTimeout(t);
    // combo 入依赖：连击里程碑也要触发
  }, [score, combo]);

  return (
    <span className="dgb-gk-stats">
      <span className="dgb-gk-score">得分 {score}</span>
      {combo > 1 ? <span className="dgb-gk-combo">🔥 连击 ×{combo}</span> : null}
      <span className="dgb-gk-floats" aria-hidden="true">
        <AnimatePresence>
          {floats.map((f) => (
            <motion.span
              key={f.id}
              className={`dgb-gk-float dgb-gk-float--${f.kind}`}
              initial={{ opacity: 0, y: 6, scale: 0.8 }}
              animate={{ opacity: 1, y: -22, scale: 1 }}
              exit={{ opacity: 0, y: -36 }}
              transition={{ duration: 0.9, ease: 'easeOut' }}
            >
              {f.text}
            </motion.span>
          ))}
        </AnimatePresence>
      </span>
    </span>
  );
}

/**
 * GameWinBanner · Iter-49 P3 · 统一的胜利庆祝横幅 + 撒花 + 再玩按钮
 * 加星级评价（stars 1-3）+ 出现时播放胜利音效（onShow 回调）。
 *
 * 出现时自动触发 canvas-confetti 撒花，与填空游戏标杆一致。
 */
export function GameWinBanner({
  show,
  text,
  onReplay,
  replayLabel = '再玩一次',
  stars,
  onShow,
}: {
  show: boolean;
  text: string;
  onReplay: () => void;
  replayLabel?: string;
  /** 星级 1-3，传入则显示星星 */
  stars?: number;
  /** 横幅首次出现时回调（用于播放胜利音效） */
  onShow?: () => void;
}) {
  useEffect(() => {
    if (show) {
      onShow?.();
      const t = setTimeout(() => triggerSmallConfetti(), 250);
      return () => clearTimeout(t);
    }
    // onShow 故意不入依赖：只在 show 由假变真时触发一次
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [show]);

  return (
    <AnimatePresence>
      {show && (
        <motion.div
          className="dgb-gk-win"
          initial={{ opacity: 0, y: 20, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -10 }}
          transition={{ type: 'spring', stiffness: 200, damping: 18 }}
        >
          {typeof stars === 'number' && (
            <span className="dgb-gk-stars" aria-label={`${stars} 星`}>
              {[1, 2, 3].map((i) => (
                <motion.span
                  key={i}
                  className={`dgb-gk-star ${i <= stars ? 'on' : 'off'}`}
                  initial={{ scale: 0, rotate: -30 }}
                  animate={{ scale: 1, rotate: 0 }}
                  transition={{ delay: 0.15 * i, type: 'spring', stiffness: 300 }}
                >★</motion.span>
              ))}
            </span>
          )}
          <span className="dgb-gk-win-text">{text}</span>
          <motion.button
            type="button"
            className="dgb-gk-replay"
            onClick={onReplay}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            {replayLabel}
          </motion.button>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
