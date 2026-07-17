import { useEffect, useRef, useMemo, useState, useCallback } from 'react';
import { cssVarsStyle } from '@dgbook/ui';
import type { CourseManifest, Page } from '@dgbook/types';
import { PageRenderer } from '@dgbook/renderer';
import type { ManifestState, EmbedMode } from '../data/useManifest';
import s from './Shell.module.css';
import { CourseHome } from './CourseHome';
import { PageActionRunner } from '@dgbook/playback';
import { TTSAdapter } from '@dgbook/playback';
import { resolveBlockIdFromElementId } from '@dgbook/playback';
import { buildBlockNav, currentBlockIndex, type BlockNav } from '@dgbook/playback';
import { createDriver, type AnimDriver } from '@dgbook/anim';
import { useKeyboardShortcuts } from './useKeyboardShortcuts';
import { AudioBar } from './AudioBar';
import { SideNav } from './SideNav';
import { RightPanel } from './RightPanel';
import { manifestToOutline, LOADING_OUTLINE, type OutlineNode } from './outline';
import {
  HighlightProvider, HighlightOverlay, LaserOverlay,
  type HighlightContextValue,
} from '@dgbook/blocks';
import {
  IconSearch, IconBookOpen, IconLayers,
  IconMonitor,
} from './icons';
import {
  derivePageFaq,
  DEFAULT_AI_TUTOR,
  useAiTutor,
} from '@dgbook/tutor';
import { WelcomeBubble, ProgressRing, HighlightBridge } from './ShellWidgets';

type ThemeVariantName = 'textbook' | 'light' | 'chip-light' | 'chip-dark';

function themeVarsStyle(_variant: ThemeVariantName): Record<string, string> {
  return cssVarsStyle;
}

type PlaybackSpeed = 0.75 | 1 | 1.25 | 1.5 | 2;
const PLAYBACK_SPEED_OPTIONS: readonly PlaybackSpeed[] = [0.75, 1, 1.25, 1.5, 2] as const;
const DEFAULT_PLAYBACK_SPEED: PlaybackSpeed = 1;

interface RuntimeConfig {
  mode?: 'standalone' | 'offline' | 'embed';
  persistenceNamespace?: string;
  features?: {
    qwenTTS?: boolean;
    spotlight?: boolean;
    laser?: boolean;
    [k: string]: boolean | undefined;
  };
}


const THEME_KEY = 'dgbook.theme.variant';
const THEME_ORDER: ThemeVariantName[] = ['textbook', 'light', 'chip-light', 'chip-dark'];
const THEME_LABEL: Record<ThemeVariantName, string> = {
  'light':      '亮 · 通用',
  'chip-light': '亮 · 电路',
  'chip-dark':  '暗 · 电路',
  'textbook':   '纸 · 教材',
};
const THEME_GLYPH: Record<ThemeVariantName, string> = {
  'light':      '☀',
  'chip-light': '◐',
  'chip-dark':  '☾',
  'textbook':   '📖',
};

function loadStoredVariant(): ThemeVariantName | null {
  if (typeof window === 'undefined') return null;
  try {
    const v = window.localStorage.getItem(THEME_KEY);
    return THEME_ORDER.includes(v as ThemeVariantName) ? (v as ThemeVariantName) : null;
  } catch { return null; }
}

const SPEED_KEY_SUFFIX = '.speed';

function speedStorageKey(namespace: string): string {
  return `${namespace}${SPEED_KEY_SUFFIX}`;
}

function loadStoredSpeed(mode: string, namespace: string): PlaybackSpeed {
  if (mode === 'offline') return DEFAULT_PLAYBACK_SPEED;
  if (typeof window === 'undefined') return DEFAULT_PLAYBACK_SPEED;
  try {
    const raw = window.localStorage.getItem(speedStorageKey(namespace));
    if (!raw) return DEFAULT_PLAYBACK_SPEED;
    const n = Number.parseFloat(raw);
    if (!Number.isFinite(n)) return DEFAULT_PLAYBACK_SPEED;
    return (PLAYBACK_SPEED_OPTIONS as readonly number[]).includes(n)
      ? (n as PlaybackSpeed)
      : DEFAULT_PLAYBACK_SPEED;
  } catch { return DEFAULT_PLAYBACK_SPEED; }
}

function saveStoredSpeed(mode: string, namespace: string, speed: PlaybackSpeed): void {
  if (mode === 'offline') return;
  if (typeof window === 'undefined') return;
  try {
    window.localStorage.setItem(speedStorageKey(namespace), String(speed));
  } catch { /* ignore */ }
}

function nextSpeed(current: number): PlaybackSpeed {
  const opts = PLAYBACK_SPEED_OPTIONS;
  const i = opts.findIndex((s) => Math.abs(s - current) < 0.01);
  const nextIdx = (i < 0 ? 0 : i + 1) % opts.length;
  return opts[nextIdx] ?? DEFAULT_PLAYBACK_SPEED;
}

