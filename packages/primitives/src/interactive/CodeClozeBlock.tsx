/**
 * CodeClozeBlock — 代码填空互动组件 (Iter-34 / T-CD, Bloom L3 应用)
 *
 * 与 FillBlankBlock 的差异：
 *   - 单行/多行代码模板，等宽字体 + 语法语义标签
 *   - 多答案接受（一个 blank 可对应多个等价答案）
 *   - normalized/exact 校验级别
 *
 * 用法（manifest）：
 *   {
 *     kind: 'interactive',
 *     spec: {
 *       kind: 'code-cloze',
 *       language: 'c',
 *       template: 'HAL_GPIO_WritePin({{port}}, {{pin}}, {{state}});',
 *       blanks: [
 *         { id: 'port', accepted: ['GPIOA', 'GPIOB'] },
 *         ...
 *       ],
 *     },
 *   }
 */
import { useMemo, useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import './CodeClozeBlock.css';

type CodeClozeSpec = Extract<InteractiveSpec, { kind: 'code-cloze' }>;

export interface CodeClozeBlockProps {
  spec: CodeClozeSpec;
  /** 答题完成回调（correct=全对 / score 0-100 = 答对比例 × 100） */
  onAnswer?: (correct: boolean, score: number) => void;
}

interface ParsedSegment {
  type: 'text' | 'blank';
  content: string;
}

/** 把模板按 {{blank-id}} 切片为 text/blank 交替的 segment 数组 */
function parseTemplate(template: string): ParsedSegment[] {
  const out: ParsedSegment[] = [];
  const re = /\{\{([a-z0-9_-]+)\}\}/gi;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(template)) !== null) {
    if (m.index > last) out.push({ type: 'text', content: template.slice(last, m.index) });
    out.push({ type: 'blank', content: m[1] ?? '' });
    last = m.index + m[0].length;
  }
  if (last < template.length) out.push({ type: 'text', content: template.slice(last) });
  return out;
}

/** 校验单个 blank 的输入是否被接受 */
function checkBlank(
  spec: CodeClozeSpec,
  blankId: string,
  value: string,
): boolean {
  const blank = spec.blanks.find((b) => b.id === blankId);
  if (!blank) return false;
  const norm = (sx: string) => (spec.validate === 'exact' ? sx : sx.trim());
  return blank.accepted.some((a) => norm(a) === norm(value));
}

export function CodeClozeBlock({ spec, onAnswer }: CodeClozeBlockProps) {
  const [values, setValues] = useState<Record<string, string>>({});
  const [submitted, setSubmitted] = useState(false);
  const segments = useMemo(() => parseTemplate(spec.template), [spec.template]);

  const handleSubmit = () => {
    setSubmitted(true);
    const correctCount = spec.blanks.filter((b) =>
      checkBlank(spec, b.id, values[b.id] ?? ''),
    ).length;
    const allCorrect = correctCount === spec.blanks.length;
    const score = Math.round((correctCount / Math.max(1, spec.blanks.length)) * 100);
    onAnswer?.(allCorrect, score);
  };

  const handleReset = () => {
    setValues({});
    setSubmitted(false);
  };

  const allFilled = spec.blanks.every((b) => (values[b.id] ?? '').length > 0);

  return (
    <div className="dgb-cc-root" data-language={spec.language} data-testid="code-cloze-block">
      {spec.prompt && <p className="dgb-cc-prompt">{spec.prompt}</p>}

      <pre className="dgb-cc-code">
        <code className={`language-${spec.language}`}>
          {segments.map((seg, i) => {
            if (seg.type === 'text') {
              return <span key={`t-${i}`} className="dgb-cc-text">{seg.content}</span>;
            }
            const correct = submitted && checkBlank(spec, seg.content, values[seg.content] ?? '');
            const wrong = submitted && !correct;
            return (
              <input
                key={`b-${seg.content}-${i}`}
                type="text"
                spellCheck={false}
                autoCapitalize="off"
                autoCorrect="off"
                value={values[seg.content] ?? ''}
                onChange={(e) =>
                  setValues((prev) => ({ ...prev, [seg.content]: e.target.value }))
                }
                disabled={submitted}
                className={[
                  'dgb-cc-blank',
                  correct ? 'dgb-cc-blank--correct' : '',
                  wrong ? 'dgb-cc-blank--wrong' : '',
                ].filter(Boolean).join(' ')}
                aria-label={`代码填空 ${seg.content}`}
                data-blank-id={seg.content}
              />
            );
          })}
        </code>
      </pre>

      {submitted && (
        <ul className="dgb-cc-feedback">
          {spec.blanks.map((b) => {
            const v = values[b.id] ?? '';
            const ok = checkBlank(spec, b.id, v);
            return (
              <li key={b.id} className={ok ? 'dgb-cc-fb-ok' : 'dgb-cc-fb-bad'}>
                <code className="dgb-cc-fb-id">{b.id}</code>
                {ok ? ' ✓ ' : ' ✗ '}
                <span className="dgb-cc-fb-value">{v || '(空)'}</span>
                {!ok && <span className="dgb-cc-fb-expected">正确答案：{b.accepted.join(' / ')}</span>}
                {b.rationale && <span className="dgb-cc-fb-rationale">{b.rationale}</span>}
              </li>
            );
          })}
        </ul>
      )}

      <div className="dgb-cc-actions">
        {!submitted ? (
          <button
            type="button"
            className="dgb-cc-submit"
            disabled={!allFilled}
            onClick={handleSubmit}
          >
            提交
          </button>
        ) : (
          <button type="button" className="dgb-cc-reset" onClick={handleReset}>
            重做
          </button>
        )}
      </div>
    </div>
  );
}
