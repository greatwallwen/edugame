import { useMemo, useState } from 'react';
import './GraphicsBlock.css';

/**
 * Phase G3 · GraphicsBlock 节点元数据（与 manifest.ts GraphicsNodeMetaSchema 对齐）。
 *
 * 渲染层注入策略：
 *   1. selector 优先（CSS 选择器，如 `.led`、`g[data-role=led]`）
 *   2. 兜底按 `#${id}` 找 inline SVG 内的原生 id
 *
 * 注入属性：
 *   - data-element-id="dgb-graphics-{id}"   ← G3 统一可寻址协议
 *   - data-graphics-node-id="{id}"          ← 业务可读
 *   - aria-label="{label}"                  ← 无障碍 + AI 助教引用
 */
export interface GraphicsNodeMeta {
  id: string;
  selector?: string;
  label?: string;
  description?: string;
}

export interface GraphicsBlockProps {
  src: string;
  alt?: string;
  caption?: string;
  className?: string;
  /** Phase G3 · 可寻址节点（可选；不填等价于 1.x 扁平 SVG） */
  nodes?: GraphicsNodeMeta[];
  /** 用作根容器 data-block-id 与调试 */
  blockId?: string;
}

/** CSS.escape 兜底：老浏览器或 SSR 下 globalThis.CSS 可能不可用。 */
function cssEscape(s: string): string {
  if (typeof CSS !== 'undefined' && typeof CSS.escape === 'function') {
    return CSS.escape(s);
  }
  // 仅做最小转义，覆盖 a-zA-Z0-9_- 之外的字符
  return s.replace(/([^a-zA-Z0-9_-])/g, '\\$1');
}

/**
 * Phase G3.6 · 字符串级注入（替代 useEffect 后置 setAttribute）
 *
 * 为什么不再走 effect：
 *   - inline SVG 通过 `dangerouslySetInnerHTML` 渲染。React 在父组件 re-render
 *     时会重新应用 `dangerouslySetInnerHTML`，把 frame 内的 SVG 子树整体替换
 *     为新节点；此时 effect 之前 `setAttribute('data-element-id', ...)` 写在
 *     旧节点上的属性随旧节点一起被丢弃，新节点完全没有这些属性。
 *   - 实测：useLayoutEffect 注入后立即 `injectedCount=4`，但稍后查 DOM 仍为 0；
 *     用 MutationObserver 持续重注也会被后续替换抹掉，竞争窗口长期存在。
 *
 * 修复：在渲染前直接把 `data-element-id` 写进 SVG 字符串。这样 React 任意次
 * 重写 `dangerouslySetInnerHTML` 都会从同一份带属性的字符串生成 DOM，
 * 属性永远在源头里，不存在被抹掉的可能。
 *
 * 实现：浏览器原生 DOMParser + XMLSerializer。SSR / Node 环境无 DOMParser
 * 时 fallback 返回原文（本项目客户端渲染为主，不影响功能）。
 */
function injectGraphicsNodeIdsIntoSvgString(
  svgText: string,
  nodes: GraphicsNodeMeta[] | undefined,
): string {
  if (!nodes?.length) return svgText;
  if (typeof DOMParser === 'undefined' || typeof XMLSerializer === 'undefined') {
    return svgText;
  }
  try {
    const doc = new DOMParser().parseFromString(svgText, 'image/svg+xml');
    // 解析失败时 doc.querySelector('parsererror') 会命中
    if (doc.querySelector('parsererror')) return svgText;
    const svg = doc.querySelector('svg');
    if (!svg) return svgText;
    for (const n of nodes) {
      if (!n.id) continue;
      let target: Element | null = null;
      if (n.selector) {
        try { target = svg.querySelector(n.selector); } catch { target = null; }
      }
      if (!target) {
        try { target = svg.querySelector(`#${cssEscape(n.id)}`); } catch { target = null; }
      }
      if (target) {
        target.setAttribute('data-element-id', `dgb-graphics-${n.id}`);
        target.setAttribute('data-graphics-node-id', n.id);
        if (n.label) target.setAttribute('aria-label', n.label);
      }
    }
    return new XMLSerializer().serializeToString(svg);
  } catch {
    return svgText;
  }
}

/**
 * Graphics 原语：支持 `<img>` 渲染 + inline SVG（inline: 前缀） + figure/figcaption 结构。
 * N1 安全：标准 HTML figure 元素，无外部依赖。
 * inline: 前缀：直接将 SVG XML 通过 dangerouslySetInnerHTML 渲染，无需 HTTP 请求。
 *
 * Phase G3：当 props.nodes 非空且 src 为 inline SVG 时，渲染完成后扫 SVG 子树并按 selector / #id 注入
 * `data-element-id` 等属性，作为 SpotlightOverlay / EP-1 ActionRunner 的可寻址锚点。
 */
export function GraphicsBlock({ src, alt, caption, className, nodes, blockId }: GraphicsBlockProps) {
  const displayCaption = caption ?? alt;
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);

  // ── 内联 SVG 渲染（src = "inline:<svg ...>...</svg>"）──
  // 在渲染前用 DOMParser 把 nodes[].selector / #id 解析后写入 data-element-id 等属性。
  // 与 useEffect 后置 setAttribute 相比：
  //   - 不依赖 effect 时机；
  //   - 父组件 re-render 时，dangerouslySetInnerHTML 始终从同一份带属性的字符串
  //     重新生成 DOM，data-element-id 永远在源头里、不可能被「冲掉」；
  //   - 引用变化触发的 useMemo 重算只产生等价字符串，dangerouslySetInnerHTML diff
  //     仍按字符串内容比较，不会无谓重写 DOM。
  const inlineSvgWithNodeIds = useMemo<string | null>(() => {
    if (!src.startsWith('inline:')) return null;
    const raw = src.slice('inline:'.length);
    return injectGraphicsNodeIdsIntoSvgString(raw, nodes);
  }, [src, nodes]);

  if (inlineSvgWithNodeIds !== null) {
    return (
      <figure
        className={`dgb-gfx dgb-gfx-svg ${className ?? ''}`}
        data-block-id={blockId}
      >
        <div
          className="dgb-gfx-frame dgb-gfx-svg-frame"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{ __html: inlineSvgWithNodeIds }}
        />
        {displayCaption ? <figcaption>{displayCaption}</figcaption> : null}
      </figure>
    );
  }

  return (
    <figure
      className={`dgb-gfx ${className ?? ''} ${failed ? 'dgb-gfx-failed' : ''}`}
      data-block-id={blockId}
    >
      <div className="dgb-gfx-frame">
        {!loaded && !failed ? <div className="dgb-gfx-loading">图片加载中…</div> : null}
        {failed ? (
          <div className="dgb-gfx-error" role="status">
            图片加载失败
          </div>
        ) : null}
        <img
          src={src}
          alt={alt ?? ''}
          loading="lazy"
          onLoad={() => setLoaded(true)}
          onError={() => setFailed(true)}
          style={{ display: failed ? 'none' : 'block', opacity: loaded ? 1 : 0 }}
        />
      </div>
      {displayCaption ? <figcaption>{displayCaption}</figcaption> : null}
    </figure>
  );
}
