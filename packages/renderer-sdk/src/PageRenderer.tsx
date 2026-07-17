import { lazy, Suspense, useCallback, useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import type { Block, CourseManifest, Page, PageGameSpec } from '@dgbook/types';
import { SceneViewer } from './SceneViewer';
import { WidgetRenderer } from './WidgetRenderer';
import { BlockRegistry } from './BlockRegistry';
import {
  CodeBlock,
  CodeClozeBlock,

  BitFlipBlock,
  ExperimentBlock,
  FillBlankBlock,
  FlashcardBlock,
  GraphicsBlock,
  HotspotBlock,
  MatchingBlock,
  MathBlock,
  MemoryMatchBlock,
  MermaidBlock,
  MindmapBlock,
  OrderingBlock,
  ClassificationBlock,
  QuizBlock,
  QuizIntroBlock,
  SpotDifferenceBlock,
  SummaryBlock,
  TableBlock,
  TextBlock,
  VideoBlock,
  WaveformBlock,
  LessonHeroBanner,
  InfoTableBlock,
  CalloutBlock as CalloutBlockPrimitive,
  PrincipleCardsBlock,
  FigurePairBlock,
  // M10 · Finale Challenge 全屏游戏化挑战
  FinaleChallenge,

  WokwiBlock,
  SingleChoiceBlock,
  MultipleChoiceBlock,
  TrueFalseBlock,
  TimedQuizBlock,
  SliderEstimateBlock,
  SequenceBuilderBlock,
  TruthTableBlock,
  BaseConverterBlock,
  RegisterConfigBlock,
  WaveformTunerBlock,
  ParameterMatchBlock,
  HotspotSequenceBlock,
  DragLabelBlock,
  SignalTraceBlock,
  RegisterDecoderBlock,
  ArcadeRunnerBlock,
} from '@dgbook/blocks';
import './PageRenderer.css';

// DigitalHumanBlock 懒加载（含 pixi.js / Live2D，体积约 600KB）
const DigitalHumanBlock = lazy(() =>
  import('@dgbook/blocks').then((m) => ({ default: m.DigitalHumanBlock }))
);

const EduGameHost = lazy(() =>
  import('@dgbook/game/host').then((m) => ({ default: m.EduGameHost }))
);

export interface PageRendererProps {
  manifest: CourseManifest;
  page: Page;
  visitedSet?: Set<string>;
  /** 点击 SummaryBlock 的「下一课」时触发（可选：Shell 注入 setActive） */
  onNavigateNext?: (pageId: string) => void;
  /** 当前正在讲解的 Block ID（由 BlockPlaybackEngine 驱动） */
  activeBlockId?: string | null;
  /** 当前 SceneViewer 中被 spotlight 的 item ID */
  activeItemId?: string | null;
  /** 已入场显示的 item IDs（undefined = 全部显示） */
  revealedItemIds?: Set<string>;
  /** 当前正在朗读的文字（传给 SceneViewer Notes 面板） */
  currentSpeechText?: string;
  /** 4 · code-flow step 受控驱动：
   *  当 codeFlowStep.blockId === 当前渲染 code block.id 时，把 idx 作为
   *  CodeBlock.currentStepIdx 传入；其它 block 不受影响。 */
  codeFlowStep?: { blockId: string | null; idx: number };
}

/**
 * 页渲染器：按 page.template 应用外层变体；按 block.kind 分发到原语。
 * v5.0 新增 Zone Layout：Banner / Content / Practice / Review 分区渲染
 */
export function PageRenderer({ manifest, page, visitedSet, onNavigateNext, activeBlockId, activeItemId, revealedItemIds, currentSpeechText, codeFlowStep }: PageRendererProps) {
  // v5 教材化：把 textbook 头部块（intro/info-table/principles）提前到 mindmap 前；
  // animation 自带 scene+teacher，则隐藏顶层 SceneViewer，避免重复。
  const hasAnimScene = page.blocks.some((b) =>
    b.kind === 'animation' &&
    (b as { metadata?: { teacher?: unknown } }).metadata?.teacher != null,
  );

  const mindmapBlocks = page.blocks.filter((b) => b.kind === 'mindmap');
  const isIntroCallout = (b: Block) =>
    b.kind === 'callout' && (b as { calloutKind?: string }).calloutKind !== 'wrapup';
  const isWrapupCallout = (b: Block) =>
    b.kind === 'callout' && (b as { calloutKind?: string }).calloutKind === 'wrapup';
  // headBlocks: 导读 callout + 任务描述 info-table + 基本原则 principles（永远前置）
  const headBlocks = page.blocks.filter(
    (b) => b.kind === 'info-table' || b.kind === 'principles' || isIntroCallout(b),
  );
  // wrapup callout 要放到页面最末尾（收束卡）
  const wrapupBlocks = page.blocks.filter(isWrapupCallout);
  // rest: 除去 mindmap / head / wrapup 的其它 block 按 zone 分组
  const restBlocks = page.blocks.filter(
    (b) =>
      b.kind !== 'mindmap' &&
      !(b.kind === 'callout') && // 所有 callout 已在 head 或 wrapup 中归属
      b.kind !== 'info-table' &&
      b.kind !== 'principles',
  );
  const zones = groupBlocksByZone(restBlocks);
  const hasSpotlight = !!activeBlockId;

  return (
    <div className={`dgb-page dgb-page-${page.template}`}>
      <div className="dgb-page-inner">
        {page.lessonHero ? (
          <LessonHeroBanner
            eyebrow={page.lessonHero.eyebrow}
            title={page.lessonHero.title}
            subtitle={page.lessonHero.subtitle}
            heroImage={page.lessonHero.heroImage}
            brand={page.lessonHero.brand}
            kind={page.lessonHero.kind}
            duration={page.lessonHero.duration}
          />
        ) : (
          <LessonBanner page={page} visited={visitedSet?.has(page.id)} />
        )}

        {/* 教材头部：导读 → 任务描述 → 基本原则 */}
        {headBlocks.map((b, bi) => (
          <AnimatedBlockWrap key={b.id} index={bi} isActive={false} isDimmed={false} blockId={b.id}>
            <BlockSlot block={b} manifest={manifest} onNavigateNext={onNavigateNext} />
          </AnimatedBlockWrap>
        ))}

        {/* OpenMAIC 风格教学场景：仅当 animation 没有内嵌 scene+teacher 时渲染 */}
        {page.scene && !hasAnimScene && (
          <SceneViewer
            scene={page.scene}
            activeItemId={activeItemId}
            revealedItemIds={revealedItemIds}
            currentSpeechText={currentSpeechText}
          />
        )}

        {/* 思维导图作为知识结构总览 */}
        {mindmapBlocks.length > 0 && (
          <div className="dgb-mindmap-overview">
            {mindmapBlocks.map((b) => (
              <BlockSlot key={b.id} block={b} manifest={manifest} onNavigateNext={onNavigateNext} />
            ))}
          </div>
        )}

        {zones.map((zone, zi) => {
          if (zone.type === 'content') {
            return zone.blocks.map((b, bi) => {
              const isActive = activeBlockId === b.id;
              const isDimmed = hasSpotlight && !isActive;
              return (
                <AnimatedBlockWrap key={b.id} index={bi} isActive={isActive} isDimmed={isDimmed} blockId={b.id}>
                  <BlockSlot block={b} manifest={manifest} onNavigateNext={onNavigateNext} codeFlowStep={codeFlowStep} />
                </AnimatedBlockWrap>
              );
            });
          }
          if (zone.type === 'practice') {
            return <PracticeZone key={`practice-${zi}`} blocks={zone.blocks} manifest={manifest} onNavigateNext={onNavigateNext} />;
          }
          if (zone.type === 'review') {
            return <ReviewZone key={`review-${zi}`} blocks={zone.blocks} manifest={manifest} pageGame={page.game} onNavigateNext={onNavigateNext} />;
          }
          if (zone.type === 'dh') {
            // digital-human 已合并到右侧 RightPanel「讲师讲解」区，内容区不重复渲染
            return null;
          }
          return null;
        })}

        {page.game && !zones.some((zone) => zone.type === 'review') && (
          <ReviewZone blocks={[]} manifest={manifest} pageGame={page.game} onNavigateNext={onNavigateNext} />
        )}

        {/* 课堂收束 callout —— 永远出现在页面最末，作为课堂收尾卡 */}
        {wrapupBlocks.length > 0 && (
          <div className="dgb-page-wrapup">
            {wrapupBlocks.map((b, bi) => (
              <AnimatedBlockWrap key={b.id} index={bi} isActive={false} isDimmed={false} blockId={b.id}>
                <BlockSlot block={b} manifest={manifest} onNavigateNext={onNavigateNext} />
              </AnimatedBlockWrap>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

/**
 * 内置动画原语：识别 `dgb-anim:<name>` 的 src（format='plugin'），
 * 渲染对应的 inline SVG + CSS keyframe 动画。N1 安全（命名通用，无学科词）。
 *
 * 当前 18 个：
 *   信号类   pulse · waveform · sine · scope-trace · fourier-build
 *   数据类   flow · bus-transfer · data-packet · packet-flow
 *   结构类   chip-glow · clock-tree · memory-map
 *   状态类   register-bits · state-machine · fsm-trace · counter · adc-sample
 *   时序类   timing-diagram
 *
 * 此外 format=html 走 sandbox=allow-scripts 的 iframe（src 可为 inline:<...>
 * 或 data:text/html;base64,...）；format=gif/外部 URL 走 <img> 兜底。
 */
/**
 * M9: 装饰性 SVG 动画已清理（无教学价值）。
 * 保留 AnimationBlock 处理 HTML/video/svg-inline 格式动画（有教学内容的原理动画）。
 * `dgb-anim:<name>` 的 plugin 格式将渲染占位提示。
 */
const ANIM_REGISTRY: Record<string, () => ReactElement> = {};


type AnimationMetadata = {
  topic?: string;
  interactive?: boolean;
  engine?: string;
  /**
   * 动画质量等级：
   * - 'placeholder' — OpenMAIC 通用占位模板，未承载该章节具体知识点，待重做
   * - 'final'       — 已为该章节定制的真动画
   * 渲染时 placeholder 会顶部挂一条「占位动画 · 重做中」提示条，避免误导。
   */
  quality?: 'placeholder' | 'final';
  teacher?: {
    script: string;
    voice?: string;
    autoPlay?: boolean;
    sceneId?: string;
    steps?: string[];
    stepScripts?: string[];
  };
};

/**
 * HTML iframe 动画子组件 — postMessage 动态高度自适应 + 手动步骤控制
 * iframe 内可监听 { type: 'dgb-step', step: number } 实现分步动画。
 */
function AnimationHtmlBlock({ src, format, metadata }: { src: string; format: string; metadata?: AnimationMetadata }) {
  const [iframeHeight, setIframeHeight] = useState<number>(640);
  // currentStep/totalSteps 被 iframe postMessage 更新；未来可由 Shell 的全局 engine
  // 下发 step 指令驱动 iframe 内部动画。当前仅用于接收 iframe 自身 step 状态。
  const [, setTotalSteps] = useState<number>(0);
  const [, setCurrentStep] = useState<number>(0);
  const iframeRef = useRef<HTMLIFrameElement>(null);

  // postMessage 监听：接收 iframe 上报的内容高度、总步数、当前步
  useEffect(() => {
    const handleMessage = (e: MessageEvent) => {
      if (!iframeRef.current) return;
      if (e.source !== iframeRef.current.contentWindow) return;
      if (e.data?.type === 'dgb-iframe-height' && typeof e.data.height === 'number') {
        // v6.9 · 修复底部空白：原下界 520 会把真实内容只 ~380px 的小动画卡硬撑出 100~140px 空白。
        //         真实内容上报的是 contentH × scale，scale 在窄屏可能 0.4 → 实测 200~400px 都有可能。
        //         下界放到 240，上界保持 1200（防止异常上报炸窗）。
        const h = Math.min(Math.max(e.data.height, 240), 1200);
        setIframeHeight(h);
      }
      if (e.data?.type === 'dgb-steps-total' && typeof e.data.total === 'number') {
        setTotalSteps(e.data.total);
        setCurrentStep(0);
      }
      if (e.data?.type === 'dgb-step-change' && typeof e.data.step === 'number') {
        setCurrentStep(e.data.step);
        if (typeof e.data.total === 'number') setTotalSteps(e.data.total);
      }
    };
    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  let iframeSrc = src;
  if (src.startsWith('inline:')) {
    const html = src.slice('inline:'.length);
    const patchedHtml = patchIframeHtml(html, format);
    iframeSrc = 'data:text/html;charset=utf-8;base64,' + safeBtoa(patchedHtml);
  }

  // 占位动画：通用 OpenMAIC 模板，未承载本章节具体知识点 — 顶部挂提示条避免误导
  const isPlaceholder = metadata?.quality === 'placeholder';

  return (
    <figure
      className={`dgb-block-anim dgb-block-anim-html${isPlaceholder ? ' dgb-block-anim-placeholder' : ''}`}
      aria-label={`动画 (${format})${isPlaceholder ? ' · 占位模板' : ''}`}
    >
      {isPlaceholder && (
        <div className="dgb-anim-placeholder-notice" role="note">
          <span className="dgb-anim-placeholder-badge">动画重做中</span>
          <span className="dgb-anim-placeholder-text">
            当前为通用占位模板，尚未承载「{metadata?.topic || '本节'}」的关键知识点，请以后续定制动画为准。
          </span>
        </div>
      )}
      <div className="dgb-anim-single">
        <div className="dgb-anim-stage-pane">
          <iframe
            ref={iframeRef}
            src={iframeSrc}
            className="dgb-anim-html-frame"
            sandbox="allow-scripts"
            loading="lazy"
            title={metadata?.topic || '动画'}
            style={{
              border: 'none', outline: 'none', boxShadow: 'none',
              background: 'transparent', height: `${iframeHeight}px`,
            }}
          />
        </div>
        {/* 局部 CommentaryBar 已迁移到底部全局 Roundtable AudioBar：
            朗读时由 Shell 的 BlockPlaybackEngine 驱动，气泡浮在讲师头像旁。 */}
      </div>
    </figure>
  );
}

function AnimationBlock({
  src,
  format,
  metadata,
  blockId,
}: {
  src: string;
  format: string;
  metadata?: AnimationMetadata;
  /** 视频联动定位：play-video action 通过 data-anim-video={blockId} 找到 video 元素 */
  blockId?: string;
}) {
  // 内置原语
  if (format === 'plugin' && src.startsWith('dgb-anim:')) {
    const name = src.slice('dgb-anim:'.length);
    const render = ANIM_REGISTRY[name];
    return (
      <figure className={`dgb-block-anim dgb-anim-${name}`} aria-label={`动画: ${name}`}>
        {render ? render() : <div className="dgb-block-placeholder">未知动画 · {name}</div>}
        <figcaption>动画 · {name}</figcaption>
      </figure>
    );
  }

  // 视频格式（Manim 预渲染）— data-anim-video 让 play-video action 定位并联动播放
  if (format === 'video-mp4' || format === 'video-webm') {
    return (
      <figure className="dgb-block-anim dgb-block-anim-video" aria-label="动画 (video)">
        <video
          data-anim-video={blockId ?? ''}
          controls
          width="100%"
          preload="metadata"
          style={{ borderRadius: '12px', maxHeight: '540px' }}
        >
          <source src={src} type={format === 'video-mp4' ? 'video/mp4' : 'video/webm'} />
        </video>
        <figcaption>动画 · {metadata?.topic || format}</figcaption>
      </figure>
    );
  }

  // 直接内联 SVG（最安全，无 iframe）
  if (format === 'svg-inline') {
    return (
      <figure className="dgb-block-anim dgb-block-anim-svg-inline" aria-label="动画 (svg)">
        <div className="dgb-anim-svg-container" dangerouslySetInnerHTML={{ __html: src }} />
        <figcaption>动画 · {metadata?.topic || 'svg'}</figcaption>
      </figure>
    );
  }

  // HTML 类格式（SVG / Three.js / Canvas 2D）— postMessage 动态高度
  if (format === 'html-svg' || format === 'html-threejs' || format === 'html-canvas' || format === 'html') {
    return <AnimationHtmlBlock src={src} format={format} metadata={metadata} />;
  }

  if (format === 'gif') {
    return (
      <figure className="dgb-block-anim">
        <img src={src} alt="动画" loading="lazy" />
      </figure>
    );
  }
  return (
    <div className="dgb-block-placeholder">
      <code>animation/{format}</code> · <code>{src.slice(0, 50)}</code>
    </div>
  );
}

/**
 * 修复 iframe HTML 内容中的样式问题：
 * 1. 移除 body/html 的黑色边框/背景
 * 2. 统一为浅色主题
 * 3. 确保 iframe 内部无 scrollbars
 */
function patchIframeHtml(html: string, format: string): string {
  let patched = html;

  // 1. 强制 body/html 无边距、无黑色背景
  const bodyStyleRegex = /(body\s*,\s*html|body|html)\s*\{([^}]*)\}/gi;
  patched = patched.replace(bodyStyleRegex, (match, selector, styles) => {
    const newStyles = styles
      .replace(/border\s*:\s*[^;]+;?/gi, '')
      .replace(/outline\s*:\s*[^;]+;?/gi, '')
      .replace(/background(?:-color)?\s*:\s*#000000;?/gi, 'background: #f8fafc;')
      .replace(/background(?:-color)?\s*:\s*#1[0-9a-f]{2};?/gi, 'background: #f8fafc;')
      .replace(/background(?:-color)?\s*:\s*black;?/gi, 'background: #f8fafc;');
    return `${selector} { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; ${newStyles} }`;
  });

  // 2. 在 </head> 前注入全局样式修复
  const fixStyle = `<style>
    * { scrollbar-width: none; }
    ::-webkit-scrollbar { display: none; }
    body, html { border: none !important; outline: none !important; box-shadow: none !important; }
    ${format === 'html-threejs' ? 'canvas { display: block; width: 100%; height: 100%; }' : ''}
  </style>`;

  const headEnd = patched.search(/<\/head>/i);
  if (headEnd > 0) {
    patched = patched.slice(0, headEnd) + fixStyle + patched.slice(headEnd);
  } else {
    // 无 head，在 body 前注入
    const bodyStart = patched.search(/<body/i);
    if (bodyStart > 0) {
      patched = patched.slice(0, bodyStart) + fixStyle + patched.slice(bodyStart);
    }
  }

  return patched;
}

/** btoa 不能直接吃 UTF-8；用 unescape(encodeURIComponent(...)) 保 CJK 安全。
 *  非浏览器环境（SSR）兜底返回原串，由调用方决定是否再编码。 */
function safeBtoa(s: string): string {
  if (typeof window === 'undefined' || typeof window.btoa !== 'function') return s;
  try {
    return window.btoa(unescape(encodeURIComponent(s)));
  } catch {
    return window.btoa(s);
  }
}


/* M9: 18个装饰性SVG动画函数已删除 — 无教学价值，仅占体积 */

/* ============================================================
 * Zone Layout · v5.0
 * 分区板式布局：将页面按 pedagogical zone 分组渲染，
 * 减少认知负荷，互动游戏以图标卡片形式呈现。
 * ============================================================ */

type ZoneType = 'content' | 'practice' | 'review' | 'dh';

function getZoneType(kind: Block['kind']): ZoneType {
  switch (kind) {
    case 'text':
    case 'graphics':
    case 'code':
    case 'animation':
    case 'video':
    case 'mindmap':
    case 'table':
    case 'waveform':
    case 'experiment':
    case 'quiz':
    case 'callout':
    case 'info-table':
    case 'principles':
    case 'figure-pair':
    case 'wokwi-element':
      return 'content';
    case 'widget':
    case 'interactive':
      return 'practice';
    case 'quiz-intro-animation':
    case 'summary':
    case 'finale-challenge':
      return 'review';
    case 'digital-human':
      return 'dh';
    default:
      return 'content';
  }
}

interface ZoneGroup {
  type: ZoneType;
  blocks: Block[];
}

/**
 * 分区聚合 · v6.0
 *
 * 规则：按页面阅读顺序出现的第一个 zone 为锚点顺序；同类 zone 只聚合成**一个**，
 * 所有同类 block 按原顺序追加进去。
 *
 * 这样无论源 manifest 中 widget / interactive / experiment 如何穿插，
 * 页面最终只会有唯一的 practice / review / content 区，保证版式规范一致。
 */
function groupBlocksByZone(blocks: Block[]): ZoneGroup[] {
  const order: ZoneType[] = [];
  const bucket = new Map<ZoneType, Block[]>();
  for (const block of blocks) {
    const zone = getZoneType(block.kind);
    if (!bucket.has(zone)) {
      bucket.set(zone, []);
      order.push(zone);
    }
    bucket.get(zone)!.push(block);
  }
  return order.map((type) => ({ type, blocks: bucket.get(type) ?? [] }));
}

const INTERACTIVE_ICONS: Record<string, { icon: string; label: string }> = {
  matching:        { icon: '⟷', label: '连线配对' },
  'fill-blank':    { icon: '▭', label: '填空挑战' },
  ordering:        { icon: '≡', label: '排序练习' },
  classification:  { icon: '⊞', label: '分类归纳' },
  hotspot:         { icon: '◎', label: '热点标注' },
  'spot-difference': { icon: '⊕', label: '差异识别' },
  'memory-match':  { icon: '◈', label: '记忆配对' },
  flashcard:       { icon: '▷', label: '闪卡复习' },
  'code-cloze':    { icon: '⌷', label: '代码填空' },
  'bit-flip':      { icon: '⧉', label: '寄存器位翻转' },
  'single-choice':   { icon: '◉', label: '单选题' },
  'multiple-choice': { icon: '☑', label: '多选题' },
  'true-false':      { icon: '⚖', label: '判断题' },
  'timed-quiz':      { icon: '⏱', label: '计时快答' },
  'slider-estimate': { icon: '🎚', label: '滑块估值' },
  'sequence-builder':{ icon: '🧩', label: '流程拼装' },
  'truth-table':     { icon: '▦', label: '真值表' },
  'base-converter':  { icon: '⇄', label: '进制转换' },
  'register-config': { icon: '⚙', label: '寄存器配置' },
  'waveform-tuner':  { icon: '〜', label: '波形调节' },
  'parameter-match': { icon: '🎛', label: '参数匹配' },
  'hotspot-sequence':{ icon: '①', label: '顺序点击' },
  'drag-label':      { icon: '🏷', label: '标签配位' },
  'signal-trace':    { icon: '📈', label: '信号时序描点' },
  'register-decoder': { icon: '⬓', label: '寄存器解码' },
};

function LessonBanner({ page, visited }: { page: Page; visited?: boolean }) {
  const meta = page.lesson;
  const [sourceOpen, setSourceOpen] = useState(false);
  const difficultyLabel: Record<string, string> = {
    beginner: '入门',
    intermediate: '进阶',
    advanced: '高级',
  };
  const difficultyColor: Record<string, string> = {
    beginner: '#10b981',
    intermediate: '#f59e0b',
    advanced: '#ef4444',
  };
  const src = page.source;
  const sourceLabel = src?.pageNumbers && src.pageNumbers.length > 0
    ? `源 · p${src.pageNumbers[0]}${src.pageNumbers.length > 1 ? `–p${src.pageNumbers[src.pageNumbers.length - 1]}` : ''}`
    : src?.pageSourceKey ? '源' : null;
  return (
    <div className="dgb-lesson-banner">
      <div className="dgb-lesson-banner-top">
        <span className="dgb-lesson-template">{page.template.replace('T-', '')}</span>
        <h2 className="dgb-lesson-title">{page.title}</h2>
        {meta?.difficulty ? (
          <span
            className="dgb-lesson-difficulty"
            style={{ background: difficultyColor[meta.difficulty] + '18', color: difficultyColor[meta.difficulty], border: `1px solid ${difficultyColor[meta.difficulty]}40` }}
          >
            {difficultyLabel[meta.difficulty]}
          </span>
        ) : null}
        {visited ? <span className="dgb-lesson-visited">✓ 已学</span> : null}
        {sourceLabel ? (
          <button
            type="button"
            className="dgb-lesson-source-btn"
            onClick={() => setSourceOpen(true)}
            title="查看本页对应的原始 Markdown chunk（N5 · 可追溯）"
          >
            📎 {sourceLabel}
          </button>
        ) : null}
      </div>
      {meta?.objectives ? (
        <div className="dgb-lesson-objectives">
          🎯 {meta.objectives.slice(0, 3).join(' · ')}
        </div>
      ) : null}
      <div className="dgb-lesson-meta">
        {meta?.estimatedMinutes ? <span>⏱ {meta.estimatedMinutes} 分钟</span> : null}
        {meta?.tags?.slice(0, 3).map((t) => <span key={t} className="dgb-lesson-tag">{t}</span>)}
      </div>
      {sourceOpen && src ? (
        <SourceDrawer source={src} pageTitle={page.title} onClose={() => setSourceOpen(false)} />
      ) : null}
    </div>
  );
}

function SourceDrawer({ source, pageTitle, onClose }: { source: NonNullable<Page['source']>; pageTitle: string; onClose: () => void }) {
  // ESC 关闭
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <div className="dgb-source-overlay" onClick={onClose} role="dialog" aria-modal="true" aria-label="原始来源">
      <aside className="dgb-source-drawer" onClick={(e) => e.stopPropagation()}>
        <header className="dgb-source-head">
          <div>
            <div className="dgb-source-title">📎 原始来源 · {pageTitle}</div>
            <div className="dgb-source-sub">
              {source.pageNumbers && source.pageNumbers.length > 0
                ? <>原 PDF 页：{source.pageNumbers.map((p) => `p${p}`).join(', ')}</>
                : null}
              {source.pageSourceKey ? <code className="dgb-source-key"> · {source.pageSourceKey}</code> : null}
            </div>
          </div>
          <button type="button" className="dgb-source-close" onClick={onClose} aria-label="关闭">×</button>
        </header>
        <div className="dgb-source-body">
          {source.markdown
            ? <pre className="dgb-source-markdown">{source.markdown}</pre>
            : <div className="dgb-source-empty">该课程未保留原始 markdown 文本（仅有页码索引）。</div>}
        </div>
      </aside>
    </div>
  );
}

function InteractiveCard({ block, onExpand }: { block: Block; onExpand: () => void }) {
  if (block.kind !== 'interactive') return null;
  const info = INTERACTIVE_ICONS[block.spec.kind] ?? { icon: '🎮', label: '互动练习' };
  return (
    <button
      type="button"
      className="dgb-interactive-card"
      onClick={onExpand}
    >
      <span className="dgb-interactive-card-icon">{info.icon}</span>
      <span className="dgb-interactive-card-body">
        <span className="dgb-interactive-card-label">{info.label}</span>
        <span className="dgb-interactive-card-prompt">{block.spec.prompt ?? '点击开始互动练习'}</span>
      </span>
      <span className="dgb-interactive-card-action">开始 ▶</span>
    </button>
  );
}

/**
 * PracticeZone · 点击卡片 → 全屏弹窗玩
 *
 * 取舍说明：Iter-47 曾把游戏全部内联展开（解决"藏太深"），但导致页面极长、
 *   占满空间。Iter-50 回到"醒目卡片 + 点击弹窗"：卡片大图标+标签+提示+开始按钮，
 *   一眼可见可发现；点击后全屏弹窗沉浸玩，省页面空间。两全其美。
 */
function PracticeZone({ blocks, manifest, onNavigateNext }: { blocks: Block[]; manifest: CourseManifest; onNavigateNext?: (id: string) => void }) {
  const [modalBlock, setModalBlock] = useState<Block | null>(null);

  useEffect(() => {
    if (!modalBlock) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setModalBlock(null); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [modalBlock]);

  return (
    <>
      <div className="dgb-zone-practice">
        <div className="dgb-zone-header">
          <span className="dgb-zone-icon">⚡</span>
          <span className="dgb-zone-title">互动练习</span>
          <span className="dgb-zone-count">{blocks.length} 个练习</span>
        </div>
        <div className="dgb-practice-grid">
          {blocks.map((block) => {
            if (block.kind === 'interactive') {
              return (
                <InteractiveCard key={block.id} block={block} onExpand={() => setModalBlock(block)} />
              );
            }
            if (block.kind === 'widget') {
              return (
                <div key={block.id} className="dgb-practice-widget">
                  <BlockSlot block={block} manifest={manifest} onNavigateNext={onNavigateNext} />
                </div>
              );
            }
            return (
              <div key={block.id} className="dgb-practice-misc">
                <BlockSlot block={block} manifest={manifest} onNavigateNext={onNavigateNext} />
              </div>
            );
          })}
        </div>
      </div>

      {modalBlock && (
        <div
          className="dgb-practice-modal-overlay"
          onClick={() => setModalBlock(null)}
          role="dialog"
          aria-modal="true"
          aria-label="互动练习"
        >
          <div className="dgb-practice-modal" onClick={(e) => e.stopPropagation()}>
            <header className="dgb-practice-modal-head">
              <span className="dgb-practice-modal-title">
                {INTERACTIVE_ICONS[(modalBlock as Extract<Block, { kind: 'interactive' }>).spec.kind]?.icon ?? '⚡'}
                &nbsp;{INTERACTIVE_ICONS[(modalBlock as Extract<Block, { kind: 'interactive' }>).spec.kind]?.label ?? '互动练习'}
              </span>
              <button type="button" className="dgb-practice-modal-close" onClick={() => setModalBlock(null)} aria-label="关闭">×</button>
            </header>
            <div className="dgb-practice-modal-body">
              <BlockSlot block={modalBlock} manifest={manifest} onNavigateNext={onNavigateNext} />
            </div>
          </div>
        </div>
      )}
    </>
  );
}

function ReviewZone({ blocks, manifest, pageGame, onNavigateNext }: { blocks: Block[]; manifest: CourseManifest; pageGame?: PageGameSpec; onNavigateNext?: (id: string) => void }) {
  // finale-challenge / quiz-intro-animation 为副栏卡。不再靠 grid 块数自适应，
  // 避免单块（如仅 finale）退化成全宽横幅。
  const mainBlocks = blocks.filter((b) => b.kind === 'summary');
  const sideBlocks = blocks.filter((b) => b.kind !== 'summary');
  const hasSideContent = pageGame || sideBlocks.length > 0;
  return (
    <div className="dgb-zone-review">
      <div className="dgb-zone-header">
        <span className="dgb-zone-icon">✅</span>
        <span className="dgb-zone-title">复习巩固</span>
      </div>
      <div className="dgb-review-layout">
        {mainBlocks.length > 0 && (
          <div className="dgb-review-main">
            {mainBlocks.map((block) => (
              <div key={block.id} className="dgb-review-item">
                <BlockSlot block={block} manifest={manifest} onNavigateNext={onNavigateNext} />
              </div>
            ))}
          </div>
        )}
        {hasSideContent && (
          <div className="dgb-review-side">
            {pageGame && (
              <div className="dgb-review-item">
                <PageGameCard game={pageGame} />
              </div>
            )}
            {sideBlocks.map((block) => (
              <div key={block.id} className="dgb-review-item">
                <BlockSlot block={block} manifest={manifest} onNavigateNext={onNavigateNext} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function PageGameCard({ game }: { game: PageGameSpec }) {
  const [open, setOpen] = useState(false);
  const level = useMemo(() => ({
    modeId: game.modeId,
    levelId: game.levelId,
    title: game.title,
    objective: game.objective,
    difficulty: game.difficulty,
    starThresholds: game.starThresholds,
    timeLimit: game.timeLimit,
    data: game.data,
  }), [game]);

  return (
    <>
      <button
        type="button"
        className="dgb-interactive-card dgb-page-game-card"
        onClick={() => setOpen(true)}
      >
        <span className="dgb-interactive-card-icon">🎮</span>
        <span className="dgb-interactive-card-body">
          <span className="dgb-interactive-card-label">{game.title}</span>
          <span className="dgb-interactive-card-prompt">{game.objective}</span>
        </span>
        <span className="dgb-interactive-card-action">开始挑战 ▶</span>
      </button>
      {open && (
        <Suspense fallback={<div className="dgb-block-placeholder">游戏加载中…</div>}>
          <EduGameHost level={level} onClose={() => setOpen(false)} />
        </Suspense>
      )}
    </>
  );
}

/**
 * AnimatedBlockWrap — Block 入场动画包装器
 * 使用 IntersectionObserver，当 Block 进入视口时触发 CSS 动画。
 * 动画效果参考 OpenMAIC configs/animation.ts 的 fadeInUp。
 */
function AnimatedBlockWrap({
  children,
  index,
  isActive,
  isDimmed,
  blockId,
}: {
  children: ReactElement;
  index: number;
  isActive?: boolean;
  isDimmed?: boolean;
  /** T-19-B · 暴露 data-element-id="dgb-block-{id}"，
   *  让 BlockPlaybackEngine 在缺 nodes 数据时仍能整体 spotlight 当前 block。
   *  与 graphics/mermaid 内部 nodes 级 elementId 互不冲突（前者更细粒度）。 */
  blockId?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      ([entry]) => { if (entry?.isIntersecting) { setVisible(true); obs.disconnect(); } },
      { threshold: 0.15 },
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  // 当 Block 被激活时，滚动到视口中央（center），让 AI 讲师讲到的 block 居中可见
  useEffect(() => {
    if (isActive && ref.current) {
      // 先确保入场动画的 dgb-block-hidden 已经被切换走，避免 scrollIntoView 跳到一个 0 高度的占位上
      if (!visible) setVisible(true);
      // 用 rAF 延后一帧，等浏览器算完高度再滚
      const id = requestAnimationFrame(() => {
        ref.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      });
      return () => cancelAnimationFrame(id);
    }
  }, [isActive, visible]);

  let cls = visible ? 'dgb-block-animated dgb-anim-fadeInUp' : 'dgb-block-hidden';
  if (isActive) cls += ' dgb-block-spotlight';
  else if (isDimmed) cls += ' dgb-block-dimmed';

  return (
    <div
      ref={ref}
      className={cls}
      data-element-id={blockId ? `dgb-block-${blockId}` : undefined}
      style={{ animationDelay: visible ? '0s' : `${index * 0.08}s` }}
    >
      {children}
    </div>
  );
}

function BlockSlot({ block, manifest, onNavigateNext, codeFlowStep }: {
  block: Block;
  manifest: CourseManifest;
  onNavigateNext?: (id: string) => void;
  /** 4 · 仅 content zone 内传入；命中 block.id 时驱动 CodeBlock.currentStepIdx */
  codeFlowStep?: { blockId: string | null; idx: number };
}) {
  switch (block.kind) {
    case 'text':
      // 局部 CommentaryBar 已迁移到底部全局 Roundtable AudioBar；
      // block.commentary.stepScripts 由 Shell.buildBlockActions 拼入统一播放队列。
      return <TextBlock markdown={block.markdown} blockId={block.id} />;
    case 'graphics':
      // 之前只传 src/alt，导致 GraphicsBlock 的 inline SVG 注入逻辑（把
      // data-element-id="dgb-graphics-{nodeId}" 写到 SVG 子树）拿不到 nodes，
      // 直接 return 原始 svgText → DOM 上没有任何 data-element-id →
      // BlockPlaybackEngine 调用 highlight('dgb-graphics-gpio') 时 querySelector
      // 命中 0 → LaserOverlay/HighlightOverlay 静默退出 → 用户看不到 spotlight/laser/方框。
      // 这是"完全没看到 spotlight、方框、重点"的真根因。
      return (
        <GraphicsBlock
          src={block.src}
          alt={block.alt}
          caption={block.caption}
          nodes={block.nodes}
          blockId={block.id}
        />
      );
    case 'quiz': {
      const quiz = manifest.quizzes?.[block.ref];
      return <QuizBlock quiz={quiz} refId={block.ref} />;
    }
    case 'digital-human':
      return (
        <Suspense fallback={<div className="dgb-dh-loading">数字人加载中…</div>}>
          <DigitalHumanBlock
            script={block.script}
            avatarState={block.avatarState}
            faq={block.faq}
            ttsEnabled={block.ttsEnabled}
            welcomeMessage={block.welcomeMessage}
          />
        </Suspense>
      );
    case 'animation':
      return <AnimationBlock src={block.src} format={block.format} metadata={block.metadata} blockId={block.id} />;
    case 'quiz-intro-animation': {
      const quizRef = block.quizRef;
      const quiz = manifest.quizzes?.[quizRef] ?? undefined;
      return <QuizIntroBlock block={block} quiz={quiz} />;
    }
    case 'interactive': {
      if (block.spec.kind === 'matching') return <MatchingBlock spec={block.spec} />;
      if (block.spec.kind === 'fill-blank') return <FillBlankBlock spec={block.spec} />;
      if (block.spec.kind === 'ordering') return <OrderingBlock spec={block.spec} />;
      if (block.spec.kind === 'classification') return <ClassificationBlock spec={block.spec} />;
      if (block.spec.kind === 'memory-match') return <MemoryMatchBlock spec={block.spec} />;
      if (block.spec.kind === 'flashcard') return <FlashcardBlock spec={block.spec} />;
      if (block.spec.kind === 'spot-difference') return <SpotDifferenceBlock spec={block.spec} />;
      if (block.spec.kind === 'hotspot') return <HotspotBlock spec={block.spec} />;
      if (block.spec.kind === 'code-cloze') return <CodeClozeBlock spec={block.spec} />;

      if (block.spec.kind === 'bit-flip') return <BitFlipBlock spec={block.spec} />;
      if (block.spec.kind === 'single-choice') return <SingleChoiceBlock spec={block.spec} />;
      if (block.spec.kind === 'multiple-choice') return <MultipleChoiceBlock spec={block.spec} />;
      if (block.spec.kind === 'true-false') return <TrueFalseBlock spec={block.spec} />;
      if (block.spec.kind === 'timed-quiz') return <TimedQuizBlock spec={block.spec} />;
      if (block.spec.kind === 'slider-estimate') return <SliderEstimateBlock spec={block.spec} />;
      if (block.spec.kind === 'sequence-builder') return <SequenceBuilderBlock spec={block.spec} />;
      if (block.spec.kind === 'truth-table') return <TruthTableBlock spec={block.spec} />;
      if (block.spec.kind === 'base-converter') return <BaseConverterBlock spec={block.spec} />;
      if (block.spec.kind === 'register-config') return <RegisterConfigBlock spec={block.spec} />;
      if (block.spec.kind === 'waveform-tuner') return <WaveformTunerBlock spec={block.spec} />;
      if (block.spec.kind === 'parameter-match') return <ParameterMatchBlock spec={block.spec} />;
      if (block.spec.kind === 'hotspot-sequence') return <HotspotSequenceBlock spec={block.spec} />;
      if (block.spec.kind === 'drag-label') return <DragLabelBlock spec={block.spec} />;
      if (block.spec.kind === 'signal-trace') return <SignalTraceBlock spec={block.spec} />;
      if (block.spec.kind === 'register-decoder') return <RegisterDecoderBlock spec={block.spec} />;
      if (block.spec.kind === 'arcade-runner') return <ArcadeRunnerBlock spec={block.spec} />;
      // TypeScript 收窄后 block.spec 为 never，不应继续访问 .kind
      return <div className="dgb-block-placeholder">interactive · 未知类型</div>;
    }
    case 'video':
      return <VideoBlock src={block.src} poster={block.poster} caption={block.caption} />;
    // v4 · 新增 block kinds —— 已实装渲染组件
    case 'code': {
      // commentary.stepScripts 由 Shell.buildBlockActions 拼入底部统一播放队列；
      // flow（若存在）由 CodeBlock 自身渲染为 Mermaid pane + step list（4.3）；
      //            currentStepIdx 受控驱动 step 切换（与 stepScripts 对齐）。
      const isFlowOwner = !!(block.flow && codeFlowStep && codeFlowStep.blockId === block.id);
      return (
        <CodeBlock
          language={block.language}
          code={block.code}
          filename={block.filename}
          highlightLines={block.highlightLines}
          explanation={block.explanation}
          flow={block.flow}
          currentStepIdx={isFlowOwner ? codeFlowStep!.idx : undefined}
        />
      );
    }
    case 'mindmap':
      return <MindmapBlock root={block.root} />;
    case 'experiment':
      return (
        <ExperimentBlock
          title={block.title}
          steps={block.steps}
          expectedResult={block.expectedResult}
          troubleshooting={block.troubleshooting}
        />
      );
    case 'summary':
      return (
        <SummaryBlock
          keyPoints={block.keyPoints}
          nextLessonId={block.nextLessonId}
          reviewQuestions={block.reviewQuestions}
          onNavigateNext={onNavigateNext}
        />
      );
    case 'table':
      return (
        <TableBlock
          headers={block.headers}
          rows={block.rows}
          caption={block.caption}
        />
      );
    case 'waveform':
      return (
        <WaveformBlock
          title={block.title}
          timeScale={block.timeScale}
          signals={block.signals}
        />
      );
    // v4.4 · OpenMAIC 互动 Widget
    case 'widget':
      return <WidgetRenderer block={block} />;
    // v5 · 教材化 Block 套件
    case 'callout':
      return (
        <CalloutBlockPrimitive kind={block.calloutKind} title={block.title} subtitle={block.subtitle}>
          <TextBlock markdown={block.markdown} />
        </CalloutBlockPrimitive>
      );
    case 'info-table':
      return (
        <InfoTableBlock
          title={block.title}
          intro={block.intro}
          rows={block.rows.map((r) => ({ label: r.label, value: r.value, tone: r.tone }))}
        />
      );
    case 'principles':
      return (
        <PrincipleCardsBlock
          heading={block.heading}
          items={block.items.map((it) => ({ title: it.title, content: it.content, numeral: it.numeral }))}
          layout={block.layout}
        />
      );
    case 'figure-pair':
      return (
        <FigurePairBlock
          items={
            block.items.length === 2
              ? [block.items[0]!, block.items[1]!]
              : [block.items[0]!]
          }
        />
      );
    // G1.3 · Mermaid 流程图 block
    case 'mermaid':
      return (
        <MermaidBlock
          source={block.source}
          diagramType={block.diagramType}
          title={block.title}
          nodes={block.nodes}
          blockId={block.id}
        />
      );
    // M10 · Finale Challenge 全屏游戏化挑战
    case 'finale-challenge':
      return <FinaleChallenge block={block} />;

    case 'math':
      return <MathBlock block={block} />;

    case 'wokwi-element':
      return (
        <WokwiBlock
          blockId={block.id}
          spec={block.spec}
          title={block.title}
          caption={block.caption}
        />
      );
    default: {
      // BlockRegistry fallback: 查询注册表中是否有自定义渲染器
      const registryRenderer = BlockRegistry.get((block as any).kind);
      if (registryRenderer) {
        const Renderer = registryRenderer;
        return <Renderer block={block} manifest={manifest} />;
      }
      const exhaustive: never = block;
      return (
        <div className="dgb-block-placeholder">
          未知 block kind: <code>{(exhaustive as { kind?: string }).kind ?? '?'}</code>
        </div>
      );
    }
  }
}
