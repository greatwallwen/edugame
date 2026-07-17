import './SummaryBlock.css';

export interface SummaryBlockProps {
  keyPoints: string[];
  nextLessonId?: string;
  reviewQuestions?: string[];
  /** 点击「下一课」时的导航回调（由 PageRenderer 注入） */
  onNavigateNext?: (lessonId: string) => void;
}

export function SummaryBlock({ keyPoints, nextLessonId, reviewQuestions, onNavigateNext }: SummaryBlockProps) {
  return (
    <div className="dgb-summary">
      <div className="dgb-summary-head">
        <span className="dgb-summary-badge">📝 课后总结</span>
      </div>
      <ul className="dgb-summary-points">
        {keyPoints.map((p, i) => (
          <li key={i} className="dgb-summary-point">
            <span className="dgb-summary-num">{i + 1}</span>
            <span className="dgb-summary-text">{p}</span>
          </li>
        ))}
      </ul>
      {reviewQuestions && reviewQuestions.length > 0 ? (
        <div className="dgb-summary-review">
          <strong className="dgb-summary-review-title">💭 自测问题</strong>
          <ol className="dgb-summary-review-list">
            {reviewQuestions.map((q, i) => (
              <li key={i} className="dgb-summary-review-item">{q}</li>
            ))}
          </ol>
        </div>
      ) : null}
      {/* 页底 CTA：「下一页」导航按钮 */}
      {nextLessonId && nextLessonId !== '' ? (
        <div className="dgb-summary-next-cta">
          <div className="dgb-summary-next-label">✅ 本节已完成，继续学习下一课</div>
          <button
            type="button"
            className="dgb-summary-next-btn"
            onClick={() => onNavigateNext?.(nextLessonId)}
          >
            下一课 →
          </button>
        </div>
      ) : null}
    </div>
  );
}
