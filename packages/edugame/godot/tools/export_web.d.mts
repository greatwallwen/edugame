export interface FinalizeWebExportOptions {
  outputDir: string;
  gameId: string;
  entryFiles?: string[];
}

export interface ExportWebResult {
  gameId: string;
  hash: string;
  outputDir: string;
}

export interface PublishStagedWebExportOptions {
	outputDir: string;
	stagedOutputDir: string;
}

export interface GodotSpawnSpec {
	command: string;
	args: string[];
	options: { cwd: string; stdio: 'inherit'; shell: false };
}

export interface ConfiguredGodotGame {
	gameId: string;
	entryFiles: string[];
}

export function configuredGodotGames(): ConfiguredGodotGame[];
export function defaultGodotBinary(options?: { platform?: string }): string;
export function cleanWebExportDirectory(outputDir: string, allowedRoot: string): Promise<void>;
export function finalizeWebExport(options: FinalizeWebExportOptions): Promise<ExportWebResult>;
export function publishStagedWebExport(options: PublishStagedWebExportOptions): Promise<void>;
export function createGodotSpawnSpec(
	godotBin: string,
	args: string[],
	options?: { platform?: string; comspec?: string },
): GodotSpawnSpec;
export function exportWebGames(options: { gameIds: string[]; godotBin?: string }): Promise<ExportWebResult[]>;
