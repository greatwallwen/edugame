/**
 * abilityMapData.ts — 课程能力图谱数据加载器
 *
 * 数据已迁到 public/assets/ability-map.json（课程资产层），
 * 平台代码只定义类型 + 提供 fetch 加载函数。
 */
import { useState, useEffect } from 'react';

export interface WorkProcess { label: string }
export interface Skill { label: string }
export interface Project { id: string; name: string }

export interface TaskGroup {
  id: string;
  name: string;
  projects: Project[];
  workProcesses: WorkProcess[];
  skills: Skill[];
}

export interface CapItem { id: string; name: string; evidence: string }
export interface KnowledgeGroup { name: string; items: string[]; source: string }
export interface SourceCard { title: string; lines: string[]; tag: string }

export interface AbilityMapFullData {
  courseTitle: string;
  taskGroups: TaskGroup[];
  capItems: CapItem[];
  knowledgeGroups: KnowledgeGroup[];
  leftSources: SourceCard[];
  rightSources: SourceCard[];
  coursePosition: string[];
  typicalOutcomes: string[];
  teachingSupport: string[];
  profEthics: string;
  abilityPath: string;
}

const EMPTY: AbilityMapFullData = {
  courseTitle: '',
  taskGroups: [],
  capItems: [],
  knowledgeGroups: [],
  leftSources: [],
  rightSources: [],
  coursePosition: [],
  typicalOutcomes: [],
  teachingSupport: [],
  profEthics: '',
  abilityPath: '',
};

let cached: AbilityMapFullData | null = null;

export async function loadAbilityMapData(): Promise<AbilityMapFullData> {
  if (cached) return cached;
  try {
    const res = await fetch('/assets/ability-map.json');
    if (!res.ok) return EMPTY;
    cached = await res.json() as AbilityMapFullData;
    return cached;
  } catch {
    return EMPTY;
  }
}

/** React hook：异步加载能力图谱数据 */
export function useAbilityMapData(): AbilityMapFullData {
  const [data, setData] = useState<AbilityMapFullData>(cached ?? EMPTY);
  useEffect(() => {
    void loadAbilityMapData().then(setData);
  }, []);
  return data;
}

// 兼容旧 import（AbilityMapPanel / AbilityGraphScene 迁移期间）
// 这些导出在运行时为空数组，组件应改用 useAbilityMapData()
export const COURSE_TITLE = '';
export const TASK_GROUPS: TaskGroup[] = [];
export const CAP_ITEMS: CapItem[] = [];
export const KNOWLEDGE_GROUPS: KnowledgeGroup[] = [];
export const LEFT_SOURCES: SourceCard[] = [];
export const RIGHT_SOURCES: SourceCard[] = [];
export const COURSE_POSITION: string[] = [];
export const TYPICAL_OUTCOMES: string[] = [];
export const TEACHING_SUPPORT: string[] = [];
export const PROF_ETHICS = '';
export const ABILITY_PATH = '';
