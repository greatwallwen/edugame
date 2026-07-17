/**
 * ArcadeRunnerBlock.tsx — 街机跑酷互动题型渲染组件
 *
 * 学生控制角色跑酷，收集正确知识碎片，躲避错误障碍。
 * 使用 Canvas 2D 渲染，无外部依赖。
 */
import React, { useRef, useEffect, useState, useCallback } from 'react';
import './ArcadeRunnerBlock.css';

interface Collectible {
  id: string;
  text: string;
  correct: boolean;
}

interface ArcadeRunnerSpec {
  kind: 'arcade-runner';
  prompt: string;
  theme?: 'space' | 'circuit' | 'forest' | 'ocean';
  collectibles: Collectible[];
  duration?: number;
  passThreshold?: number;
  explanation?: string;
}

interface Props {
  spec: ArcadeRunnerSpec;
}

const THEMES = {
  space: { bg: '#0a0e27', ground: '#1a1f3a', player: '#00d4ff', correct: '#4ade80', wrong: '#f87171' },
  circuit: { bg: '#1a1a2e', ground: '#16213e', player: '#e94560', correct: '#4ade80', wrong: '#f87171' },
  forest: { bg: '#2d5016', ground: '#1a3a0a', player: '#fbbf24', correct: '#4ade80', wrong: '#f87171' },
  ocean: { bg: '#0c4a6e', ground: '#164e63', player: '#38bdf8', correct: '#4ade80', wrong: '#f87171' },
};

export function ArcadeRunnerBlock({ spec }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [score, setScore] = useState(0);
  const [collected, setCollected] = useState<string[]>([]);
  const [gameState, setGameState] = useState<'ready' | 'playing' | 'won' | 'lost'>('ready');
  const [timeLeft, setTimeLeft] = useState(spec.duration || 30);

  const theme = THEMES[spec.theme || 'circuit'];
  const threshold = spec.passThreshold || Math.ceil(spec.collectibles.filter(c => c.correct).length * 0.6);

  const startGame = useCallback(() => {
    setGameState('playing');
    setScore(0);
    setCollected([]);
    setTimeLeft(spec.duration || 30);
  }, [spec.duration]);

  // 游戏主循环
  useEffect(() => {
    if (gameState !== 'playing') return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const W = canvas.width = 600;
    const H = canvas.height = 300;

    let playerY = H - 60;
    let playerVy = 0;
    let items = spec.collectibles.map((c, i) => ({
      ...c, x: W + i * 120 + Math.random() * 60, y: 100 + Math.random() * 120,
    }));
    let frameId: number;
    let localScore = 0;
    let localCollected: string[] = [];

    const jump = () => { if (playerY >= H - 62) playerVy = -8; };
    canvas.onclick = jump;
    const onKey = (e: KeyboardEvent) => { if (e.code === 'Space') { e.preventDefault(); jump(); } };
    window.addEventListener('keydown', onKey);

    const draw = () => {
      // 背景
      ctx.fillStyle = theme.bg;
      ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = theme.ground;
      ctx.fillRect(0, H - 40, W, 40);

      // 玩家
      playerVy += 0.4;
      playerY = Math.min(H - 60, playerY + playerVy);
      ctx.fillStyle = theme.player;
      ctx.beginPath();
      ctx.arc(60, playerY, 16, 0, Math.PI * 2);
      ctx.fill();

      // 碎片
      items.forEach(item => {
        item.x -= 2.5;
        if (item.x < -30) item.x = W + Math.random() * 200;

        const dist = Math.hypot(60 - item.x, playerY - item.y);
        if (dist < 28 && !localCollected.includes(item.id)) {
          localCollected.push(item.id);
          if (item.correct) localScore += 10;
          else localScore = Math.max(0, localScore - 5);
          setScore(localScore);
          setCollected([...localCollected]);
        }

        ctx.fillStyle = localCollected.includes(item.id)
          ? '#666'
          : item.correct ? theme.correct : theme.wrong;
        ctx.font = '12px sans-serif';
        ctx.fillText(item.text.substring(0, 8), item.x - 20, item.y - 12);
        ctx.beginPath();
        ctx.arc(item.x, item.y, 10, 0, Math.PI * 2);
        ctx.fill();
      });

      // HUD
      ctx.fillStyle = '#fff';
      ctx.font = '14px sans-serif';
      ctx.fillText(`得分: ${localScore}`, 10, 20);

      frameId = requestAnimationFrame(draw);
    };

    draw();

    // 倒计时
    const timer = setInterval(() => {
      setTimeLeft(prev => {
        if (prev <= 1) {
          clearInterval(timer);
          cancelAnimationFrame(frameId);
          const correctCount = localCollected.filter(id =>
            spec.collectibles.find(c => c.id === id)?.correct
          ).length;
          setGameState(correctCount >= threshold ? 'won' : 'lost');
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => {
      cancelAnimationFrame(frameId);
      clearInterval(timer);
      window.removeEventListener('keydown', onKey);
    };
  }, [gameState, spec.collectibles, theme, threshold]);

  return (
    <div className="dgb-arcade-runner">
      <div className="dgb-arcade-prompt">{spec.prompt}</div>

      {gameState === 'ready' && (
        <div className="dgb-arcade-start">
          <p>点击空格或画布跳跃，收集<span className="correct">绿色</span>知识碎片，躲避<span className="wrong">红色</span>障碍</p>
          <button onClick={startGame}>🎮 开始游戏</button>
        </div>
      )}

      {gameState === 'playing' && (
        <div className="dgb-arcade-hud">
          <span>⏱ {timeLeft}s</span>
          <span>🎯 {score} 分</span>
          <span>📦 {collected.length}/{spec.collectibles.length}</span>
        </div>
      )}

      <canvas ref={canvasRef} className="dgb-arcade-canvas"
        style={{ display: gameState === 'playing' ? 'block' : 'none' }} />

      {(gameState === 'won' || gameState === 'lost') && (
        <div className={`dgb-arcade-result ${gameState}`}>
          <h3>{gameState === 'won' ? '🎉 通关！' : '💪 再来一次'}</h3>
          <p>得分: {score} 分</p>
          {spec.explanation && <p className="explanation">{spec.explanation}</p>}
          <button onClick={startGame}>重新开始</button>
        </div>
      )}
    </div>
  );
}
