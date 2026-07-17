/**
 * RightPanel · AI 助教侧栏
 *
 * 从 Shell.tsx 抽出，Shell 仅注入 props。
 */
import { ChatMarkdown } from './ChatMarkdown';
import { IconSend } from './icons';
import s from './Shell.module.css';
import type { AiTutorState, FaqItem } from '@dgbook/tutor';

interface RightPanelProps {
  aiName: string;
  aiSubtitle: string;
  aiWelcome: string;
  aiAvatarEmoji?: string;
  aiTutorEnabled: boolean;
  tutor: AiTutorState;
  pageFaq: FaqItem[];
  WelcomeBubble: React.ComponentType<{ text: string }>;
  /** 讨论模式：播放引擎处于 live / pause-for-discussion 状态 */
  isLive?: boolean;
  /** 结束讨论回调 */
  onEndDiscussion?: () => void;
}

export function RightPanel(props: RightPanelProps) {
  const {
    aiName, aiSubtitle, aiWelcome, aiAvatarEmoji,
    aiTutorEnabled, tutor, pageFaq, WelcomeBubble,
    isLive, onEndDiscussion,
  } = props;

  return (
    <aside className={`${s.right} ${s.rightPanel}`}>
      {isLive && (
        <div className={s.rpDiscussionBanner}>
          <span>💬 讨论模式：自由探索，可向 AI 提问</span>
          {onEndDiscussion && (
            <button type="button" className={s.rpEndDiscussionBtn} onClick={onEndDiscussion}>
              结束讨论
            </button>
          )}
        </div>
      )}
      <div className={s.rpHeader}>
        <div className={s.rpAvatar} aria-hidden>
          {aiAvatarEmoji ? (
            <span className={s.rpAvatarEmoji}>{aiAvatarEmoji}</span>
          ) : (
            <span className={s.rpAvatarChar}>
              {(aiName || '助').trim().charAt(0)}
            </span>
          )}
        </div>
        <div className={s.rpHeaderText}>
          <div className={s.rpTitle}>{aiName}</div>
          {aiSubtitle && <div className={s.rpTitleSub}>{aiSubtitle}</div>}
        </div>
      </div>
      <WelcomeBubble text={aiWelcome} />

      {tutor.chatOpen && (
        <div className={s.rpChat}>
          {tutor.messages.map((m, i) => (
            <div key={i}>
              <div className={`${s.rpChatMsg} ${m.role === 'user' ? s.rpChatUser : s.rpChatTutor}`}>
                <span className={s.rpChatRole}>{m.role === 'user' ? '我' : aiName}</span>
                {m.role === 'user'
                  ? <span className={s.rpChatText}>{m.text}</span>
                  : <div className={s.rpChatText}>
                      <ChatMarkdown
                        content={m.text}
                        streaming={tutor.streaming && i === tutor.messages.length - 1}
                      />
                    </div>
                }
              </div>
              {m.role === 'tutor' && m.sources && m.sources.length > 0 ? (
                <div className={s.rpChatSources}>
                  {m.sources.map((source, idx) => (
                    <span key={`${source.chunkId ?? source.pageKey ?? idx}-${idx}`} className={s.rpChatSourceTag}>
                      来源 {idx + 1}{source.pageKey ? ` · ${source.pageKey}` : ''}
                    </span>
                  ))}
                </div>
              ) : null}
              {aiTutorEnabled && m.role === 'tutor' && m.followUps && m.followUps.length > 0 && i === tutor.messages.length - 1 && !tutor.streaming && (
                <div className={s.rpFollowUps}>
                  <span className={s.rpFollowUpsLabel}>继续追问</span>
                  {m.followUps.map((q, fi) => (
                    <button key={fi} type="button" className={s.rpFollowUpBtn} onClick={() => tutor.askFollowUp(q)}>
                      {q}
                    </button>
                  ))}
                </div>
              )}
            </div>
          ))}
          {tutor.loading && !tutor.streaming && (
            <div className={s.rpChatLoading}>
              <span className={s.rpChatLoadingDot} />
              <span className={s.rpChatLoadingDot} />
              <span className={s.rpChatLoadingDot} />
              <span>{aiName} 正在思考…</span>
            </div>
          )}
        </div>
      )}

      {aiTutorEnabled && (
      <div className={s.rpChatInputRow}>
        <input
          className={s.rpChatInput}
          placeholder="问我任何问题…"
          value={tutor.draft}
          onChange={(e) => tutor.setDraft(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') { tutor.openAndSubmit(); } }}
        />
        <button
          className={s.rpChatSend}
          type="button"
          onClick={() => { tutor.openAndSubmit(); }}
          disabled={!tutor.draft.trim() || tutor.loading || tutor.streaming}
          aria-label="发送"
        >
          <IconSend size={14} />
        </button>
      </div>
      )}

      {pageFaq.length > 0 && (
        <div className={s.rpFaqSection}>
          <div className={s.rpFaqTitle}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
              <circle cx="12" cy="12" r="10" /><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" /><line x1="12" y1="17" x2="12.01" y2="17" />
            </svg>
            本节快问
          </div>
          <div className={s.rpFaqChips}>
            {pageFaq.slice(0, 5).map((item, i) => (
              <button
                key={i}
                type="button"
                className={s.rpQuickQ}
                onClick={() => tutor.askFaq(item.q, item.a)}
                title={item.q}
              >
                {item.q}
              </button>
            ))}
          </div>
        </div>
      )}
    </aside>
  );
}
