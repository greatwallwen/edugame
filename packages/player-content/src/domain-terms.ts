/**
 * domain-terms · 领域术语类型定义（零硬编码数据）
 *
 * 术语数据由 manifest.domainTerms 注入，平台代码只定义类型。
 */

export type DomainTermKind = string;

export interface DomainTerm {
  term: string;
  kind: DomainTermKind;
}

export interface FollowUpTemplate {
  kind: string;
  template: string;
}

