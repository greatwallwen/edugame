/**
 * EduGameHost · React 容器 + 模式注册表
 *
 * Shell 通过 dynamic import 按需加载本组件，把 modeId + level 数据传入。
 * 组件内部根据 modeId 实例化对应 GameMode + GameSession，并管理一局生命周期。
 *
 * Phase 6 现状：
 *   - bit-flip-quest 模式有完整逻辑层 + UI 通过简单的位面板渲染
 *   - 其余 4 模式 stub：UI 占位 + onComplete(0 stars) 让通关流程可走通
 *   - PixiJS 渲染将在后续 sub-phase 引入；本版本先用纯 DOM 把交互闭环
 */
import { useEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import type { LevelData, GameResult } from './types';
import { GameSession } from './GameSession';
import { GameMode } from './GameMode';
import { BitFlipQuestMode } from '../modes/bit-flip-quest';
import { PinRushMode } from '../modes/pin-rush';
import { SignalSurferMode } from '../modes/signal-surfer';
import { CircuitBuilderMode } from '../modes/circuit-builder';
import { InterruptDefenderMode } from '../modes/interrupt-defender';
import { QuickHitMode } from '../modes/quick-hit';
import { MemoryCardMode } from '../modes/memory-card';
import { DragMatchMode } from '../modes/drag-match';
import { SortFlowMode } from '../modes/sort-flow';
import { CardBattleMode } from '../modes/card-battle';
import { Match3Mode } from '../modes/match-3';
import { BossReviewMode } from '../modes/boss-review';
import { QuizRushMode } from '../modes/quiz-rush';
import { PipeConnectMode } from '../modes/pipe-connect';
import { DeviceAssembleMode } from '../modes/device-assemble';
import { MazeTroubleshootMode } from '../modes/maze-troubleshoot';
import { TowerDefenseMode } from '../modes/tower-defense';
import { Merge2048Mode } from '../modes/2048-merge';
import { MinesweeperRiskMode } from '../modes/minesweeper-risk';
import { RhythmTapMode } from '../modes/rhythm-tap';
import { TimelineBuildMode } from '../modes/timeline-build';
import { CaseDetectiveMode } from '../modes/case-detective';
import { KnowledgeMapMode } from '../modes/knowledge-map';
import { RepairSimMode } from '../modes/repair-sim';
import { LabProcedureMode } from '../modes/lab-procedure';
import { ClassificationRunMode } from '../modes/classification-run';
import { ResourceManagementMode } from '../modes/resource-management';
import { ScenarioChoiceMode } from '../modes/scenario-choice';
import { CheckpointAdventureMode } from '../modes/checkpoint-adventure';
import {
  createGodotInitGate,
  getGodotResultPresentation,
  GodotGameMode,
  GODOT_BRIDGE_VERSION,
  isGodotToHostMessage,
  type GodotGameData,
  type GodotHostMessage,
} from '../modes/godot-game';

export interface EduGameHostProps {
  level: LevelData;
  onClose: () => void;
  onComplete?: (result: GameResult) => void;
}

function createMode(level: LevelData): GameMode {
  switch (level.modeId) {
    case 'bit-flip-quest': return new BitFlipQuestMode();
    case 'pin-rush': return new PinRushMode();
    case 'signal-surfer': return new SignalSurferMode();
    case 'circuit-builder': return new CircuitBuilderMode();
    case 'interrupt-defender': return new InterruptDefenderMode();
    case 'quick-hit': return new QuickHitMode();
    case 'memory-card': return new MemoryCardMode();
    case 'drag-match': return new DragMatchMode();
    case 'sort-flow': return new SortFlowMode();
    case 'card-battle': return new CardBattleMode();
    case 'match-3': return new Match3Mode();
    case 'boss-review': return new BossReviewMode();
    case 'quiz-rush': return new QuizRushMode();
    case 'pipe-connect': return new PipeConnectMode();
    case 'device-assemble': return new DeviceAssembleMode();
    case 'maze-troubleshoot': return new MazeTroubleshootMode();
    case 'tower-defense': return new TowerDefenseMode();
    case '2048-merge': return new Merge2048Mode();
    case 'minesweeper-risk': return new MinesweeperRiskMode();
    case 'rhythm-tap': return new RhythmTapMode();
    case 'timeline-build': return new TimelineBuildMode();
    case 'case-detective': return new CaseDetectiveMode();
    case 'knowledge-map': return new KnowledgeMapMode();
    case 'repair-sim': return new RepairSimMode();
    case 'lab-procedure': return new LabProcedureMode();
    case 'classification-run': return new ClassificationRunMode();
    case 'resource-management': return new ResourceManagementMode();
    case 'scenario-choice': return new ScenarioChoiceMode();
    case 'checkpoint-adventure': return new CheckpointAdventureMode();
    case 'godot-game': return new GodotGameMode();
    default: return new QuickHitMode(); // fallback
  }
}

export function EduGameHost(props: EduGameHostProps) {
  const { level, onClose, onComplete } = props;
  const [progress, setProgress] = useState(0);
  const [hint, setHint] = useState<string | undefined>(undefined);
  const [result, setResult] = useState<GameResult | null>(null);

  const mode = useMemo(() => createMode(level), [level]);
  const sessionRef = useRef<GameSession | null>(null);

  useEffect(() => {
    const session = new GameSession(mode, level, {
      onProgress: (ratio, h) => { setProgress(ratio); setHint(h); },
      onResult: (r) => { setResult(r); onComplete?.(r); },
    });
    sessionRef.current = session;
    void session.start();
    return () => { session.abort(); sessionRef.current = null; };
  }, [mode, level, onComplete]);

  // 键盘 Esc 关闭
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div role="dialog" aria-label={level.title} style={overlayStyle}>
      <div style={panelStyle}>
        <header style={headerStyle}>
          <div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{level.title}</div>
            <div style={{ fontSize: 13, opacity: 0.75 }}>{level.objective}</div>
          </div>
          <button type="button" onClick={onClose} aria-label="关闭" style={closeStyle}>×</button>
        </header>

        {result ? (
          <ResultView result={result} onClose={onClose} />
        ) : (
          <PlayView level={level} mode={mode} progress={progress} hint={hint} />
        )}
      </div>
    </div>
  );
}

