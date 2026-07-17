import { useState, useCallback, useEffect, useRef } from 'react';
import './CodeBlock.css';

/** code-flow 单 step（高亮窗口）*/
export interface CodeFlowStep {
  id: string;
  title?: string;
  /** 该 step 激活时覆盖父 CodeBlock.highlightLines（行号 1-based）*/
  highlightLines?: number[];
}

/** code-flow 流程图 + step 联动数据。*/
export interface CodeFlowSpec {
  format: 'mermaid';
  source: string;
  steps?: CodeFlowStep[];
}

export interface CodeBlockProps {
  language: string;
  code: string;
  filename?: string;
  highlightLines?: number[];
  explanation?: string;
  /** 可选流程图 + step 联动；存在时双列 layout。*/
  flow?: CodeFlowSpec;
  /** 外控当前 step（受控模式）。给定时优先于内部 state。*/
  currentStepIdx?: number;
  /** step 变化回调（可双控）。*/
  onStepChange?: (idx: number) => void;
  /** 额外高亮词（从 manifest.codeHighlightExtras 注入，平台零课程词） */
  extraKeywords?: Record<string, string[]>;
  extraBuiltins?: Record<string, string[]>;
}

const BASE_KEYWORDS: Record<string, string[]> = {
  c: ['int', 'void', 'return', 'if', 'else', 'for', 'while', 'switch', 'case', 'break', 'continue', 'struct', 'typedef', 'static', 'const', '#include', '#define', 'uint8_t', 'uint16_t', 'uint32_t'],
  cpp: ['class', 'public', 'private', 'protected', 'virtual', 'override', 'template', 'typename', 'auto', 'constexpr'],
  python: ['def', 'class', 'import', 'from', 'return', 'if', 'elif', 'else', 'for', 'while', 'try', 'except', 'with', 'as', 'lambda', 'None', 'True', 'False'],
  javascript: ['function', 'const', 'let', 'var', 'return', 'if', 'else', 'for', 'while', 'switch', 'case', 'break', 'class', 'import', 'export', 'async', 'await'],
  typescript: ['interface', 'type', 'enum', 'implements', 'extends', 'namespace', 'declare', 'readonly', 'abstract'],
};

const BASE_BUILTINS: Record<string, string[]> = {
  c: ['printf', 'scanf', 'malloc', 'free', 'strlen', 'memcpy', 'memset', 'sprintf'],
  python: ['print', 'len', 'range', 'map', 'filter', 'enumerate', 'zip', 'open', 'int', 'str', 'list', 'dict'],
};

function mergeExtras(base: Record<string, string[]>, extras?: Record<string, string[]>): Record<string, string[]> {
  if (!extras) return base;
  const merged = { ...base };
  for (const [lang, words] of Object.entries(extras)) {
    merged[lang] = [...(merged[lang] || []), ...words];
  }
  return merged;
}

