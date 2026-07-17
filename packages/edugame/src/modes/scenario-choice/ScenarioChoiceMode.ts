import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface ScenarioChoiceData {
  [key: string]: unknown;
}

export class ScenarioChoiceMode extends GameMode<ScenarioChoiceData> {
  readonly id = 'scenario-choice' as const;
  readonly displayName = '情境决策';
  readonly objective = '分支剧情选择';
  readonly howToPlay = ['情境决策玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
