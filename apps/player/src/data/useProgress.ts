/**
 * useProgress.ts — 学习进度持久化 Hook
 *
 * 层级：
 *   L0: localStorage（离线可用，当前实现）
 *   L1: BFF API + localStorage 缓存（待后续实现）
 *
 * 数据模型：
 *   courseId → { pageId → { visited, completedAt, interactiveResults, lastVisit } }
 */
import { useState, useCallback, useEffect } from 'react';

export interface PageProgress {
  visited: boolean;
  completedAt?: string;       // ISO8601
  lastVisit: string;          // ISO8601
  interactiveResults?: Record<string, {
    correct: boolean;
    attempts: number;
    lastAttempt: string;
  }>;
}

export interface CourseProgress {
  courseId: string;
  version: number;
  pages: Record<string, PageProgress>;
  totalPages: number;
  visitedPages: number;
  completedPages: number;
  lastActivity: string;
}

const STORAGE_KEY = 'dgbook-progress';

function loadProgress(courseId: string): CourseProgress {
  try {
    const raw = localStorage.getItem(`${STORAGE_KEY}-${courseId}`);
    if (raw) return JSON.parse(raw);
  } catch { /* ignore */ }
  return {
    courseId,
    version: 1,
    pages: {},
    totalPages: 0,
    visitedPages: 0,
    completedPages: 0,
    lastActivity: new Date().toISOString(),
  };
}

function saveProgress(progress: CourseProgress): void {
  try {
    localStorage.setItem(
      `${STORAGE_KEY}-${progress.courseId}`,
      JSON.stringify(progress)
    );
  } catch { /* quota exceeded — degrade gracefully */ }
}

export function useProgress(courseId: string, totalPages: number) {
  const [progress, setProgress] = useState<CourseProgress>(() => {
    const p = loadProgress(courseId);
    p.totalPages = totalPages;
    return p;
  });

  // 持久化到 localStorage
  useEffect(() => { saveProgress(progress); }, [progress]);

  const markVisited = useCallback((pageId: string) => {
    setProgress(prev => {
      const existing = prev.pages[pageId];
      const now = new Date().toISOString();
      const updated = {
        ...prev,
        pages: {
          ...prev.pages,
          [pageId]: {
            ...existing,
            visited: true,
            lastVisit: now,
          },
        },
        lastActivity: now,
      };
      updated.visitedPages = Object.values(updated.pages).filter(p => p.visited).length;
      return updated;
    });
  }, []);

  const markCompleted = useCallback((pageId: string) => {
    setProgress(prev => {
      const now = new Date().toISOString();
      const updated = {
        ...prev,
        pages: {
          ...prev.pages,
          [pageId]: {
            ...prev.pages[pageId],
            visited: true,
            completedAt: now,
            lastVisit: now,
          },
        },
        lastActivity: now,
      };
      updated.visitedPages = Object.values(updated.pages).filter(p => p.visited).length;
      updated.completedPages = Object.values(updated.pages).filter(p => p.completedAt).length;
      return updated;
    });
  }, []);

  const recordInteractive = useCallback((pageId: string, blockId: string, correct: boolean) => {
    setProgress(prev => {
      const now = new Date().toISOString();
      const page = prev.pages[pageId] || { visited: true, lastVisit: now };
      const results = page.interactiveResults || {};
      const existing = results[blockId];
      const updated = {
        ...prev,
        pages: {
          ...prev.pages,
          [pageId]: {
            ...page,
            lastVisit: now,
            interactiveResults: {
              ...results,
              [blockId]: {
                correct: correct || existing?.correct || false,
                attempts: (existing?.attempts || 0) + 1,
                lastAttempt: now,
              },
            },
          },
        },
        lastActivity: now,
      };
      return updated;
    });
  }, []);

  const completionRate = progress.totalPages > 0
    ? Math.round(progress.visitedPages / progress.totalPages * 100)
    : 0;

  return {
    progress,
    markVisited,
    markCompleted,
    recordInteractive,
    completionRate,
  };
}
