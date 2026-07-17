
import { useState, useMemo, useCallback } from 'react';
import './BitFlipBlock.css';

export interface BitFlipBlockProps {
  spec: {
    kind: 'bit-flip';
    prompt: string;
    registerName?: string;
    initial: number;
    target: number;
    explanation?: string;
    bitLabels?: string[]; // length 8
  };
  /** 提交答案时回调（correct + score）*/
  onAnswer?: (correct: boolean, score: number) => void;
}

const DEFAULT_LABELS = ['bit0', 'bit1', 'bit2', 'bit3', 'bit4', 'bit5', 'bit6', 'bit7'];

function toBinStr(v: number): string {
  return v.toString(2).padStart(8, '0');
}
function toHexStr(v: number): string {
  return '0x' + v.toString(16).padStart(2, '0').toUpperCase();
}

export function BitFlipBlock({ spec, onAnswer }: BitFlipBlockProps) {
  const [value, setValue] = useState<number>(spec.initial & 0xff);
  const [submitted, setSubmitted] = useState(false);
  const target = spec.target & 0xff;
  const labels = spec.bitLabels && spec.bitLabels.length === 8 ? spec.bitLabels : DEFAULT_LABELS;

  const isCorrect = value === target;
  const diffCount = useMemo(() => {
    let n = 0;
    for (let i = 0; i < 8; i++) {
      if (((value >> i) & 1) !== ((target >> i) & 1)) n++;
    }
    return n;
  }, [value, target]);

  const toggleBit = useCallback((bit: number) => {
    if (submitted) return;
    setValue((v) => v ^ (1 << bit));
  }, [submitted]);

  const handleSubmit = useCallback(() => {
    if (submitted) return;
    setSubmitted(true);
    onAnswer?.(isCorrect, isCorrect ? 100 : 0);
  }, [submitted, isCorrect, onAnswer]);

  const handleReset = useCallback(() => {
    setValue(spec.initial & 0xff);
    setSubmitted(false);
  }, [spec.initial]);

  return (
    <section className="dgb-bitflip" data-block-kind="bit-flip">
      <header className="dgb-bitflip__head">
        <h4 className="dgb-bitflip__prompt">{spec.prompt}</h4>
        {spec.registerName ? (
          <code className="dgb-bitflip__reg">{spec.registerName}</code>
        ) : null}
      </header>

      <div className="dgb-bitflip__target">
        <span className="dgb-bitflip__target-label">目标值：</span>
        <code className="dgb-bitflip__target-value">{toHexStr(target)}</code>
        <span className="dgb-bitflip__target-bin">（{toBinStr(target)}）</span>
      </div>

      {/* 8 个 bit cell，从高位到低位排列（左 bit7、右 bit0），与寄存器视觉对齐 */}
      <div className="dgb-bitflip__bits" role="group" aria-label="8 个可切换 bit">
        {[7, 6, 5, 4, 3, 2, 1, 0].map((i) => {
          const isOn = ((value >> i) & 1) === 1;
          const targetOn = ((target >> i) & 1) === 1;
          const matched = isOn === targetOn;
          return (
            <button
              key={i}
              type="button"
              className={`dgb-bitflip__cell ${isOn ? 'is-on' : 'is-off'} ${submitted ? (matched ? 'is-correct' : 'is-wrong') : ''}`}
              onClick={() => toggleBit(i)}
              disabled={submitted}
              aria-label={`${labels[i]} 当前 ${isOn ? '1' : '0'}`}
              aria-pressed={isOn}
            >
              <span className="dgb-bitflip__cell-val">{isOn ? '1' : '0'}</span>
              <span className="dgb-bitflip__cell-label">{labels[i]}</span>
            </button>
          );
        })}
      </div>

      <div className="dgb-bitflip__current">
        <span className="dgb-bitflip__current-label">当前值：</span>
        <code className={`dgb-bitflip__current-value ${isCorrect ? 'is-correct' : ''}`}>
          {toHexStr(value)}
        </code>
        <span className="dgb-bitflip__current-bin">（{toBinStr(value)}）</span>
        {!isCorrect && diffCount > 0 ? (
          <span className="dgb-bitflip__diff">差 {diffCount} 位</span>
        ) : null}
      </div>

      <div className="dgb-bitflip__actions">
        {!submitted ? (
          <button
            type="button"
            className="dgb-bitflip__btn dgb-bitflip__btn--primary"
            onClick={handleSubmit}
            disabled={!isCorrect && diffCount > 0 ? false : false}
          >
            提交
          </button>
        ) : (
          <button
            type="button"
            className="dgb-bitflip__btn dgb-bitflip__btn--ghost"
            onClick={handleReset}
          >
            重做
          </button>
        )}
      </div>

      {submitted ? (
        <div className={`dgb-bitflip__feedback ${isCorrect ? 'is-correct' : 'is-wrong'}`}>
          {isCorrect ? '✓ 正确！' : `✗ 不对，目标是 ${toHexStr(target)}`}
          {spec.explanation ? <p className="dgb-bitflip__explanation">{spec.explanation}</p> : null}
        </div>
      ) : null}
    </section>
  );
}
