/**
 * @dgbook/types · 共享类型
 *
 * 里程碑映射：
 * - M0: 占位
 * - M2: manifest v3 schema（课程契约）
 * - M3: QuizSpec（单/多选 discriminated union）
 * - M4: ExtractedIndex（extractor → generator 的中间件契约）
 * - M6: ragflow-plus 调用协议
 * - M11: postMessage 宿主通信协议
 */

export const VERSION = '0.0.0' as const;

export * from './manifest';
export * from './extracted';

export * from './action';
export * from './playback';

// 平台能力层
export * from './SimulatorAdapter';
export * from './EmbedProtocol';
export * from './TutorAdapter';
