import { useCallback, useState } from 'react';
import { useSound } from './useSound';

/**
 * useGameScore · Iter-49 P3 互动游戏通用底座（Iter-50 加音效 + 星级）
 *
 * 统一所有互动游戏的"得分 / 连击 / 最佳连击 / 错误数 / 音效"逻辑，
 * 让 7 种游戏共享一致的游戏性体验（与填空游戏标杆对齐）。
 *
 * 计分规则：
 *   - 答对：+base(10) + combo×comboBonus(2)，连击 +1，播放 correct 音效
 *   - 答错：连击清零，错误数 +1，播放 wrong 音效
 *
 * 星级（stars 1-3）：依据错误数 —— 0 错=3 星，1-2 错=2 星，更多=1 星。
 */
export interface GameScoreState {
  score: number;
  combo: number;
  bestCombo: number;
  wrong: number;
}

export interface UseGameScoreOptions {
  base?: number;        // 答对基础分
  comboBonus?: number;  // 每级连击的额外分
  sound?: boolean;      // 是否播放音效（默认 true）
}

export interface UseGameScoreReturn extends GameScoreState {
  register: (correct: boolean) => void;
  reset: () => void;
  /** 通关音效（胜利时调用） */
  playWin: () => void;
  /** 依据错误数算星级 1-3 */
  stars: number;
}

export function useGameScore(opts: UseGameScoreOptions = {}): UseGameScoreReturn {
  const base = opts.base ?? 10;
  const comboBonus = opts.comboBonus ?? 2;
  const soundOn = opts.sound !== false;
  const { play } = useSound();
  const [state, setState] = useState<GameScoreState>({ score: 0, combo: 0, bestCombo: 0, wrong: 0 });

  const register = useCallback((correct: boolean) => {
    if (soundOn) play(correct ? 'correct' : 'wrong');
    setState((s) => {
      if (!correct) return { ...s, combo: 0, wrong: s.wrong + 1 };
      const combo = s.combo + 1;
      return {
        score: s.score + base + combo * comboBonus,
        combo,
        bestCombo: Math.max(s.bestCombo, combo),
        wrong: s.wrong,
      };
    });
  }, [base, comboBonus, soundOn, play]);

  const reset = useCallback(() => {
    setState({ score: 0, combo: 0, bestCombo: 0, wrong: 0 });
  }, []);

  const playWin = useCallback(() => { if (soundOn) play('win'); }, [soundOn, play]);

  const stars = state.wrong === 0 ? 3 : state.wrong <= 2 ? 2 : 1;

  return { ...state, register, reset, playWin, stars };
}
