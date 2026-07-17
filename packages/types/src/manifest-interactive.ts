/**
 * @dgbook/types · Interactive schema（v3-rich+ / Iter-35 拆分自 manifest.ts）
 *
 * 9 种 page 内嵌互动模块 + InteractiveSpecSchema 联合 + InteractiveBlockSchema。
 *
 * 题型清单（kind 字面量）：
 *   v3-rich   · matching          左右两列配对
 *   v4        · fill-blank        分段填空（segments + blank）
 *   v4        · spot-difference   找区别（双图/双文 + diff 区域）
 *   v4        · ordering          序列排序
 *   v4        · classification    分类拖拽
 *   v4        · hotspot           图上热点点击
 *   v4.2      · memory-match      翻牌记忆配对
 *   v4.2      · flashcard         闪卡正反面
 *   code-cloze        代码填空（多答案 + normalized/exact 校验）
 *
 * 与 QuizSpec 的边界见 manifest-quiz.ts 头注释。
 */

import { z } from 'zod';
import { BlockBase, IdSchema } from './manifest-core';

/** v3-rich · 互动学习模块。首版仅支持 'matching'（左右两列配对）。 */
export const InteractiveMatchingSchema = z.object({
  kind: z.literal('matching'),
  prompt: z.string().optional(),
  pairs: z.array(z.object({
    left: z.string().min(1),
    right: z.string().min(1),
  })).min(2).max(8),
});

/** v4 · 填空 */
export const InteractiveFillBlankSchema = z.object({
  kind: z.literal('fill-blank'),
  prompt: z.string().optional(),
  segments: z.array(
    z.union([
      z.string(),
      z.object({ blank: z.literal(true), answer: z.string().min(1), hint: z.string().optional() }),
    ])
  ).min(1),
});

/** v4 · 找区别 */
export const InteractiveSpotDifferenceSchema = z.object({
  kind: z.literal('spot-difference'),
  prompt: z.string().min(1),
  left: z.object({ type: z.enum(['text', 'image']), content: z.string().min(1) }),
  right: z.object({ type: z.enum(['text', 'image']), content: z.string().min(1) }),
  differences: z.array(z.object({
    description: z.string().min(1),
    coords: z.tuple([z.number(), z.number()]).optional(),
  })).min(1),
});

/** v4 · 排序 */
export const InteractiveOrderingSchema = z.object({
  kind: z.literal('ordering'),
  prompt: z.string().optional(),
  items: z.array(z.object({ id: IdSchema, text: z.string().min(1) })).min(2),
  correctOrder: z.array(IdSchema).min(2),
});

/** v4 · 分类 */
export const InteractiveClassificationSchema = z.object({
  kind: z.literal('classification'),
  prompt: z.string().optional(),
  categories: z.array(z.object({ id: IdSchema, label: z.string().min(1) })).min(2),
  items: z.array(z.object({
    id: IdSchema,
    text: z.string().min(1),
    correctCategory: IdSchema,
  })).min(2),
});

/** v4 · 热点点击 */
export const InteractiveHotspotSchema = z.object({
  kind: z.literal('hotspot'),
  prompt: z.string().min(1),
  image: z.string().min(1),
  hotspots: z.array(z.object({
    id: IdSchema,
    description: z.string().min(1),
    x: z.number(),
    y: z.number(),
    radius: z.number().positive(),
  })).min(1),
});

/** v4.2 · 记忆配对 */
export const InteractiveMemoryMatchSchema = z.object({
  kind: z.literal('memory-match'),
  prompt: z.string().optional(),
  pairs: z.array(z.object({
    id: IdSchema,
    front: z.string().min(1),
    back: z.string().min(1),
  })).min(3).max(12),
});

/** v4.2 · 闪卡 */
export const InteractiveFlashcardSchema = z.object({
  kind: z.literal('flashcard'),
  prompt: z.string().optional(),
  cards: z.array(z.object({
    id: IdSchema,
    front: z.string().min(1),
    back: z.string().min(1),
    hint: z.string().optional(),
  })).min(2).max(20),
});


export const InteractiveCodeClozeSchema = z.object({
  kind: z.literal('code-cloze'),
  prompt: z.string().optional(),
  language: z.enum(['c', 'cpp', 'python', 'verilog', 'javascript', 'typescript']),
  /** 代码模板，{{blank-id}} 标识填空位 */
  template: z.string().min(1),
  /** 每个 blank 的可接受答案列表 */
  blanks: z.array(z.object({
    id: IdSchema,
    /** 一个 blank 可接受多个等价答案 */
    accepted: z.array(z.string().min(1)).min(1),
    /** 解释：该位置的语义（提交后展示） */
    rationale: z.string().optional(),
  })).min(1).max(10),
  /** 校验级别：exact 严格相等 / normalized 去首尾空格（默认） */
  validate: z.enum(['exact', 'normalized']).default('normalized'),
});