function PlayView({ level, mode, progress, hint }: {
  level: LevelData;
  mode: GameMode;
  progress: number;
  hint?: string;
}) {
  return (
    <section style={{ flex: 1, padding: '16px 24px', overflow: 'auto' }}>
      <p style={{ fontSize: 14, lineHeight: 1.6 }}>
        {mode.howToPlay.join(' · ')}
      </p>
      <div style={progressBarStyle}>
        <div style={{ ...progressFillStyle, width: `${Math.round(progress * 100)}%` }} />
      </div>
      {hint && <div style={{ fontSize: 13, opacity: 0.7, marginTop: 8 }}>{hint}</div>}
      {level.modeId === 'bit-flip-quest' ? (
        <BitFlipPanel mode={mode as BitFlipQuestMode} level={level} />
      ) : level.modeId === 'godot-game' ? (
        <GodotGamePanel mode={mode as GodotGameMode} level={level as LevelData<GodotGameData>} />
      ) : (
        <p style={{ marginTop: 24, opacity: 0.6 }}>
          [{mode.displayName}] 完整玩法将在 Phase 6 后续子阶段交付；
          当前关卡可直接关闭以记录尝试。
        </p>
      )}
    </section>
  );
}

function isFetchableKnowledgeUrl(url: string | undefined): url is string {
  return Boolean(url && !url.startsWith('res://'));
}

function asKnowledgeItems(value: unknown): Record<string, unknown>[] | undefined {
  return Array.isArray(value) ? value.filter((item): item is Record<string, unknown> => Boolean(item && typeof item === 'object' && !Array.isArray(item))) : undefined;
}

