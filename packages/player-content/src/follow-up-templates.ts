/**
 * follow-up-templates · 追问建议 + FAQ 派生
 *
 * 输入：question / answer / 当前页 title + 外部注入的术语词典
 * 输出：3 条针对性追问 + 派生 FAQ chips
 *
 * 平台零课程词：所有课程特定数据通过 terms / templates 参数注入。
 */
import type { Page } from '@dgbook/types';
import type { DomainTerm, FollowUpTemplate } from './domain-terms';

export interface FaqItem {
  q: string;
  a: string;
}

/** 默认通用模板（当 manifest 未提供 followUpTemplates 时使用） */
function defaultByKind(term: string, _kind?: string): string {
  return `${term} 在工程中常见的调试方法是什么？`;
}

/**
 * 给定 question + answer + page.title + 术语词典，命中领域术语后生成 3 条追问。
 */
export function generateFollowUps(
  question: string,
  answer: string,
  pageTitle?: string,
  terms?: ReadonlyArray<DomainTerm>,
  templates?: ReadonlyArray<FollowUpTemplate>,
): string[] {
  const domainTerms = terms ?? [];
  const haystack = `${answer}\n${question}\n${pageTitle ?? ''}`;
  const hits: { term: string; kind: string }[] = [];
  const seen = new Set<string>();
  for (const t of domainTerms) {
    if (seen.has(t.term)) continue;
    if (haystack.includes(t.term)) {
      hits.push(t);
      seen.add(t.term);
    }
    if (hits.length >= 3) break;
  }
  const pageTopic = (pageTitle || '本节内容').slice(0, 12);
  const primary = hits[0]?.term || pageTopic;
  const secondary = hits[1]?.term;
  const tertiary = hits[2]?.term;

  // 按 kind 查模板
  const tplMap = new Map<string, string>();
  for (const t of templates ?? []) {
    tplMap.set(t.kind, t.template);
  }
  const byKind = (term: string, kind?: string): string => {
    const tpl = kind ? tplMap.get(kind) : undefined;
    if (tpl) return tpl.replace('{term}', term);
    return defaultByKind(term, kind);
  };

  const candidates: string[] = [];
  if (hits[0]) candidates.push(byKind(hits[0].term, hits[0].kind));
  if (secondary && hits[1]) {
    candidates.push(`${primary} 和 ${secondary} 在使用上要怎么取舍？`);
  } else {
    candidates.push(`${primary} 在 ${pageTopic} 里通常和谁配合使用？`);
  }
  if (tertiary) {
    candidates.push(`${tertiary} 学到什么程度才算掌握？`);
  } else {
    candidates.push(`${primary} 调不通的时候，最快的排查顺序是什么？`);
  }

  const out: string[] = [];
  for (const c of candidates) {
    if (!out.includes(c)) out.push(c);
    if (out.length >= 3) break;
  }
  return out;
}

/**
 * derivePageFaq · 当 page 没有 digital-human block 提供 FAQ 时，
 * 从 commentary / teacher / block.title 抽 FAQ chip。
 * terms 参数注入术语词典（从 manifest.domainTerms 取）。
 */
export function derivePageFaq(page: Page, terms?: ReadonlyArray<DomainTerm>): FaqItem[] {
  const domainTerms = terms ?? [];
  const entityKeywords = domainTerms.map(t => t.term);

  const text = page.blocks
    .map((b) => {
      const x = b as typeof b & {
        commentary?: { stepScripts?: string[]; script?: string };
        metadata?: { teacher?: { stepScripts?: string[]; script?: string } };
        title?: string;
      };
      const parts: string[] = [page.title];
      if (x.title) parts.push(x.title);
      for (const s of x.commentary?.stepScripts || []) if (s) parts.push(s);
      if (x.commentary?.script) parts.push(x.commentary.script);
      for (const s of x.metadata?.teacher?.stepScripts || []) if (s) parts.push(s);
      if (x.metadata?.teacher?.script) parts.push(x.metadata.teacher.script);
      return parts.join(' ');
    })
    .join(' ');
  const seen = new Set<string>();
  const entities: string[] = [];
  for (const kw of entityKeywords) {
    if (text.includes(kw) && !seen.has(kw)) {
      entities.push(kw);
      seen.add(kw);
      if (entities.length >= 4) break;
    }
  }
  const tpls: Array<(e: string) => FaqItem> = [
    (e) => ({ q: `为什么要用${e}？`, a: `${e} 在本节的作用与典型场景。` }),
    (e) => ({ q: `${e} 与常规做法的区别？`, a: `对比说明 ${e} 与常规方式的差异。` }),
    (e) => ({ q: `${e} 的典型应用场景？`, a: `举一两个 ${e} 的实际使用例子。` }),
    (e) => ({ q: `${e} 的常见坑？`, a: `${e} 使用时的常见错误与排查思路。` }),
  ];
  return [
    { q: `本节"${page.title}"的核心要点？`, a: '按本页讲解条按顺序复述 3 个关键点。' },
    ...entities.map((e, i) => {
      const tpl = tpls[i % tpls.length]!;
      return tpl(e);
    }),
  ];
}
