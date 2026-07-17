export interface GodotInitGate {
  claim(): number | null;
  isCurrent(token: number): boolean;
  reset(): void;
}

export function createGodotInitGate(): GodotInitGate {
  let generation = 0;
  let claimed = false;
  return {
    claim() {
      if (claimed) return null;
      claimed = true;
      return generation;
    },
    isCurrent(token) {
      return claimed && token === generation;
    },
    reset() {
      generation += 1;
      claimed = false;
    },
  };
}