function requireKnowledgeItems(value: unknown, kind: 'questions' | 'upgrades', url: string): Record<string, unknown>[] {
  const items = asKnowledgeItems(value);
  if (!items || items.length === 0 || items.length !== (value as unknown[]).length) {
    throw new Error(`Invalid ${kind} teaching asset: ${url}`);
  }
  return items;
}

function getKnowledgeSource(data: GodotGameData): 'external' | 'embedded' {
  if ([data.knowledgePackUrl, data.questionsUrl, data.upgradesUrl, data.bindingUrl].some(isFetchableKnowledgeUrl)) {
    return 'external';
  }
  try {
    const override = window.localStorage.getItem(`dgbook:godot:${data.gameId}:knowledgeSource`);
    if (override === 'external' || override === 'embedded') return override;
  } catch {
    // localStorage can be unavailable in restricted browser contexts.
  }
  return data.knowledgeSource ?? 'external';
}

async function fetchKnowledgeJson(url: string): Promise<unknown> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`加载知识包失败：${url} (${response.status})`);
  }
  return response.json() as Promise<unknown>;
}

export async function resolveGodotInitData(data: GodotGameData): Promise<GodotGameData> {
  let resolved: GodotGameData = { ...data };
  if (getKnowledgeSource(data) === 'embedded') {
    return {
      ...resolved,
      questions: undefined,
      upgrades: undefined,
      bindings: undefined,
      concepts: undefined,
    };
  }

  if (isFetchableKnowledgeUrl(data.knowledgePackUrl)) {
    const pack = await fetchKnowledgeJson(data.knowledgePackUrl);
    if (pack && typeof pack === 'object' && !Array.isArray(pack)) {
      const packObject = pack as Record<string, unknown>;
      resolved = {
        ...resolved,
        questions: resolved.questions ?? asKnowledgeItems(packObject.questions),
        upgrades: resolved.upgrades ?? asKnowledgeItems(packObject.upgrades),
        bindings: resolved.bindings ?? (packObject.bindings as GodotGameData['bindings']),
        concepts: resolved.concepts ?? asKnowledgeItems(packObject.concepts),
      };
    }
  }

  if (!resolved.questions && isFetchableKnowledgeUrl(data.questionsUrl)) {
    resolved = {
      ...resolved,
      questions: requireKnowledgeItems(await fetchKnowledgeJson(data.questionsUrl), 'questions', data.questionsUrl),
    };
  }

  if (!resolved.upgrades && isFetchableKnowledgeUrl(data.upgradesUrl)) {
    resolved = {
      ...resolved,
      upgrades: requireKnowledgeItems(await fetchKnowledgeJson(data.upgradesUrl), 'upgrades', data.upgradesUrl),
    };
  }

  if (!resolved.bindings && isFetchableKnowledgeUrl(data.bindingUrl)) {
    resolved = { ...resolved, bindings: await fetchKnowledgeJson(data.bindingUrl) as GodotGameData['bindings'] };
  }

  return resolved;
}

