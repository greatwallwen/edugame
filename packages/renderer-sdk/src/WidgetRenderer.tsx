/**
 * WidgetRenderer.tsx — 互动 Widget 渲染器（对标 OpenMAIC InteractiveRenderer）
 * 在 iframe sandbox 中渲染自包含 HTML，通过 postMessage 与 Action 引擎联动
 */
import { useMemo, useRef, useEffect, useCallback, useState } from 'react';
import type { WidgetBlock } from '@dgbook/types';
import s from './WidgetRenderer.module.css';

/** 注入 viewport meta + base styles 到 HTML */
function patchHtml(html: string): string {
  let patched = html;
  // 确保有 viewport meta
  if (!patched.includes('viewport')) {
    patched = patched.replace('<head>', '<head><meta name="viewport" content="width=device-width,initial-scale=1">');
  }
  // 注入 postMessage 桥接 CSS（高亮动画）
  if (!patched.includes('pulse-highlight')) {
    const style = `<style>
@keyframes pulse-highlight{0%,100%{outline-color:rgba(14,165,233,0.8)}50%{outline-color:rgba(14,165,233,0.3)}}
.teacher-annotation{animation:fadeInUp .3s ease}
@keyframes fadeInUp{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
</style>`;
    patched = patched.replace('</head>', style + '</head>');
  }
  return patched;
}

interface WidgetRendererProps {
  block: WidgetBlock;
  /** 当前是否正在被 Action 引擎操控 */
  isActive?: boolean;
}

export function WidgetRenderer({ block, isActive }: WidgetRendererProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);

  const patchedHtml = useMemo(() => patchHtml(block.html), [block.html]);

  // 向 iframe 发送消息的方法（供外部 Action 引擎调用）
  const sendMessage = useCallback((type: string, payload: Record<string, unknown>) => {
    if (iframeRef.current?.contentWindow) {
      iframeRef.current.contentWindow.postMessage({ type, ...payload }, '*');
    }
  }, []);

  // 暴露 sendMessage 到 DOM data 属性（供 Shell 读取）
  useEffect(() => {
    const wrap = wrapRef.current;
    if (!wrap) return;
    (wrap as unknown as Record<string, unknown>).__widgetSend = sendMessage;
    return () => { (wrap as unknown as Record<string, unknown>).__widgetSend = undefined; };
  }, [sendMessage]);

  // 全屏控制
  const toggleFullscreen = useCallback(() => {
    const el = wrapRef.current;
    if (!el) return;
    if (!document.fullscreenElement) {
      el.requestFullscreen?.().catch(() => {});
    } else {
      document.exitFullscreen?.().catch(() => {});
    }
  }, []);

  useEffect(() => {
    const onChange = () => setIsFullscreen(!!document.fullscreenElement);
    document.addEventListener('fullscreenchange', onChange);
    return () => document.removeEventListener('fullscreenchange', onChange);
  }, []);

  // Widget 类型标签
  const typeLabel: Record<string, string> = {
    simulation: '🔬 互动模拟',
    diagram: '📊 流程图',
    code: '💻 代码实验',
    game: '🎮 互动游戏',
    visualization3d: '🧊 3D 可视化',
  };

  return (
    <div
      ref={wrapRef}
      className={`${s.widgetWrap} ${isActive ? s.widgetActive : ''} ${isFullscreen ? s.widgetFullscreen : ''}`}
      data-widget-id={block.id}
      data-widget-type={block.widgetType}
    >
      {/* 工具栏 */}
      <div className={s.widgetToolbar}>
        <span className={s.widgetType}>{typeLabel[block.widgetType] ?? '📦 Widget'}</span>
        {block.description && <span className={s.widgetDesc}>{block.description}</span>}
        <div className={s.widgetToolbarRight}>
          <button className={s.widgetBtn} onClick={toggleFullscreen} title={isFullscreen ? '退出全屏' : '全屏'}>
            {isFullscreen ? '⊠' : '⛶'}
          </button>
        </div>
      </div>
      {/* iframe 容器 */}
      <div className={s.widgetBody}>
        {!loaded && (
          <div className={s.widgetLoading}>
            <div className={s.widgetSpinner} />
            <span>加载互动模块…</span>
          </div>
        )}
        <iframe
          ref={iframeRef}
          srcDoc={patchedHtml}
          className={s.widgetIframe}
          title={`Widget: ${block.description ?? block.widgetType}`}
          sandbox="allow-scripts allow-popups"
          onLoad={() => setLoaded(true)}
        />
      </div>
    </div>
  );
}
