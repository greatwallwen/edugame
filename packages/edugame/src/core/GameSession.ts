/**
 * @dgbook/game · GameSession
 *
 * 一局生命周期：start / pause / resume / abort / complete。
 * 不依赖 PixiJS；驱动 GameMode lifecycle 钩子 + 维护一些定时统计。
 */
import { GameMode } from './GameMode';
import { ScoreSystem } from './ScoreSystem';
import type { GameResult, LevelData } from './types';

export type SessionState = 'idle' | 'running' | 'paused' | 'finished';

export interface SessionCallbacks {
  onStateChange?: (state: SessionState) => void;
  onResult?: (result: GameResult) => void;
  onProgress?: (ratio: number, hint?: string) => void;
}

export class GameSession {
  private state: SessionState = 'idle';
  private startedAt = 0;
  private accumulated = 0;
  private pausedAt = 0;

  private rafTimer: number | null = null;
  private lastTick = 0;

  readonly score: ScoreSystem;

  constructor(
    private readonly mode: GameMode,
    private readonly level: LevelData,
    private readonly callbacks: SessionCallbacks = {},
    /** 注入定时器以便测试时替换为可控版本 */
    private readonly clock: { now: () => number } = { now: () => Date.now() },
  ) {
    this.score = new ScoreSystem(level);
  }

  getState(): SessionState {
    return this.state;
  }

  async start(): Promise<void> {
    if (this.state !== 'idle') return;
    await this.mode.init({
      level: this.level,
      onComplete: (r) => this.complete(r),
      onProgress: (ratio, hint) => this.callbacks.onProgress?.(ratio, hint),
    });
    this.startedAt = this.clock.now();
    this.lastTick = this.startedAt;
    this.setState('running');
  }

  pause(): void {
    if (this.state !== 'running') return;
    this.pausedAt = this.clock.now();
    this.accumulated += this.pausedAt - this.lastTick;
    this.mode.pause();
    this.setState('paused');
  }

  resume(): void {
    if (this.state !== 'paused') return;
    this.lastTick = this.clock.now();
    this.mode.resume();
    this.setState('running');
  }

  /** 外部驱动 update（host 用 PIXI ticker 调）。session 维护 dt 累积。 */
  tick(now: number = this.clock.now()): void {
    if (this.state !== 'running') return;
    const dt = now - this.lastTick;
    this.lastTick = now;
    this.accumulated += dt;
    this.mode.update(dt);
    if (this.level.timeLimit > 0 && this.accumulated >= this.level.timeLimit * 1000) {
      // 时间到 → 用当前分数自动 complete
      this.complete({
        modeId: this.level.modeId,
        levelId: this.level.levelId,
        score: this.score.getScore(),
        stars: this.score.getStars(),
        durationMs: this.accumulated,
        stats: this.score.getStats(),
      });
    }
  }

  complete(partial?: Partial<GameResult>): void {
    if (this.state === 'finished') return;
    const now = this.clock.now();
    if (this.state === 'running') {
      this.accumulated += now - this.lastTick;
    }
    const result: GameResult = {
      modeId: this.level.modeId,
      levelId: this.level.levelId,
      score: partial?.score ?? this.score.getScore(),
      stars: (partial?.stars ?? this.score.getStars()) as 0 | 1 | 2 | 3,
      durationMs: partial?.durationMs ?? this.accumulated,
      stats: partial?.stats ?? this.score.getStats(),
    };
    this.setState('finished');
    this.callbacks.onResult?.(result);
    this.mode.destroy();
  }

  abort(): void {
    if (this.state === 'finished') return;
    this.setState('finished');
    this.mode.destroy();
  }

  private setState(s: SessionState): void {
    if (this.state === s) return;
    this.state = s;
    this.callbacks.onStateChange?.(s);
  }
}
