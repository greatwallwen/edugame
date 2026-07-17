/**
 * SideNav · Iter-42 P4.1+ 拆分
 *
 * 左侧目录侧栏：单环进度 + 三级章节树（chapter > section > page）+ 拖拽宽度调节。
 *
 * 抽取自 Shell.tsx，行为与拆前 1:1。Shell 仅负责状态注入，不再持有树渲染逻辑。
 */
import type { ReactElement } from 'react';
import type { OutlineNode } from './outline';
import { IconCheckCircle, IconChevron, IconFolder } from './icons';
import s from './Shell.module.css';

export interface SideNavProps {
  /** 章节大纲（chapter > section > page 三级） */
  outline: OutlineNode[];
  /** 已学完页 ID 集合（用于打勾） */
  visited: Set<string>;
  /** 当前活动 page ID，用于高亮 + 自动展开所在 section */
  effectiveActive: string;
  /** 章节展开 ID 集合 */
  expandedMods: Set<string>;
  /** 小节展开 ID 集合 */
  expandedSecs: Set<string>;
  /** 顶部搜索过滤文本 */
  filterText: string;
  /** 全部页列表（用于计算 progress） */
  pages: ReadonlyArray<unknown>;
  /** 已完成页数（用于显示 X/Y） */
  completedCount: number;
  /** 章节展开切换 */
  toggleMod: (chId: string) => void;
  /** 小节展开切换 */
  toggleSec: (secId: string) => void;
  /** 切页 */
  setActive: (pageId: string) => void;
  /** manifest 加载错误信息 */
  errorMessage?: string;
  /** sideOpen 控制 aside-hidden（拖拽时也维持当前展开态） */
  sideOpen: boolean;
  /** ProgressRing 组件由 Shell 注入，避免 SideNav 反向依赖 */
  ProgressRing: (props: { pct: number }) => ReactElement;
}

export function SideNav(props: SideNavProps) {
  const {
    outline, visited, effectiveActive, expandedMods, expandedSecs, filterText,
    pages, completedCount, toggleMod, toggleSec, setActive,
    errorMessage, sideOpen, ProgressRing,
  } = props;

  const totalPages = pages.length;
  const pct = totalPages > 0 ? Math.round((visited.size / totalPages) * 100) : 0;

  return (
    <aside className={`${s.side} ${s.sideNav}`} aria-hidden={!sideOpen}>
      <div className={s.sideProgressWrap}>
        <div className={s.sideProgressRing}>
          <ProgressRing pct={pct} />
        </div>
        <div className={s.sideProgressMeta}>
          <div className={s.sideProgressVal}>{pct}%</div>
          <div className={s.sideProgressLabel}>已学 {completedCount}/{totalPages}</div>
        </div>
      </div>
      <div className={s.sideSection}>课程目录</div>
      {errorMessage && <div className={s.sideError}>manifest 加载失败：{errorMessage}</div>}
      {outline.map((ch, chIdx) => {
        const allPages = ch.sections.flatMap((sec) => sec.pages);
        const matchedPages = filterText.trim()
          ? allPages.filter((p) => p.title.toLowerCase().includes(filterText.trim().toLowerCase()))
          : allPages;
        const chMatchesSelf = filterText.trim()
          ? ch.title.toLowerCase().includes(filterText.trim().toLowerCase())
          : true;
        if (filterText.trim() && matchedPages.length === 0 && !chMatchesSelf) return null;
        const chVisited = allPages.filter((p) => visited.has(p.id)).length;
        const isChExpanded = expandedMods.has(ch.id) || !!filterText.trim();
        return (
          <div key={ch.id} className={s.sideGroup}>
            <div
              className={s.sideGroupTitle}
              onClick={() => toggleMod(ch.id)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => { if (e.key === 'Enter') toggleMod(ch.id); }}
            >
              <span className={`${s.sideGroupChevron} ${isChExpanded ? s.sideGroupChevronOpen : ''}`}>
                <IconChevron size={14} />
              </span>
              <span className={s.sideGroupIcon}><IconFolder size={14} /></span>
              <span className={s.sideGroupText}>{chIdx + 1}. {ch.title}</span>
              <span className={s.sideGroupProgress}>{chVisited}/{allPages.length}</span>
            </div>
            {isChExpanded && (
              <div className={s.sideGroupUnits}>
                {ch.sections.map((sec) => {
                  const secPages = sec.pages;
                  const secVisited = secPages.filter((p) => visited.has(p.id)).length;
                  const secContainsActive = secPages.some(p => p.id === effectiveActive);
                  const isSecExpanded = !!filterText.trim() || expandedSecs.has(sec.id) || secContainsActive;
                  const visibleSecPages = filterText.trim() && !chMatchesSelf
                    ? secPages.filter((p) => p.title.toLowerCase().includes(filterText.trim().toLowerCase()))
                    : secPages;
                  if (filterText.trim() && visibleSecPages.length === 0) return null;
                  return (
                    <div key={sec.id} className={s.sideSection}>
                      <div
                        className={s.sideSectionTitle}
                        onClick={() => toggleSec(sec.id)}
                        role="button"
                        tabIndex={0}
                        onKeyDown={(e) => { if (e.key === 'Enter') toggleSec(sec.id); }}
                      >
                        <span className={`${s.sideSectionChevron} ${isSecExpanded ? s.sideSectionChevronOpen : ''}`}>
                          <IconChevron size={12} />
                        </span>
                        <span className={s.sideSectionText}>{sec.title}</span>
                        <span className={s.sideSectionProgress}>{secVisited}/{secPages.length}</span>
                      </div>
                      {isSecExpanded && (
                        <div className={s.sideSectionPages}>
                          {visibleSecPages.map((p) => {
                            const isVisited = visited.has(p.id);
                            const isActive = effectiveActive === p.id;
                            return (
                              <div
                                key={p.id}
                                className={`${s.sideUnit} ${isActive ? s.sideUnitActive : ''}`}
                                onClick={() => { setActive(p.id); }}
                                role="button"
                                tabIndex={0}
                                onKeyDown={(e) => { if (e.key === 'Enter') { setActive(p.id); } }}
                              >
                                <span className={s.sideUnitIcon}>
                                  {isVisited
                                    ? <IconCheckCircle size={14} color="var(--dg-color-state-success)" />
                                    : <span className={s.sideUnitDot} />}
                                </span>
                                <span className={s.sideUnitText}>{p.title}</span>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        );
      })}
    </aside>
  );
}
