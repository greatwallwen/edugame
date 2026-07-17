/**
 * AbilityMapPanel.tsx - 课程能力图谱（对标 reference/课程能力图谱.svg）
 * 特性：滚轮缩放/拖拽平移/工具栏/入场动画/连线SVG/T行点击高亮
 * 连线使用 stroke-dashoffset 描线动画（对标 Motion pathLength API）
 */
import { useRef, useState, useEffect, useCallback, useLayoutEffect } from 'react';
import s from './AbilityMapPanel.module.css';
import { useAbilityMapData, type AbilityMapFullData } from './abilityMapData';

const T_TO_CAP: Record<string, string[]> = {
  T1: ['CAP-001', 'CAP-002'],
  T2: ['CAP-003'],
  T3: ['CAP-004'],
  T4: ['CAP-005'],
  T5: ['CAP-006'],
  T6: ['CAP-007', 'CAP-008'],
};
const SCALE_MIN = 0.2;
const SCALE_MAX = 3.0;
const SCALE_STEP = 0.12;

/* ─────────────────────────────────────────────────────────
   连线 SVG Overlay
   策略：运行时 getBoundingClientRect 测量各列元素的位置，
         在画布顶层绝对定位 <svg> 绘制连接线，
         stroke-dashoffset 动画实现"描线"效果
──────────────────────────────────────────────────────────*/

interface LineSegment {
  id: string;
  x1: number; y1: number;
  x2: number; y2: number;
  cpx1?: number; cpy1?: number; // 贝塞尔控制点1
  cpx2?: number; cpy2?: number; // 贝塞尔控制点2
  stroke: string;
  opacity: number;
  dashed: boolean;
  delay: number; // 动画延迟秒
  highlighted?: boolean;
}

/** 计算两点间贝塞尔曲线路径字符串 */
function cubicPath(x1: number, y1: number, x2: number, y2: number,
  cpx1?: number, cpy1?: number, cpx2?: number, cpy2?: number): string {
  if (cpx1 !== undefined) {
    return `M${x1},${y1} C${cpx1},${cpy1} ${cpx2},${cpy2} ${x2},${y2}`;
  }
  // 默认：水平 S 形贝塞尔
  const mx = (x1 + x2) / 2;
  return `M${x1},${y1} C${mx},${y1} ${mx},${y2} ${x2},${y2}`;
}

/** 近似计算 SVG path 长度（贝塞尔曲线采样法） */
function approxPathLen(d: string): number {
  try {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    p.setAttribute('d', d);
    svg.appendChild(p);
    document.body.appendChild(svg);
    const len = p.getTotalLength();
    document.body.removeChild(svg);
    return len;
  } catch { return 100; }
}

