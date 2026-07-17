/**
 * FinaleResult · 结算页（pass / fail 共用）
 *
 * 功能：
 *  - 段位徽章（S+ ~ C）+ 通关 / 失败标题
 *  - 三宫格统计（分数 / 连击峰值 / 用时）
 *  - [重玩][继续学习][跳回错题点] 三按钮
 *  - 失败页温和文案 + 错题列表
 *
 * 跳回错题点的实际滚动 / 高亮由父级（FinaleChallenge）通过 onJumpToAnchor 落地，
 * 这里只暴露按钮 + 报 anchor。
 */
import type { FinaleEngineState, FinaleHistoryEntry, FinaleRank } from './types';

export interface FinaleResultProps {
  phase: 'result-pass' | 'result-fail';
  state: FinaleEngineState;
  rank: FinaleRank;
  challengeTitle: string;
  onReplay: () => void;
  onContinue: () => void;
  onJumpToAnchor?: (anchor: string) => void;
  /** 课后总结要点（来自 finale block.summaryPoints） */
  summaryPoints?: string[];
}

const RANK_TITLE: Record<FinaleRank, string> = {
  'S+': '王者',
  S: '钻石',
  A: '黄金',
  B: '白银',
  C: '青铜',
};

const PASS_HEADLINES: Record<FinaleRank, string> = {
  'S+': '完美无瑕，可以教别人了 👑',
  S: '炉火纯青 ✨',
  A: '游刃有余 ⚡',
  B: '稳过通关 ✅',
  C: '过了，但可以更好 🌱',
};

function formatDuration(ms: number): string {
  const sec = Math.round(ms / 1000);
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return m > 0 ? `${m}分${s}秒` : `${s}秒`;
}

function summarizeHistory(history: FinaleHistoryEntry[]): {
  totalTimeMs: number;
  correctCount: number;
  wrongCount: number;
  wrongs: FinaleHistoryEntry[];
} {
  let totalTimeMs = 0;
  let correctCount = 0;
  const wrongs: FinaleHistoryEntry[] = [];
  for (const e of history) {
    totalTimeMs += e.timeUsedMs;
    if (e.correct) correctCount++;
    else wrongs.push(e);
  }
  return {
    totalTimeMs,
    correctCount,
    wrongCount: wrongs.length,
    wrongs,
  };
}

export function FinaleResult({
  phase,
  state,
  rank,
  challengeTitle,
  onReplay,
  onContinue,
  onJumpToAnchor,
  summaryPoints,
}: FinaleResultProps) {
  const summary = summarizeHistory(state.history);
  const isFail = phase === 'result-fail';
  const headline = isFail
    ? '差一点点 — 把刚才不熟的地方再过一遍 💡'
    : PASS_HEADLINES[rank];

  return (
    <section className="dgb-finale-result dgb-finale-enter" aria-live="polite">
      <div
        className={`dgb-finale-result__rank${isFail ? ' is-fail' : ''}`}
        aria-label={`段位 ${rank}`}
      >
        {rank}
      </div>
      <h2 className={`dgb-finale-result__title${isFail ? ' is-fail' : ''}`}>
        {isFail ? `${challengeTitle} · 未通关` : `${challengeTitle} · ${RANK_TITLE[rank]}`}
      </h2>
      <p style={{ color: 'var(--finale-fg-mute)', margin: 0 }}>{headline}</p>

      <div className="dgb-finale-result__stats">
        <div className="dgb-finale-result__stat">
          <div className="dgb-finale-result__stat-value">{state.score}</div>
          <div className="dgb-finale-result__stat-label">总分</div>
        </div>
        <div className="dgb-finale-result__stat">
          <div className="dgb-finale-result__stat-value">×{state.comboPeak}</div>
          <div className="dgb-finale-result__stat-label">连击峰值</div>
        </div>
        <div className="dgb-finale-result__stat">
          <div className="dgb-finale-result__stat-value">
            {summary.correctCount}/{state.history.length || summary.correctCount}
          </div>
          <div className="dgb-finale-result__stat-label">正确率</div>
        </div>
      </div>

      <div style={{ color: 'var(--finale-fg-mute)', fontSize: 13, marginTop: 6 }}>
        总用时 {formatDuration(summary.totalTimeMs)} · HP 剩余 {state.hp}/{state.hpMax}
      </div>

      <div className="dgb-finale-result__actions">
        <button
          type="button"
          className="dgb-finale-result__action is-primary"
          onClick={onReplay}
        >
          {isFail ? '再来一次' : '挑战更高段位'}
        </button>
        <button
          type="button"
          className="dgb-finale-result__action"
          onClick={onContinue}
        >
          继续学习
        </button>
      </div>

      {summaryPoints && summaryPoints.length > 0 ? (
        <div className="dgb-finale-result__summary">
          <div className="dgb-finale-result__summary-title">
            📌 课后总结要点（全部解锁）
          </div>
          <ul className="dgb-finale-result__summary-list">
            {summaryPoints.map((pt, i) => (
              <li key={i} className="dgb-finale-result__summary-item">
                <span className="dgb-finale-result__summary-num">
                  {String(i + 1).padStart(2, '0')}
                </span>
                <span className="dgb-finale-result__summary-text">{pt}</span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      {summary.wrongs.length > 0 ? (
        <div className="dgb-finale-result__missed">
          <div style={{ fontWeight: 600, color: 'var(--finale-fg)' }}>
            ⚠ 错题回顾（{summary.wrongs.length} 道）
          </div>
          <ul className="dgb-finale-result__missed-list">
            {summary.wrongs.map((w) => (
              <li key={`${w.stageId}-${w.questionId}`}>
                {w.stageId} · {w.questionId}
                {w.knowledgeAnchor && onJumpToAnchor ? (
                  <button
                    type="button"
                    onClick={() => onJumpToAnchor(w.knowledgeAnchor!)}
                    style={{
                      marginLeft: 8,
                      background: 'transparent',
                      border: 'none',
                      color: 'var(--finale-accent-2)',
                      cursor: 'pointer',
                      textDecoration: 'underline',
                    }}
                  >
                    跳回知识点
                  </button>
                ) : null}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}