export const InteractiveBitFlipSchema = z.object({
  kind: z.literal('bit-flip'),
  prompt: z.string().min(1).max(200),
  /** 寄存器名（仅显示用，例如 "PORTA->ODR"）*/
  registerName: z.string().min(1).max(40).optional(),
  /** 初始值（0-255）*/
  initial: z.number().int().min(0).max(255),
  /** 目标值（0-255）*/
  target: z.number().int().min(0).max(255),
  /** 提交后的原理解释（如"PIN_5 是 bit5，OR 1<<5 = 0x20"）*/
  explanation: z.string().max(400).optional(),
  /** bit 标签数组（长度 8，从低位到高位 bit0..bit7），用于业务命名（如 "PA0..PA7"）；
   *  缺省时显示 "bit0..bit7"。*/
  bitLabels: z.array(z.string().min(1).max(10)).length(8).optional(),
});

// ════════════ 13 种通用题型（平台能力，内容来自教材资产）════════════

/** 单选题：一组选项选 1 个正确答案 */
export const InteractiveSingleChoiceSchema = z.object({
  kind: z.literal('single-choice'),
  prompt: z.string().min(1).max(300),
  options: z.array(z.object({ id: IdSchema, text: z.string().min(1) })).min(2).max(8),
  answer: IdSchema,
  explanation: z.string().max(400).optional(),
});

/** 多选题：选出全部正确项（部分对不得分） */
export const InteractiveMultipleChoiceSchema = z.object({
  kind: z.literal('multiple-choice'),
  prompt: z.string().min(1).max(300),
  options: z.array(z.object({ id: IdSchema, text: z.string().min(1) })).min(3).max(10),
  answers: z.array(IdSchema).min(1),
  explanation: z.string().max(400).optional(),
});

/** 判断题：一组陈述句逐条判对错 */
export const InteractiveTrueFalseSchema = z.object({
  kind: z.literal('true-false'),
  prompt: z.string().max(300).optional(),
  statements: z.array(z.object({
    id: IdSchema,
    text: z.string().min(1),
    correct: z.boolean(),
    rationale: z.string().max(300).optional(),
  })).min(2).max(12),
});

/** 计时快答：限时内连续作答单选小题，倒计时驱动紧迫感 */
export const InteractiveTimedQuizSchema = z.object({
  kind: z.literal('timed-quiz'),
  prompt: z.string().max(300).optional(),
  /** 总时长（秒） */
  seconds: z.number().int().min(10).max(600),
  questions: z.array(z.object({
    id: IdSchema,
    stem: z.string().min(1),
    options: z.array(z.string().min(1)).min(2).max(6),
    /** 正确选项下标（0-based） */
    answer: z.number().int().min(0),
  })).min(2).max(20),
});

/** 滑块估值：拖动滑块到目标值（容差判定） */
export const InteractiveSliderEstimateSchema = z.object({
  kind: z.literal('slider-estimate'),
  prompt: z.string().min(1).max(300),
  min: z.number(),
  max: z.number(),
  step: z.number().positive().optional(),
  target: z.number(),
  /** 容差（绝对值），缺省 (max-min)*0.03 */
  tolerance: z.number().min(0).optional(),
  unit: z.string().max(16).optional(),
  explanation: z.string().max(400).optional(),
});

/** 流程拼装：从打乱的候选步骤里按正确顺序逐个选入流程槽（区别于 ordering 的整体重排） */
export const InteractiveSequenceBuilderSchema = z.object({
  kind: z.literal('sequence-builder'),
  prompt: z.string().min(1).max(300),
  /** 候选步骤（含干扰项可选） */
  steps: z.array(z.object({ id: IdSchema, text: z.string().min(1) })).min(3).max(10),
  /** 正确顺序（id 序列；可少于 steps，多余为干扰项） */
  correctSequence: z.array(IdSchema).min(2),
  explanation: z.string().max(400).optional(),
});

/** 真值表填写：给逻辑表达式，填每行输出列（0/1） */
export const InteractiveTruthTableSchema = z.object({
  kind: z.literal('truth-table'),
  prompt: z.string().min(1).max(300),
  /** 输入变量名（如 ['A','B']） */
  inputs: z.array(z.string().min(1).max(8)).min(1).max(4),
  /** 输出列名（如 ['Y']），与每行 outputs 等长 */
  outputs: z.array(z.string().min(1).max(8)).min(1).max(3),
  /** 每行：inputs 组合（0/1 数组）+ 期望输出（0/1 数组） */
  rows: z.array(z.object({
    in: z.array(z.union([z.literal(0), z.literal(1)])).min(1),
    out: z.array(z.union([z.literal(0), z.literal(1)])).min(1),
  })).min(2).max(16),
  explanation: z.string().max(400).optional(),
});

