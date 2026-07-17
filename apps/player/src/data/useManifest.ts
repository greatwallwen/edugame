import { useEffect, useState } from 'react';
import { type CourseManifest, safeParseCourseManifest } from '@dgbook/types';

export type ManifestState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'ok'; manifest: CourseManifest }
  | { status: 'error'; message: string };

/**
 * 从 BFF 拉取课程 manifest 并用 zod 校验。
 * 路径走相对 `/api/...`，由 vite dev proxy 或生产环境同源转发。
 */
export function useManifest(courseId: string | null): ManifestState {
  const [state, setState] = useState<ManifestState>({ status: 'idle' });

  useEffect(() => {
    if (!courseId) {
      setState({ status: 'idle' });
      return;
    }
    const abort = new AbortController();
    setState({ status: 'loading' });

    (async () => {
      try {
        // 优先支持 ?manifest=./path/to.json 直接加载（测试/本地使用）
        const manifestUrl = readManifestUrlFromUrl();
        let raw: unknown;
        if (manifestUrl) {
          const res = await fetch(manifestUrl, { signal: abort.signal, headers: { accept: 'application/json' } });
          if (!res.ok) {
            setState({ status: 'error', message: `HTTP ${res.status} ${res.statusText}` });
            return;
          }
          raw = (await res.json()) as unknown;
        } else {
          const res = await fetch(`/api/courses/${encodeURIComponent(courseId)}/manifest`, {
            signal: abort.signal,
            headers: { accept: 'application/json' },
          });
          if (!res.ok) {
            setState({ status: 'error', message: `HTTP ${res.status} ${res.statusText}` });
            return;
          }
          raw = (await res.json()) as unknown;
        }
        const parsed = safeParseCourseManifest(raw);
        if (!parsed.success) {
          setState({
            status: 'error',
            message: `manifest schema invalid: ${parsed.error.issues[0]?.path.join('.') ?? ''} ${parsed.error.issues[0]?.message ?? ''}`,
          });
          return;
        }
        setState({ status: 'ok', manifest: parsed.data });
      } catch (err) {
        if ((err as Error).name === 'AbortError') return;
        setState({ status: 'error', message: (err as Error).message });
      }
    })();

    return () => abort.abort();
  }, [courseId]);

  return state;
}

/**
 * 默认课程 id：平台级单一配置点。
 * 优先取构建期环境变量 VITE_DEFAULT_COURSE_ID，未设时回退到 'stm32-course'。
 * 未来新教材只需设置该 env（或用 ?courseId= 覆盖），无需改平台代码。
 */
export const DEFAULT_COURSE_ID: string =
  (import.meta.env?.VITE_DEFAULT_COURSE_ID as string | undefined) || 'stm32-course';

/** 从当前 URL 读 `?courseId=...`（兼容 `?course=...`），没传则用默认值。 */
export function readCourseIdFromUrl(fallback = DEFAULT_COURSE_ID): string {
  if (typeof window === 'undefined') return fallback;
  const params = new URLSearchParams(window.location.search);
  const id = params.get('courseId') ?? params.get('course');
  return id && /^[a-zA-Z0-9_-]+$/.test(id) ? id : fallback;
}

/** 从当前 URL 读 `?manifest=...`，支持直接加载本地 JSON 文件进行测试。 */
export function readManifestUrlFromUrl(): string | null {
  if (typeof window === 'undefined') return null;
  const params = new URLSearchParams(window.location.search);
  return params.get('manifest');
}

/** Phase B · iframe embed 模式：
 *  - none    ：默认，独立播放器（完整 chrome）
 *  - content ：仅主舞台（隐藏 TopBar/SideNav/RightPanel/AudioBar），由宿主提供导航
 *  - full    ：保留完整 chrome，但内部知道自己被嵌入（影响品牌/postMessage 行为）
 *  通过 `?embed=content|full` 切换。 */
export type EmbedMode = 'none' | 'content' | 'full';

export function readEmbedModeFromUrl(): EmbedMode {
  if (typeof window === 'undefined') return 'none';
  const params = new URLSearchParams(window.location.search);
  const v = params.get('embed');
  if (v === 'content' || v === 'full') return v;
  return 'none';
}
