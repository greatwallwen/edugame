/**
 * Phase G1.3 · MermaidBlock primitive
 *
 * 真正的 mermaid 渲染层（替换 PageRenderer 中 G1.1 的 stub）。
 *
 * 设计要点：
 *   1. lazy `await import('mermaid')` —— 与 CodeBlock.MermaidPane / ChatMarkdown.MermaidBlock
 *      统一模式，复用 vendor-mermaid chunk（vite.config.ts manualChunks 已分包）；
 *   2. 节点 id 注入 —— 渲染完成后扫 SVG，给每个 nodes[].id 对应的节点设
 *      data-element-id="dgb-mermaid-{nodeId}"，作为 G3 SpotlightOverlay 的可寻址锚点；
 *   3. 错误兜底 —— 渲染失败时 fallback 显示原始 source（不让父页面崩溃）；
 *   4. 唯一 ID —— 每个实例 module-level 计数器 + block id，避免同页多图冲突；
 *   5. 主题适配 —— 用 mermaid 'neutral' 主题，再让 CSS 接管描边色，与教材风对齐；
 *   6. 卸载守卫 —— useEffect 内 cancelled 标志，避免快速切页导致的 race。
 *
 * 朗读联动（与 blockToSpeech.ts 的 case 'mermaid' 配套）：
 *   nodes[].description 已进 SPEAKABLE，未来 EP-1 ActionRunner 落地后，
 *   朗读到第 N 个节点 → 给对应 g.node 设 data-mermaid-active="true" → CSS 高亮。
 */
import { useEffect, useRef, useState } from 'react';
import './MermaidBlock.css';

export interface MermaidNodeMeta {
  id: string;
  label?: string;
  description?: string;
}

export interface MermaidBlockProps {
  source: string;
  diagramType?: string;
  title?: string;
  nodes?: MermaidNodeMeta[];
  /** 可选：用于 SVG 内部生成的稳定 id 前缀（同 block id 即可）。 */
  blockId?: string;
}

let __mermaidInstanceCounter = 0;

/**
 * 在 SVG 内寻找一个 mermaid 节点。mermaid v11 在 flowchart 下渲染节点时通常给
 * `<g class="node" id="flowchart-{nodeId}-{N}">`；state diagram 是 `state-{id}-{N}`，
 * sequence 用 `actor-{id}-{N}`。统一策略：先尝试包含 `-{nodeId}-` 的 g.node，
 * 命中失败再退到 id 等于或包含 nodeId 的任意元素。
 */
function findMermaidNode(svg: SVGElement, nodeId: string): Element | null {
  const safe = nodeId.replace(/[^a-zA-Z0-9_-]/g, '');
  if (!safe) return null;
  const candidates = svg.querySelectorAll<SVGElement>('g.node, g.actor, g[id]');
  // 优先匹配 -nodeId- 形式（最稳）
  for (const el of Array.from(candidates)) {
    const id = el.getAttribute('id') || '';
    if (id.includes(`-${safe}-`)) return el;
  }
  // 退化匹配：完整等于或包含 nodeId
  for (const el of Array.from(candidates)) {
    const id = el.getAttribute('id') || '';
    if (id === safe || id.endsWith(`-${safe}`) || id.includes(safe)) return el;
  }
  return null;
}

/** 给所有匹配上的节点注入 data-element-id（G3 协议）+ data-mermaid-node-id（业务）。 */
function injectNodeIds(svgRoot: HTMLElement, nodes: MermaidNodeMeta[] | undefined): void {
  if (!nodes?.length) return;
  const svg = svgRoot.querySelector<SVGElement>('svg');
  if (!svg) return;
  for (const n of nodes) {
    if (!n.id) continue;
    const el = findMermaidNode(svg, n.id);
    if (el) {
      el.setAttribute('data-element-id', `dgb-mermaid-${n.id}`);
      el.setAttribute('data-mermaid-node-id', n.id);
      if (n.label) el.setAttribute('aria-label', n.label);
    }
  }
}

export function MermaidBlock(props: MermaidBlockProps) {
  const { source, diagramType, title, nodes, blockId } = props;
  const containerRef = useRef<HTMLDivElement>(null);
  const idRef = useRef<string>(
    `dgb-mermaid-${blockId || 'b'}-${++__mermaidInstanceCounter}`,
  );
  const [error, setError] = useState<string>('');
  const [ready, setReady] = useState<boolean>(false);

  useEffect(() => {
    let cancelled = false;
    setError('');
    setReady(false);
    (async () => {
      try {
        const { default: mermaid } = await import('mermaid');
        // 与 CodeBlock.MermaidPane / ChatMarkdown 统一配置
        mermaid.initialize({
          startOnLoad: false,
          theme: 'neutral',
          securityLevel: 'loose',
          fontFamily: 'inherit',
        });
        const { svg } = await mermaid.render(idRef.current, source);
        if (cancelled || !containerRef.current) return;
        containerRef.current.innerHTML = svg;
        // 注入节点 id（G3 协议先行）
        injectNodeIds(containerRef.current, nodes);
        setReady(true);
      } catch (e) {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : String(e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [source, nodes]);

  return (
    <section
      className="dgb-mermaid"
      data-block-id={blockId}
      data-diagram-type={diagramType || 'auto'}
      aria-label={title || '流程图'}
    >
      <header className="dgb-mermaid__head">
        <span className="dgb-mermaid__badge">流程图</span>
        {title ? <span className="dgb-mermaid__title">{title}</span> : null}
        {diagramType && diagramType !== 'auto' ? (
          <span className="dgb-mermaid__type">{diagramType}</span>
        ) : null}
      </header>
      {error ? (
        <>
          <pre className="dgb-mermaid__error">[Mermaid 渲染失败] {error}</pre>
          <pre className="dgb-mermaid__source-fallback">{source}</pre>
        </>
      ) : (
        // Fix: loading div 必须在 containerRef 之外，React 永远不在 containerRef
        // 内部渲染任何子节点。mermaid.render() 通过 innerHTML 写入 SVG，
        // 若 React 同时管理内部子节点会在 reconcile 时触发 removeChild
        // NotFoundError（React 找不到已被 innerHTML 替换掉的 loading div）。
        <div className="dgb-mermaid__canvas-wrap">
          {!ready ? <div className="dgb-mermaid__loading">流程图加载中…</div> : null}
          {/* containerRef 内部不放任何 React 子节点，完全由 mermaid 管理 */}
          <div ref={containerRef} className="dgb-mermaid__canvas" />
        </div>
      )}
    </section>
  );
}
