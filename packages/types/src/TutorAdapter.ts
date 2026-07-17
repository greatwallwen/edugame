/**
 * TutorAdapter.ts — AI 助教能力抽象层
 *
 * 统一接口封装不同的 AI 助教后端（BFF RAG、OpenAI、本地模型等），
 * 使前端组件只依赖接口而非具体实现。
 *
 * 架构：
 *   RightPanel ChatInput → TutorAdapter.ask(question, context)
 *   ↓
 *   BffTutorAdapter / OpenAITutorAdapter / MockTutorAdapter
 *   ↓
 *   HTTP/WebSocket → 后端 AI 服务
 */

export interface TutorContext {
  courseId: string;
  pageId: string;
  chapterId: string;
  /** 当前页面的 block 内容摘要（帮助 AI 理解上下文） */
  pageContent?: string;
  /** 学生历史对话 */
  history?: TutorMessage[];
}

export interface TutorMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: string;
}

export interface TutorResponse {
  answer: string;
  /** 引用的知识源（RAG 检索结果） */
  sources?: Array<{
    title: string;
    snippet: string;
    relevance: number;
  }>;
  /** 后续建议问题 */
  suggestions?: string[];
}

export interface TutorAdapter {
  /** 适配器类型标识 */
  readonly type: string;

  /** 初始化连接 */
  init(config: { apiUrl: string; apiKey?: string }): Promise<void>;

  /** 提问（流式返回） */
  ask(question: string, context: TutorContext): Promise<TutorResponse>;

  /** 流式提问（逐 token 返回） */
  askStream?(
    question: string,
    context: TutorContext,
    onToken: (token: string) => void,
  ): Promise<TutorResponse>;

  /** 获取 FAQ（基于当前页面） */
  getFaq?(pageId: string): Promise<Array<{ question: string; answer: string }>>;

  /** 健康检查 */
  ping(): Promise<boolean>;
}

/**
 * BFF 助教适配器 — 通过 DGBook BFF API 对接 RAG 服务
 */
export class BffTutorAdapter implements TutorAdapter {
  readonly type = 'bff';
  private apiUrl = '';

  async init(config: { apiUrl: string }): Promise<void> {
    this.apiUrl = config.apiUrl;
  }

  async ask(question: string, context: TutorContext): Promise<TutorResponse> {
    const res = await fetch(`${this.apiUrl}/api/tutor/ask`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question, context }),
    });
    if (!res.ok) throw new Error(`Tutor API error: ${res.status}`);
    return res.json();
  }

  async ping(): Promise<boolean> {
    try {
      const res = await fetch(`${this.apiUrl}/api/tts/ping`);
      return res.ok;
    } catch { return false; }
  }
}

/**
 * Mock 适配器 — 开发测试用
 */
export class MockTutorAdapter implements TutorAdapter {
  readonly type = 'mock';
  async init(): Promise<void> {}

  async ask(question: string): Promise<TutorResponse> {
    return {
      answer: `这是关于 "${question}" 的模拟回答。在正式环境中，这里会返回 RAG 检索结果。`,
      suggestions: ['什么是 GPIO？', '定时器如何配置？', 'I2C 协议是什么？'],
    };
  }

  async ping(): Promise<boolean> { return true; }
}

/**
 * 助教适配器工厂
 */
export function createTutor(type: 'bff' | 'mock' = 'bff'): TutorAdapter {
  switch (type) {
    case 'bff': return new BffTutorAdapter();
    case 'mock': return new MockTutorAdapter();
    default: return new BffTutorAdapter();
  }
}
