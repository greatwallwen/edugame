import type { GameResult } from '../../core/types';

export interface GodotResultPresentation {
  label: '手环分' | '追光分' | '得分';
  score: number;
}

export function getGodotResultPresentation(result: GameResult): GodotResultPresentation {
	if (result.modeId !== 'godot-game') {
		return { label: '得分', score: result.score };
	}
	const stats = result.stats ?? {};
  if (typeof stats.bandScore === 'number' && Number.isFinite(stats.bandScore)) {
    return { label: '手环分', score: stats.bandScore };
  }
  if (typeof stats.solarScore === 'number' && Number.isFinite(stats.solarScore)) {
    return { label: '追光分', score: stats.solarScore };
  }
  return { label: '得分', score: result.score };
}
