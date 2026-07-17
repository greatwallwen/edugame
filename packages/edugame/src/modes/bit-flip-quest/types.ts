/**
 * bit-flip-quest 关卡数据 schema
 *
 * 寄存器位运算闯关：给定 32 位寄存器初值 + 目标值 + 允许的操作，
 * 玩家从工具栏拖卡牌到位区，操作生效后计算命中度。
 */
import type { LevelData } from '../../core/types';

export type BitOp =
  | { op: 'or'; mask: number }
  | { op: 'and'; mask: number }
  | { op: 'xor'; mask: number }
  | { op: 'shl'; bits: number }
  | { op: 'shr'; bits: number };

export interface BitFlipQuestData {
  /** 寄存器宽度（8 / 16 / 32） */
  width: 8 | 16 | 32;
  /** 寄存器初值（无符号整数） */
  initial: number;
  /** 目标值（无符号整数） */
  target: number;
  /** 允许操作的次数上限（牌数） */
  cardLimit: number;
  /** 提供给玩家的可选操作池（玩家从中挑选 ≤ cardLimit 张） */
  operations: ReadonlyArray<BitOp>;
  /** 题面解释（可选） */
  explanation?: string;
}

export type BitFlipQuestLevel = LevelData<BitFlipQuestData>;
