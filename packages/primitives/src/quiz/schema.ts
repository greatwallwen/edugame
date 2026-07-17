/**
 * quiz.json v1 schema 出口。
 *
 * 真正的 zod schema 定义在 `@dgbook/types`（宪法级合约），这里只是
 * 把"原语自用的子集"对外暴露，方便消费者只 import @dgbook/blocks。
 * M3 仅支持 single-choice / multiple-choice。
 */
export {
  QuizSpecSchema,
  SingleChoiceQuizSchema,
  MultipleChoiceQuizSchema,
  QuizOptionSchema,
  type QuizSpec,
  type QuizOption,
} from '@dgbook/types';
