import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface CaseDetectiveData {
  [key: string]: unknown;
}

export class CaseDetectiveMode extends GameMode<CaseDetectiveData> {
  readonly id = 'case-detective' as const;
  readonly displayName = '案例侦探';
  readonly objective = '收集线索推理结论';
  readonly howToPlay = ['案例侦探玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