function GodotGamePanel({ mode, level }: { mode: GodotGameMode; level: LevelData<GodotGameData> }) {
  const iframeRef = useRef<HTMLIFrameElement | null>(null);
  const initGateRef = useRef(createGodotInitGate());
  const [ready, setReady] = useState(false);
  const [paused, setPaused] = useState(false);
  const [lastLog, setLastLog] = useState<string | null>(null);
  const [initError, setInitError] = useState<string | null>(null);
  const data = level.data;

  const postToGodot = (message: GodotHostMessage) => {
    iframeRef.current?.contentWindow?.postMessage(message, '*');
  };

  const sendInit = async (token: number) => {
    setPaused(false);
    setInitError(null);
    let initData = data;
    try {
      initData = await resolveGodotInitData(data);
    } catch (error) {
      if (!initGateRef.current.isCurrent(token)) return;
      const message = error instanceof Error ? error.message : '加载 Godot 知识包失败';
      setInitError(message);
      return;
    }
    if (!initGateRef.current.isCurrent(token)) return;
    postToGodot({
      type: 'DGB_GODOT_INIT',
      version: GODOT_BRIDGE_VERSION,
      level: { ...level, data: initData },
      data: initData,
    });
  };

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      if (event.source !== iframeRef.current?.contentWindow) return;
      if (!isGodotToHostMessage(event.data)) return;
      const message = event.data;
      if (message.type === 'DGB_GODOT_READY') {
        setReady(true);
        const token = initGateRef.current.claim();
        if (token != null) {
          mode.reportReady();
          void sendInit(token);
        }
      } else if (message.type === 'DGB_GODOT_PROGRESS') {
        mode.reportProgress(message.progress, message.hint);
      } else if (message.type === 'DGB_GODOT_COMPLETE') {
        setPaused(false);
        mode.completeFromGodot(message);
      } else if (message.type === 'DGB_GODOT_LOG') {
        setLastLog(message.message);
      }
    };
    window.addEventListener('message', onMessage);
    return () => {
      window.removeEventListener('message', onMessage);
    };
  }, [level, mode]);

  useEffect(() => () => {
    initGateRef.current.reset();
  }, []);

  return (
    <div style={{ marginTop: 16 }}>
      <div style={godotFrameShellStyle}>
        <iframe
          ref={iframeRef}
          title={level.title}
          src={data.entryUrl}
          allow={data.allow ?? 'fullscreen; gamepad'}
          style={{ ...godotFrameStyle, aspectRatio: data.aspectRatio ?? '16 / 9' }}
          onLoad={() => {
            initGateRef.current.reset();
            setReady(false);
            setPaused(false);
            setInitError(null);
          }}
        />
      </div>
      <div style={godotMetaStyle}>
        <span>{ready ? 'Godot 已连接' : '等待 Godot 连接'}</span>
        <button
          type="button"
          onClick={() => {
            postToGodot({ type: paused ? 'DGB_GODOT_RESUME' : 'DGB_GODOT_PAUSE', version: GODOT_BRIDGE_VERSION });
            setPaused(!paused);
          }}
          style={btnStyle}
          disabled={!ready || Boolean(initError)}
        >
          {paused ? '继续' : '暂停'}
        </button>
        <button
          type="button"
          onClick={() => {
            setPaused(false);
            postToGodot({ type: 'DGB_GODOT_RESET', version: GODOT_BRIDGE_VERSION });
          }}
          style={btnStyle}
          disabled={!ready || Boolean(initError)}
        >
          重置
        </button>
      </div>
      {initError && (
        <div style={godotLogStyle}>
          <div>{initError}</div>
          <button
            type="button"
            style={{ ...btnStyle, marginTop: 8 }}
            onClick={() => {
              initGateRef.current.reset();
              const token = initGateRef.current.claim();
              if (token != null) void sendInit(token);
            }}
          >
            重试加载教学资源
          </button>
        </div>
      )}
      {lastLog && <div style={godotLogStyle}>{lastLog}</div>}
    </div>
  );
}

function BitFlipPanel({ mode, level }: { mode: BitFlipQuestMode; level: LevelData }) {
  const data = (level as { data: { width: number; target: number; operations: { op: string; mask?: number; bits?: number }[] } }).data;
  return (
    <div style={{ marginTop: 16 }}>
      <div style={{ fontFamily: 'ui-monospace, monospace', fontSize: 12, opacity: 0.8 }}>
        target = 0x{data.target.toString(16).toUpperCase()}
      </div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 12 }}>
        {data.operations.map((op, i) => (
          <button
            key={i}
            type="button"
            onClick={() => mode.playOp(op as Parameters<BitFlipQuestMode['playOp']>[0])}
            style={cardStyle}
          >
            {op.op.toUpperCase()}{'mask' in op && op.mask != null ? ` 0x${op.mask.toString(16).toUpperCase()}` : ''}{'bits' in op && op.bits != null ? ` ${op.bits}` : ''}
          </button>
        ))}
      </div>
      <div style={{ marginTop: 12, display: 'flex', gap: 8 }}>
        <button type="button" onClick={() => mode.undo()} style={btnStyle}>撤回</button>
        <button type="button" onClick={() => mode.finish()} style={primaryBtnStyle}>确认结束</button>
      </div>
    </div>
  );
}