/** 连线 SVG 层 — 绝对覆盖在 mapRoot 上 */
function ConnectionLines({
  containerRef,
  taskRefs,
  processRefs,
  skillRefs,
  capRefs,
  knowledgeRefs,
  entered,
  activeT,
  data,
}: {
  containerRef: React.RefObject<HTMLDivElement | null>;
  taskRefs: React.RefObject<(HTMLDivElement | null)[]>;
  processRefs: React.RefObject<(HTMLDivElement | null)[]>;
  skillRefs: React.RefObject<(HTMLDivElement | null)[]>;
  capRefs: React.RefObject<(HTMLDivElement | null)[]>;
  knowledgeRefs: React.RefObject<(HTMLDivElement | null)[]>;
  entered: boolean;
  activeT: string | null;
  data: AbilityMapFullData;
}) {
  const TASK_GROUPS = data.taskGroups;
  const CAP_ITEMS = data.capItems;
  const [lines, setLines] = useState<LineSegment[]>([]);
  const [size, setSize] = useState({ w: 0, h: 0 });

  const measure = useCallback(() => {
    const root = containerRef.current;
    if (!root) return;
    // 使用 offsetWidth/offsetHeight（布局空间，不受 CSS transform 影响）
    const W = root.offsetWidth, H = root.offsetHeight;
    setSize({ w: W, h: H });
    const segs: LineSegment[] = [];

    // offsetLeft/offsetTop 递归累加到 root，获取不受 scale 影响的坐标
    const relRect = (el: HTMLDivElement | null | undefined) => {
      if (!el) return null;
      let left = 0, top = 0;
      let cur: HTMLElement | null = el;
      while (cur && cur !== root) {
        left += cur.offsetLeft;
        top  += cur.offsetTop;
        cur = cur.offsetParent as HTMLElement | null;
      }
      const w = el.offsetWidth, h = el.offsetHeight;
      return {
        left, top,
        right: left + w, bottom: top + h,
        cx: left + w / 2, cy: top + h / 2,
      };
    };

    // ── 1. 任务→工作过程（水平蓝色实线，SVG中 M670,y C710,y 750,y）
    TASK_GROUPS.forEach((tg, i) => {
      const task = relRect(taskRefs.current![i]);
      const proc = relRect(processRefs.current![i]);
      if (!task || !proc) return;
      const isActive = activeT === tg.id;
      segs.push({
        id: `t2p-${i}`, x1: task.right, y1: task.cy,
        x2: proc.left, y2: proc.cy,
        cpx1: task.right + 20, cpy1: task.cy,
        cpx2: proc.left - 20, cpy2: proc.cy,
        stroke: isActive ? '#00a38a' : '#2563eb',
        opacity: isActive ? 0.85 : 0.55,
        dashed: false, delay: 0.4 + i * 0.12,
        highlighted: isActive,
      });
    });

    // ── 2. 工作过程→技能点（水平蓝色实线）
    TASK_GROUPS.forEach((tg, i) => {
      const proc = relRect(processRefs.current![i]);
      const skill = relRect(skillRefs.current![i]);
      if (!proc || !skill) return;
      const isActive = activeT === tg.id;
      segs.push({
        id: `p2s-${i}`, x1: proc.right, y1: proc.cy,
        x2: skill.left, y2: skill.cy,
        cpx1: proc.right + 20, cpy1: proc.cy,
        cpx2: skill.left - 20, cpy2: skill.cy,
        stroke: isActive ? '#00a38a' : '#2563eb',
        opacity: isActive ? 0.85 : 0.55,
        dashed: false, delay: 0.55 + i * 0.12,
        highlighted: isActive,
      });
    });

    // ── 3. 技能点→CAP（跨行汇聚曲线，SVG中 M1500,y C1597,y 1597,capY 1695,capY）
    const T_CAP_MAP: Record<string, string[]> = {
      T1: ['CAP-001', 'CAP-002'], T2: ['CAP-003'],
      T3: ['CAP-004'], T4: ['CAP-005'],
      T5: ['CAP-006'], T6: ['CAP-007', 'CAP-008'],
    };
    TASK_GROUPS.forEach((tg, i) => {
      const skill = relRect(skillRefs.current![i]);
      const capIds = T_CAP_MAP[tg.id] ?? [];
      capIds.forEach(capId => {
        const ci = CAP_ITEMS.findIndex(c => c.id === capId);
        const cap = relRect(capRefs.current![ci]);
        if (!skill || !cap) return;
        const isActive = activeT === tg.id;
        const mx = (skill.right + cap.left) / 2;
        segs.push({
          id: `s2c-${i}-${capId}`,
          x1: skill.right, y1: skill.cy,
          x2: cap.left,    y2: cap.cy,
          cpx1: mx, cpy1: skill.cy,
          cpx2: mx, cpy2: cap.cy,
          stroke: isActive ? '#00a38a' : '#2563eb',
          opacity: isActive ? 0.9 : 0.5,
          dashed: false, delay: 0.7 + i * 0.1,
          highlighted: isActive,
        });
      });
    });

    // ── 4. CAP→知识点（右侧曲线，对应 SVG M2505,capY C2632,capY 2632,kgY 2760,kgY）
    // CAP-001→知识1, CAP-002→知识2, CAP-003→知识3 ... 以此类推
    const CAP_KG: number[] = [0, 1, 2, 3, 4, 5, 6, 7]; // CAP i -> knowledge i
    CAP_ITEMS.forEach((cap, ci) => {
      const capEl = relRect(capRefs.current![ci]);
      const kgEl  = relRect(knowledgeRefs.current![CAP_KG[ci]!] ?? null);
      if (!capEl || !kgEl) return;
      const isActive = activeT !== null && (T_CAP_MAP[activeT] ?? []).includes(cap.id);
      const mx = (capEl.right + kgEl.left) / 2;
      segs.push({
        id: `c2k-${ci}`,
        x1: capEl.right, y1: capEl.cy,
        x2: kgEl.left,   y2: kgEl.cy,
        cpx1: mx, cpy1: capEl.cy,
        cpx2: mx, cpy2: kgEl.cy,
        stroke: isActive ? '#e46a26' : '#2563eb',
        opacity: isActive ? 0.85 : 0.45,
        dashed: false, delay: 0.9 + ci * 0.07,
        highlighted: isActive,
      });
    });

    setLines(segs);
  }, [containerRef, taskRefs, processRefs, skillRefs, capRefs, knowledgeRefs, activeT, TASK_GROUPS, CAP_ITEMS]);

  // 进入视图 + activeT 变化时重新测量
  useLayoutEffect(() => {
    if (!entered) return;
    const timer = setTimeout(measure, 80);
    return () => clearTimeout(timer);
  }, [entered, measure, activeT]);

  // ResizeObserver 响应容器大小变化
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => { if (entered) measure(); });
    ro.observe(el);
    return () => ro.disconnect();
  }, [containerRef, entered, measure]);

  // 动画状态：entered 后触发 transition
  const [showLines, setShowLines] = useState(false);
  useEffect(() => {
    if (entered && lines.length > 0) {
      const t = setTimeout(() => setShowLines(true), 150);
      return () => clearTimeout(t);
    }
    setShowLines(false);
  }, [entered, lines.length]);

  if (!entered || size.w === 0) return null;

  return (
    <svg
      className={s.lineOverlay}
      width={size.w} height={size.h}
    >
      <defs>
        <marker id="arrowBlue" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto">
          <path d="M0,0 L8,3 L0,6 Z" fill="#2563eb" opacity="0.7" />
        </marker>
        <marker id="arrowGreen" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto">
          <path d="M0,0 L8,3 L0,6 Z" fill="#00a38a" />
        </marker>
        <marker id="arrowOrange" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto">
          <path d="M0,0 L8,3 L0,6 Z" fill="#e46a26" opacity="0.7" />
        </marker>
      </defs>
      {lines.map((seg) => {
        const d = cubicPath(seg.x1, seg.y1, seg.x2, seg.y2,
                            seg.cpx1, seg.cpy1, seg.cpx2, seg.cpy2);
        const len = approxPathLen(d);
        const markerId = seg.highlighted
          ? (seg.stroke === '#e46a26' ? 'arrowOrange' : 'arrowGreen')
          : 'arrowBlue';
        return (
          <path
            key={seg.id}
            d={d}
            fill="none"
            stroke={seg.stroke}
            strokeWidth={seg.highlighted ? 1.8 : 1.1}
            opacity={seg.opacity}
            strokeDasharray={`${len} ${len}`}
            strokeDashoffset={showLines ? 0 : len}
            markerEnd={`url(#${markerId})`}
            style={{
              transition: `stroke-dashoffset ${0.6 + seg.delay * 0.3}s cubic-bezier(0.4,0,0.2,1) ${seg.delay}s`,
            }}
          />
        );
      })}
    </svg>
  );
}

