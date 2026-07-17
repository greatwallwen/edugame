import confetti from 'canvas-confetti';

export function triggerConfetti(options?: confetti.Options) {
  confetti({
    particleCount: 120,
    spread: 70,
    origin: { y: 0.6 },
    colors: ['#0E7C4A', '#B0872B', '#10915A', '#8A5A2B', '#0A5132'],
    ...options,
  });
}

export function triggerSmallConfetti() {
  confetti({
    particleCount: 60,
    spread: 50,
    origin: { y: 0.7 },
    colors: ['#0E7C4A', '#B0872B'],
    gravity: 1.2,
    scalar: 0.8,
  });
}
