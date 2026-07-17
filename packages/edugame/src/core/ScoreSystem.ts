/**
 * @dgbook/game · ScoreSystem
 *
 * 给定关卡的星阈值 + 当前分数 → 计算星数。
 * 同时保留连击 / 命中 / 失误的简单统计，给 onComplete 时附带。
 */
import type { LevelData } from './types';

export class ScoreSystem {
  private score = 0;
  private hits = 0;
  private misses = 0;
  private combo = 0;
  private maxCombo = 0;

  constructor(private readonly level: LevelData) {}

  hit(points: number): void {
    this.score += Math.max(0, points);
    this.hits += 1;
    this.combo += 1;
    if (this.combo > this.maxCombo) this.maxCombo = this.combo;
  }

  miss(penalty: number = 0): void {
    this.score = Math.max(0, this.score - Math.max(0, penalty));
    this.misses += 1;
    this.combo = 0;
  }

  setScore(value: number): void {
    this.score = Math.max(0, Math.min(100, value));
  }

  getScore(): number {
    return this.score;
  }

  getStats(): Record<string, number> {
    return {
      hits: this.hits,
      misses: this.misses,
      maxCombo: this.maxCombo,
    };
  }

  /**
   * 0=未通关  1=一星  2=二星  3=三星
   * 阈值约定：score < t1 → 0；t1 ≤ score < t2 → 1；t2 ≤ score < t3 → 2；≥ t3 → 3
   */
  getStars(): 0 | 1 | 2 | 3 {
    const [t1, t2, t3] = this.level.starThresholds;
    const s = this.score;
    if (s >= t3) return 3;
    if (s >= t2) return 2;
    if (s >= t1) return 1;
    return 0;
  }
}
