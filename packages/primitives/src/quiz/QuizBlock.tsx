import { useMemo, useState } from 'react';
import type { QuizSpec } from '@dgbook/types';
import './QuizBlock.css';

export interface QuizBlockProps {
  /** 未找到题目时显示占位；ref 对齐 manifest.quizzes[key]。 */
  quiz?: QuizSpec;
  refId?: string;
}

type Status = 'idle' | 'submitted';

function sameSet(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false;
  const s = new Set(a);
  return b.every((x) => s.has(x));
}

/**
 * Quiz 原语：单选 / 多选 / 填空 / 判断，本地判分不持久化。
 */
export function QuizBlock({ quiz, refId }: QuizBlockProps) {
  const [picked, setPicked] = useState<string[]>([]);
  const [fillAnswer, setFillAnswer] = useState('');
  const [tfAnswer, setTfAnswer] = useState<boolean | null>(null);
  const [status, setStatus] = useState<Status>('idle');

  const isMulti = quiz?.kind === 'multiple-choice';
  const isFillBlank = quiz?.kind === 'fill-blank';
  const isTrueFalse = quiz?.kind === 'true-false';

  const correctIds = useMemo<string[]>(() => {
    if (!quiz) return [];
    if (quiz.kind === 'single-choice' || quiz.kind === 'multiple-choice') {
      return Array.isArray(quiz.answer) ? quiz.answer : [quiz.answer];
    }
    return [];
  }, [quiz]);

  if (!quiz) {
    return (
      <div className="dgb-quiz">
        <div className="dgb-quiz-missing">
          题库中未找到 <code>{refId ?? '(unknown)'}</code>；请检查 manifest.quizzes。
        </div>
      </div>
    );
  }

  const toggle = (id: string) => {
    if (status === 'submitted') return;
    if (isMulti) {
      setPicked((xs) => (xs.includes(id) ? xs.filter((x) => x !== id) : [...xs, id]));
    } else {
      setPicked([id]);
    }
  };

  const checkFillBlank = (): boolean => {
    if (!isFillBlank || !quiz || quiz.kind !== 'fill-blank') return false;
    const userAnswer = quiz.caseSensitive ? fillAnswer.trim() : fillAnswer.trim().toLowerCase();
    return quiz.answers.some((a) => {
      const correct = quiz.caseSensitive ? a.trim() : a.trim().toLowerCase();
      return userAnswer === correct;
    });
  };

  const checkTrueFalse = (): boolean => {
    if (!isTrueFalse || !quiz || quiz.kind !== 'true-false') return false;
    return tfAnswer === quiz.answer;
  };

  const passed = status === 'submitted' && (
    (isFillBlank && checkFillBlank()) ||
    (isTrueFalse && checkTrueFalse()) ||
    (!isFillBlank && !isTrueFalse && sameSet(picked, correctIds))
  );

  const optClass = (id: string) => {
    if (status !== 'submitted') return picked.includes(id) ? 'dgb-quiz-opt-checked' : '';
    if (correctIds.includes(id)) return 'dgb-quiz-opt-correct';
    if (picked.includes(id)) return 'dgb-quiz-opt-wrong';
    return '';
  };

  const canSubmit = () => {
    if (status === 'submitted') return false;
    if (isFillBlank) return fillAnswer.trim().length > 0;
    if (isTrueFalse) return tfAnswer !== null;
    return picked.length > 0;
  };

  const kindLabel = isMulti ? '多选' : isFillBlank ? '填空' : isTrueFalse ? '判断' : '单选';

  return (
    <div className="dgb-quiz">
      <p className="dgb-quiz-stem">
        <span className="dgb-quiz-kind">{kindLabel}</span>
        {quiz.stem}
      </p>

      {/* 单选/多选 */}
      {!isFillBlank && !isTrueFalse && (
        <div className="dgb-quiz-opts">
          {quiz.options.map((o) => (
            <label key={o.id} className={`dgb-quiz-opt ${optClass(o.id)}`}>
              <input
                type={isMulti ? 'checkbox' : 'radio'}
                name={`q-${quiz.id}`}
                checked={picked.includes(o.id)}
                onChange={() => toggle(o.id)}
                disabled={status === 'submitted'}
              />
              <span>{o.label}</span>
            </label>
          ))}
        </div>
      )}

      {/* 填空 */}
      {isFillBlank && quiz.kind === 'fill-blank' && (
        <div className="dgb-quiz-fill-blank">
          <input
            type="text"
            className={`dgb-quiz-fill-input ${status === 'submitted' ? (passed ? 'dgb-quiz-fill-correct' : 'dgb-quiz-fill-wrong') : ''}`}
            placeholder="请输入答案..."
            value={fillAnswer}
            onChange={(e) => setFillAnswer(e.target.value)}
            disabled={status === 'submitted'}
            onKeyDown={(e) => { if (e.key === 'Enter' && canSubmit()) setStatus('submitted'); }}
          />
          {status === 'submitted' && !passed && (
            <div className="dgb-quiz-fill-answer">
              正确答案：{quiz.answers.join(' / ')}
            </div>
          )}
        </div>
      )}

      {/* 判断 */}
      {isTrueFalse && quiz.kind === 'true-false' && (
        <div className="dgb-quiz-tf-opts">
          <button
            type="button"
            className={`dgb-quiz-tf-btn ${tfAnswer === true ? 'dgb-quiz-tf-selected' : ''} ${status === 'submitted' ? (quiz.answer === true ? 'dgb-quiz-tf-correct' : tfAnswer === true ? 'dgb-quiz-tf-wrong' : '') : ''}`}
            onClick={() => setTfAnswer(true)}
            disabled={status === 'submitted'}
          >
            ✓ 正确
          </button>
          <button
            type="button"
            className={`dgb-quiz-tf-btn ${tfAnswer === false ? 'dgb-quiz-tf-selected' : ''} ${status === 'submitted' ? (quiz.answer === false ? 'dgb-quiz-tf-correct' : tfAnswer === false ? 'dgb-quiz-tf-wrong' : '') : ''}`}
            onClick={() => setTfAnswer(false)}
            disabled={status === 'submitted'}
          >
            ✗ 错误
          </button>
        </div>
      )}

      <div className="dgb-quiz-actions">
        <button
          type="button"
          className="dgb-quiz-submit"
          onClick={() => setStatus('submitted')}
          disabled={!canSubmit()}
        >
          提交
        </button>
        {status === 'submitted' ? (
          <button
            type="button"
            className="dgb-quiz-reset"
            onClick={() => {
              setPicked([]);
              setFillAnswer('');
              setTfAnswer(null);
              setStatus('idle');
            }}
          >
            重做
          </button>
        ) : null}
      </div>
      {status === 'submitted' ? (
        <div className={`dgb-quiz-feedback ${passed ? 'dgb-quiz-feedback-ok' : 'dgb-quiz-feedback-ng'}`}>
          {passed ? '✓ 回答正确！' : '✗ 尚未答对，再看一遍题干试试。'}
          {passed && <span className="dgb-quiz-score">🎯 +10 分</span>}
          {quiz.explanation ? <div style={{ marginTop: 6 }}>{quiz.explanation}</div> : null}
        </div>
      ) : null}
    </div>
  );
}
