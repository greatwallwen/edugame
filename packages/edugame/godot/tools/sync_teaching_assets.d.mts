export interface TeachingAssetResult {
  assets: Array<{ id: string; gameId: string; hash: string; source: string }>;
}

export function syncTeachingAssets(options: {
  repositoryRoot: string;
  mode?: 'sync' | 'check';
}): Promise<TeachingAssetResult>;
