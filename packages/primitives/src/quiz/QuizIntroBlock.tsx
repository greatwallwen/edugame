import { useState, useCallback, useEffect } from 'react';
import type { QuizIntroBlock as QuizIntroBlockType, QuizSpec } from '@dgbook/types';
import { motion, AnimatePresence } from 'framer-motion';
import { triggerConfetti } from '../utils/confetti';
import './QuizIntroBlock.css';

interface QuizIntroBlockProps {
  block: QuizIntroBlockType;
  quiz?: QuizSpec;
}

/**
 * QuizIntroBlock · v4.1 测验开场动画组件
 *
 * 设计：
 * - 默认显示 trigger icon（可点击）
 * - 点击后弹出模态框，播放开场动画（3-5s）
 * - 动画结束后显示测验题目
 * - 回答后显示结果动画
 */
export function QuizIntroBlock({ block, quiz }: QuizIntroBlockProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [phase, setPhase] = useState<'intro' | 'question' | 'result' | 'idle'>('idle');
  const [selectedAnswer, setSelectedAnswer] = useState<string | null>(null);
  const [showResult, setShowResult] = useState(false);

  const handleOpen = useCallback(() => {
    setIsOpen(true);
    setPhase('intro');
    setSelectedAnswer(null);
    setShowResult(false);
  }, []);

  const handleClose = useCallback(() => {
    setIsOpen(false);
    setPhase('idle');
  }, []);

  const handleIntroDone = useCallback(() => {
    setPhase('question');
  }, []);

  const isAnswerCorrect = (q: NonNullable<typeof quiz>, answer: string | null): boolean => {
    if (!q) return false;
    if ('options' in q) {
      // single-choice or multiple-choice
      return answer === q.answer;
    }
    if ('answers' in q) {
      // fill-blank
      return q.answers.includes(answer ?? '');
    }
    // true-false
    return answer === String(q.answer);
  };

  const handleSubmit = useCallback(() => {
    setShowResult(true);
    setPhase('result');
    if (quiz && isAnswerCorrect(quiz, selectedAnswer)) {
      triggerConfetti();
    }
  }, [quiz, selectedAnswer]);

  // 监听 iframe 的 postMessage（开场动画完成信号）
  useEffect(() => {
    if (phase !== 'intro') return;
    const handler = (e: MessageEvent) => {
      if (e.data?.type === 'quiz-intro-done') {
        handleIntroDone();
      }
    };
    window.addEventListener('message', handler);
    // 5s 兜底：如果动画没有发信号，自动切换
    const timer = setTimeout(handleIntroDone, 5000);
    return () => {
      window.removeEventListener('message', handler);
      clearTimeout(timer);
    };
  }, [phase, handleIntroDone]);

  if (!quiz) {
    return (
      <div className="quizIntroPlaceholder">
        <span className="quizIntroIcon">{block.triggerIcon}</span>
        <span>测验加载中...</span>
      </div>
    );
  }

  return (
    <div className="quizIntroWrapper">
      {/* Trigger Button */}
      <motion.button
        className="quizIntroTrigger"
        onClick={handleOpen}
        type="button"
        aria-label={`开始测验：${quiz.stem.slice(0, 20)}`}
        whileHover={{ scale: 1.02, y: -2 }}
        whileTap={{ scale: 0.97 }}
        transition={{ type: 'spring', stiffness: 400, damping: 18 }}
      >
        <motion.span className="quizIntroIconLarge" animate={{ y: [0, -3, 0] }} transition={{ repeat: Infinity, duration: 2, ease: 'easeInOut' }}>
          {block.triggerIcon}
        </motion.span>
        <span className="quizIntroTriggerText">挑战测验</span>
        <span className="quizIntroTriggerSub">{quiz.stem.slice(0, 40)}...</span>
      </motion.button>

      {/* Modal Overlay */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            className="quizIntroOverlay"
            onClick={(e) => { if (e.target === e.currentTarget) handleClose(); }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.25 }}
          >
            <motion.div
              className="quizIntroModal"
              role="dialog"
              aria-modal="true"
              initial={{ scale: 0.94, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.94, opacity: 0 }}
              transition={{ type: 'spring', stiffness: 300, damping: 24 }}
            >
              {/* Close button */}
              <motion.button
                className="quizIntroClose"
                onClick={handleClose}
                type="button"
                aria-label="关闭"
                whileHover={{ scale: 1.15, background: '#e2e8f0' }}
                whileTap={{ scale: 0.9 }}
              >
                ✕
              </motion.button>

              <AnimatePresence mode="wait">
                {/* Phase: Intro Animation */}
                {phase === 'intro' && (
                  <motion.div
                    key="intro"
                    className="quizIntroPhase"
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: 20 }}
                    transition={{ duration: 0.25 }}
                  >
                    <div className="quizIntroAnimContainer">
                      <iframe
                        src={`data:text/html;charset=utf-8;base64,${btoa(encodeURIComponent(block.animationSrc).replace(/%([0-9A-F]{2})/g, (_, p1) => String.fromCharCode(parseInt(p1, 16))))}`}
                        className="quizIntroIframe"
                        sandbox="allow-scripts"
                        title="测验开场动画"
                      />
                    </div>
                    <p className="quizIntroLoading">准备挑战...</p>
                  </motion.div>
                )}

                {/* Phase: Question */}
                {(phase === 'question' || phase === 'result') && (
                  <motion.div
                    key="question"
                    className="quizIntroPhase"
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: -20 }}
                    transition={{ duration: 0.25 }}
                  >
                    <div className="quizIntroBadge">{block.introType === 'experiment' ? '🧪' : block.introType === 'circuit' ? '⚡' : block.introType === 'logic' ? '🧠' : '🎯'} 知识挑战</div>
                    <h3 className="quizIntroStem">{quiz.stem}</h3>

                    {quiz.kind === 'single-choice' && (
                      <div className="quizIntroOptions">
                        {quiz.options.map((opt) => {
                          const isSelected = selectedAnswer === opt.id;
                          const isCorrect = showResult && opt.id === quiz.answer;
                          const isWrong = showResult && isSelected && opt.id !== quiz.answer;
                          return (
                            <motion.label
                              key={opt.id}
                              className={`quizIntroOption ${isSelected ? 'quizIntroOptionSelected' : ''} ${isCorrect ? 'quizIntroOptionCorrect' : ''} ${isWrong ? 'quizIntroOptionWrong' : ''}`}
                              whileHover={!showResult ? { scale: 1.015, x: 4 } : undefined}
                              whileTap={!showResult ? { scale: 0.98 } : undefined}
                              transition={{ type: 'spring', stiffness: 400, damping: 20 }}
                            >
                              <input
                                type="radio"
                                name="quiz-answer"
                                value={opt.id}
                                checked={isSelected}
                                onChange={() => setSelectedAnswer(opt.id)}
                                disabled={showResult}
                              />
                              <span className="quizIntroOptionId">{opt.id}</span>
                              <span className="quizIntroOptionLabel">{opt.label}</span>
                            </motion.label>
                          );
                        })}
                      </div>
                    )}

                    {!showResult ? (
                      <motion.button
                        className="quizIntroSubmit"
                        onClick={handleSubmit}
                        disabled={!selectedAnswer}
                        type="button"
                        whileHover={selectedAnswer ? { scale: 1.02, y: -1 } : undefined}
                        whileTap={selectedAnswer ? { scale: 0.97 } : undefined}
                        transition={{ type: 'spring', stiffness: 400, damping: 18 }}
                      >
                        提交答案
                      </motion.button>
                    ) : (
                      <motion.div
                        className="quizIntroResult"
                        initial={{ opacity: 0, scale: 0.95 }}
                        animate={{ opacity: 1, scale: 1 }}
                        transition={{ type: 'spring', stiffness: 200, damping: 18 }}
                      >
                        <motion.div
                          className="quizIntroResultIcon"
                          initial={{ scale: 0 }}
                          animate={{ scale: [1.2, 0.9, 1.1, 1] }}
                          transition={{ duration: 0.5 }}
                        >
                          {isAnswerCorrect(quiz, selectedAnswer) ? '🎉' : '💡'}
                        </motion.div>
                        <p className="quizIntroResultText">
                          {isAnswerCorrect(quiz, selectedAnswer) ? '回答正确！' : '回答错误，再想想？'}
                        </p>
                        {quiz.explanation && (
                          <p className="quizIntroExplanation">{quiz.explanation}</p>
                        )}
                        <motion.button
                          className="quizIntroRetry"
                          onClick={() => { setSelectedAnswer(null); setShowResult(false); setPhase('question'); }}
                          type="button"
                          whileHover={{ scale: 1.03, y: -1 }}
                          whileTap={{ scale: 0.97 }}
                        >
                          再试一次
                        </motion.button>
                      </motion.div>
                    )}
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
