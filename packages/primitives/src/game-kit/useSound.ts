import { useCallback, useRef } from 'react';

/**
 * useSound · Iter-50 P3 · 游戏音效反馈（Web Audio 合成，零素材依赖）
 *
 * 用代码合成简单音效，不下载任何音频文件：
 *   - correct  : 上行两音（叮——），答对的愉悦反馈
 *   - wrong    : 下行短音（咚），答错的提示
 *   - win      : 三音和弦琶音，通关庆祝
 *
 * 浏览器自动播放策略：AudioContext 在首次用户交互（点击/按键）后才能出声，
 * 游戏内的音效都由用户操作触发，天然满足。静音/不支持时静默降级。
 */
type SoundKind = 'correct' | 'wrong' | 'win';

export function useSound() {
  const ctxRef = useRef<AudioContext | null>(null);

  const getCtx = useCallback((): AudioContext | null => {
    if (typeof window === 'undefined') return null;
    try {
      if (!ctxRef.current) {
        const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
        if (!AC) return null;
        ctxRef.current = new AC();
      }
      return ctxRef.current;
    } catch {
      return null;
    }
  }, []);

  const tone = useCallback((ctx: AudioContext, freq: number, start: number, dur: number, gain = 0.12) => {
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.value = freq;
    g.gain.setValueAtTime(0, ctx.currentTime + start);
    g.gain.linearRampToValueAtTime(gain, ctx.currentTime + start + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + start + dur);
    osc.connect(g);
    g.connect(ctx.destination);
    osc.start(ctx.currentTime + start);
    osc.stop(ctx.currentTime + start + dur);
  }, []);

  const play = useCallback((kind: SoundKind) => {
    const ctx = getCtx();
    if (!ctx) return;
    if (ctx.state === 'suspended') void ctx.resume();
    if (kind === 'correct') {
      tone(ctx, 660, 0, 0.12);
      tone(ctx, 880, 0.09, 0.16);
    } else if (kind === 'wrong') {
      tone(ctx, 220, 0, 0.18, 0.1);
    } else if (kind === 'win') {
      // C-E-G 大三和弦琶音
      tone(ctx, 523, 0, 0.18);
      tone(ctx, 659, 0.12, 0.18);
      tone(ctx, 784, 0.24, 0.3);
    }
  }, [getCtx, tone]);

  return { play };
}
