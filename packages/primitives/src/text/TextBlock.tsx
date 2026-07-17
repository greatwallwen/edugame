import { Children, isValidElement, type ReactNode } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import 'katex/dist/katex.min.css';
import './TextBlock.css';

export interface TextBlockProps {
  markdown: string;
  className?: string;
  /** block ID，用于生成段落级 spotlight 目标 */
  blockId?: string;
}

/**
 * v3-rich · 引文型 callout：识别首段以 💡 / 🎯 / ⚠️ / ✅ / ❓ 开头的 blockquote，
 * 给容器 .dgb-callout-<key> 类名，由 CSS 上色块/底色。emoji 自身保留以保持视觉。
 */
const CALLOUT_MAP: Record<string, string> = {
  '💡': 'tip',
  '🎯': 'goal',
  '⚠️': 'warn',
  '✅': 'ok',
  '❓': 'ask',
};

function firstTextChar(children: ReactNode): string {
  for (const c of Children.toArray(children)) {
    if (typeof c === 'string') return c.trimStart();
    if (typeof c === 'number') return String(c);
    if (isValidElement(c)) {
      const inner = (c.props as { children?: ReactNode }).children;
      const s = firstTextChar(inner ?? null);
      if (s) return s;
    }
  }
  return '';
}

function calloutKey(children: ReactNode): string | null {
  const s = firstTextChar(children);
  if (!s) return null;
  for (const emoji of Object.keys(CALLOUT_MAP)) {
    if (s.startsWith(emoji)) return CALLOUT_MAP[emoji]!;
  }
  return null;
}

/**
 * Text 原语：markdown + GFM 表格/任务列表 + KaTeX 数学公式。
 * 不接 Mermaid / Shiki（M7 再议）；代码块用浏览器默认 `<pre>`。
 */
export function TextBlock({ markdown, className, blockId }: TextBlockProps) {
  // 小节标题计数器：只给 h2/h3 编号（不给 p）
  // spotlight 精确框住标题，而非框整个段落
  let headingIdx = 0;
  const prefix = blockId ? `dgb-text-${blockId}` : '';

  return (
    <div className={`dgb-text ${className ?? ''}`}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm, remarkMath]}
        rehypePlugins={[rehypeKatex]}
        components={{
          blockquote: ({ children, ...rest }) => {
            const key = calloutKey(children);
            const cls = key ? `dgb-callout dgb-callout-${key}` : '';
            return (
              <blockquote className={cls} {...rest}>{children}</blockquote>
            );
          },
          h2: ({ children, ...rest }) => {
            const id = prefix ? `${prefix}-s${headingIdx++}` : undefined;
            return <h2 data-element-id={id} className="dgb-text-heading" {...rest}>{children}</h2>;
          },
          h3: ({ children, ...rest }) => {
            const id = prefix ? `${prefix}-s${headingIdx++}` : undefined;
            return <h3 data-element-id={id} className="dgb-text-heading" {...rest}>{children}</h3>;
          },
        }}
      >
        {markdown}
      </ReactMarkdown>
    </div>
  );
}
