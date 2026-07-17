/**
 * ai-tutor-config · AI 助教默认元数据
 *
 * manifest.aiTutor 缺省时使用本配置兜底，让 Shell.tsx 不再硬编码文案。
 */

export interface AiTutorDefaults {
  name: string;
  subtitle: string;
  welcome: string;
}

export const DEFAULT_AI_TUTOR: AiTutorDefaults = {
  name: '课程助教',
  subtitle: '随堂问答 · 课堂伙伴',
  welcome: '你好，我会基于本课内容解答疑问，也可以点下方「本节快问」直接开始。',
};
