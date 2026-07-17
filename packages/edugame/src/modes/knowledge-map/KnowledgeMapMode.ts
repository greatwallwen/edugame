import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface KnowledgeMapData {
  [key: string]: unknown;
}

export class KnowledgeMapMode extends GameMode<KnowledgeMapData> {
  readonly id = 'knowledge-map' as const;
  readonly displayName = '知识地图探险';
  readonly objective = '地图探索解锁知识点';
  readonly howToPlay = ['知识地图探险玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
