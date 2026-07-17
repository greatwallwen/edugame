/**
 * EmbedProtocol.ts — DGBook 第三方嵌入 postMessage 协议
 *
 * 使 DGBook 课程播放器可嵌入第三方教学平台（如 LMS、在线实验平台）。
 *
 * 消息方向：
 *   Host → DGBook: 导航、控制播放、设置参数
 *   DGBook → Host: 学习事件、进度报告、互动结果
 *
 * 用法（Host 端）：
 *   <iframe src="https://dgbook.example.com/?page=p1-concept&embed=true" />
 *   window.addEventListener('message', (e) => { ... });
 */

// ── Host → DGBook 消息 ──

export interface NavigateMessage {
  type: 'dgbook:navigate';
  pageId: string;
}

export interface PlayMessage {
  type: 'dgbook:play';
}

export interface PauseMessage {
  type: 'dgbook:pause';
}

export interface SetConfigMessage {
  type: 'dgbook:config';
  config: {
    theme?: 'light' | 'dark';
    locale?: string;
    hideNav?: boolean;
    hideTutor?: boolean;
    autoPlay?: boolean;
  };
}

export type HostMessage =
  | NavigateMessage
  | PlayMessage
  | PauseMessage
  | SetConfigMessage;

// ── DGBook → Host 消息 ──

export interface ReadyEvent {
  type: 'dgbook:ready';
  version: string;
  courseId: string;
  totalPages: number;
}

export interface PageChangeEvent {
  type: 'dgbook:page-change';
  pageId: string;
  pageTitle: string;
  chapterId: string;
  pageIndex: number;
}

export interface ProgressEvent {
  type: 'dgbook:progress';
  visitedPages: number;
  totalPages: number;
  completionRate: number;  // 0~100
}

export interface InteractiveResultEvent {
  type: 'dgbook:interactive-result';
  pageId: string;
  blockId: string;
  interactiveKind: string;
  correct: boolean;
  attempts: number;
}

export interface FinaleResultEvent {
  type: 'dgbook:finale-result';
  pageId: string;
  rank: string;          // S/A/B/C/D
  score: number;
  maxScore: number;
  hp: number;
  combo: number;
}

export type DGBookEvent =
  | ReadyEvent
  | PageChangeEvent
  | ProgressEvent
  | InteractiveResultEvent
  | FinaleResultEvent;

// ── 嵌入工具函数 ──

/**
 * 向宿主页面发送事件（在 DGBook 内部调用）
 */
export function emitToHost(event: DGBookEvent): void {
  if (window.parent !== window) {
    window.parent.postMessage(event, '*');
  }
}

/**
 * 监听宿主页面消息（在 DGBook 内部调用）
 */
export function listenFromHost(handler: (msg: HostMessage) => void): () => void {
  const listener = (e: MessageEvent) => {
    const data = e.data;
    if (data && typeof data.type === 'string' && data.type.startsWith('dgbook:')) {
      handler(data as HostMessage);
    }
  };
  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}
