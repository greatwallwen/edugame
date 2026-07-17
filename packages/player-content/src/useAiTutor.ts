/**
 * useAiTutor · AI 助教对话 hook
 *
 * 把原 Shell.tsx 中 chatOpen / chatDraft / chatStreaming / chatMsgs / submitChat /
 * askFaq / askFollowUp 全套 state + 流式 SSE 提交逻辑封装。
 *
 * Shell 仅负责 layout，对话状态机一律走本 hook。
 */
import { useCallback, useState } from 'react';
import type { Page } from '@dgbook/types';
import { generateFollowUps } from './follow-up-templates';
import type { DomainTerm, FollowUpTemplate } from './domain-terms';

export interface ChatSource {
  chunkId?: string;
  pageKey?: string;
  score?: number;
}

export interface ChatMessage {
  role: 'tutor' | 'user';
  text: string;
  sources?: ChatSource[];
  followUps?: string[];
}

export interface UseAiTutorOptions {
  /** features.aiTutor=false 时所有提交 no-op（offline 静态包） */
  enabled: boolean;
  courseId: string;
  /** 当前页（用于派生 followUp 上下文） */
  activePage: Page | undefined;
  /** RAG 检索 pageKey */
  pageSourceKey?: string;
  aiName: string;
  /** 从 manifest.domainTerms 注入 */
  domainTerms?: ReadonlyArray<DomainTerm>;
  /** 从 manifest.followUpTemplates 注入 */
  followUpTemplates?: ReadonlyArray<FollowUpTemplate>;
}

export interface AiTutorState {
  chatOpen: boolean;
  draft: string;
  setDraft: (v: string) => void;
  messages: ChatMessage[];
  loading: boolean;
  streaming: boolean;
  /** 提交输入框中的 draft；自动 setChatOpen(true) */
  openAndSubmit: () => Promise<void>;
  /** 点击 FAQ chip：直接展示 q+a 对，不走 BFF */
  askFaq: (q: string, a: string) => void;
  /** 点击追问 chip：填回输入框、展开对话、不立即发送 */
  askFollowUp: (q: string) => void;
}

/** 本 hook 不依赖 React Context；Shell 直接调用即可。 */
export function useAiTutor(opts: UseAiTutorOptions): AiTutorState {
  const { enabled, courseId, activePage, pageSourceKey, aiName, domainTerms, followUpTemplates } = opts;
  const [chatOpen, setChatOpen] = useState(false);
  const [draft, setDraft] = useState('');
  const [streaming, setStreaming] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(false);

  const submit = useCallback(async () => {
    if (!enabled) return;
    const v = draft.trim();
    if (!v || loading || streaming) return;
    setMessages((prev) => [...prev, { role: 'user', text: v }]);
    setDraft('');
    setLoading(true);
    setMessages((prev) => [...prev, { role: 'tutor', text: '' }]);
    setStreaming(true);

    const body = JSON.stringify({
      courseId,
      question: v,
      pageKey: pageSourceKey,
      topK: 3,
    });

    try {
      const resp = await fetch('/api/chat/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
      });
      if (!resp.ok || !resp.body) throw new Error(`HTTP ${resp.status}`);

      const reader = resp.body.getReader();
      const decoder = new TextDecoder();
      let accumulated = '';
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';
        for (const line of lines) {
          if (!line.startsWith('data:')) continue;
          const raw = line.slice(5).trim();
          if (raw === '[DONE]') break;
          try {
            const chunk = JSON.parse(raw);
            if (chunk.content) {
              accumulated += chunk.content;
              const snap = accumulated;
              setMessages((prev) => {
                const next = [...prev];
                const last = next[next.length - 1];
                if (last && last.role === 'tutor') {
                  next[next.length - 1] = { ...last, text: snap };
                }
                return next;
              });
            }
          } catch { /* ignore parse error */ }
        }
      }
      const followUps = generateFollowUps(v, accumulated, activePage?.title, domainTerms, followUpTemplates);
      setMessages((prev) => {
        const next = [...prev];
        const last = next[next.length - 1];
        if (last && last.role === 'tutor') {
          next[next.length - 1] = { ...last, followUps };
        }
        return next;
      });
    } catch (err) {
      setMessages((prev) => {
        const next = [...prev];
        const last = next[next.length - 1];
        if (last && last.role === 'tutor') {
          next[next.length - 1] = {
            ...last,
            text: `AI 服务暂时不可用（${(err as Error).message}）。请确认 BFF 已启动。`,
          };
        }
        return next;
      });
    } finally {
      setLoading(false);
      setStreaming(false);
    }
  }, [enabled, draft, loading, streaming, courseId, pageSourceKey, activePage]);

  const openAndSubmit = useCallback(async () => {
    setChatOpen(true);
    await submit();
  }, [submit]);

  const askFaq = useCallback(
    (q: string, a: string) => {
      setChatOpen(true);
      const followUps = generateFollowUps(q, a, activePage?.title, domainTerms, followUpTemplates);
      setMessages([
        { role: 'user', text: q },
        { role: 'tutor', text: a, followUps },
      ]);
    },
    [activePage],
  );

  const askFollowUp = useCallback((q: string) => {
    setDraft(q);
    setChatOpen(true);
  }, []);

  void aiName; // 保留接口兼容（未来可在错误兜底里使用）

  return {
    chatOpen, draft, setDraft, messages, loading, streaming,
    openAndSubmit, askFaq, askFollowUp,
  };
}