function tokenize(code: string, lang: string, keywords: Record<string, string[]>, builtins: Record<string, string[]>): { text: string; type: 'plain' | 'keyword' | 'string' | 'comment' | 'number' | 'builtin' }[] {
  const kw = new Set(keywords[lang] || []);
  const bi = new Set(builtins[lang] || []);
  const tokens: { text: string; type: any }[] = [];
  const re = /(\/\/[^\n]*|\/\*[\s\S]*?\*\/|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|\b0[xX][0-9a-fA-F]+\b|\b\d+\.?\d*\b|#\s*\w+|\b\w+\b|[^\w\s]|[ \t]+|\n)/g;
  let m;
  while ((m = re.exec(code)) !== null) {
    const t = m[1] ?? '';
    let type: any = 'plain';
    if (t.startsWith('//') || t.startsWith('/*')) type = 'comment';
    else if (t.startsWith('"') || t.startsWith("'")) type = 'string';
    else if (/^\b\d/.test(t) || /^0[xX]/.test(t)) type = 'number';
    else if (kw.has(t)) type = 'keyword';
    else if (bi.has(t)) type = 'builtin';
    else if (t.startsWith('#')) type = 'keyword';
    tokens.push({ text: t, type });
  }
  return tokens;
}

export function CodeBlock({
  language, code, filename, highlightLines, explanation,
  flow, currentStepIdx, onStepChange,
  extraKeywords, extraBuiltins,
}: CodeBlockProps) {
  const keywords = mergeExtras(BASE_KEYWORDS, extraKeywords);
  const builtins = mergeExtras(BASE_BUILTINS, extraBuiltins);
  const [showExp, setShowExp] = useState(false);
  const [copied, setCopied] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [localStepIdx, setLocalStepIdx] = useState(0);

  const hasFlow = !!(flow && flow.format === 'mermaid' && flow.source);
  const steps = flow?.steps ?? [];
  const externalIdx = currentStepIdx;
  const requestedIdx = externalIdx ?? localStepIdx;
  const safeActiveIdx = steps.length > 0
    ? Math.max(0, Math.min(requestedIdx, steps.length - 1))
    : 0;
  const activeStep = steps[safeActiveIdx];
  const effectiveHighlightLines = activeStep?.highlightLines?.length
    ? activeStep.highlightLines
    : highlightLines;

  const setStep = useCallback((idx: number) => {
    if (steps.length === 0) return;
    const safe = Math.max(0, Math.min(idx, steps.length - 1));
    setLocalStepIdx(safe);
    onStepChange?.(safe);
  }, [steps.length, onStepChange]);

  const lines = code.split('\n');
  const hlSet = new Set(effectiveHighlightLines || []);

  const copy = useCallback(() => {
    navigator.clipboard?.writeText(code).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    });
  }, [code]);

  // ESC 关闭全屏
  useEffect(() => {
    if (!fullscreen) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setFullscreen(false); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [fullscreen]);

  const langLabel = language.toUpperCase();

  const codeContent = (
    <figure className="dgb-code">
      <figcaption className="dgb-code-cap">
        <span className="dgb-code-lang">{langLabel}</span>
        {filename ? <span className="dgb-code-file">{filename}</span> : null}
        <span className="dgb-code-grow" />
        <button type="button" className="dgb-code-copy" onClick={copy}>
          {copied ? '✓ 已复制' : '复制'}
        </button>
        <button
          type="button"
          className="dgb-code-fullscreen"
          onClick={() => setFullscreen((s) => !s)}
          title={fullscreen ? '退出全屏' : '全屏查看'}
          aria-label={fullscreen ? '退出全屏' : '全屏查看'}
        >
          {fullscreen ? (
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M8 3v3a2 2 0 0 1-2 2H3M21 8h-3a2 2 0 0 1-2-2V3M3 16h3a2 2 0 0 1 2 2v3M16 21v-3a2 2 0 0 1 2-2h3" />
            </svg>
          ) : (
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M3 7V3h4M21 7V3h-4M3 17v4h4M21 17v4h-4" />
            </svg>
          )}
          {fullscreen ? '退出' : '全屏'}
        </button>
      </figcaption>
      {hasFlow ? (
        <div className="dgb-codeflow-layout">
          <aside className="dgb-codeflow-pane">
            <MermaidPane source={flow!.source} />
            {steps.length > 0 ? (
              <ol className="dgb-codeflow-steps">
                {steps.map((s, i) => (
                  <li
                    key={s.id}
                    className={`dgb-codeflow-step ${i === safeActiveIdx ? 'is-active' : ''}`}
                  >
                    <button
                      type="button"
                      className="dgb-codeflow-step-btn"
                      onClick={() => setStep(i)}
                      aria-current={i === safeActiveIdx ? 'step' : undefined}
                    >
                      <span className="dgb-codeflow-step-idx">{i + 1}</span>
                      <span className="dgb-codeflow-step-title">{s.title || s.id}</span>
                    </button>
                  </li>
                ))}
              </ol>
            ) : null}
          </aside>
          <pre className="dgb-code-pre dgb-codeflow-codepane">
            <code className="dgb-code-body">
              {lines.map((line, i) => (
                <div key={i} className={`dgb-code-line ${hlSet.has(i + 1) ? 'highlight' : ''}`}>
                  <span className="dgb-code-lineno">{i + 1}</span>
                  <span className="dgb-code-content">
                    {tokenize(line, language, keywords, builtins).map((t, j) => (
                      <span key={j} className={`dgb-code-${t.type}`}>{t.text}</span>
                    ))}
                  </span>
                </div>
              ))}
            </code>
          </pre>
        </div>
      ) : (
        <pre className="dgb-code-pre">
          <code className="dgb-code-body">
            {lines.map((line, i) => (
              <div key={i} className={`dgb-code-line ${hlSet.has(i + 1) ? 'highlight' : ''}`}>
                <span className="dgb-code-lineno">{i + 1}</span>
                <span className="dgb-code-content">
                  {tokenize(line, language, keywords, builtins).map((t, j) => (
                    <span key={j} className={`dgb-code-${t.type}`}>{t.text}</span>
                  ))}
                </span>
              </div>
            ))}
          </code>
        </pre>
      )}
      {explanation ? (
        <div className="dgb-code-exp">
          <button type="button" className="dgb-code-exp-toggle" onClick={() => setShowExp((s) => !s)}>
            {showExp ? '▾ 隐藏解析' : '▸ 代码解析'}
          </button>
          {showExp ? <div className="dgb-code-exp-body">{explanation}</div> : null}
        </div>
      ) : null}
    </figure>
  );

  if (fullscreen) {
    return (
      <div
        className="dgb-code-modal-overlay"
        onClick={() => setFullscreen(false)}
        role="dialog"
        aria-modal="true"
        aria-label="代码全屏查看"
      >
        <div className="dgb-code-modal" onClick={(e) => e.stopPropagation()}>
          {codeContent}
        </div>
      </div>
    );
  }

  return codeContent;
}


/* ──────────────────────────────────────────────────────────────────────
 * MermaidPane —— code-flow 流程图渲染
 *   • lazy import mermaid（首屏不增体积；与 ChatMarkdown 同步）
 *   • render 失败时 fallback 为可读源码块
 *   • 卸载/重渲染做 cancel 守卫，避免 race
 * ──────────────────────────────────────────────────────────────────────
 */
let __mermaidIdCounter = 0;

function MermaidPane({ source }: { source: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const idRef = useRef<string>(`dgb-codeflow-${++__mermaidIdCounter}`);
  const [error, setError] = useState<string>('');

  useEffect(() => {
    let cancelled = false;
    setError('');
    (async () => {
      try {
        const { default: mermaid } = await import('mermaid');
        mermaid.initialize({ startOnLoad: false, theme: 'neutral', securityLevel: 'loose' });
        const { svg } = await mermaid.render(idRef.current, source);
        if (!cancelled && ref.current) ref.current.innerHTML = svg;
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      }
    })();
    return () => { cancelled = true; };
  }, [source]);

  if (error) {
    return (
      <pre className="dgb-codeflow-error" aria-live="polite">
        <code>[Mermaid 渲染失败] {error}</code>
      </pre>
    );
  }
  return <div ref={ref} className="dgb-codeflow-mermaid" />;
}
