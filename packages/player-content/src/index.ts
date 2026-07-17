export {
  type DomainTerm,
  type DomainTermKind,
  type FollowUpTemplate,
} from './domain-terms';
export {
  generateFollowUps,
  derivePageFaq,
  type FaqItem,
} from './follow-up-templates';
export { DEFAULT_AI_TUTOR, type AiTutorDefaults } from './ai-tutor-config';
export {
  useAiTutor,
  type ChatMessage,
  type ChatSource,
  type AiTutorState,
  type UseAiTutorOptions,
} from './useAiTutor';
