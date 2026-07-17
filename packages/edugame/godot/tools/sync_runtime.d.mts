export interface RuntimeTarget {
  name: string;
  directory: string;
}

export interface SyncRuntimeOptions {
  sourceDir: string;
  gamesDir: string;
  mode?: 'sync' | 'check';
  extraTargets?: RuntimeTarget[];
}

export interface RuntimeFileDigest {
  path: string;
  sha256: string;
}

export interface RuntimeManifest {
  version: number;
  sourceHash: string;
  files: RuntimeFileDigest[];
}

export interface SyncRuntimeResult {
  games: string[];
  manifest: RuntimeManifest;
}

export function syncRuntime(options: SyncRuntimeOptions): Promise<SyncRuntimeResult>;