/** 进制转换：把给定数从源进制转到目标进制并输入 */
export const InteractiveBaseConverterSchema = z.object({
  kind: z.literal('base-converter'),
  prompt: z.string().max(300).optional(),
  /** 题目数组：每题给一个值与源/目标进制 */
  tasks: z.array(z.object({
    id: IdSchema,
    value: z.string().min(1),
    fromBase: z.union([z.literal(2), z.literal(8), z.literal(10), z.literal(16)]),
    toBase: z.union([z.literal(2), z.literal(8), z.literal(10), z.literal(16)]),
    answer: z.string().min(1),
  })).min(1).max(10),
});

/** 寄存器配置器：用下拉/位选配置多个字段，使寄存器值达到目标（通用硬件配置抽象）*/
export const InteractiveRegisterConfigSchema = z.object({
  kind: z.literal('register-config'),
  prompt: z.string().min(1).max(300),
  registerName: z.string().min(1).max(40).optional(),
  fields: z.array(z.object({
    id: IdSchema,
    label: z.string().min(1),
    /** 候选取值（显示文案 → 期望选中文案为 answer） */
    options: z.array(z.string().min(1)).min(2).max(8),
    answer: z.string().min(1),
    hint: z.string().max(120).optional(),
  })).min(2).max(8),
  explanation: z.string().max(400).optional(),
});

/** 波形参数调节器：调频率/占空比等参数使波形匹配目标（容差判定，实时预览） */
export const InteractiveWaveformTunerSchema = z.object({
  kind: z.literal('waveform-tuner'),
  prompt: z.string().min(1).max(300),
  /** 可调参数（频率/占空比/幅值等），每个一个滑块 */
  params: z.array(z.object({
    id: IdSchema,
    label: z.string().min(1),
    min: z.number(),
    max: z.number(),
    step: z.number().positive().optional(),
    target: z.number(),
    tolerance: z.number().min(0).optional(),
    unit: z.string().max(12).optional(),
  })).min(1).max(4),
  /** 波形类型（仅预览渲染用） */
  waveform: z.enum(['square', 'sine', 'sawtooth', 'triangle']).optional(),
  explanation: z.string().max(400).optional(),
});

/** 按序点击热点：在图上按正确顺序依次点击热点 */
export const InteractiveHotspotSequenceSchema = z.object({
  kind: z.literal('hotspot-sequence'),
  prompt: z.string().min(1),
  image: z.string().min(1).optional(),
  hotspots: z.array(z.object({
    id: IdSchema,
    label: z.string().min(1),
    x: z.number(),
    y: z.number(),
    radius: z.number().positive().optional(),
  })).min(2).max(10),
  /** 正确点击顺序（id 序列） */
  correctOrder: z.array(IdSchema).min(2),
  explanation: z.string().max(400).optional(),
});

/** 拖标签到目标位：把文字标签拖到图上对应锚点（标签↔锚点配对） */
export const InteractiveDragLabelSchema = z.object({
  kind: z.literal('drag-label'),
  prompt: z.string().min(1),
  image: z.string().min(1).optional(),
  /** 目标锚点（位置 + 期望标签 id） */
  targets: z.array(z.object({
    id: IdSchema,
    x: z.number(),
    y: z.number(),
    answer: IdSchema,
  })).min(2).max(8),
  /** 可拖标签 */
  labels: z.array(z.object({ id: IdSchema, text: z.string().min(1) })).min(2).max(8),
  explanation: z.string().max(400).optional(),
});

/** 参数匹配：一组滑块同时调到各自目标（综合调参，全部命中才通关） */
export const InteractiveParameterMatchSchema = z.object({
  kind: z.literal('parameter-match'),
  prompt: z.string().min(1).max(300),
  params: z.array(z.object({
    id: IdSchema,
    label: z.string().min(1),
    min: z.number(),
    max: z.number(),
    step: z.number().positive().optional(),
    target: z.number(),
    tolerance: z.number().min(0).optional(),
    unit: z.string().max(12).optional(),
  })).min(2).max(6),
  explanation: z.string().max(400).optional(),
});

/**
 * 信号时序描点（第 24 种题型）
 *
 * 学生在时序波形图上标记关键时刻（上升沿/下降沿/采样点/中断触发等），
 * 系统判定标记位置是否在容差范围内。适用于信号处理/通信协议/时序分析等教学场景。
 *
 * Bloom 层级：L4（分析波形结构）/ L3（应用信号知识标记时刻）
 */
