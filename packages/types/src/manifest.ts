/**
 * @dgbook/types · manifest schema 入口（Iter-35 / T-2 拆分后的聚合 re-export）
 *
 * 历史：原 manifest.ts 单文件 1120 行，承担 23 block kind / 9 interactive / 4 quiz /
 * finale / page / theme / aiTutor / blueprint / achievement / report / abilityMap 等
 * 全部 schema 定义。Iter-35 / T-2 按主题拆为 6 文件 + 本聚合（详见各 manifest-*.ts 头注释）。
 *
 * 本文件仅做 re-export，不再包含任何 schema 定义。
 * 下游消费者无需感知拆分：import { ... } from '@dgbook/types' 仍然有效。
 */

export * from './manifest-core';
export * from './manifest-quiz';
export * from './manifest-interactive';
export * from './manifest-finale';
export * from './manifest-block';
export * from './manifest-page';
