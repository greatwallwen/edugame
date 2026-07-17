import { useEffect, useRef } from 'react';
import type { CourseManifest } from '@dgbook/types';
import { triggerConfetti } from '@dgbook/blocks';
import { AbilityMapPanel } from './AbilityMapPanel';
import s from './CourseHome.module.css';

interface CourseHomeProps {
  manifest: CourseManifest;
  visited: Set<string>;
  onSelectPage: (pageId: string) => void;
}

/** SVG 环形进度图（Donut Chart） */
function DonutChart({ pct, size = 72, stroke = 9, color = '#0ea5e9' }: {
  pct: number; size?: number; stroke?: number; color?: string;
}) {
  const r = (size - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const offset = circ * (1 - pct / 100);
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className={s.donut}>
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#e2e8f0" strokeWidth={stroke} />
      <circle
        cx={size / 2} cy={size / 2} r={r} fill="none"
        stroke={color} strokeWidth={stroke}
        strokeDasharray={circ} strokeDashoffset={offset}
        strokeLinecap="round"
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
        style={{ transition: 'stroke-dashoffset .6s ease' }}
      />
      <text x="50%" y="50%" dominantBaseline="central" textAnchor="middle"
        className={s.donutText} fontSize={size * 0.22} fill={color} fontWeight={700}>
        {pct}%
      </text>
    </svg>
  );
}

/** 课程主页：全章节学习路径 + 进度统计（v3 精简版） */
export function CourseHome({ manifest, visited, onSelectPage }: CourseHomeProps) {
  const bp = manifest.blueprint;

  const courseChapters = manifest.chapters.filter((ch) => !ch.id.startsWith('appendix-'));
  const allPages = courseChapters.flatMap((ch) =>
    ch.sections.flatMap((sec) => sec.pages)
  );
  const totalPages = allPages.length;
  const totalVisited = allPages.filter((p) => visited.has(p.id)).length;
  const progressPct = totalPages > 0 ? Math.round((totalVisited / totalPages) * 100) : 0;
  const estimatedMinutes = bp?.totalEstimatedMinutes ?? totalPages * 4;

  const firedRef = useRef(false);
  useEffect(() => {
    if (progressPct >= 100 && !firedRef.current) {
      firedRef.current = true;
      setTimeout(() => triggerConfetti(), 400);
    }
  }, [progressPct]);

  return (
    <div className={s.courseHome}>
      {/* ── Hero 区 ── */}
      <div className={s.hero}>
        <h1 className={s.heroTitle}>{manifest.title}</h1>
        <p className={s.heroDesc}>{bp?.learningObjectives?.slice(0, 2).join(' · ') ?? '欢迎使用本课程'}</p>
        <div className={s.heroMeta}>
          <span className={s.metaItem}>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
            {courseChapters.length} 章
          </span>
          <span className={s.metaItem}>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
            {totalPages} 课时
          </span>
          <span className={s.metaItem}>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            约 {Math.round(estimatedMinutes / 60)} 小时
          </span>
        </div>
      </div>

      {/* ── Hero 统计已由侧边栏环形进度展示，这里只保留课程简介 ── */}

      {/* ── 能力图谱：SVG矩阵布局（对标 reference/课程能力图谱.svg） ── */}
      <div className={s.abilitySection}>
        <AbilityMapPanel />
      </div>

      {/* ── 成就系统 ── */}
      {manifest.achievements && Object.keys(manifest.achievements).length > 0 && (() => {
        const achievementList = Object.values(manifest.achievements!);
        const unlocked = achievementList.filter((ach) => {
          const cond = ach.condition;
          if (cond.type === 'lesson-complete') return visited.has(cond.lessonId);
          return false;
        });
        return (
          <div className={s.achieveSection}>
            <div className={s.pathLabel}>成就徽章 <span className={s.achieveSummary}>{unlocked.length}/{achievementList.length}</span></div>
            <div className={s.achieveGrid}>
              {achievementList.map((ach) => {
                const isUnlocked = unlocked.some((u) => u.id === ach.id);
                return (
                  <div key={ach.id} className={`${s.achieveCard} ${isUnlocked ? s.achieveCardUnlocked : ''}`}
                    title={isUnlocked ? ach.description : `未解锁：${ach.description}`}
                  >
                    <span className={s.achieveIcon}>
                      {isUnlocked ? ach.icon : (
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                      )}
                    </span>
                    <span className={s.achieveName}>{ach.name}</span>
                  </div>
                );
              })}
            </div>
          </div>
        );
      })()}

    </div>
  );
}