function formatSpeed(s: number): string {
  return Number.isInteger(s) ? `${s}×` : `${s}×`;
}


interface ShellProps {
  courseId: string;
  state: ManifestState;
  runtimeConfig?: RuntimeConfig;
  embedMode?: EmbedMode;
}

function flatPages(m: CourseManifest): Page[] {
  return m.chapters.flatMap((ch) => ch.sections.flatMap((sec) => sec.pages));
}

const PROGRESS_KEY = 'dgbook.progress.';

function readPageFromUrl(): string {
  if (typeof window === 'undefined') return '';
  try {
    const sp = new URLSearchParams(window.location.search);
    const p = sp.get('page');
    return p && p.trim().length > 0 ? p.trim() : '';
  } catch { return ''; }
}

function writePageToUrl(pageId: string) {
  if (typeof window === 'undefined') return;
  try {
    const sp = new URLSearchParams(window.location.search);
    if (pageId) sp.set('page', pageId);
    else sp.delete('page');
    const qs = sp.toString();
    const next = window.location.pathname + (qs ? `?${qs}` : '') + window.location.hash;
    window.history.replaceState(null, '', next);
  } catch { /* ignore */ }
}

function loadProgress(courseId: string): Set<string> {
  try {
    const raw = window.localStorage.getItem(PROGRESS_KEY + courseId);
    if (!raw) return new Set();
    return new Set(JSON.parse(raw) as string[]);
  } catch { return new Set(); }
}
function saveProgress(courseId: string, visited: Set<string>) {
  try {
    window.localStorage.setItem(PROGRESS_KEY + courseId, JSON.stringify([...visited]));
  } catch { /* ignore */ }
}

