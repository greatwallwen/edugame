/**
 * ChatMarkdown — AI 回答的 Markdown + Mermaid 渲染器
 *
 * - 使用 react-markdown + remark-gfm 渲染 Markdown
 * - code block lang=mermaid → MermaidBlock 组件（lazy import mermaid）
 * - 其余 code block → 带语言标签的 <pre><code>
 */
import { useEffect, useRef, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import s from './ChatMarkdown.module.css';

/* ── Mermaid 渲染子组件 ─────────────────────────────────────────── */

interface MermaidBlockProps {
  code: string;
}

let mermaidIdCounter = 0;

function MermaidBlock({ code }: MermaidBlockProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [error, setError] = useState('');
  const id = useRef(`mermaid-${++mermaidIdCounter}`);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        // 动态导入 mermaid（避免主包体积膨胀）
        const { default: mermaid } = await import('mermaid');
        mermaid.initialize({
          startOnLoad: false,
          theme: 'neutral',
          securityLevel: 'loose',
        });
        const { svg } = await mermaid.render(id.current, code);
        if (!cancelled && ref.current) {
          ref.current.innerHTML = svg;
        }
      } catch (e) {
        if (!cancelled) setError(String(e));
      }
    })();
    return () => { cancelled = true; };
  }, [code]);

  if (error) {
    return (
      <pre className={s.mermaidError}>
        <code>[Mermaid 渲染失败] {error}</code>
      </pre>
    );
  }

  return <div ref={ref} className={s.mermaidBlock} />;
}

/* ── 代码块路由 ─────────────────────────────────────────────────── */

function CodeBlock({ className, children }: { className?: string; children?: React.ReactNode }) {
  const lang = /language-(\w+)/.exec(className ?? '')?.[1] ?? '';
  const code = String(children ?? '').replace(/\n$/, '');

  if (lang === 'mermaid') {
    return <MermaidBlock code={code} />;
  }

  return (
    <pre className={s.codeBlock}>
      {lang && <span className={s.codeLang}>{lang}</span>}
      <code>{code}</code>
    </pre>
  );
}

/* ── 自定义组件映射 ─────────────────────────────────────────────── */

/**
 * 注：react-markdown v10 的 `Components` 类型对部分元素（blockquote/strong/a/table/th/td）
 * 推断 strict narrowing 与 React 19 global types 之间出现 desync——`({ children })` 解构
 * 在那几个 element 上推不出 children 类型（其它 9 个 element 同模式 OK）。这里给整个映射
 * 显式类型签名 `Record<string, (props: any) => JSX.Element>` 绕过 — 等 react-markdown
 * v11 / TS 升级再回到 `Components` 严类型。Iter-34 跟进。
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type MdComponents = Record<string, (props: any) => any>;

const components: MdComponents = {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  code: (props: any) => {
    // react-markdown v8: inline code vs block code 由父级 pre 区分
    const { node, inline, className, children } = props;
    void node;
    if (inline) {
      return <code className={s.inlineCode}>{children}</code>;
    }
    return <CodeBlock className={className}>{children}</CodeBlock>;
  },
  p: (props) => <p className={s.para}>{props.children}</p>,
  ul: (props) => <ul className={s.list}>{props.children}</ul>,
  ol: (props) => <ol className={s.list}>{props.children}</ol>,
  li: (props) => <li className={s.listItem}>{props.children}</li>,
  h1: (props) => <h1 className={s.heading1}>{props.children}</h1>,
  h2: (props) => <h2 className={s.heading2}>{props.children}</h2>,
  h3: (props) => <h3 className={s.heading3}>{props.children}</h3>,
  blockquote: (props) => <blockquote className={s.blockquote}>{props.children}</blockquote>,
  strong: (props) => <strong className={s.strong}>{props.children}</strong>,
  a: (props) => (
    <a href={props.href} className={s.link} target="_blank" rel="noopener noreferrer">{props.children}</a>
  ),
  table: (props) => <div className={s.tableWrapper}><table className={s.table}>{props.children}</table></div>,
  th: (props) => <th className={s.th}>{props.children}</th>,
  td: (props) => <td className={s.td}>{props.children}</td>,
};

/* ── 主导出 ─────────────────────────────────────────────────────── */

interface ChatMarkdownProps {
  content: string;
  /** 流式输出时显示光标 */
  streaming?: boolean;
}

export function ChatMarkdown({ content, streaming }: ChatMarkdownProps) {
  return (
    <div className={s.root}>
      <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
        {content}
      </ReactMarkdown>
      {streaming && <span className={s.cursor} aria-hidden />}
    </div>
  );
}
