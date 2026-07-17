import { Shell } from './shell/Shell';
import { readCourseIdFromUrl, readEmbedModeFromUrl, useManifest } from './data/useManifest';

export function App() {
  // 不传参 → 用 DEFAULT_COURSE_ID（env 可配），不在此硬编码课程 id
  const courseId = readCourseIdFromUrl();
  const embedMode = readEmbedModeFromUrl();
  const state = useManifest(courseId);
  return <Shell courseId={courseId} state={state} embedMode={embedMode} />;
}
