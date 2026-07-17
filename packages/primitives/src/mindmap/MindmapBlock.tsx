import { useEffect, useMemo, useRef, useState } from 'react';
import { Markmap, deriveOptions } from 'markmap-view';
import type { IPureNode } from 'markmap-common';
import './MindmapBlock.css';

interface MindmapNode {
  text: string;
  children?: MindmapNode[];
  color?: string;
  icon?: string;
}

export interface MindmapBlockProps {
  root: MindmapNode;
}

/** 把课程 manifest 中的树状节点转换为 markmap-view 需要的 IPureNode。 */
function toPureNode(node: MindmapNode): IPureNode {
  const label = node.icon ? `${node.icon} ${node.text}` : node.text;
  return {
    content: label,
    children: (node.children ?? []).map(toPureNode),
  };
}

/** 课程级配色基线（textbook 教材风：墨绿 + 米黄 + 赭）。 */
const MARKMAP_COLOR = ['#0E7C4A', '#0A5132', '#B0872B', '#8A5A2B', '#0F766E', '#4C6F1F'];

/**
 * MindmapBlock v3.0 · 接入 markmap-view 开源渲染引擎。
 *
 * 决策记录：之前的自建 SVG 引擎在 foreignObject 渲染上失败（节点退化为像素点）。
 * markmap-view 是 markmap 项目官方包：渲染稳定 / 自带 D3 zoom+pan / autoFit /
 * 节点折叠 / 社区维护活跃。仅做数据适配 + 容器尺寸。
 */
export function MindmapBlock(props: MindmapBlockProps) {
  const { root } = props;
  const svgRef = useRef<SVGSVGElement>(null);
  const mmRef = useRef<Markmap | null>(null);
  const fullSvgRef = useRef<SVGSVGElement>(null);
  const fullMmRef = useRef<Markmap | null>(null);
  const [fullscreen, setFullscreen] = useState(false);

  const data = useMemo<IPureNode>(() => toPureNode(root), [root]);

  // 内嵌导图初始化
  useEffect(() => {
    if (!svgRef.current) return;
    const options = deriveOptions({
      color: MARKMAP_COLOR,
      colorFreezeLevel: 2,
      duration: 400,
      maxWidth: 240,
      spacingHorizontal: 80,
      spacingVertical: 18,
      paddingX: 12,
      initialExpandLevel: -1,
    });
    if (!mmRef.current) {
      mmRef.current = Markmap.create(svgRef.current, options, data);
    } else {
      mmRef.current.setOptions(options);
      mmRef.current.setData(data);
      mmRef.current.fit();
    }
  }, [data]);

  // 全屏导图初始化
  useEffect(() => {
    if (!fullscreen || !fullSvgRef.current) return;
    const options = deriveOptions({
      color: MARKMAP_COLOR,
      colorFreezeLevel: 2,
      duration: 300,
      maxWidth: 320,
      spacingHorizontal: 100,
      spacingVertical: 22,
      paddingX: 16,
      initialExpandLevel: -1,
    });
    if (!fullMmRef.current) {
      fullMmRef.current = Markmap.create(fullSvgRef.current, options, data);
    } else {
      fullMmRef.current.setData(data);
      fullMmRef.current.fit();
    }
    return () => {
      fullMmRef.current?.destroy();
      fullMmRef.current = null;
    };
  }, [fullscreen, data]);

  // ESC 关闭全屏
  useEffect(() => {
    if (!fullscreen) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setFullscreen(false); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [fullscreen]);

  // 销毁内嵌实例
  useEffect(() => {
    return () => {
      mmRef.current?.destroy();
      mmRef.current = null;
    };
  }, []);

  return (
    <>
      <section className="dgb-mindmap-v3" aria-label="思维导图">
        <header className="dgb-mindmap-v3-head">
          <span className="dgb-mindmap-v3-badge">思维导图</span>
          <span className="dgb-mindmap-v3-hint">拖拽平移 · 滚轮缩放 · 点击展开全屏</span>
          <button
            type="button"
            className="dgb-mindmap-v3-fullbtn"
            onClick={() => setFullscreen(true)}
            title="全屏查看"
            aria-label="全屏查看思维导图"
          >
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M3 7V3h4M21 7V3h-4M3 17v4h4M21 17v4h-4" />
            </svg>
            全屏
          </button>
        </header>
        {/* 画布容器：整体可点击（cursor:zoom-in），右下角覆盖展开按钮 */}
        <div
          className="dgb-mindmap-v3-canvas dgb-mindmap-v3-canvas-clickable"
          onClick={() => setFullscreen(true)}
          role="button"
          tabIndex={0}
          aria-label="点击全屏查看思维导图"
          onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') setFullscreen(true); }}
        >
          <div className="dgb-mindmap-v3-canvas-inner">
            <svg
              ref={svgRef}
              className="dgb-mindmap-v3-svg"
              xmlns="http://www.w3.org/2000/svg"
            />
          </div>
          {/* 右下角覆盖展开提示按钮 */}
          <button
            type="button"
            className="dgb-mindmap-v3-overlay-btn"
            onClick={(e) => { e.stopPropagation(); setFullscreen(true); }}
            aria-hidden
            tabIndex={-1}
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M3 7V3h4M21 7V3h-4M3 17v4h4M21 17v4h-4" />
            </svg>
            展开全图
          </button>
        </div>
      </section>

      {/* 全屏 Modal */}
      {fullscreen && (
        <div
          className="dgb-mindmap-modal-overlay"
          onClick={() => setFullscreen(false)}
          role="dialog"
          aria-modal="true"
          aria-label="思维导图全屏"
        >
          <div className="dgb-mindmap-modal" onClick={(e) => e.stopPropagation()}>
            <header className="dgb-mindmap-modal-head">
              <span className="dgb-mindmap-modal-title">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="3" />
                  <path d="M12 2v3M12 19v3M4.22 4.22l2.12 2.12M17.66 17.66l2.12 2.12M2 12h3M19 12h3M4.22 19.78l2.12-2.12M17.66 6.34l2.12-2.12" />
                </svg>
                思维导图
              </span>
              <span className="dgb-mindmap-modal-hint">拖拽 · 缩放 · 点击节点折叠</span>
              <button
                type="button"
                className="dgb-mindmap-modal-close"
                onClick={() => setFullscreen(false)}
                aria-label="关闭"
              >×</button>
            </header>
            <div className="dgb-mindmap-modal-canvas">
              <svg
                ref={fullSvgRef}
                className="dgb-mindmap-v3-svg"
                xmlns="http://www.w3.org/2000/svg"
              />
            </div>
          </div>
        </div>
      )}
    </>
  );
}
