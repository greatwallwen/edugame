import type { GameResult, LevelData } from '../../core/types';

export const GODOT_BRIDGE_VERSION = 1;

export type GodotKnowledgeItem = Record<string, unknown>;

export interface GodotGameData {
  gameId: string;
  entryUrl: string;
  bridgeVersion?: number;
  aspectRatio?: string;
  assetsBaseUrl?: string;
  initialState?: Record<string, unknown>;
  knowledgeSource?: 'external' | 'embedded';
  knowledgePackUrl?: string;
  questionsUrl?: string;
  upgradesUrl?: string;
  bindingUrl?: string;
  questions?: GodotKnowledgeItem[];
  upgrades?: GodotKnowledgeItem[];
  bindings?: GodotKnowledgeItem[] | Record<string, unknown>;
  concepts?: GodotKnowledgeItem[];
  allow?: string;
}

export interface GodotHostInitMessage {
  type: 'DGB_GODOT_INIT';
  version: number;
  level: LevelData<GodotGameData>;
  data: GodotGameData;
}

export interface GodotHostControlMessage {
  type: 'DGB_GODOT_PAUSE' | 'DGB_GODOT_RESUME' | 'DGB_GODOT_RESET';
  version: number;
}

export type GodotHostMessage = GodotHostInitMessage | GodotHostControlMessage;

export interface GodotReadyMessage {
  type: 'DGB_GODOT_READY';
  version?: number;
  gameId?: string;
}

export interface GodotProgressMessage {
  type: 'DGB_GODOT_PROGRESS';
  progress: number;
  hint?: string;
  stats?: Record<string, number>;
}

export interface GodotCompleteMessage {
  type: 'DGB_GODOT_COMPLETE';
  score: number;
  stars?: 0 | 1 | 2 | 3;
  durationMs?: number;
  stats?: Record<string, number>;
}

export interface GodotLogMessage {
  type: 'DGB_GODOT_LOG';
  level?: 'debug' | 'info' | 'warn' | 'error';
  message: string;
}

export type GodotToHostMessage =
  | GodotReadyMessage
  | GodotProgressMessage
  | GodotCompleteMessage
  | GodotLogMessage;

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function isFiniteNumberRecord(value: unknown): value is Record<string, number> {
  return value != null
    && typeof value === 'object'
    && !Array.isArray(value)
    && Object.values(value).every(isFiniteNumber);
}

function isOptionalString(value: unknown): value is string | undefined {
  return value == null || typeof value === 'string';
}

function isValidStars(value: unknown): value is 0 | 1 | 2 | 3 {
  return Number.isInteger(value) && isFiniteNumber(value) && value >= 0 && value <= 3;
}

export function isGodotToHostMessage(value: unknown): value is GodotToHostMessage {
  if (!value || typeof value !== 'object') return false;
  const message = value as Record<string, unknown>;
  switch (message.type) {
    case 'DGB_GODOT_READY':
      return (message.version == null || (Number.isInteger(message.version) && isFiniteNumber(message.version)))
        && isOptionalString(message.gameId);
    case 'DGB_GODOT_PROGRESS':
      return isFiniteNumber(message.progress)
        && isOptionalString(message.hint)
        && (message.stats == null || isFiniteNumberRecord(message.stats));
    case 'DGB_GODOT_COMPLETE':
      return isFiniteNumber(message.score)
        && (message.stars == null || isValidStars(message.stars))
        && (message.durationMs == null || (isFiniteNumber(message.durationMs) && message.durationMs >= 0))
        && (message.stats == null || isFiniteNumberRecord(message.stats));
    case 'DGB_GODOT_LOG':
      return typeof message.message === 'string'
        && (message.level == null
          || (typeof message.level === 'string' && ['debug', 'info', 'warn', 'error'].includes(message.level)));
    default:
      return false;
  }
}

export function starsFromScore(score: number, thresholds: [number, number, number]): 0 | 1 | 2 | 3 {
  return score >= thresholds[2] ? 3 : score >= thresholds[1] ? 2 : score >= thresholds[0] ? 1 : 0;
}

export function normalizeGodotResult(
  level: LevelData<GodotGameData>,
  message: GodotCompleteMessage,
): GameResult {
  const rawScore = isFiniteNumber(message.score) ? message.score : 0;
  const score = Math.max(0, Math.min(100, Math.round(rawScore)));
  const durationMs = isFiniteNumber(message.durationMs) ? Math.max(0, Math.round(message.durationMs)) : 0;
  const stars = isValidStars(message.stars) ? message.stars : starsFromScore(score, level.starThresholds);
  return {
    modeId: 'godot-game',
    levelId: level.levelId,
    score,
    stars,
    durationMs,
    stats: isFiniteNumberRecord(message.stats) ? message.stats : undefined,
  };
}
