 import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
 import type { InteractiveSpec } from '@dgbook/types';
 import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
 import './MatchingBlock.css';

 export interface MatchingBlockProps {
   spec: Extract<InteractiveSpec, { kind: 'matching' }>;
 }

 type Pt = { x: number; y: number };
 type Line = { lid: string; x1: number; y1: number; x2: number; y2: number; correct?: boolean };
 type DragState = { fromLid: string; start: Pt; cur: Pt } | null;

 /**
  * 配对互动 v2：拖拽连线模式。
  * 从左侧按钮拖拽，橡皮筋线实时跟随，松开在右侧项目上建立连接。
  * 提交后：正确=绿线+动画，错误=红线，显示参考答案。
  */
 export function MatchingBlock({ spec }: MatchingBlockProps) {
   const lefts = useMemo(() => spec.pairs.map((p, i) => ({ id: `L${i}`, text: p.left })), [spec]);
   const rights = useMemo(() => {
     const arr = spec.pairs.map((p, i) => ({ id: `R${i}`, text: p.right, correctFor: `L${i}` }));
     return shuffleStable(arr, spec.pairs.map((p) => p.left + '|' + p.right).join('§'));
   }, [spec]);

   const [picks, setPicks] = useState<Record<string, string>>({});
   const [submitted, setSubmitted] = useState(false);
   const [drag, setDrag] = useState<DragState>(null);
   const [hoverRid, setHoverRid] = useState<string | null>(null);
   const { score, combo, register, reset: resetScore, stars, playWin } = useGameScore();

   const containerRef = useRef<HTMLDivElement>(null);
  const gridRef = useRef<HTMLDivElement>(null);  // SVG 实际父容器，坐标基准
   const leftRefs = useRef<Map<string, HTMLButtonElement | null>>(new Map());
   const rightRefs = useRef<Map<string, HTMLButtonElement | null>>(new Map());
   const [lines, setLines] = useState<Line[]>([]);

   // ── 重新计算已确认连线坐标 ──────────────────────────────────────────
   const recalcLines = useCallback(() => {
    // 用 gridRef（SVG 父容器）作为坐标基准，避免 dgb-match-head 高度偏移
    const box = gridRef.current?.getBoundingClientRect();
     if (!box) return;
     const result: Line[] = [];
     for (const [lid, rid] of Object.entries(picks)) {
       const lEl = leftRefs.current.get(lid);
       const rEl = rightRefs.current.get(rid);
       if (!lEl || !rEl) continue;
       const lr = lEl.getBoundingClientRect();
       const rr = rEl.getBoundingClientRect();
       let correct: boolean | undefined;
       if (submitted) correct = rights.find((r) => r.id === rid)?.correctFor === lid;
       result.push({
         lid, correct,
         x1: lr.right - box.left, y1: lr.top + lr.height / 2 - box.top,
         x2: rr.left - box.left,  y2: rr.top + rr.height / 2 - box.top,
       });
     }
     setLines(result);
   }, [picks, submitted, rights]);

   useEffect(() => {
     recalcLines();
     window.addEventListener('resize', recalcLines);
     return () => window.removeEventListener('resize', recalcLines);
   }, [recalcLines]);

   // ── 拖拽：全局 pointermove/pointerup 监听 ──────────────────────────
   useEffect(() => {
     if (!drag) return;
     const onMove = (e: PointerEvent) => {
      const box = gridRef.current?.getBoundingClientRect();
       if (!box) return;
       setDrag((d) => d ? { ...d, cur: { x: e.clientX - box.left, y: e.clientY - box.top } } : null);
     };
     const onUp = (e: PointerEvent) => {
      const box = gridRef.current?.getBoundingClientRect();
       if (!box) { setDrag(null); setHoverRid(null); return; }
       // 检查是否落在右侧某个按钮上
       const target = document.elementFromPoint(e.clientX, e.clientY);
       let rid: string | null = null;
       rightRefs.current.forEach((el, id) => { if (el && (el === target || el.contains(target))) rid = id; });
       if (rid) {
         const usedRights = new Set(Object.values(picks));
         if (!usedRights.has(rid) || picks[drag.fromLid] === rid) {
           setPicks((cur) => ({ ...cur, [drag!.fromLid]: rid! }));
         }
       }
       setDrag(null);
       setHoverRid(null);
     };
     document.addEventListener('pointermove', onMove);
     document.addEventListener('pointerup', onUp);
     return () => {
       document.removeEventListener('pointermove', onMove);
       document.removeEventListener('pointerup', onUp);
     };
   }, [drag, picks]);

   // ── 事件处理 ────────────────────────────────────────────────────────
   function startDrag(e: React.PointerEvent, lid: string) {
     if (submitted) return;
     e.preventDefault();
    const box = gridRef.current?.getBoundingClientRect();
     if (!box) return;
     const lEl = leftRefs.current.get(lid);
     if (!lEl) return;
     const lr = lEl.getBoundingClientRect();
     const startX = lr.right - box.left;
     const startY = lr.top + lr.height / 2 - box.top;
     setDrag({ fromLid: lid, start: { x: startX, y: startY }, cur: { x: startX, y: startY } });
   }

   function clearLeft(lid: string, e: React.MouseEvent) {
     e.stopPropagation();
     if (submitted) return;
     setPicks((cur) => { const n = { ...cur }; delete n[lid]; return n; });
   }

   const usedRights = useMemo(() => new Set(Object.values(picks)), [picks]);
   const allDone = Object.keys(picks).length === lefts.length;

   function leftClass(lid: string) {
     const cls = ['dgb-match-cell', 'dgb-match-cell-left'];
     if (drag?.fromLid === lid) cls.push('dgb-match-dragging');
     if (picks[lid]) cls.push('dgb-match-paired');
     if (submitted) {
       const r = rights.find((x) => x.id === picks[lid]);
       cls.push(r && r.correctFor === lid ? 'dgb-match-ok' : 'dgb-match-ng');
     }
     return cls.join(' ');
   }
   function rightClass(rid: string) {
     const cls = ['dgb-match-cell', 'dgb-match-cell-right'];
     if (usedRights.has(rid)) cls.push('dgb-match-paired');
     if (drag && hoverRid === rid) cls.push('dgb-match-hover-target');
     if (submitted) {
       const lid = Object.entries(picks).find(([, v]) => v === rid)?.[0];
       const r = rights.find((x) => x.id === rid)!;
       if (lid) cls.push(r.correctFor === lid ? 'dgb-match-ok' : 'dgb-match-ng');
     }
     return cls.join(' ');
   }

   const correctCount = submitted
     ? lefts.reduce((acc, l) => acc + (rights.find((r) => r.id === picks[l.id])?.correctFor === l.id ? 1 : 0), 0)
     : 0;
   const allCorrect = submitted && correctCount === lefts.length;

   function handleSubmit() {
     lefts.forEach((l) => register(rights.find((r) => r.id === picks[l.id])?.correctFor === l.id));
     setSubmitted(true);
   }
   function handleReset() {
     setPicks({}); setSubmitted(false); setLines([]); resetScore();
   }

   // ── 橡皮筋线路径 ────────────────────────────────────────────────────
   const rubberPath = drag ? (() => {
     const { start, cur } = drag;
     const cx1 = start.x + (cur.x - start.x) * 0.5;
     const cx2 = cx1;
     return `M${start.x},${start.y} C${cx1},${start.y} ${cx2},${cur.y} ${cur.x},${cur.y}`;
   })() : null;

   return (
     <div className="dgb-match" ref={containerRef} style={{ userSelect: 'none' }}>
       <div className="dgb-match-head">
         <span className="dgb-match-badge">🔗 连线配对</span>
         {spec.prompt ? <span className="dgb-match-prompt">{spec.prompt}</span> : null}
         {!submitted && <span className="dgb-match-hint-tip">🖱️ 从左侧拖拽连线到右侧匹配项</span>}
         {/* GameStat 常驻渲染：从 0 分起，提交时分数跳变才能触发飘分反馈 */}
        <GameStat score={score} combo={combo} />
       </div>
      <div className="dgb-match-grid" ref={gridRef} style={{ position: 'relative' }}>
         {/* SVG overlay：确认连线 + 拖拽橡皮筋 */}
         <svg className="dgb-match-svg" aria-hidden style={{ pointerEvents: 'none' }}>
           <defs>
             <marker id="dgb-arr-ok"  markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#16a34a"/></marker>
             <marker id="dgb-arr-ng"  markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#dc2626"/></marker>
             <marker id="dgb-arr-def" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#0E7C4A"/></marker>
             <marker id="dgb-arr-rub" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#94a3b8"/></marker>
           </defs>
           {/* 已确认连线 */}
           {lines.map((ln) => {
             const color = submitted ? (ln.correct ? '#16a34a' : '#dc2626') : '#0E7C4A';
             const mid = `url(#${submitted ? (ln.correct ? 'dgb-arr-ok' : 'dgb-arr-ng') : 'dgb-arr-def'})`;
             const cx1 = ln.x1 + (ln.x2 - ln.x1) * 0.45;
             const cx2 = ln.x1 + (ln.x2 - ln.x1) * 0.55;
             const pathD = `M${ln.x1},${ln.y1} C${cx1},${ln.y1} ${cx2},${ln.y2} ${ln.x2},${ln.y2}`;
             const len = Math.hypot(ln.x2 - ln.x1, ln.y2 - ln.y1) + 80;
             return (
               <path key={ln.lid} d={pathD} stroke={color} strokeWidth="2.5" fill="none"
                 markerEnd={mid} opacity="0.9"
                 className={submitted ? 'dgb-line-confirmed' : 'dgb-line-drawn'}
                 style={submitted ? undefined : { strokeDasharray: len, strokeDashoffset: 0, animation: `dgbDrawLine .35s ease forwards` }}
               />
             );
           })}
           {/* 拖拽橡皮筋线 */}
           {rubberPath && (
             <path d={rubberPath} stroke="#94a3b8" strokeWidth="2" fill="none"
               strokeDasharray="6 4" markerEnd="url(#dgb-arr-rub)" opacity="0.7" />
           )}
         </svg>
         <ul className="dgb-match-col">
           {lefts.map((l) => (
             <li key={l.id}>
               <button type="button" className={leftClass(l.id)}
                 ref={(el) => { leftRefs.current.set(l.id, el); }}
                 onPointerDown={(e) => startDrag(e, l.id)}
               >
                 <span className="dgb-match-drag-icon">⠿</span>
                 <span className="dgb-match-text">{l.text}</span>
                 {picks[l.id] && !submitted
                   ? <span className="dgb-match-clear" onClick={(e) => clearLeft(l.id, e)}>×</span>
                   : null}
               </button>
             </li>
           ))}
         </ul>
         <ul className="dgb-match-col">
           {rights.map((r) => (
             <li key={r.id}>
               <button type="button" className={rightClass(r.id)} disabled={submitted}
                 ref={(el) => { rightRefs.current.set(r.id, el); }}
                 onPointerEnter={() => drag && setHoverRid(r.id)}
                 onPointerLeave={() => setHoverRid(null)}
               >
                 <span className="dgb-match-text">{r.text}</span>
               </button>
             </li>
           ))}
         </ul>
       </div>
       <div className="dgb-match-actions">
         <button type="button" className="dgb-match-submit"
           onClick={handleSubmit} disabled={!allDone || submitted}>提交</button>
         {submitted && !allCorrect && (
           <button type="button" className="dgb-match-reset"
             onClick={handleReset}>重做</button>
         )}
         {submitted && (
           <span className={`dgb-match-score ${allCorrect ? 'ok' : 'ng'}`}>
             {correctCount} / {lefts.length} 正确
           </span>
         )}
       </div>
       {submitted && correctCount < lefts.length && (
         <div className="dgb-match-answer-panel">
           <div className="dgb-match-answer-title">📖 参考答案</div>
           {spec.pairs.map((p, i) => (
             <div key={i} className="dgb-match-answer-row">
               <span className="dgb-match-answer-left">{p.left}</span>
               <span className="dgb-match-answer-arrow">→</span>
               <span className="dgb-match-answer-right">{p.right}</span>
             </div>
           ))}
         </div>
       )}
       <GameWinBanner
         show={allCorrect}
         text={`🎉 全部连对！最终得分 ${score}`}
         onReplay={handleReset}
         stars={stars}
         onShow={playWin}
       />
     </div>
   );
 }

 /** 稳定洗牌：同一 spec 每次刷新顺序一致。 */
 function shuffleStable<T>(arr: readonly T[], seed: string): T[] {
   let s = 0;
   for (let i = 0; i < seed.length; i++) s = (s * 31 + seed.charCodeAt(i)) >>> 0;
   const out = arr.slice();
   for (let i = out.length - 1; i > 0; i--) {
     s = (s * 1103515245 + 12345) >>> 0;
     const j = s % (i + 1);
     [out[i], out[j]] = [out[j]!, out[i]!];
   }
   return out;
 }