function SourceCard({ title, lines, tag, side }: { title: string; lines: string[]; tag: string; side: 'left'|'right' }) {
  return (
    <div className={`${s.sourceCard} ${side === 'left' ? s.sourceLeft : s.sourceRight}`}>
      <div className={s.sourceTitle}>{title}</div>
      {lines.map((l, i) => <div key={i} className={s.sourceLine}>{l}</div>)}
      <span className={s.sourceTag}>{tag}</span>
    </div>
  );
}

function MapContent({ activeT, setActiveT, activeCaps, containerRef, taskRefs, processRefs, skillRefs, capRefs, knowledgeRefs, entered, data }: {
  activeT: string|null; setActiveT: (t: string|null) => void; activeCaps: string[];
  containerRef: React.RefObject<HTMLDivElement | null>;
  taskRefs: React.RefObject<(HTMLDivElement | null)[]>;
  processRefs: React.RefObject<(HTMLDivElement | null)[]>;
  skillRefs: React.RefObject<(HTMLDivElement | null)[]>;
  capRefs: React.RefObject<(HTMLDivElement | null)[]>;
  knowledgeRefs: React.RefObject<(HTMLDivElement | null)[]>;
  entered: boolean;
  data: AbilityMapFullData;
}) {
  const {
    taskGroups: TASK_GROUPS, capItems: CAP_ITEMS, knowledgeGroups: KNOWLEDGE_GROUPS,
    leftSources: LEFT_SOURCES, rightSources: RIGHT_SOURCES,
    coursePosition: COURSE_POSITION, typicalOutcomes: TYPICAL_OUTCOMES,
    teachingSupport: TEACHING_SUPPORT, profEthics: PROF_ETHICS, abilityPath: ABILITY_PATH,
  } = data;
  return (
    <div className={s.mapRoot} ref={containerRef} style={{ position: 'relative' }}>
      {/* SVG 连线层 */}
      <ConnectionLines
        containerRef={containerRef}
        taskRefs={taskRefs} processRefs={processRefs}
        skillRefs={skillRefs} capRefs={capRefs}
        knowledgeRefs={knowledgeRefs}
        entered={entered} activeT={activeT} data={data}
      />
      {/* 大标题（来自资产 ability-map.json 的 courseTitle，不在平台代码硬编码） */}
      <div className={s.mainTitle}>
        {data.courseTitle || '课程能力图谱'}
      </div>
      {/* 列头 */}
      <div className={s.colHeaders}>
        {['来源依据','典型项目/典型任务','工作过程/场景','技能点','课程定位/核心能力/成果/评价','知识点/规范','来源依据'].map((h,i) => (
          <div key={i} className={`${s.colHeader} ${s[`colH${i}`]}`}>{h}</div>
        ))}
      </div>
      {/* 主体七列 */}
      <div className={s.body}>
        {/* 列1：左侧来源 */}
        <div className={s.col}>
          {LEFT_SOURCES.map((src, i) => <SourceCard key={i} {...src} side="left" />)}
        </div>
        {/* 列2：典型任务 */}
        <div className={s.col}>
          {TASK_GROUPS.map((tg, i) => (
            <div
              key={tg.id}
              ref={el => { taskRefs.current![i] = el; }}
              className={`${s.taskBlock} ${activeT === tg.id ? s.taskBlockActive : ''} ${s.animFade}`}
              onClick={() => setActiveT(activeT === tg.id ? null : tg.id)}
              style={{ animationDelay: `${i * 0.08}s` }}
            >
              <div className={s.taskTag}>{tg.id}</div>
              <div className={s.taskName}>{tg.name}</div>
              <div className={s.taskProjects}>
                {tg.projects.map(p => (
                  <span key={p.id} className={s.projectBadge}>
                    <span className={s.projectId}>{p.id}</span>
                    <span className={s.projectName}>{p.name}</span>
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>
        {/* 列3：工作过程 */}
        <div className={s.col}>
          {TASK_GROUPS.map((tg, i) => (
            <div key={tg.id} ref={el => { processRefs.current![i] = el; }}
              className={`${s.cellGroup} ${activeT === tg.id ? s.cellGroupActive : ''} ${s.animFade}`}
              style={{ animationDelay: `${i*0.08+0.04}s` }}>
              {tg.workProcesses.map((wp, j) => <div key={j} className={s.processItem}>{wp.label}</div>)}
            </div>
          ))}
        </div>
        {/* 列4：技能点 */}
        <div className={s.col}>
          {TASK_GROUPS.map((tg, i) => (
            <div key={tg.id} ref={el => { skillRefs.current![i] = el; }}
              className={`${s.cellGroup} ${activeT === tg.id ? s.cellGroupActive : ''} ${s.animFade}`}
              style={{ animationDelay: `${i*0.08+0.08}s` }}>
              {tg.skills.map((sk, j) => <div key={j} className={s.skillItem}>{sk.label}</div>)}
            </div>
          ))}
        </div>
        {/* 列5：核心能力（中央大列） */}
        <div className={s.col}>
          {/* 课程定位 */}
          <div className={s.coursePositionBox}>
            <div className={s.boxTitle}>课程定位</div>
            {COURSE_POSITION.map((l, i) => <div key={i} className={s.boxLine}>{l}</div>)}
          </div>
          {/* 核心能力项 */}
          <div className={s.capSection}>
            <div className={s.capSectionTitle}>核心能力项（逐项映射 + 评价短标签）</div>
            {CAP_ITEMS.map((cap, i) => (
              <div
                key={cap.id}
                ref={el => { capRefs.current![i] = el; }}
                className={`${s.capRow} ${activeCaps.includes(cap.id) ? s.capRowHighlight : ''} ${s.animFade}`}
                style={{ animationDelay: `${i * 0.06}s` }}
              >
                <span className={s.capId}>{cap.id}</span>
                <span className={s.capName}>{cap.name}</span>
                <span className={s.capEvidence}>{cap.evidence}</span>
              </div>
            ))}
          </div>
          {/* 典型成果 */}
          <div className={s.outcomesBox}>
            <div className={s.boxTitle}>典型成果</div>
            {TYPICAL_OUTCOMES.map((l, i) => <div key={i} className={s.boxLine}>{l}</div>)}
          </div>
          {/* 教学与评价支撑 */}
          <div className={s.supportBox}>
            <div className={s.boxTitle}>教学与评价支撑</div>
            {TEACHING_SUPPORT.map((l, i) => <div key={i} className={s.boxLine}>{l}</div>)}
          </div>
        </div>
        {/* 列6：知识点 */}
        <div className={s.col}>
          {KNOWLEDGE_GROUPS.map((kg, i) => (
            <div key={i} ref={el => { knowledgeRefs.current![i] = el; }}
              className={`${s.knowledgeGroup} ${s.animFade}`}
              style={{ animationDelay: `${i*0.08+0.12}s` }}>
              <div className={s.knowledgeGroupName}>{kg.name}</div>
              {kg.items.map((item, j) => <div key={j} className={s.pill}>{item}</div>)}
              <span className={s.sourceTag}>{kg.source}</span>
            </div>
          ))}
        </div>
        {/* 列7：右侧来源 */}
        <div className={s.col}>
          {RIGHT_SOURCES.map((src, i) => <SourceCard key={i} {...src} side="right" />)}
        </div>
      </div>
      {/* 底部信息 */}
      <div className={s.footer}>
        <div className={s.ethicsBox}>
          <span className={s.ethicsTitle}>职业素养 / 安全质量 / 课程思政融入</span>
          <span className={s.ethicsContent}>{PROF_ETHICS}</span>
        </div>
        <div className={s.abilityPath}>{ABILITY_PATH}</div>
        <div className={s.versionNote}>版本：公开发布候选版 V1.0｜2026-05-10</div>
      </div>
    </div>
  );
}

export function AbilityMapPanel() {
  const data = useAbilityMapData();
  const panelRef    = useRef<HTMLDivElement>(null);
  const viewportRef = useRef<HTMLDivElement>(null);
  const canvasRef   = useRef<HTMLDivElement>(null);
  // refs for line measurement
  const containerRef    = useRef<HTMLDivElement>(null);
  const taskRefs        = useRef<(HTMLDivElement | null)[]>([]);
  const processRefs     = useRef<(HTMLDivElement | null)[]>([]);
  const skillRefs       = useRef<(HTMLDivElement | null)[]>([]);
  const capRefs         = useRef<(HTMLDivElement | null)[]>([]);
  const knowledgeRefs   = useRef<(HTMLDivElement | null)[]>([]);

  const [scale, setScale] = useState(1);
  const [tx, setTx] = useState(0);
  const [ty, setTy] = useState(0);
  const [dragging, setDragging] = useState(false);
  const dragStart = useRef<{ x: number; y: number; tx: number; ty: number } | null>(null);
  const [activeT, setActiveT] = useState<string | null>(null);
  const [entered, setEntered] = useState(false);

  useEffect(() => {
    const vp = viewportRef.current;
    const cv = canvasRef.current;
    if (!vp || !cv) return;
    const fit = () => {
      const sw = (vp.clientWidth - 24) / Math.max(cv.scrollWidth, 1);
      const sh = (vp.clientHeight - 16) / Math.max(cv.scrollHeight, 1);
      const s0 = Math.min(1, Math.min(sw, sh));
      setScale(parseFloat(s0.toFixed(3)));
      // 水平居中
      const visW = cv.scrollWidth * s0;
      setTx(Math.max(0, (vp.clientWidth - visW) / 2));
      setTy(0);
    };
    fit();
    setTimeout(() => setEntered(true), 120);
    const ro = new ResizeObserver(fit);
    ro.observe(vp);
    return () => ro.disconnect();
    // data 加载完成后重新适配（canvas 尺寸随真实内容变化）
  }, [data]);

  // 注册为 passive listener，于是回调里的 e.preventDefault() 触发：
  //   "Unable to preventDefault inside passive event listener invocation."
  // 解法：useRef 拿到 viewport DOM，用 useEffect 的原生 addEventListener
  //       明确传 { passive: false }，这样 preventDefault 才合法。
  // setScale/setTx/setTy 是 React state dispatcher（引用稳定），用 prev =>
  // 函数式更新闭包永远拿到最新值，因此 deps=[] 单次注册即可。
  useEffect(() => {
    const vp = viewportRef.current;
    if (!vp) return;
    const handler = (e: WheelEvent) => {
      e.preventDefault();
      const rect = vp.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const delta = e.deltaY < 0 ? SCALE_STEP : -SCALE_STEP;
      setScale(prev => {
        const next = parseFloat(Math.min(SCALE_MAX, Math.max(SCALE_MIN, prev + delta)).toFixed(3));
        const r = next / prev;
        setTx(t => mx - r * (mx - t));
        setTy(t => my - r * (my - t));
        return next;
      });
    };
    vp.addEventListener('wheel', handler, { passive: false });
    return () => vp.removeEventListener('wheel', handler);
  }, []);

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    if (e.button !== 0) return;
    setDragging(true);
    dragStart.current = { x: e.clientX, y: e.clientY, tx, ty };
  }, [tx, ty]);

  const onMouseMove = useCallback((e: React.MouseEvent) => {
    if (!dragStart.current) return;
    setTx(dragStart.current.tx + e.clientX - dragStart.current.x);
    setTy(dragStart.current.ty + e.clientY - dragStart.current.y);
  }, []);

  const onMouseUp = useCallback(() => { setDragging(false); dragStart.current = null; }, []);

  const fitWidth = () => {
    const vp = viewportRef.current; const cv = canvasRef.current;
    if (!vp || !cv) return;
    const sw = (vp.clientWidth - 24) / Math.max(cv.scrollWidth, 1);
    const sh = (vp.clientHeight - 16) / Math.max(cv.scrollHeight, 1);
    const s = parseFloat(Math.min(1, Math.min(sw, sh)).toFixed(3));
    setScale(s);
    const visW = cv.scrollWidth * s;
    setTx(Math.max(0, (vp.clientWidth - visW) / 2));
    setTy(0);
  };

  const activeCaps = activeT ? (T_TO_CAP[activeT] ?? []) : [];

  // 全屏控制
  const [isFullscreen, setIsFullscreen] = useState(false);
  const toggleFullscreen = useCallback(() => {
    const el = panelRef.current;
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

  return (
    <div className={`${s.panel} ${isFullscreen ? s.panelFullscreen : ''}`} ref={panelRef}>
      <div className={s.toolbar}>
        <span className={s.toolbarTitle}>课程能力图谱</span>
        <span className={s.toolbarHint}>滚轮缩放 · 拖拽平移 · 点击任务行关联高亮</span>
        <div className={s.toolbarControls}>
          <button className={s.tbBtn} onClick={() => setScale(v => parseFloat(Math.max(SCALE_MIN, v - SCALE_STEP).toFixed(3)))} title="缩小">−</button>
          <span className={s.tbScale}>{Math.round(scale * 100)}%</span>
          <button className={s.tbBtn} onClick={() => setScale(v => parseFloat(Math.min(SCALE_MAX, v + SCALE_STEP).toFixed(3)))} title="放大">+</button>
          <button className={s.tbBtn} onClick={fitWidth} title="适应宽度">⊡</button>
          <button className={s.tbBtn} onClick={() => { setScale(1); setTx(0); setTy(0); }} title="重置 1:1">↺</button>
          <button className={s.tbBtn} onClick={toggleFullscreen} title={isFullscreen ? '退出全屏' : '全屏'}>
            {isFullscreen ? '⊠' : '⛶'}
          </button>
          {activeT && <button className={s.tbBtnClear} onClick={() => setActiveT(null)}>清除 ×</button>}
        </div>
      </div>
      <div
        ref={viewportRef}
        className={s.viewport}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
        style={{ cursor: dragging ? 'grabbing' : 'grab' }}
      >
        <div
          ref={canvasRef}
          className={`${s.canvas} ${entered ? s.canvasEntered : ''}`}
          style={{ transform: `translate(${tx}px,${ty}px) scale(${scale})`, transformOrigin: '0 0' }}
        >
          <MapContent activeT={activeT} setActiveT={setActiveT} activeCaps={activeCaps} containerRef={containerRef} taskRefs={taskRefs} processRefs={processRefs} skillRefs={skillRefs} capRefs={capRefs} knowledgeRefs={knowledgeRefs} entered={entered} data={data} />
        </div>
      </div>
    </div>
  );
}