export const InteractiveSignalTraceSchema = z.object({
  kind: z.literal('signal-trace'),
  prompt: z.string().min(1).max(300),
  /** 波形数据点（x 为时间，y 为电平 0/1 或模拟值 0~1）*/
  waveform: z.array(z.object({
    x: z.number(),
    y: z.number(),
  })).min(4).max(200),
  /** 需要标记的关键时刻 */
  markers: z.array(z.object({
    id: IdSchema,
    label: z.string().min(1),
    /** 正确的 x 坐标 */
    x: z.number(),
    /** 容差（绝对值），缺省 waveform 总时长的 3% */
    tolerance: z.number().min(0).optional(),
    /** 标记类型提示 */
    markerType: z.enum(['rising-edge', 'falling-edge', 'sample', 'trigger', 'custom']).optional(),
  })).min(1).max(8),
  /** x 轴单位（如 "ms", "μs"）*/
  xUnit: z.string().max(8).optional(),
  /** y 轴标签（如 "PA0 电平"）*/
  yLabel: z.string().max(30).optional(),
  explanation: z.string().max(400).optional(),
});

/**
 * 第 25 种题型：register-decoder 寄存器位段解码
 *
 * 用途：给定一个寄存器十六进制值，学生为每个关键位段选择正确含义/取值。
 *   比 bit-flip 更进阶——bit-flip 是改单 bit，本题型是分析整段寄存器的语义。
 *   例：PORTx_CRL=0x4444_4444 → 每 4 位一组（MODE+CNF），选出对应工作模式。
 * Bloom 层级：L4（分析寄存器位段语义）/ L5（评估配置正确性）
 */
export const InteractiveRegisterDecoderSchema = z.object({
  kind: z.literal('register-decoder'),
  prompt: z.string().min(1).max(300),
  /** 寄存器名（如 "GPIOA->CRL"）*/
  registerName: z.string().min(1).max(40),
  /** 寄存器十六进制值（如 "0x44444444"）*/
  registerValue: z.string().min(1).max(20),
  /** 待解码的位段，每段给出位范围与选项 */
  fields: z.array(z.object({
    id: IdSchema,
    /** 位段标签（如 "MODE0 [1:0]"）*/
    label: z.string().min(1).max(40),
    /** 候选含义 */
    options: z.array(z.string().min(1)).min(2).max(6),
    /** 正确选项索引 */
    answer: z.number().int().min(0),
  })).min(2).max(8),
  explanation: z.string().max(400).optional(),
});

/**
 * 第 26 种题型：arcade-runner 街机跑酷游戏
 *
 * 用途：学生控制角色跑酷，收集正确知识点碎片（如正确的配置步骤），
 *   躲避错误选项障碍物。融合知识评测与游戏化体验。
 * Bloom 层级：L2（理解正确概念） / L3（在时间压力下应用知识）
 */
export const InteractiveArcadeRunnerSchema = z.object({
  kind: z.literal('arcade-runner'),
  prompt: z.string().min(1).max(300),
  /** 游戏主题（影响视觉风格） */
  theme: z.enum(['space', 'circuit', 'forest', 'ocean']).optional(),
  /** 要收集的正确知识碎片 */
  collectibles: z.array(z.object({
    id: IdSchema,
    text: z.string().min(1).max(60),
    correct: z.boolean(),
  })).min(4).max(20),
  /** 游戏时长（秒） */
  duration: z.number().int().min(15).max(120).optional(),
  /** 通关需要收集的正确碎片数 */
  passThreshold: z.number().int().min(1).optional(),
  explanation: z.string().max(400).optional(),
});
export const InteractiveSpecSchema = z.discriminatedUnion('kind', [
  InteractiveMatchingSchema,
  InteractiveFillBlankSchema,
  InteractiveSpotDifferenceSchema,
  InteractiveOrderingSchema,
  InteractiveClassificationSchema,
  InteractiveHotspotSchema,
  InteractiveMemoryMatchSchema,
  InteractiveFlashcardSchema,
  InteractiveCodeClozeSchema,

  InteractiveBitFlipSchema,
  InteractiveSingleChoiceSchema,
  InteractiveMultipleChoiceSchema,
  InteractiveTrueFalseSchema,
  InteractiveTimedQuizSchema,
  InteractiveSliderEstimateSchema,
  InteractiveSequenceBuilderSchema,
  InteractiveTruthTableSchema,
  InteractiveBaseConverterSchema,
  InteractiveRegisterConfigSchema,
  InteractiveWaveformTunerSchema,
  InteractiveHotspotSequenceSchema,
  InteractiveDragLabelSchema,
  InteractiveParameterMatchSchema,
  InteractiveSignalTraceSchema,
  InteractiveRegisterDecoderSchema,
  InteractiveArcadeRunnerSchema,
]);
export type InteractiveSpec = z.infer<typeof InteractiveSpecSchema>;

export const InteractiveBlockSchema = BlockBase.extend({
  kind: z.literal('interactive'),
  spec: InteractiveSpecSchema,
});
