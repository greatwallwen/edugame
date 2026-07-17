/**
 * @dgbook/game · LevelLoader
 *
 * 简单的关卡数据反序列化与基本字段校验。
 * 只检查 LevelData 顶层字段；data 由各 mode 自己再校验。
 */
import type { LevelData, ModeId } from './types';

const VALID_MODES: ReadonlyArray<ModeId> = [
  'bit-flip-quest',
  'pin-rush',
  'signal-surfer',
  'circuit-builder',
  'interrupt-defender',
  'godot-game',
];

export interface LoadLevelOptions {
  /** 严格模式：缺字段抛错；否则用默认值兜底 */
  strict?: boolean;
}

export class LevelLoadError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'LevelLoadError';
  }
}

export function loadLevel(raw: unknown, opts: LoadLevelOptions = {}): LevelData {
  if (!raw || typeof raw !== 'object') {
    throw new LevelLoadError('level must be an object');
  }
  const o = raw as Record<string, unknown>;
  const modeId = o.modeId;
  if (typeof modeId !== 'string' || !VALID_MODES.includes(modeId as ModeId)) {
    throw new LevelLoadError(`unknown modeId: ${String(modeId)}`);
  }
  const levelId = o.levelId;
  if (typeof levelId !== 'string' || levelId.length === 0) {
    throw new LevelLoadError('levelId must be a non-empty string');
  }
  const title = typeof o.title === 'string' ? o.title : levelId;
  const objective = typeof o.objective === 'string' ? o.objective : '';
  const difficulty = clamp(toInt(o.difficulty, 1), 1, 5) as 1 | 2 | 3 | 4 | 5;
  const timeLimit = toInt(o.timeLimit, 0);

  const thresholdsRaw = Array.isArray(o.starThresholds) ? o.starThresholds : [];
  const t1 = clamp(toInt(thresholdsRaw[0], 50), 0, 100);
  const t2 = clamp(toInt(thresholdsRaw[1], 80), t1, 100);
  const t3 = clamp(toInt(thresholdsRaw[2], 95), t2, 100);

  if (opts.strict) {
    if (!o.objective) throw new LevelLoadError('strict: objective required');
    if (!Array.isArray(o.starThresholds) || o.starThresholds.length !== 3) {
      throw new LevelLoadError('strict: starThresholds must be 3 numbers');
    }
  }

  const data = o.data ?? {};
  return {
    modeId: modeId as ModeId,
    levelId,
    title,
    objective,
    difficulty,
    starThresholds: [t1, t2, t3],
    timeLimit,
    data,
  };
}

function toInt(v: unknown, fallback: number): number {
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : fallback;
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, v));
}