function ResultView({ result, onClose }: { result: GameResult; onClose: () => void }) {
  const isGodotGame = result.modeId === 'godot-game';
  const stats = result.stats ?? {};
  const presentation = getGodotResultPresentation(result);
  return (
    <section style={{ flex: 1, padding: '24px', textAlign: 'center' }}>
      <div style={{ fontSize: 18 }}>{presentation.label}</div>
      {isGodotGame ? (
        <div style={{ margin: '12px 0 18px' }}>
          <div style={{ fontSize: 34, fontWeight: 700 }}>{presentation.score}</div>
          <div style={{ fontSize: 28, marginTop: 8 }}>{'★'.repeat(result.stars)}{'☆'.repeat(3 - result.stars)}</div>
          <div style={{ marginTop: 10, fontSize: 13, color: '#64748b', lineHeight: 1.7 }}>
            {typeof stats.trackingEfficiency === 'number' && <div>追光效率 {stats.trackingEfficiency}%</div>}
            {typeof stats.stability === 'number' && <div>稳定度 {stats.stability}%</div>}
            {typeof stats.correct === 'number' && typeof stats.wrong === 'number' && (
              <div>答题 {stats.correct} 对 / {stats.wrong} 错</div>
            )}
          </div>
        </div>
      ) : (
        <div style={{ fontSize: 32, margin: '12px 0' }}>{'★'.repeat(result.stars)}{'☆'.repeat(3 - result.stars)}</div>
      )}
      <button type="button" onClick={onClose} style={primaryBtnStyle}>完成</button>
    </section>
  );
}

const overlayStyle: CSSProperties = {
  position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.72)',
  display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000,
};
const panelStyle: CSSProperties = {
  background: '#fff', color: '#0f172a', borderRadius: 16,
  width: 'min(720px, 92vw)', maxHeight: '88vh', overflow: 'hidden',
  display: 'flex', flexDirection: 'column',
  boxShadow: '0 24px 64px rgba(0,0,0,0.35)',
};
const headerStyle: CSSProperties = {
  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
  padding: '16px 24px', borderBottom: '1px solid #e2e8f0',
};
const closeStyle: CSSProperties = {
  background: 'transparent', border: 0, fontSize: 24, cursor: 'pointer', color: '#64748b',
};
const progressBarStyle: CSSProperties = {
  marginTop: 16, height: 6, borderRadius: 4, background: '#e2e8f0', overflow: 'hidden',
};
const progressFillStyle: CSSProperties = {
  height: '100%', background: 'linear-gradient(90deg, #0ea5e9, #6366f1)', transition: 'width 0.3s ease',
};
const cardStyle: CSSProperties = {
  padding: '6px 12px', border: '1px solid #cbd5e1', borderRadius: 8,
  background: '#f8fafc', cursor: 'pointer', fontFamily: 'ui-monospace, monospace', fontSize: 12,
};
const godotFrameShellStyle: CSSProperties = {
  width: '100%', border: '1px solid #cbd5e1', borderRadius: 8,
  background: '#0f172a', overflow: 'hidden',
};
const godotFrameStyle: CSSProperties = {
  display: 'block', width: '100%', minHeight: 320, border: 0, background: '#0f172a',
};
const godotMetaStyle: CSSProperties = {
  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
  gap: 12, marginTop: 10, color: '#64748b', fontSize: 13,
};
const godotLogStyle: CSSProperties = {
  marginTop: 8, padding: '8px 10px', borderRadius: 8,
  background: '#f8fafc', color: '#475569', fontSize: 12,
};
const btnStyle: CSSProperties = {
  padding: '8px 16px', border: '1px solid #cbd5e1', borderRadius: 8, background: '#fff', cursor: 'pointer',
};
const primaryBtnStyle: CSSProperties = {
  ...btnStyle, background: '#0ea5e9', color: '#fff', borderColor: '#0ea5e9',
};
