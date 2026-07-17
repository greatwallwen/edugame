/**
 * Playback runtime types (v4.5 · 设计中，运行时未实现)
 *
 * 状态：DESIGN-ONLY · 类型骨架
 * 实现路线图：
 *   - 状态机 4 态：docs/architecture/openmaic-benchmark.md §3.3
 *   - 进度持久化：docs/architecture/openmaic-benchmark.md §3.6
 *   - 速度切换：docs/architecture/openmaic-benchmark.md §3.5
 *
 * 设计目标：
 *   把当前隐式的"播 / 不播"二态显式化为 4 态状态机；
 *   定义 PlaybackSnapshot 作为跨 session 恢复的契约；
 *   定义 PlaybackSpeed 作为速度切换的固定档位。
 *
 * 与 OpenMAIC 对应关系：
 *   - DGBook EngineMode = OpenMAIC EngineMode（4 态完全一致）
 *   - DGBook PlaybackSnapshot 比 OpenMAIC 多 actionIndex（适配 PageAction）
 *
 * 兼容策略：
 *   - 仅 standalone 形态启用（offline 形态保持纯静态，不写 localStorage）；
 *   - snapshot 缺失时回退到 page 0 / block 0；
 *   - schema 版本 = 1，未来变更走 migration。
 */

import { z } from 'zod';

/**
 * 4 态状态机（与 OpenMAIC PlaybackEngine 同构）
 *
 *   idle ──start()──→ playing ──pause()──→ paused
 *     ▲                  ▲                    │
 *     │                  └──── resume() ──────┘
 *     │
 *     └──── handleEndDiscussion() ──── live ←── pause-for-discussion action
 */
export const EngineModeSchema = z.enum(['idle', 'playing', 'paused', 'live']);
export type EngineMode = z.infer<typeof EngineModeSchema>;

/**
 * 播放速度档位
 *
 * 0.75 / 1 / 1.25 / 1.5 / 2 五档；其它值在 UI 层 round 到最近档。
 * Qwen TTS rate 范围 0.5-2.0；Web Speech rate 范围浏览器实现差异较大，
 * 因此选取的是两端都能稳定支持的子集。
 */
export const PlaybackSpeedSchema = z.union([
  z.literal(0.75),
  z.literal(1),
  z.literal(1.25),
  z.literal(1.5),
  z.literal(2),
]);
export type PlaybackSpeed = z.infer<typeof PlaybackSpeedSchema>;

export const DEFAULT_PLAYBACK_SPEED: PlaybackSpeed = 1;
export const PLAYBACK_SPEED_OPTIONS: readonly PlaybackSpeed[] = [
  0.75,
  1,
  1.25,
  1.5,
  2,
] as const;

/**
 * PlaybackSnapshot · 跨 session 进度
 *
 * 写入策略：
 *   - standalone：localStorage[`dgbook:${courseId}:progress`]
 *   - offline：不写盘；URL fragment 兜底（#/p3-led-blink/b2）
 *
 * 读取策略：
 *   - useManifest hook 启动时尝试 parse；版本不匹配或 schema 失败时静默丢弃。
 *   - 不在播放器渲染前阻塞，最坏情况是回到 page 0。
 */
export const PlaybackSnapshotSchema = z.object({
  /** snapshot schema 版本，当前固定 1 */
  v: z.literal(1),
  courseId: z.string().min(1).max(64),
  pageId: z.string().min(1).max(64),
  /** 上次定位到的 block id；不是必填（刚进入 page 时可能为空） */
  blockId: z.string().min(1).max(64).optional(),
  /** 若 page 走 PageAction 编排，记录到第几个 action（0-based） */
  actionIndex: z.number().int().nonnegative().optional(),
  /** 上次保存时刻（ms） */
  ts: z.number().int().nonnegative(),
  /** 用户偏好的播放速度（v1 起持久化） */
  speed: PlaybackSpeedSchema.optional(),
});
export type PlaybackSnapshot = z.infer<typeof PlaybackSnapshotSchema>;

/**
 * 创建一个空 snapshot（用于"无历史进度"场景）
 */
export function createEmptySnapshot(courseId: string, pageId: string): PlaybackSnapshot {
  return {
    v: 1,
    courseId,
    pageId,
    ts: Date.now(),
  };
}

/**
 * 安全 parse · 失败时返回 null（绝不抛错，避免阻塞播放器启动）
 */
export function parseSnapshotSafe(raw: unknown): PlaybackSnapshot | null {
  const r = PlaybackSnapshotSchema.safeParse(raw);
  return r.success ? r.data : null;
}

/**
 * localStorage key 工厂（standalone 形态唯一写盘点）
 */
export function snapshotStorageKey(courseId: string): string {
  return `dgbook:${courseId}:progress`;
}

/**
 * PlaybackEngineCallbacks · 状态机外部协作接口（design-only）
 *
 * 当前 BlockPlaybackEngine 已隐式具备 onSpeechStart/End；本接口把
 * onModeChange / onProgress 等正式化，留作 §3.3 重构时直接套用。
 */
export interface PlaybackEngineCallbacks {
  onModeChange?(mode: EngineMode): void;
  onSpeechStart?(text: string): void;
  onSpeechEnd?(): void;
  onProgress?(snapshot: PlaybackSnapshot): void;
  /** 用户暂停讲解、进入 live（AI 助教对话）模式 */
  onEnterLive?(topic?: string): void;
  /** 用户从 live 模式恢复讲解 */
  onResumeFromLive?(): void;
}