export function Shell({ courseId, state, runtimeConfig, embedMode: _embedMode }: ShellProps) {
  const features = runtimeConfig?.features ?? {
    aiTutor: true, qwenTTS: true,
    topBar: true, sideNav: true, rightPanel: true, audioBar: true, themeToggle: true,
  };
  const runtimeMode = runtimeConfig?.mode ?? 'standalone';
  const persistenceNamespace = runtimeConfig?.persistenceNamespace ?? `dgbook.${runtimeMode}`;

  const highlightApiRef = useRef<HighlightContextValue | null>(null);
  const animDriverRef = useRef<AnimDriver | null>(null);

  // 朗读速率 / 进度（PageActionRunner 唯一引擎）；offline 永远 1.0
  const [ttsProgress, setTtsProgress] = useState(0);
  const [ttsRate, setTtsRate] = useState<number>(
    () => loadStoredSpeed(runtimeMode, persistenceNamespace),
  );

  const outline = useMemo<OutlineNode[]>(() => {
    if (state.status === 'ok') return manifestToOutline(state.manifest);
    return LOADING_OUTLINE;
  }, [state]);

  const pages = useMemo<Page[]>(
    () => (state.status === 'ok' ? flatPages(state.manifest) : []),
    [state],
  );

  const [active, setActive] = useState<string>(() => readPageFromUrl());
  const effectiveActive = active;

  const pageIdSet = useMemo(() => new Set(pages.map((p) => p.id)), [pages]);
  useEffect(() => {
    if (state.status !== 'ok') return;
    if (active && !pageIdSet.has(active)) {
      setActive('');
      writePageToUrl('');
    }
  }, [state.status, active, pageIdSet]);

  useEffect(() => {
    writePageToUrl(active);
  }, [active]);

  useEffect(() => {
    const onPop = () => {
      const next = readPageFromUrl();
      setActive(next && pageIdSet.has(next) ? next : '');
    };
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, [pageIdSet]);
  const activePage = pages.find((p) => p.id === effectiveActive);
  const activePageRef = useRef(activePage);
  useEffect(() => { activePageRef.current = activePage; }, [activePage]);
  const activeIdx = pages.findIndex((p) => p.id === effectiveActive);
  const courseTitle =
    state.status === 'ok' ? state.manifest.title : state.status === 'error' ? '加载失败' : '加载中…';
  const activeChapter = outline.find((ch) => ch.sections.some((sec) => sec.pages.some((p) => p.id === effectiveActive)));
  const activeSection = activeChapter?.sections.find((sec) => sec.pages.some((p) => p.id === effectiveActive));
  const activeUnit = activeSection?.pages.find((p) => p.id === effectiveActive);

  const [visited, setVisited] = useState<Set<string>>(() => loadProgress(courseId));
  const markVisited = (id: string) => {
    setVisited((prev) => {
      if (prev.has(id)) return prev;
      const next = new Set(prev);
      next.add(id);
      saveProgress(courseId, next);
      return next;
    });
  };
  const mainStageRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = mainStageRef.current;
    if (!el || !effectiveActive) return;
    const onScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = el;
      if (scrollHeight > clientHeight && scrollTop + clientHeight >= scrollHeight * 0.9) {
        markVisited(effectiveActive);
      }
    };
    el.addEventListener('scroll', onScroll, { passive: true });
    const checkImmediate = () => {
      const { scrollHeight, clientHeight } = el;
      if (scrollHeight <= clientHeight + 10) markVisited(effectiveActive);
    };
    const timer = setTimeout(checkImmediate, 1200);
    return () => { el.removeEventListener('scroll', onScroll); clearTimeout(timer); };
  }, [effectiveActive]);


  // ←/→ 键盘翻页统一由 useKeyboardShortcuts 接管（Iter-53 块级导航）。

  const manifestVariant: ThemeVariantName =
    state.status === 'ok' ? (state.manifest.theme.variant as ThemeVariantName) : 'light';
  const [storedVariant, setStoredVariant] = useState<ThemeVariantName | null>(() => loadStoredVariant());
  const variant: ThemeVariantName = storedVariant ?? manifestVariant;
  const cycleTheme = () => {
    const idx = THEME_ORDER.indexOf(variant);
    const next = THEME_ORDER[(idx + 1) % THEME_ORDER.length]!;
    setStoredVariant(next);
    try { window.localStorage.setItem(THEME_KEY, next); } catch {}
  };
  const [sideOpen, setSideOpen] = useState<boolean>(true);
  const [filterText, setFilterText] = useState<string>('');
  const [focusMode, setFocusMode] = useState<boolean>(false);

  const SIDE_W_KEY = 'dgbook.layout.sideW';
  const RIGHT_W_KEY = 'dgbook.layout.rightW';
  const SIDE_MIN = 160; const SIDE_MAX = 400;
  const RIGHT_MIN = 220; const RIGHT_MAX = 520;

  const [sideW, setSideW] = useState<number>(() => {
    try { const v = parseInt(localStorage.getItem(SIDE_W_KEY) ?? '', 10); return isNaN(v) ? 220 : v; } catch { return 220; }
  });
  const [rightW, setRightW] = useState<number>(() => {
    try { const v = parseInt(localStorage.getItem(RIGHT_W_KEY) ?? '', 10); return isNaN(v) ? 280 : v; } catch { return 280; }
  });

  const dragSideRef = useRef<{ startX: number; startW: number } | null>(null);
  const dragRightRef = useRef<{ startX: number; startW: number } | null>(null);

  const onSideResizerDown = useCallback((e: React.PointerEvent) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    dragSideRef.current = { startX: e.clientX, startW: sideW };
  }, [sideW]);

  const onRightResizerDown = useCallback((e: React.PointerEvent) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    dragRightRef.current = { startX: e.clientX, startW: rightW };
  }, [rightW]);

  const onSideResizerMove = useCallback((e: React.PointerEvent) => {
    if (!dragSideRef.current) return;
    const w = Math.min(SIDE_MAX, Math.max(SIDE_MIN, dragSideRef.current.startW + e.clientX - dragSideRef.current.startX));
    setSideW(w);
    try { localStorage.setItem(SIDE_W_KEY, String(w)); } catch { /* ignore */ }
  }, []);

  const onRightResizerMove = useCallback((e: React.PointerEvent) => {
    if (!dragRightRef.current) return;
    const delta = dragRightRef.current.startX - e.clientX;
    const w = Math.min(RIGHT_MAX, Math.max(RIGHT_MIN, dragRightRef.current.startW + delta));
    setRightW(w);
    try { localStorage.setItem(RIGHT_W_KEY, String(w)); } catch { /* ignore */ }
  }, []);

  const onResizerUp = useCallback((ref: { current: unknown }) => {
    ref.current = null;
  }, []);

  const showBottomAudio = features.audioBar;

  const shellCls = [
    s.shell,
    variant === 'chip-dark' ? s.chipDark : variant === 'chip-light' ? s.chipLight : '',
    sideOpen ? '' : s.sideCollapsed,
    runtimeMode !== 'standalone' ? s.embedContent : '',
    focusMode ? s.focusMode : '',
    showBottomAudio ? '' : s.noAudio,
  ].filter(Boolean).join(' ');

  useEffect(() => {
    if (runtimeMode !== 'embed') return;
    if (typeof window === 'undefined' || window.parent === window) return;
    try {
      window.parent.postMessage({
        source: 'dgbook-player',
        type: 'page-change',
        courseId,
        pageId: effectiveActive || null,
        pageTitle: activeUnit?.title ?? null,
        visitedCount: visited.size,
        totalPages: pages.length,
      }, '*');
    } catch { /* ignore */ }
  }, [runtimeMode, courseId, effectiveActive, activeUnit, visited.size, pages.length]);

  const [expandedMods, setExpandedMods] = useState<Set<string>>(() => new Set(outline.map((o) => o.id)));
  const [expandedSecs, setExpandedSecs] = useState<Set<string>>(() => new Set());
  const toggleMod = (id: string) => {
    setExpandedMods((prev) => {
      const n = new Set(prev);
      if (n.has(id)) n.delete(id); else n.add(id);
      return n;
    });
  };
  const toggleSec = (id: string) => {
    setExpandedSecs((prev) => {
      const n = new Set(prev);
      if (n.has(id)) n.delete(id); else n.add(id);
      return n;
    });
  };

  const aiTutor = state.status === 'ok' ? state.manifest.aiTutor : undefined;
  const aiName = aiTutor?.name ?? DEFAULT_AI_TUTOR.name;
  const aiSubtitle = aiTutor?.subtitle ?? DEFAULT_AI_TUTOR.subtitle;
  const aiWelcome = aiTutor?.welcome ?? DEFAULT_AI_TUTOR.welcome;
  const aiAvatarEmoji = aiTutor?.avatarEmoji;

  const domainTerms = state.status === 'ok' ? state.manifest.domainTerms : undefined;
  const followUpTemplates = state.status === 'ok' ? state.manifest.followUpTemplates : undefined;

  // 每节讲稿 + FAQ：从当前页 digital-human block 取，否则降级到 tutor 派生器
  const { pageFaq } = useMemo(() => {
    if (!activePage) return { pageFaq: [] };
    const dh = activePage.blocks.find((b) => b.kind === 'digital-human');
    if (dh && dh.kind === 'digital-human') {
      return {
        pageFaq: Array.isArray(dh.faq) ? dh.faq : [],
      };
    }
    return { pageFaq: derivePageFaq(activePage, domainTerms) };
  }, [activePage, domainTerms]);


  // PageActionRunner 唯一引擎：page.actions 驱动 spotlight + speak 微电影
  const [activeBlockId, setActiveBlockId] = useState<string | null>(null);
  const [activeItemId, setActiveItemId] = useState<string | null>(null);
  const [revealedItemIds, setRevealedItemIds] = useState<Set<string> | undefined>(undefined);
  const [codeFlowStep, setCodeFlowStep] = useState<{ blockId: string | null; idx: number }>({ blockId: null, idx: 0 });
  const [speechText, setSpeechText] = useState('');
  const [engineState, setEngineState] = useState<'idle' | 'playing' | 'paused'>('idle');
  const [isLive, setIsLive] = useState(false);

  const actionsRunnerRef = useRef<PageActionRunner | null>(null);
  const actionsTtsRef = useRef<TTSAdapter | null>(null);
  const [showActionsHint, setShowActionsHint] = useState(false);
  const actionsHintShownRef = useRef<boolean>(false);

  /**
   * 块级导航：从 page.actions 推导内容块顺序 + 每块首个 action 下标。
   * 「上一个/下一个」与 ←/→ 据此在 block 间前进后退（seekTo + 滚动 + 高亮 + 媒体联动）。
   */
  const blockNav = useMemo<BlockNav>(() => buildBlockNav(activePage), [activePage]);
  const blockNavRef = useRef<BlockNav>(blockNav);
  useEffect(() => { blockNavRef.current = blockNav; }, [blockNav]);
  /** 跨页溢出后，新页加载完定位到首块('first')或末块('last')。 */
  const pendingBlockNavRef = useRef<'first' | 'last' | null>(null);

  // 页面切换：dispose 旧 runner，page.actions 非空时启 PageActionRunner
  useEffect(() => {
    if (actionsRunnerRef.current) {
      actionsRunnerRef.current.dispose();
      actionsRunnerRef.current = null;
    }
    if (actionsTtsRef.current) {
      actionsTtsRef.current.dispose();
      actionsTtsRef.current = null;
    }
    setActiveBlockId(null);
    setActiveItemId(null);
    setRevealedItemIds(undefined);
    setSpeechText('');
    setCodeFlowStep({ blockId: null, idx: 0 });
    setEngineState('idle');
    setIsLive(false);

    // 清理上一页的 AnimDriver
    animDriverRef.current?.finalize();
    animDriverRef.current?.destroy();
    animDriverRef.current = null;

    const currentPage = pages.find((p) => p.id === effectiveActive);
    const actionsList = currentPage?.actions;
    if (!actionsList || actionsList.length === 0) {
      try {
        (window as unknown as { __dgbookActions?: unknown }).__dgbookActions = null;
      } catch { /* ignore */ }
      return;
    }

    const tts = new TTSAdapter({ forceWebSpeech: !features.qwenTTS, rate: ttsRate });
    void tts.init();
    actionsTtsRef.current = tts;
    const runner = new PageActionRunner(
      tts,
      { actions: actionsList, courseId: 'dgbook', pageId: effectiveActive },
      {
        onModeChange: (mode) => {
          if (mode === 'playing') { setEngineState('playing'); setIsLive(false); }
          else if (mode === 'live') { setEngineState('paused'); setIsLive(true); }
          else if (mode === 'paused') { setEngineState('paused'); setIsLive(false); }
          else { setEngineState('idle'); setIsLive(false); }
        },
        onSpeechStart: (text) => setSpeechText(text),
        onSpeechEnd: () => { /* 字幕保留到下条 speak 覆盖；防闪烁 */ },
        onEffectFire: (effect) => {
          const api = highlightApiRef.current;
          const stage = mainStageRef.current;
          const targetId = effect.kind === 'reveal' ? null : effect.targetId;
          const blockId = resolveBlockIdFromElementId(targetId, activePageRef.current);
          if (blockId) setActiveBlockId(blockId);

          // 解决 anim-step 在 iframe 内 HighlightOverlay 无法 scrollIntoView 的问题。
          if (stage && blockId && (effect.kind === 'spotlight' || effect.kind === 'laser')) {
            const blockEl = stage.querySelector<HTMLElement>(
              `[data-element-id="dgb-block-${blockId}"]`,
            );
            if (blockEl) {
              const r = blockEl.getBoundingClientRect();
              const outOfView = r.bottom < 0 || r.top > window.innerHeight;
              if (outOfView) {
                blockEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
              }
            }
          }

          // animation step 协议：targetId 形如 dgb-anim-step-{N} 时通过 AnimDriver 推进
          if (effect.kind === 'spotlight' || effect.kind === 'laser') {
            const m = /^dgb-anim-step-(\d+)$/.exec(effect.targetId);
            if (m && m[1]) {
              animDriverRef.current?.step(Math.max(0, parseInt(m[1], 10) - 1));
            }
          }

          if (!api) return;
          if (effect.kind === 'spotlight' || effect.kind === 'reveal') {
            api.spotlight({ elementId: effect.targetId });
          } else if (effect.kind === 'laser') {
            api.laser({ elementId: effect.targetId });
          }
        },
        onEffectClear: () => {
          highlightApiRef.current?.clear();
        },
        onProgress: ({ actionIndex, total }) => {
          setTtsProgress(total > 0 ? actionIndex / total : 0);
        },
        onComplete: () => {
          setSpeechText('');
          highlightApiRef.current?.clear();
          setActiveBlockId(null);
          // P1: Auto-play 下一页（对标 OpenMAIC autoPlayLecture）
          // 当前页播完后 1.5s 自动跳到下一页继续播报
          const nextPage = (() => {
            const ap = activePageRef.current;
            if (!ap || state.status !== 'ok') return null;
            const allPages: string[] = [];
            for (const ch of state.manifest.chapters) {
              for (const sec of ch.sections) {
                for (const p of sec.pages) allPages.push(p.id);
              }
            }
            const idx = allPages.indexOf(ap.id);
            return idx >= 0 && idx < allPages.length - 1 ? allPages[idx + 1] : null;
          })();
          if (nextPage) {
            setTimeout(() => {
              setActive(nextPage);
              // 新页加载后 PageActionRunner 会在 useEffect 中重建，
              // 需要延迟 start（等 runner 初始化完毕）
              setTimeout(() => {
                actionsRunnerRef.current?.start();
              }, 500);
            }, 1500);
          }
        },
        onEnterLive: () => { /* 占位：未来接 AI 助教面板聚焦 */ },

        //   按视频时间轴逐句切字幕（与画面对齐，不依赖 TTS），ended 后继续 cursor。
        onPlayVideo: (targetId, done, subtitles) => {
          const stage = mainStageRef.current;
          // targetId 形如 dgb-block-{blockId}；video 上的 data-anim-video={blockId}
          const blockId = targetId.replace(/^dgb-block-/, '');
          const video = stage?.querySelector<HTMLVideoElement>(
            `video[data-anim-video="${blockId}"]`,
          ) ?? stage?.querySelector<HTMLVideoElement>('video[data-anim-video]');
          if (!video) { done(); return; }
          setActiveBlockId(blockId);
          video.scrollIntoView({ block: 'center', behavior: 'smooth' });

          const subs = (subtitles ?? []).slice().sort((a, b) => a.t - b.t);
          let lastSubIdx = -1;
          const onTimeUpdate = () => {
            if (subs.length === 0) return;
            const t = video.currentTime;
            // 找到当前时间点应显示的最后一段字幕
            let idx = -1;
            for (let k = 0; k < subs.length; k++) {
              if (subs[k]!.t <= t + 0.05) idx = k; else break;
            }
            if (idx >= 0 && idx !== lastSubIdx) {
              lastSubIdx = idx;
              const text = subs[idx]!.text;
              setSpeechText(text);
              // TTS 伴随朗读（有就读，读不出也不影响字幕推进）
              try { actionsTtsRef.current?.speak(text, () => {}, () => {}); } catch { /* ignore */ }
            }
          };
          const finish = () => {
            video.removeEventListener('ended', finish);
            video.removeEventListener('timeupdate', onTimeUpdate);
            done();
          };
          video.addEventListener('timeupdate', onTimeUpdate);
          video.addEventListener('ended', finish);
          // 首段字幕立即显示
          if (subs.length > 0) { setSpeechText(subs[0]!.text); lastSubIdx = 0;
            try { actionsTtsRef.current?.speak(subs[0]!.text, () => {}, () => {}); } catch { /* ignore */ } }
          video.currentTime = 0;
          void video.play().catch(() => finish());
        },
      },
    );
    actionsRunnerRef.current = runner;

    // 当页面有 animation block 时，创建 AnimDriver 代理已有 DOM iframe
    let animTimer: ReturnType<typeof setTimeout> | null = null;
    const hasAnimBlock = currentPage?.blocks?.some(
      (b: { kind: string }) => b.kind === 'animation',
    );
    if (hasAnimBlock && mainStageRef.current) {
      // 延迟绑定：等 PageRenderer 渲染出 iframe 后再查找
      animTimer = window.setTimeout(() => {
        const stage = mainStageRef.current;
        if (!stage) return;
        const iframe = stage.querySelector<HTMLIFrameElement>('iframe.dgb-anim-html-frame');
        if (iframe) {
          animDriverRef.current = {
            kind: 'svg-iframe-proxy',
            stepCount: 0,
            async mount() {},
            step(n: number) {
              try { iframe.contentWindow?.postMessage({ type: 'dgb-step', step: n }, '*'); } catch { /* sandbox */ }
            },
            play() {},
            pause() {},
            resume() {},
            finalize() {
              try { iframe.contentWindow?.postMessage({ type: 'dgb-anim-finalize' }, '*'); } catch { /* sandbox */ }
            },
            destroy() { animDriverRef.current = null; },
          };
        }
      }, 500);
    }

    try {
      (window as unknown as { __dgbookActions?: unknown }).__dgbookActions = {
        mode: () => runner.getMode(),
        actionCount: actionsList.length,
        pageId: effectiveActive,
        actionIndex: () => runner.getActionIndex(),
        blockCount: () => blockNavRef.current.entries.length,
        currentBlock: () => currentBlockIndex(blockNavRef.current, runner.getActionIndex()),
        prevBlock: () => gotoPrevBlock(),
        nextBlock: () => gotoNextBlock(),
      };
    } catch { /* ignore */ }

    let navTimer: ReturnType<typeof setTimeout> | null = null;
    const pendingNav = pendingBlockNavRef.current;
    if (pendingNav) {
      pendingBlockNavRef.current = null;
      navTimer = window.setTimeout(() => {
        const nav = blockNavRef.current;
        if (nav.entries.length === 0) return;
        gotoBlockEntry(pendingNav === 'first' ? 0 : nav.entries.length - 1);
      }, 360);
    }
    if (!actionsHintShownRef.current) {
      actionsHintShownRef.current = true;
      setShowActionsHint(true);
      window.setTimeout(() => setShowActionsHint(false), 5000);
    }

    return () => {
      if (animTimer) window.clearTimeout(animTimer);
      if (navTimer) window.clearTimeout(navTimer);
    };
  }, [effectiveActive, pages, features.qwenTTS, ttsRate]);

  useEffect(() => {
    if (!effectiveActive) return;
    for (const ch of outline) {
      for (const sec of ch.sections) {
        if (sec.pages.some(p => p.id === effectiveActive)) {
          setExpandedMods(prev => prev.has(ch.id) ? prev : new Set([...prev, ch.id]));
          setExpandedSecs(prev => prev.has(sec.id) ? prev : new Set([...prev, sec.id]));
          return;
        }
      }
    }
  }, [effectiveActive, outline]);

  /** 统一播放入口：page.actions 非空时由 runner 接管，否则 no-op（纯渲染页） */
  const startPlay = useCallback(() => {
    const runner = actionsRunnerRef.current;
    if (!runner) return;
    const mode = runner.getMode();
    if (mode === 'idle') runner.start();
    else if (mode === 'paused') runner.resume();
  }, []);

  /**
   * 跳到本页第 entryIdx 个内容块：seekTo 该块首个 action（连续播报 →
   * 讲解 + 动画 step + 视频联动随之触发）+ 滚动到该块 + 高亮。
   * runner 不存在（纯渲染页）时只做滚动 + 高亮。
   */
  const gotoBlockEntry = useCallback((entryIdx: number) => {
    const nav = blockNavRef.current;
    const entry = nav.entries[entryIdx];
    if (!entry) return;
    setActiveBlockId(entry.blockId);
    const stage = mainStageRef.current;
    const el = stage?.querySelector<HTMLElement>(`[data-element-id="dgb-block-${entry.blockId}"]`)
      ?? stage?.querySelector<HTMLElement>(`[data-element-id="dgb-wokwi-${entry.blockId}"]`);
    el?.scrollIntoView({ block: 'center', behavior: 'smooth' });
    const runner = actionsRunnerRef.current;
    if (runner) runner.seekTo(entry.firstActionIndex);
  }, []);

  /**
   * 块级「上一个 / 下一个」：在本页 block 间前进后退；到首/末块再按则溢出到相邻页的末/首块。
   * 键盘 ←/→ 与底部按钮共用本逻辑，语义一致。
   */
  const navBlock = useCallback((dir: 1 | -1) => {
    const nav = blockNavRef.current;
    const runner = actionsRunnerRef.current;
    if (nav.entries.length === 0) {
      // 纯渲染页（无 actions）→ 退化为跨页翻页
      const cur = pages.findIndex((p) => p.id === effectiveActive);
      const ni = cur < 0 ? 0 : cur + dir;
      const target = pages[ni];
      if (target) setActive(target.id);
      return;
    }
    const curBlock = runner
      ? currentBlockIndex(nav, runner.getActionIndex())
      : -1;
    const nextIdx = curBlock < 0 ? (dir > 0 ? 0 : nav.entries.length - 1) : curBlock + dir;
    if (nextIdx >= 0 && nextIdx < nav.entries.length) {
      gotoBlockEntry(nextIdx);
      return;
    }
    // 溢出到相邻页：dir>0 → 下一页首块；dir<0 → 上一页末块
    const cur = pages.findIndex((p) => p.id === effectiveActive);
    const ni = cur < 0 ? 0 : cur + dir;
    const target = pages[ni];
    if (target) {
      pendingBlockNavRef.current = dir > 0 ? 'first' : 'last';
      setActive(target.id);
    }
  }, [pages, effectiveActive, setActive, gotoBlockEntry]);

  const gotoPrevBlock = useCallback(() => navBlock(-1), [navBlock]);
  const gotoNextBlock = useCallback(() => navBlock(1), [navBlock]);

  useKeyboardShortcuts({
    enabled: !!features.audioBar,
    activeIdx,
    pages,
    setActive,
    startPlay,
    actionsRunnerRef,
    gotoPrevBlock,
    gotoNextBlock,
  });


  /** 气泡顶部标题：active block.title 优先，回退 page.title / unit.title */
  const bubbleTitleText = useMemo(() => {
    const block = activePage?.blocks.find((b) => b.id === activeBlockId) as
      | { title?: string }
      | undefined;
    const blockTitle = block?.title;
    return (blockTitle && blockTitle.trim())
      || activePage?.title
      || activeUnit?.title
      || '课程播放器';
  }, [activeBlockId, activePage, activeUnit]);

  /** 字幕跟读：playing 时显示当前朗读 chunk 的 speechText，否则显示 bubbleTitleText */
  const bubbleDisplayText = useMemo(() => {
    if (engineState === 'playing' && speechText && speechText.trim()) {
      return speechText.trim();
    }
    return bubbleTitleText;
  }, [engineState, speechText, bubbleTitleText]);
  const isFollowingSpeech = engineState === 'playing' && !!(speechText && speechText.trim());

  // AI 助教对话状态由 useAiTutor hook 接管（含 streaming / followUps / sources）
  const aiTutorEnabled = !!features.aiTutor;
  const tutor = useAiTutor({
    enabled: aiTutorEnabled,
    courseId,
    activePage,
    pageSourceKey: activePage?.source?.pageSourceKey,
    aiName,
    domainTerms,
    followUpTemplates,
  });

  const brandName = (state.status === 'ok' ? state.manifest.theme.brandName : undefined) ?? 'DG';
  const brandSubtitle = (state.status === 'ok' ? state.manifest.theme.brandSubtitle : undefined) ?? '数字教材';

  const completedCount = visited.size;

  const shellStyle = {
    ...themeVarsStyle(variant),
    '--side-w': sideOpen && !focusMode && features.sideNav ? `${sideW}px` : undefined,
    '--right-w': !focusMode && features.rightPanel ? `${rightW}px` : undefined,
  } as React.CSSProperties;

  return (
    <HighlightProvider>
    <HighlightBridge apiRef={highlightApiRef} />
    <div className={shellCls} style={shellStyle}>
      {features.topBar && (
      <header className={`${s.top} ${s.topBar}`}>
        <button
          type="button"
          className={s.topLogo}
          onClick={() => setSideOpen((v) => !v)}
          title={sideOpen ? '收起目录' : '展开目录'}
          aria-label="切换目录"
        >
          <span className={s.topLogoDot}>{brandName.slice(0, 2)}</span>
          <span className={s.topLogoText}>
            <span className={s.topLogoName}>{brandName}</span>
            {brandSubtitle ? <span className={s.topLogoSub}>{brandSubtitle}</span> : null}
          </span>
        </button>
        <div className={s.topCourse}>
          <span className={s.topCourseLabel}>{courseTitle}</span>
        </div>
        <nav className={s.topTabs}>
          <button
            type="button"
            className={`${s.topTab} ${sideOpen ? s.topTabActive : ''}`}
            onClick={() => setSideOpen((v) => !v)}
          >
            <IconBookOpen size={16} />
            <span>目录</span>
          </button>
          <button
            type="button"
            className={`${s.topTab} ${effectiveActive === '' ? s.topTabActive : ''}`}
            onClick={() => setActive('')}
            title="返回课程主页"
          >
            <IconLayers size={16} />
            <span>主页</span>
          </button>
        </nav>
        <div className={s.topGrow} />
        <label className={s.topSearch}>
          <IconSearch size={16} />
          <input
            placeholder="按章节标题过滤…"
            value={filterText}
            onChange={(e) => setFilterText(e.target.value)}
          />
        </label>
        <button
          className={s.topThemeBtn}
          type="button"
          onClick={cycleTheme}
          title={`主题：${THEME_LABEL[variant]}`}
        >
          <span className={s.topThemeGlyph}>{THEME_GLYPH[variant]}</span>
        </button>
        <button
          className={`${s.topThemeBtn} ${focusMode ? s.topFocusActive : ''}`}
          type="button"
          onClick={() => setFocusMode((v) => !v)}
          title={focusMode ? '退出专注模式' : '专注模式'}
        >
          <IconMonitor size={14} />
        </button>
      </header>
      )}

      {features.sideNav && !focusMode && (
        <SideNav
          outline={outline}
          visited={visited}
          effectiveActive={effectiveActive}
          expandedMods={expandedMods}
          expandedSecs={expandedSecs}
          filterText={filterText}
          pages={pages}
          completedCount={completedCount}
          toggleMod={toggleMod}
          toggleSec={toggleSec}
          setActive={setActive}
          errorMessage={state.status === 'error' ? state.message : undefined}
          sideOpen={sideOpen}
          ProgressRing={ProgressRing}
        />
      )}
      {features.sideNav && !focusMode && sideOpen && (
        <div
          className={s.sideResizer}
          onPointerDown={onSideResizerDown}
          onPointerMove={onSideResizerMove}
          onPointerUp={() => onResizerUp(dragSideRef)}
          title="拖动调整目录宽度"
        />
      )}

      <section className={s.main}>
        <div className={s.mainStage} ref={mainStageRef}>
          {state.status === 'ok' ? (
            activePage ? (
              <PageRenderer
                manifest={state.manifest}
                page={activePage}
                visitedSet={visited}
                onNavigateNext={(id) => { setActive(id); }}
                activeBlockId={activeBlockId}
                activeItemId={activeItemId}
                revealedItemIds={revealedItemIds}
                currentSpeechText={engineState !== 'idle' ? speechText : undefined}
                codeFlowStep={codeFlowStep}
              />
            ) : (
              <CourseHome
                manifest={state.manifest}
                visited={visited}
                onSelectPage={(id) => { setActive(id); }}
              />
            )
          ) : (
            <div className={s.mainHint}>
              <div>
                <h2>主舞台 · MainStage</h2>
                <p>
                  {state.status === 'error'
                    ? `manifest 加载失败：${state.message}`
                    : '正在加载课程…'}
                </p>
              </div>
            </div>
          )}
        </div>
      </section>

      {features.rightPanel && !focusMode && (
      <>
      <div
        className={s.rightResizer}
        onPointerDown={onRightResizerDown}
        onPointerMove={onRightResizerMove}
        onPointerUp={() => onResizerUp(dragRightRef)}
        title="拖动调整助教栏宽度"
      />
      <RightPanel
        aiName={aiName}
        aiSubtitle={aiSubtitle}
        aiWelcome={aiWelcome}
        aiAvatarEmoji={aiAvatarEmoji}
        aiTutorEnabled={aiTutorEnabled}
        tutor={tutor}
        pageFaq={pageFaq}
        WelcomeBubble={WelcomeBubble}
        isLive={isLive}
        onEndDiscussion={isLive ? () => { actionsRunnerRef.current?.resume(); } : undefined}
      />
      </>
      )}

      {showBottomAudio && (
        <AudioBar
          showActionsHint={showActionsHint}
          engineState={engineState}
          activePage={activePage}
          activeIdx={activeIdx}
          pages={pages}
          aiTutor={aiTutor}
          aiName={aiName}
          ttsProgress={ttsProgress}
          ttsRate={ttsRate}
          bubbleDisplayText={bubbleDisplayText}
          isFollowingSpeech={isFollowingSpeech}
          startPlay={startPlay}
          setActive={setActive}
          actionsRunnerRef={actionsRunnerRef}
          gotoPrevBlock={gotoPrevBlock}
          gotoNextBlock={gotoNextBlock}
          speedLabel={formatSpeed(ttsRate)}
          onSpeedClick={() => {
            const ns = nextSpeed(ttsRate);
            actionsTtsRef.current?.setRate(ns);
            setTtsRate(ns);
            saveStoredSpeed(runtimeMode, persistenceNamespace, ns);
          }}
        />
      )}
      <HighlightOverlay />
      <LaserOverlay />
    </div>
    </HighlightProvider>
  );
}
