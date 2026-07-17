/**
 * signal-surfer · 波形冲浪
 *
 * 完整逻辑层：每帧 tick 驱动频率匹配 + 障碍判定。
 */
import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import {
  createInitialState, tick, adjustFreq, computeFinalScore,
  type SignalSurferState, type Obstacle, type Waveform,
} from './logic';

export interface SignalSurferData {
  waveform: Waveform;
  initialFreqHz: number;
  obstacleRatePerSec: number;
  /** 预生成障碍列表（关卡数据） */
  obstacles?: ReadonlyArray<Obstacle>;
}

export class SignalSurferMode extends GameMode<SignalSurferData> {
  readonly id = 'signal-surfer' as const;
  readonly displayName = '波形冲浪';
  readonly objective = 'PWM 占空比 / 频率感知 / ADC 采样';
  readonly howToPlay = [
    '↑↓ 调频率（或鼠标滚轮）',
    '匹配目标波形频率得分',
    '避开障碍物保住血量',
  ];

  private state: SignalSurferState = createInitialState(0);
  private obstacles: ReadonlyArray<Obstacle> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.state = createInitialState(data.initialFreqHz);
    this.obstacles = data.obstacles ?? this.generateObstacles(data);
  }

  override update(dt: number): void {
    if (!this.ctx || this.state.finished) return;
    this.state = tick(this.state, this.obstacles, dt);
    this.ctx.onProgress(
      Math.min(1, this.state.elapsed / Math.max(1, this.getLevelData().timeLimit)),
      `HP ${this.state.hp} · 分数 ${Math.round(this.state.matchScore)}`,
    );
    if (this.state.finished || (this.getLevelData().timeLimit > 0 && this.state.elapsed >= this.getLevelData().timeLimit)) {
      this.finish();
    }
  }

  /** 玩家调频 */
  changeFreq(delta: number): void {
    this.state = adjustFreq(this.state, delta);
  }

  finish(): void {
    if (!this.ctx) return;
    const score = computeFinalScore(this.state, this.getLevelData().timeLimit);
    const thresholds = this.getLevelData().starThresholds;
    const stars =
      score >= thresholds[2] ? 3 :
      score >= thresholds[1] ? 2 :
      score >= thresholds[0] ? 1 : 0;
    this.state = { ...this.state, finished: true };
    this.ctx.onComplete({
      modeId: this.id,
      levelId: this.getLevelData().levelId,
      score,
      stars,
      durationMs: Math.round(this.state.elapsed * 1000),
      stats: {
        hp: this.state.hp,
        maxPerfectStreak: this.state.maxPerfectStreak,
        matchScore: Math.round(this.state.matchScore),
      },
    });
  }

  getState(): SignalSurferState { return this.state; }

  destroy(): void {
    this.state = createInitialState(0);
    this.obstacles = [];
    this.ctx = null;
  }

  /** 如果关卡没有预设障碍，按 rate 自动生成 */
  private generateObstacles(data: SignalSurferData): Obstacle[] {
    const timeLimit = this.getLevelData().timeLimit || 30;
    const count = Math.round(timeLimit * data.obstacleRatePerSec);
    const obs: Obstacle[] = [];
    for (let i = 0; i < count; i++) {
      const atSec = (i + 1) * (timeLimit / (count + 1));
      const center = data.initialFreqHz * (0.8 + Math.random() * 0.4);
      obs.push({
        atSec,
        safeFreqMin: center - 20,
        safeFreqMax: center + 20,
      });
    }
    return obs;
  }
}
